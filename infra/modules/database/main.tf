# ============================================================================
# 数据库模块：PostgreSQL 主备 + 凭据 + 备份
# ============================================================================
# 提供业务数据库（主备高可用）：
#   - RDS for PostgreSQL（主备，2 节点）
#   - 参数组（max_locks_per_transaction / datestyle / max_connections）
#   - 管理员 / 业务用户凭据（CSMS 凭据管理）
#   - 云备份（CBR）定时备份策略
# ============================================================================

variable "stack_prefix" {
  type = string
}

variable "region" {
  type = string
}

variable "azs" {
  type = list(string)
}

variable "subnets" {
  type = list(string)
}

variable "vpc_id" {
  type = string
}

variable "db_security_group_id" {
  type = string
}

variable "db_flavor" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "kms_key_id" {
  type = string
}

# -------------------------------------------------------------------------
# 随机密码 + CSMS 凭据（管理员 / 业务用户）
# -------------------------------------------------------------------------
resource "random_password" "admin_password" {
  length  = 16
  special = true
}

resource "random_password" "user_password" {
  length  = 16
  special = true
}

# 管理员凭据（对外暴露 db_password 变量优先；随机密码供无变量场景兜底）
resource "huaweicloud_csms_secret" "db_admin" {
  name        = "${var.stack_prefix}-db-password"
  description = "Database admin credentials"
  secret_text = var.db_password != "" ? var.db_password : random_password.admin_password.result
}

resource "huaweicloud_csms_secret" "db_user" {
  name        = "${var.stack_prefix}-user-database-password"
  description = "Runtime database user credentials"
  secret_text = random_password.user_password.result
}

# -------------------------------------------------------------------------
# 数据库参数组
# -------------------------------------------------------------------------
resource "huaweicloud_rds_parametergroup" "main" {
  name        = "${var.stack_prefix}-db-parameter-group"
  description = "PostgreSQL parameter group for mainframe workload"

  datastore {
    type    = "postgresql"
    version = "16"
  }

  values = {
    max_locks_per_transaction = "100"
    max_connections           = "1600"
  }
}

# -------------------------------------------------------------------------
# RDS for PostgreSQL（主备）
# -------------------------------------------------------------------------
resource "huaweicloud_rds_instance" "main" {
  name              = "${var.stack_prefix}-postgresql"
  flavor            = var.db_flavor
  vpc_id            = var.vpc_id
  subnet_id         = var.subnets[0]
  security_group_id = var.db_security_group_id
  availability_zone = var.azs
  param_group_id    = huaweicloud_rds_parametergroup.main.id

  db {
    type     = "PostgreSQL"
    version  = "16"
    password = var.db_password != "" ? var.db_password : random_password.admin_password.result
    port     = 5432
  }

  volume {
    type = "CLOUDSSD"
    size = 100
  }

  # 主备高可用
  ha_replication_mode = "async"

  backup_strategy {
    start_time = "02:00-03:00"
    keep_days  = 5
  }

  tags = {
    Name = "${var.stack_prefix}-db"
  }
}

# -------------------------------------------------------------------------
# 云备份（CBR）：数据库定时备份
# -------------------------------------------------------------------------
resource "huaweicloud_cbr_policy" "main" {
  name      = "${var.stack_prefix}-db-backup-policy"
  type      = "backup"
  time_zone = "UTC+08:00"

  backup_cycle {
    interval        = 1
    execution_times = ["04:00"]
  }

  # 保留最近 14 个每日备份；数量上限兜底，防止存储库无限增长
  long_term_retention {
    daily = 14
  }
  backup_quantity = 30
}

resource "huaweicloud_cbr_vault" "main" {
  name             = "${var.stack_prefix}-db-backup-vault"
  type             = "server"
  protection_type  = "backup"
  size             = 200
  consistent_level = "app_consistent"
  policy_id        = huaweicloud_cbr_policy.main.id
  auto_bind        = true
  auto_expand      = true

  tags = {
    Name = "${var.stack_prefix}-db-backup-vault"
  }
}

# -------------------------------------------------------------------------
# 输出
# -------------------------------------------------------------------------
output "db_instance_id" {
  value = huaweicloud_rds_instance.main.id
}

output "db_node_ids" {
  value = huaweicloud_rds_instance.main.nodes[*].id
}

output "db_private_endpoint" {
  value = huaweicloud_rds_instance.main.private_ips[0]
}

output "db_private_dns" {
  value = try(huaweicloud_rds_instance.main.private_dns_names[0], "")
}

output "db_user_secret_name" {
  value = huaweicloud_csms_secret.db_user.name
}

output "db_admin_secret_name" {
  value = huaweicloud_csms_secret.db_admin.name
}