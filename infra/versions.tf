# ============================================================================
# 大型机现代化应用容器化编排环境（Terraform）
# ============================================================================
# 本工程为大型机（mainframe）应用现代化后的容器化运行提供模块化编排环境：
#   - 私有网络（VPC/子网/NAT/安全组）
#   - 对象存储（输入/输出桶）
#   - 数据加密密钥
#   - 关系数据库（PostgreSQL 主备）
#   - 容器编排平台（CCE 集群 + 节点池）
#   - 批处理任务（一次性 Job）与实时服务（Deployment + 内部 ELB）
#   - 监控告警（云监控 + 消息通知）
# 各能力按模块拆分，可直接复用或按需裁剪。
# ============================================================================

terraform {
  required_version = ">= 1.3"

  required_providers {
    huaweicloud = {
      source  = "huaweicloud/huaweicloud"
      version = "~> 1.94"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # 状态文件建议存储到 OBS 桶（生产环境取消注释并按环境填写）
  backend "local" {
    # backend "obs" {
    #   bucket = "mainframe-orchestration-tfstate"
    #   key    = "enterprise-mainframe-container-orchestration/terraform.tfstate"
    #   region = "cn-north-4"
    # }
  }
}

# ============================================================================
# Provider 配置
# ============================================================================

provider "huaweicloud" {
  region = var.region
  # 凭据通过环境变量设置（推荐）：
  #   export HW_ACCESS_KEY="your-access-key"
  #   export HW_SECRET_KEY="your-secret-key"
  # 或使用云上委托（agency）自动获取
}

# Kubernetes Provider：连接 CCE 集群（证书经 base64decode，见 provider 约定）
provider "kubernetes" {
  host                   = huaweicloud_cce_cluster.main.certificate_clusters[0].server
  cluster_ca_certificate = base64decode(huaweicloud_cce_cluster.main.certificate_clusters[0].certificate_authority_data)
  client_certificate     = base64decode(huaweicloud_cce_cluster.main.certificate_users[0].client_certificate_data)
  client_key             = base64decode(huaweicloud_cce_cluster.main.certificate_users[0].client_key_data)
}