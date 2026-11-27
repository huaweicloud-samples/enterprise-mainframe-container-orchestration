# ============================================================================
# 引导基础设施：Terraform 状态存储桶（OBS）
# ============================================================================
# 本目录一次性运行，创建 OBS 桶用于承载 Terraform 状态文件。
# OBS backend 原生支持 state locking（并发写入保护），无需额外锁表。
# 用法：
#   1. 配置好凭据后在本目录执行 terraform init && terraform apply
#   2. 在根目录 infra/ 将 backend "local" 改为 backend "obs"，填入桶名
# ============================================================================

terraform {
  required_version = ">= 1.3"

  required_providers {
    huaweicloud = {
      source  = "huaweicloud/huaweicloud"
      version = "~> 1.94"
    }
  }
}

provider "huaweicloud" {
  region = var.region
}

variable "region" {
  type    = string
  default = "cn-north-4"
}

variable "bucket_name" {
  description = "OBS 桶名（全局唯一）"
  type        = string
  default     = "mainframe-orchestration-terraform-state"
}

resource "huaweicloud_obs_bucket" "tfstate" {
  bucket        = var.bucket_name
  acl           = "private"
  versioning    = true
  force_destroy = false

  lifecycle {
    prevent_destroy = true
  }

  lifecycle_rule {
    name    = "expire-noncurrent-versions"
    enabled = true
    prefix  = ""

    noncurrent_version_expiration {
      days = 30
    }
  }

  tags = {
    Name = "terraform-state-backend"
  }
}

output "state_bucket" {
  value = huaweicloud_obs_bucket.tfstate.bucket
}