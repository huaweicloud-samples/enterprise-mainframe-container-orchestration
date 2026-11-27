# ============================================================================
# 存储模块：输入 / 输出对象存储桶
# ============================================================================
# 批处理任务从输入桶读取数据、向输出桶写入结果。
# 桶开启版本化、服务端加密、生命周期清理与公共访问封锁。
# ============================================================================

variable "stack_prefix" {
  type = string
}

resource "huaweicloud_obs_bucket" "input" {
  bucket        = "${var.stack_prefix}-inputs"
  acl           = "private"
  versioning    = true
  force_destroy = true

  # 服务端加密（SSE-KMS 由 kms 模块密钥承载；此处用 OBS 默认 AES256）
  encryption    = true
  sse_algorithm = "AES256"

  lifecycle_rule {
    name    = "expire-after-1-year"
    enabled = true
    prefix  = ""
    expiration {
      days = 365
    }
  }

  tags = {
    Name = "${var.stack_prefix}-inputs"
  }
}

resource "huaweicloud_obs_bucket" "output" {
  bucket        = "${var.stack_prefix}-outputs"
  acl           = "private"
  versioning    = true
  force_destroy = true

  encryption    = true
  sse_algorithm = "AES256"

  lifecycle_rule {
    name    = "expire-after-1-year"
    enabled = true
    prefix  = ""
    expiration {
      days = 365
    }
  }

  tags = {
    Name = "${var.stack_prefix}-outputs"
  }
}

# -------------------------------------------------------------------------
# 输出
# -------------------------------------------------------------------------
output "input_bucket_name" {
  value = huaweicloud_obs_bucket.input.bucket
}

output "output_bucket_name" {
  value = huaweicloud_obs_bucket.output.bucket
}

output "input_bucket_id" {
  value = huaweicloud_obs_bucket.input.id
}

output "output_bucket_id" {
  value = huaweicloud_obs_bucket.output.id
}