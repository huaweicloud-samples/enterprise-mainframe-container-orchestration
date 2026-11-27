# ============================================================================
# 变量定义
# ============================================================================

variable "region" {
  description = "华为云区域"
  type        = string
  default     = "cn-north-4"
}

variable "stack_prefix" {
  description = "资源命名前缀"
  type        = string
  default     = "mainframe-orchestration"
}

variable "vpc_cidr" {
  description = "VPC 网段"
  type        = string
  default     = "172.16.0.0/23"
}

variable "az_count" {
  description = "可用区数量（2 表示主备/多 AZ）"
  type        = number
  default     = 2
}

variable "azs" {
  description = "所选可用区列表（需与 region 匹配，如 cn-north-4a/cn-north-4b）"
  type        = list(string)
  default     = ["cn-north-4a", "cn-north-4b"]
}

variable "db_flavor" {
  description = "关系数据库实例规格"
  type        = string
  default     = "rds.pg.n1.large.2.ha"
}

variable "container_image" {
  description = "业务容器镜像（大型机现代化应用镜像，替换为实际 SWR 镜像地址）"
  type        = string
  default     = "swr.cn-north-4.myhuaweicloud.com/mainframe-orchestration/bluage-runtime:latest"
}

variable "target_environment" {
  description = "目标环境（dev/test/prod），影响批处理导出时间参数"
  type        = string
  default     = "dev"
}

variable "additional_elb_ingress_cidrs" {
  description = "内部负载均衡额外入站网段（默认仅同 VPC）"
  type        = list(string)
  default     = ["10.0.0.0/16", "10.1.0.0/16"]
}

variable "direct_internet_access_required" {
  description = "批处理任务是否需直连互联网（false 时仅走内网，不启用 NAT 网关）"
  type        = bool
  default     = false
}

variable "cce_cluster_flavor" {
  description = "CCE 集群规格（cce.s1.small 单AZ / cce.s2.small 多AZ）"
  type        = string
  default     = "cce.s1.small"
}

variable "cce_node_flavor" {
  description = "CCE 节点规格"
  type        = string
  default     = "s6.large.2"
}

variable "cce_node_count" {
  description = "CCE 节点数量"
  type        = number
  default     = 2
}

variable "cce_node_password" {
  description = "CCE 节点登录密码（8-26 位，含大小写字母+数字+特殊字符；也可改用 key_pair）"
  type        = string
  sensitive   = true
}

variable "cce_node_key_pair" {
  description = "CCE 节点密钥对名称（与密码二选一；为空则使用密码）"
  type        = string
  default     = ""
}

variable "db_password" {
  description = "关系数据库管理员密码（8-128 位，含大小写字母+数字+特殊字符）"
  type        = string
  sensitive   = true
}

variable "realtime_replicas" {
  description = "实时服务副本数"
  type        = number
  default     = 2
}

variable "batch_tasks" {
  description = "批处理任务清单（每项对应一个一次性 Job）"
  type = list(object({
    name        = string
    cpu         = string
    memory      = string
    jdbc_params = string
  }))
  default = [
    {
      name        = "module1"
      cpu         = "500m"
      memory      = "1024Mi"
      jdbc_params = "defaultRowFetchSize=1500"
    },
    {
      name        = "module2"
      cpu         = "2000m"
      memory      = "12Gi"
      jdbc_params = "defaultRowFetchSize=1500"
    },
  ]
}