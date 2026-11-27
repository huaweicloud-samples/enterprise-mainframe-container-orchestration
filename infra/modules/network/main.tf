# ============================================================================
# 网络模块：VPC / 子网 / NAT / 安全组
# ============================================================================
# 本模块为编排环境提供私有网络底座：
#   - VPC + 私有/公有子网（按可用区数量生成）
#   - 可选 NAT 网关（direct_internet_access_required=true 时启用，否则依赖内网）
#   - 数据库安全组 / 实时服务安全组
# ============================================================================

variable "stack_prefix" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "az_count" {
  type = number
}

variable "azs" {
  type = list(string)
}

variable "additional_elb_ingress_cidrs" {
  type    = list(string)
  default = ["10.0.0.0/16", "10.1.0.0/16"]
}

variable "direct_internet_access_required" {
  type    = bool
  default = false
}

# -------------------------------------------------------------------------
# VPC
# -------------------------------------------------------------------------
resource "huaweicloud_vpc" "main" {
  name = "${var.stack_prefix}-vpc"
  cidr = var.vpc_cidr

  tags = {
    Name = "${var.stack_prefix}-vpc"
  }
}

# -------------------------------------------------------------------------
# 私有子网（业务工作负载、数据库）
# -------------------------------------------------------------------------
resource "huaweicloud_vpc_subnet" "private" {
  count      = var.az_count
  name       = "${var.stack_prefix}-private-subnet-${count.index + 1}"
  vpc_id     = huaweicloud_vpc.main.id
  cidr       = cidrsubnet(var.vpc_cidr, 3, count.index)
  gateway_ip = cidrhost(cidrsubnet(var.vpc_cidr, 3, count.index), 1)
}

# -------------------------------------------------------------------------
# 公有子网（NAT 网关、负载均衡 VIP 所在）
# -------------------------------------------------------------------------
resource "huaweicloud_vpc_subnet" "public" {
  count      = var.az_count
  name       = "${var.stack_prefix}-public-subnet-${count.index + 1}"
  vpc_id     = huaweicloud_vpc.main.id
  cidr       = cidrsubnet(var.vpc_cidr, 3, var.az_count + count.index)
  gateway_ip = cidrhost(cidrsubnet(var.vpc_cidr, 3, var.az_count + count.index), 1)
}

# -------------------------------------------------------------------------
# 直连互联网（可选）：NAT 网关 + SNAT，供批处理任务出公网
# -------------------------------------------------------------------------
resource "huaweicloud_vpc_eip" "nat" {
  count = var.direct_internet_access_required ? var.az_count : 0

  publicip {
    type = "5_bgp"
  }
  bandwidth {
    name        = "${var.stack_prefix}-nat-bw-${count.index + 1}"
    size        = 5
    share_type  = "PER"
    charge_mode = "traffic"
  }
}

resource "huaweicloud_nat_gateway" "main" {
  count = var.direct_internet_access_required ? 1 : 0

  name      = "${var.stack_prefix}-nat-gw"
  spec      = "1"
  vpc_id    = huaweicloud_vpc.main.id
  subnet_id = huaweicloud_vpc_subnet.public[0].id
}

resource "huaweicloud_nat_snat_rule" "private" {
  count = var.direct_internet_access_required ? var.az_count : 0

  nat_gateway_id = huaweicloud_nat_gateway.main[0].id
  subnet_id      = huaweicloud_vpc_subnet.private[count.index].id
  # 绑定该子网出网 EIP（此处用第一个 EIP 演示 SNAT 绑定）
  floating_ip_id = huaweicloud_vpc_eip.nat[count.index].id
}

# -------------------------------------------------------------------------
# 数据库安全组（仅同组互通 + 私网访问 PostgreSQL）
# -------------------------------------------------------------------------
resource "huaweicloud_networking_secgroup" "db" {
  name        = "${var.stack_prefix}-db-security-group"
  description = "Enables access to the PostgreSQL service"
}

# 允许同安全组内互通（数据库节点间复制）
resource "huaweicloud_networking_secgroup_rule" "db_self" {
  security_group_id = huaweicloud_networking_secgroup.db.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 5432
  port_range_max    = 5432
  remote_group_id   = huaweicloud_networking_secgroup.db.id
}

# 允许同 VPC 私网访问 PostgreSQL
resource "huaweicloud_networking_secgroup_rule" "db_vpc" {
  security_group_id = huaweicloud_networking_secgroup.db.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 5432
  port_range_max    = 5432
  remote_ip_prefix  = var.vpc_cidr
}

resource "huaweicloud_networking_secgroup_rule" "db_egress" {
  security_group_id = huaweicloud_networking_secgroup.db.id
  direction         = "egress"
  ethertype         = "IPv4"
  remote_ip_prefix  = "0.0.0.0/0"
}

# -------------------------------------------------------------------------
# 实时服务安全组（内部负载均衡健康检查 + 同 VPC 访问 3090）
# -------------------------------------------------------------------------
resource "huaweicloud_networking_secgroup" "service" {
  name        = "${var.stack_prefix}-service-security-group"
  description = "Enables access to the realtime services"
}

resource "huaweicloud_networking_secgroup_rule" "service_ingress" {
  security_group_id = huaweicloud_networking_secgroup.service.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 3090
  port_range_max    = 3090
  remote_ip_prefix  = var.vpc_cidr
}

resource "huaweicloud_networking_secgroup_rule" "service_ingress_extra" {
  count = length(var.additional_elb_ingress_cidrs)

  security_group_id = huaweicloud_networking_secgroup.service.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 3090
  port_range_max    = 3090
  remote_ip_prefix  = var.additional_elb_ingress_cidrs[count.index]
}

resource "huaweicloud_networking_secgroup_rule" "service_egress" {
  security_group_id = huaweicloud_networking_secgroup.service.id
  direction         = "egress"
  ethertype         = "IPv4"
  remote_ip_prefix  = "0.0.0.0/0"
}

# -------------------------------------------------------------------------
# 输出
# -------------------------------------------------------------------------
output "vpc_id" {
  value = huaweicloud_vpc.main.id
}

output "private_subnet_ids" {
  value = huaweicloud_vpc_subnet.private[*].id
}

output "public_subnet_ids" {
  value = huaweicloud_vpc_subnet.public[*].id
}

output "public_subnet_ipv4_ids" {
  value = huaweicloud_vpc_subnet.public[*].ipv4_subnet_id
}

output "db_security_group_id" {
  value = huaweicloud_networking_secgroup.db.id
}

output "service_sg_id" {
  value = huaweicloud_networking_secgroup.service.id
}