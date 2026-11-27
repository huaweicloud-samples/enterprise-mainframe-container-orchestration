# ============================================================================
# 实时服务模块：内部负载均衡 + 常驻 Deployment
# ============================================================================
# 实时接口（如大型机 CICS/联机交易）以常驻容器服务承载：
#   - 内部网络型负载均衡（ELB，端口 3090，TCP）
#   - Kubernetes Deployment（副本数可调）
#   - Service 以 LoadBalancer 类型挂到 ELB（CCE 云控制器自动注册后端 Pod）
# 内部网络型负载均衡 → 常驻容器服务（负载均衡后端直挂 Pod IP）。
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

variable "replicas" {
  type = number
}

variable "vpc_id" {
  type = string
}

variable "az" {
  type = string
}

variable "public_subnet_ipv4_ids" {
  type = list(string)
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "service_sg_id" {
  type = string
}

variable "db_security_group_id" {
  type = string
}

variable "db_user_secret_name" {
  type = string
}

variable "db_endpoint" {
  type = string
}

variable "database_name" {
  type = string
}

# -------------------------------------------------------------------------
# 内部网络型负载均衡（ELB，L4 TCP/UDP，不绑 EIP）
# -------------------------------------------------------------------------
data "huaweicloud_elb_flavors" "l4_elastic" {
  type = "L4_elastic_max"
}

resource "huaweicloud_elb_loadbalancer" "realtime" {
  name = "${var.stack_prefix}-realtime-elb"
  # 网络型内部负载均衡（provider 1.94 loadbalancer_type 仅支持 gateway，留空默认为普通应用/网络型）
  # 类型由 l4_flavor_id 决定：L4 弹性档即网络型，不绑 EIP 即内部
  vpc_id            = var.vpc_id
  availability_zone = [var.az]
  ipv4_subnet_id    = var.public_subnet_ipv4_ids[0]
  cross_vpc_backend = false

  # 显式指定 L4 弹性规格（用量型）；数据源按 type 精确匹配
  # L4 弹性档仅此一档（L4_flavor.elb.pro.max），ids[0] 结果唯一
  l4_flavor_id = data.huaweicloud_elb_flavors.l4_elastic.ids[0]

  tags = {
    Name = "${var.stack_prefix}-realtime-elb"
  }
}

# 实时服务安全组入站规则已由网络模块放行 3090；
# 如需对 ELB 健康检查放行，可追加 huaweicloud_networking_secgroup_rule。

# -------------------------------------------------------------------------
# Kubernetes 工作负载：实时服务 Deployment（端口 3090）
# -------------------------------------------------------------------------
resource "kubernetes_deployment_v1" "realtime" {
  metadata {
    name      = "${var.stack_prefix}-realtime"
    namespace = var.namespace
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = {
        app = "${var.stack_prefix}-realtime"
      }
    }

    template {
      metadata {
        labels = {
          app = "${var.stack_prefix}-realtime"
        }
      }

      spec {
        container {
          name  = "bluage_realtime_interface"
          image = var.container_image
          args  = ["./wrapper.sh", "REALTIME"]

          port {
            container_port = 3090
            protocol       = "TCP"
          }

          env {
            name  = "OBS_INPUT_BUCKET"
            value = ""
          }
          env {
            name  = "OBS_OUTPUT_BUCKET"
            value = ""
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
            name  = "DB_USER_SECRET"
            value = var.db_user_secret_name
          }
        }
      }
    }
  }
}

# Kubernetes Service：LoadBalancer 挂到 Terraform 创建的内部 ELB
# 注解说明：
#   kubernetes.io/elb.id    —— 复用已创建的 ELB（不是 loadbalance）
#   kubernetes.io/elb.class —— 独享型 = performance
# CCE 云控制器会自动在该 ELB 上创建监听器与后端池并注册 Pod IP。
resource "kubernetes_service_v1" "realtime" {
  metadata {
    name      = "${var.stack_prefix}-realtime"
    namespace = var.namespace

    annotations = {
      "kubernetes.io/elb.id"    = huaweicloud_elb_loadbalancer.realtime.id
      "kubernetes.io/elb.class" = "performance"
    }
  }

  spec {
    type = "LoadBalancer"

    selector = {
      app = "${var.stack_prefix}-realtime"
    }

    port {
      name        = "realtime-3090"
      port        = 3090
      target_port = 3090
      protocol    = "TCP"
    }
  }
}

# -------------------------------------------------------------------------
# 输出
# -------------------------------------------------------------------------
output "elb_id" {
  value = huaweicloud_elb_loadbalancer.realtime.id
}

output "elb_address" {
  value = try(huaweicloud_elb_loadbalancer.realtime.ipv4_address, "")
}

output "realtime_deployment_name" {
  value = kubernetes_deployment_v1.realtime.metadata[0].name
}