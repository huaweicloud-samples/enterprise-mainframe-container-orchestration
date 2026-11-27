# ============================================================================
# 根模块：编排各能力模块
# ============================================================================

# -------------------------------------------------------------------------
# 网络模块：VPC / 子网 / NAT / 安全组
# -------------------------------------------------------------------------
module "network" {
  source = "./modules/network"

  stack_prefix                    = var.stack_prefix
  vpc_cidr                        = var.vpc_cidr
  az_count                        = var.az_count
  azs                             = var.azs
  additional_elb_ingress_cidrs    = var.additional_elb_ingress_cidrs
  direct_internet_access_required = var.direct_internet_access_required
}

# -------------------------------------------------------------------------
# 存储模块：输入 / 输出对象存储桶
# -------------------------------------------------------------------------
module "storage" {
  source = "./modules/storage"

  stack_prefix = var.stack_prefix
}

# -------------------------------------------------------------------------
# 密钥模块：数据加密主密钥
# -------------------------------------------------------------------------
module "kms" {
  source = "./modules/kms"

  stack_prefix = var.stack_prefix
}

# -------------------------------------------------------------------------
# 数据库模块：PostgreSQL 主备 + 凭据 + 备份
# -------------------------------------------------------------------------
module "database" {
  source = "./modules/database"

  stack_prefix         = var.stack_prefix
  region               = var.region
  azs                  = var.azs
  subnets              = module.network.private_subnet_ids
  vpc_id               = module.network.vpc_id
  db_security_group_id = module.network.db_security_group_id
  db_flavor            = var.db_flavor
  db_password          = var.db_password
  kms_key_id           = module.kms.kms_key_id
}

# -------------------------------------------------------------------------
# 权限模块：容器平台访问对象存储的委托
# -------------------------------------------------------------------------
module "iam" {
  source = "./modules/iam"

  stack_prefix  = var.stack_prefix
  region        = var.region
  input_bucket  = module.storage.input_bucket_name
  output_bucket = module.storage.output_bucket_name
}

# -------------------------------------------------------------------------
# 容器平台：CCE 集群 + 节点池
# -------------------------------------------------------------------------
resource "huaweicloud_cce_cluster" "main" {
  name                   = "${var.stack_prefix}-cce"
  flavor_id              = var.cce_cluster_flavor
  vpc_id                 = module.network.vpc_id
  subnet_id              = module.network.private_subnet_ids[0]
  container_network_type = "vpc-router"
  cluster_type           = "VirtualMachine"

  # 私网场景下集群 API 走内网；如需从公网管理，可绑定 EIP
  # eip = huaweicloud_vpc_eip.cluster_api.address

  delete_all = true

  tags = {
    Name = "${var.stack_prefix}-cce-cluster"
  }
}

# CCE 节点密钥对（ARM64 平台 provider crypt 不可用，必须用密钥对替代密码）
resource "tls_private_key" "cce_node" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "huaweicloud_kps_keypair" "cce_node" {
  name       = "${var.stack_prefix}-cce-node-key"
  public_key = tls_private_key.cce_node.public_key_openssh
}

resource "huaweicloud_cce_node_pool" "main" {
  cluster_id         = huaweicloud_cce_cluster.main.id
  name               = "${var.stack_prefix}-nodepool"
  flavor_id          = var.cce_node_flavor
  os                 = "Huawei Cloud EulerOS 2.0"
  initial_node_count = var.cce_node_count
  availability_zone  = var.azs[0]
  subnet_id          = module.network.private_subnet_ids[0]
  key_pair           = huaweicloud_kps_keypair.cce_node.name

  root_volume {
    size       = 40
    volumetype = "SSD"
  }
  data_volumes {
    size       = 100
    volumetype = "SSD"
  }

  # 运行期扩缩容由 CCE 自动管理，避免下一次 apply 回滚
  lifecycle {
    ignore_changes = [initial_node_count]
  }
}

