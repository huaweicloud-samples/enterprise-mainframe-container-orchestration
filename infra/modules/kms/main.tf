# ============================================================================
# 密钥模块：数据加密主密钥
# ============================================================================
# 供数据库存储加密、凭据加密使用；密钥启用轮换。
# ============================================================================

variable "stack_prefix" {
  type = string
}

resource "huaweicloud_kms_key" "main" {
  key_alias       = "${var.stack_prefix}-kms-key-v2"
  key_description = "KMS key for the mainframe application orchestration"
  pending_days    = "7"
  is_enabled      = true

}

# -------------------------------------------------------------------------
# 输出
# -------------------------------------------------------------------------
output "kms_key_id" {
  value = huaweicloud_kms_key.main.id
}