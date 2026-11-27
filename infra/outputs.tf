# ============================================================================
# 输出
# ============================================================================

output "cce_cluster_id" {
  description = "CCE 集群 ID"
  value       = huaweicloud_cce_cluster.main.id
}

output "cce_cluster_endpoint" {
  description = "CCE 集群 API 内网地址"
  value       = huaweicloud_cce_cluster.main.certificate_clusters[0].server
}

output "swr_repository" {
  description = "业务镜像仓库地址（推送镜像后替换 container_image 变量）"
  value       = "${var.region}.swr.myhuaweicloud.com/${huaweicloud_swr_organization.main.name}/${huaweicloud_swr_repository.main.name}"
}

output "input_bucket" {
  description = "批处理输入桶"
  value       = module.storage.input_bucket_name
}

output "output_bucket" {
  description = "批处理输出桶"
  value       = module.storage.output_bucket_name
}

output "db_private_endpoint" {
  description = "数据库内网地址（供容器环境变量引用）"
  value       = module.database.db_private_endpoint
}

output "realtime_elb_address" {
  description = "实时服务内部负载均衡地址（端口 3090）"
  value       = module.realtime_service.elb_address
}

output "batch_smn_topic" {
  description = "批处理结果通知主题"
  value       = huaweicloud_smn_topic.batch_notifications.topic_urn
}

output "alert_smn_topic" {
  description = "监控告警通知主题"
  value       = huaweicloud_smn_topic.alerts.topic_urn
}

output "kubeconfig" {
  description = "CCE 集群 kubeconfig（用于 kubectl 验证）"
  value       = huaweicloud_cce_cluster.main.kube_config_raw
  sensitive   = true
}