# 日志：LTS 日志组（容器日志汇聚）
resource "huaweicloud_lts_group" "main" {
  group_name  = "${var.stack_prefix}-log-group"
  ttl_in_days = 30
}

resource "huaweicloud_lts_stream" "main" {
  group_id    = huaweicloud_lts_group.main.id
  stream_name = "${var.stack_prefix}-container-logs"
  ttl_in_days = 30
}

# -------------------------------------------------------------------------
# 镜像仓库：SWR 组织 + 仓库（业务镜像推送入口）
# -------------------------------------------------------------------------
resource "huaweicloud_swr_organization" "main" {
  name = var.stack_prefix
}

resource "huaweicloud_swr_repository" "main" {
  organization = huaweicloud_swr_organization.main.name
  name         = "bluage-runtime"
  description  = "大型机现代化应用运行时镜像"
  is_public    = false
}

# -------------------------------------------------------------------------
# 批处理模块：一次性 Job + 通知
# -------------------------------------------------------------------------
module "batch" {
  source = "./modules/batch"

  stack_prefix        = var.stack_prefix
  namespace           = kubernetes_namespace.main.metadata[0].name
  container_image     = var.container_image
  batch_tasks         = var.batch_tasks
  input_bucket        = module.storage.input_bucket_name
  output_bucket       = module.storage.output_bucket_name
  database_name       = "mainframe_db"
  db_user_secret_name = module.database.db_user_secret_name
  db_endpoint         = module.database.db_private_endpoint
  smn_topic_urn       = huaweicloud_smn_topic.batch_notifications.topic_urn
}

# -------------------------------------------------------------------------
# 实时服务模块：内部 ELB + Deployment
# -------------------------------------------------------------------------
module "realtime_service" {
  source = "./modules/realtime_service"

  stack_prefix           = var.stack_prefix
  namespace              = kubernetes_namespace.main.metadata[0].name
  container_image        = var.container_image
  replicas               = var.realtime_replicas
  vpc_id                 = module.network.vpc_id
  public_subnet_ids      = module.network.public_subnet_ids
  public_subnet_ipv4_ids = module.network.public_subnet_ipv4_ids
  az                     = var.azs[0]
  service_sg_id          = module.network.service_sg_id
  db_security_group_id   = module.network.db_security_group_id
  db_user_secret_name    = module.database.db_user_secret_name
  db_endpoint            = module.database.db_private_endpoint
  database_name          = "mainframe_db"
}

# -------------------------------------------------------------------------
# 监控模块：云监控告警 + 消息通知
# -------------------------------------------------------------------------
module "monitoring" {
  source = "./modules/monitoring"

  stack_prefix    = var.stack_prefix
  region          = var.region
  db_instance_id  = module.database.db_instance_id
  db_node_ids     = module.database.db_node_ids
  input_bucket    = module.storage.input_bucket_name
  output_bucket   = module.storage.output_bucket_name
  cce_cluster_id  = huaweicloud_cce_cluster.main.id
  elb_id          = module.realtime_service.elb_id
  alert_topic_urn = huaweicloud_smn_topic.alerts.topic_urn
}

# -------------------------------------------------------------------------
# 消息通知主题（批处理结果、监控告警共用）
# -------------------------------------------------------------------------
resource "huaweicloud_smn_topic" "batch_notifications" {
  name         = "${var.stack_prefix}-batch-notifications"
  display_name = "${var.stack_prefix} batch job notifications"
}

resource "huaweicloud_smn_topic" "alerts" {
  name         = "${var.stack_prefix}-alerts"
  display_name = "${var.stack_prefix} alert notifications"
}

# -------------------------------------------------------------------------
# Kubernetes 命名空间（业务工作负载统一放置）
# -------------------------------------------------------------------------
resource "kubernetes_namespace" "main" {
  metadata {
    name = var.stack_prefix
  }
}