# ============================================================================
# 监控模块：云监控告警 + 消息通知
# ============================================================================
# 云监控告警：
#   - 数据库：CPU / 内存 / 连接数 / 存储空间 / 读延迟
#   - 负载均衡：健康主机数
#   - 集群级运行状态告警（节点不可用）
# 告警动作统一发送到 SMN 主题（订阅邮件/短信/函数等由使用者按需配置）。
# 事件类规则（如密钥删除/桶策略变更）在华为云经 CTS 与 SMN 通知订阅，
# Terraform 侧保留通知渠道，规则订阅建议在云审计服务控制台配置。
# ============================================================================

variable "stack_prefix" {
  type = string
}

variable "region" {
  type = string
}

variable "db_instance_id" {
  type = string
}

variable "db_node_ids" {
  type = list(string)
}

variable "input_bucket" {
  type = string
}

variable "output_bucket" {
  type = string
}

variable "cce_cluster_id" {
  type = string
}

variable "elb_id" {
  type = string
}

# 告警通知动作（由根模块传入 SMN 主题 URN）
variable "alert_topic_urn" {
  type = string
}

# -------------------------------------------------------------------------
# 数据库告警：CPU 使用率
# -------------------------------------------------------------------------
resource "huaweicloud_ces_alarmrule" "db_cpu" {
  alarm_name        = "${var.stack_prefix}-db-cpu-alarm"
  alarm_description = "数据库 CPU 使用率过高"

  metric {
    namespace   = "SYS.RDS"
    metric_name = "rds001_cpu_util"
    dimensions {
      name  = "instance_id"
      value = var.db_instance_id
    }
  }

  condition {
    comparison_operator = ">"
    period              = 300
    filter              = "average"
    value               = 80
    count               = 2
  }

  alarm_actions {
    type              = "notification"
    notification_list = [var.alert_topic_urn]
  }

  alarm_enabled = true
}

# -------------------------------------------------------------------------
# 数据库告警：内存使用率
# -------------------------------------------------------------------------
resource "huaweicloud_ces_alarmrule" "db_memory" {
  alarm_name        = "${var.stack_prefix}-db-memory-alarm"
  alarm_description = "数据库内存使用率过高"

  metric {
    namespace   = "SYS.RDS"
    metric_name = "rds002_mem_util"
    dimensions {
      name  = "instance_id"
      value = var.db_instance_id
    }
  }

  condition {
    comparison_operator = ">"
    period              = 300
    filter              = "average"
    value               = 85
    count               = 2
  }

  alarm_actions {
    type              = "notification"
    notification_list = [var.alert_topic_urn]
  }

  alarm_enabled = true
}

# -------------------------------------------------------------------------
# 数据库告警：连接数
# -------------------------------------------------------------------------
resource "huaweicloud_ces_alarmrule" "db_connections" {
  alarm_name        = "${var.stack_prefix}-db-connections-alarm"
  alarm_description = "数据库连接数过多"

  metric {
    namespace   = "SYS.RDS"
    metric_name = "rds003_connections"
    dimensions {
      name  = "instance_id"
      value = var.db_instance_id
    }
  }

  condition {
    comparison_operator = ">"
    period              = 300
    filter              = "average"
    value               = 1000
    count               = 2
  }

  alarm_actions {
    type              = "notification"
    notification_list = [var.alert_topic_urn]
  }

  alarm_enabled = true
}

# -------------------------------------------------------------------------
# 数据库告警：存储空间
# -------------------------------------------------------------------------
resource "huaweicloud_ces_alarmrule" "db_storage" {
  alarm_name        = "${var.stack_prefix}-db-storage-alarm"
  alarm_description = "数据库存储空间不足"

  metric {
    namespace   = "SYS.RDS"
    metric_name = "rds004_bytes_in"
    dimensions {
      name  = "instance_id"
      value = var.db_instance_id
    }
  }

  condition {
    comparison_operator = ">"
    period              = 300
    filter              = "average"
    value               = 80
    count               = 2
  }

  alarm_actions {
    type              = "notification"
    notification_list = [var.alert_topic_urn]
  }

  alarm_enabled = true
}

# -------------------------------------------------------------------------
# 数据库告警：读延迟（主备复制延迟）
# -------------------------------------------------------------------------
resource "huaweicloud_ces_alarmrule" "db_replication_delay" {
  alarm_name        = "${var.stack_prefix}-db-replication-delay-alarm"
  alarm_description = "数据库主备延迟过高"

  metric {
    namespace   = "SYS.RDS"
    metric_name = "rds012_replication_delay"
    dimensions {
      name  = "instance_id"
      value = var.db_instance_id
    }
  }

  condition {
    comparison_operator = ">"
    period              = 300
    filter              = "average"
    value               = 10
    count               = 2
  }

  alarm_actions {
    type              = "notification"
    notification_list = [var.alert_topic_urn]
  }

  alarm_enabled = true
}

# -------------------------------------------------------------------------
# 负载均衡告警：健康主机数
# -------------------------------------------------------------------------
resource "huaweicloud_ces_alarmrule" "elb_healthy_hosts" {
  alarm_name        = "${var.stack_prefix}-realtime-healthy-hosts"
  alarm_description = "实时服务健康后端主机数过低"

  metric {
    namespace   = "SYS.ELB"
    metric_name = "m1_critica"
    dimensions {
      name  = "lb_instance_id"
      value = var.elb_id
    }
  }

  condition {
    comparison_operator = "<"
    period              = 300
    filter              = "average"
    value               = 1
    count               = 1
  }

  alarm_actions {
    type              = "notification"
    notification_list = [var.alert_topic_urn]
  }

  alarm_enabled = true
}

# -------------------------------------------------------------------------
# 集群告警：容器集群节点不可用
# -------------------------------------------------------------------------
resource "huaweicloud_ces_alarmrule" "cce_node_status" {
  alarm_name        = "${var.stack_prefix}-cce-node-status"
  alarm_description = "容器集群 CPU 使用率告警"

  metric {
    namespace   = "SYS.CCE"
    metric_name = "cpu_usage"
    dimensions {
      name  = "cluster_id"
      value = var.cce_cluster_id
    }
  }

  condition {
    comparison_operator = ">="
    period              = 300
    filter              = "average"
    value               = 80
    count               = 1
  }

  alarm_actions {
    type              = "notification"
    notification_list = [var.alert_topic_urn]
  }

  alarm_enabled = true
}

# -------------------------------------------------------------------------
# 输出
# -------------------------------------------------------------------------
output "alarm_rule_ids" {
  value = [
    huaweicloud_ces_alarmrule.db_cpu.id,
    huaweicloud_ces_alarmrule.db_memory.id,
    huaweicloud_ces_alarmrule.db_connections.id,
    huaweicloud_ces_alarmrule.db_storage.id,
    huaweicloud_ces_alarmrule.db_replication_delay.id,
    huaweicloud_ces_alarmrule.elb_healthy_hosts.id,
    huaweicloud_ces_alarmrule.cce_node_status.id,
  ]
}