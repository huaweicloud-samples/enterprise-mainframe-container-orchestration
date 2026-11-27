# ============================================================================
# 批处理模块：一次性 Job + 通知
# ============================================================================
# 每个 batch_task 对应一个 Kubernetes Job：
#   - 从输入桶读取数据，处理后写入输出桶
#   - 容器通过环境变量获取数据库地址 / 用户凭据名
#   - 结果通知发往 SMN 主题（批处理结果订阅）
# 运行模式：执行一次、结束即退出。
# ============================================================================

variable "stack_prefix" {
  type = string
}

variable "namespace" {
  type = string
}

variable "container_image" {
  type = string
}

variable "batch_tasks" {
  type = list(object({
    name        = string
    cpu         = string
    memory      = string
    jdbc_params = string
  }))
}

variable "input_bucket" {
  type = string
}

variable "output_bucket" {
  type = string
}

variable "database_name" {
  type = string
}

variable "db_user_secret_name" {
  type = string
}

variable "db_endpoint" {
  type = string
}

variable "smn_topic_urn" {
  type = string
}

# -------------------------------------------------------------------------
# 批处理任务 Job（for_each 循环）
# -------------------------------------------------------------------------
resource "kubernetes_job_v1" "batch" {
  for_each = { for t in var.batch_tasks : t.name => t }

  metadata {
    name      = "${var.stack_prefix}-${each.value.name}"
    namespace = var.namespace
  }

  spec {
    backoff_limit = 2

    template {
      metadata {
        labels = {
          app = "${var.stack_prefix}-${each.value.name}"
        }
      }

      spec {
        restart_policy = "Never"

        container {
          name  = "${var.stack_prefix}_${each.value.name}_module"
          image = var.container_image
          args  = ["./wrapper.sh", "BATCH", each.value.name, var.input_bucket, var.output_bucket]

          resources {
            requests = {
              cpu    = each.value.cpu
              memory = each.value.memory
            }
            limits = {
              cpu    = each.value.cpu
              memory = each.value.memory
            }
          }

          env {
            name  = "OBS_INPUT_BUCKET"
            value = var.input_bucket
          }
          env {
            name  = "OBS_OUTPUT_BUCKET"
            value = var.output_bucket
          }
          env {
            name  = "DB_NAME"
            value = var.database_name
          }
          env {
            name  = "DB_ENDPOINT"
            value = var.db_endpoint
          }
          env {
            name  = "JDBC_PARAMETERS"
            value = each.value.jdbc_params
          }
          env {
            name  = "NOTIFICATION_TOPIC"
            value = var.smn_topic_urn
          }
          env {
            name  = "DB_USER_SECRET"
            value = var.db_user_secret_name
          }
        }
      }
    }
  }
}

# -------------------------------------------------------------------------
# 输出
# -------------------------------------------------------------------------
output "batch_job_names" {
  value = [for t in var.batch_tasks : "${var.stack_prefix}-${t.name}"]
}