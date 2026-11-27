# ============================================================================
# 权限模块：容器平台访问对象存储的委托
# ============================================================================
# 通过 IAM 委托，让 CCE 节点具备读取输入桶 / 写入输出桶的权限。
# （相当于工作负载侧的对象存储访问通道；敏感凭据仍走 CSMS）
# ============================================================================

variable "stack_prefix" {
  type = string
}

variable "region" {
  type = string
}

variable "input_bucket" {
  type = string
}

variable "output_bucket" {
  type = string
}

resource "huaweicloud_iam_agency" "cce_obs" {
  name                  = "${var.stack_prefix}-cce-obs-agency"
  description           = "Allows CCE nodes to access OBS buckets"
  delegated_domain_name = "op_svc_cce"
  # 委托给 CCE 节点后，通过项目角色授予对象存储操作权限
  project_role {
    project = var.region
    roles   = ["OBS OperateAccess"]
  }
}

# -------------------------------------------------------------------------
# 输出
# -------------------------------------------------------------------------
output "cce_obs_agency_name" {
  value = huaweicloud_iam_agency.cce_obs.name
}

output "cce_obs_agency_id" {
  value = huaweicloud_iam_agency.cce_obs.id
}