# 部署指导书（Deployment Guide）

本文档说明如何在华为云上部署 `enterprise-mainframe-container-orchestration` 容器化编排环境。

## 0. 总览

| 项 | 值 |
|---|---|
| 部署目录 | `infra/` |
| Region | `cn-north-4`（可配置） |
| 主要资源 | VPC、CCE 集群 + 节点池、SWR 仓库、RDS PostgreSQL 主备、OBS 桶、ELB、SMN、CES 告警 |
| Terraform | `>= 1.3.0` |

## 1. 前置检查

1. 已开通华为云账号并完成实名认证；
2. 账号具备 IAM **Tenant Administrator** 或等效权限；
3. 本机安装 Terraform（`>= 1.3.0`）；
4. 已在华为云『我的凭证』页面获取 AK/SK（Access Key ID / Secret Access Key）。

## 2. （可选）创建 Terraform 状态存储桶

本仓库默认使用本地 state（`backend "local"`）。若需团队共享 state，可先运行引导目录创建 OBS 状态桶：

```bash
cd infra/bootstrap-terraform
cp terraform.tfvars.example terraform.tfvars 2>/dev/null || true
terraform init
terraform apply -auto-approve
```

然后修改 `infra/versions.tf` 中的 backend 配置：

```hcl
backend "obs" {
  bucket = "<state-bucket-name>"   # 上面创建的桶
  key    = "enterprise-mainframe-container-orchestration/terraform.tfstate"
  region = "cn-north-4"
}
```

再回到 `infra/` 重新 `terraform init -migrate-state`。

> 说明：OBS backend 原生支持 state locking，无需额外锁表。

## 3. 部署步骤

### 3.1 配置凭据

```bash
export HW_ACCESS_KEY="<your-access-key>"
export HW_SECRET_KEY="<your-secret-key>"
```

> 凭据仅作环境变量使用，不要写入任何代码或配置文件。

### 3.2 配置变量

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars
vi terraform.tfvars
```

必填项：

| 变量 | 说明 |
|---|---|
| `db_password` | 数据库管理员密码（8-128 位，含大小写+数字+特殊字符） |
| `cce_node_password` 或 `cce_node_key_pair` | CCE 节点认证，二选一 |

按环境调整项：

| 变量 | 默认值 | 建议 |
|---|---|---|
| `region` | `cn-north-4` | 与账号可用区对齐 |
| `azs` | `cn-north-4a`,`cn-north-4b` | 与 region 匹配 |
| `stack_prefix` | `mainframe-orchestration` | 多环境隔离用不同前缀 |
| `direct_internet_access_required` | `false` | 批处理需出公网时置 `true` |

### 3.3 初始化并部署

```bash
terraform init
terraform plan
terraform apply -auto-approve
```

**预期输出**：`Apply complete! Resources: 47 added, 0 changed, 0 destroyed.`

### 3.4 记录输出

```bash
terraform output
```

重点关注：`cce_cluster_id`、`swr_repository`、`input_bucket`、`output_bucket`、`db_private_endpoint`、`realtime_elb_address`、`batch_smn_topic`、`alert_smn_topic`。

## 4. 业务镜像推送

1. 获取 SWR 仓库地址：`terraform output swr_repository`；
2. 使用业务镜像（大型机现代化应用运行时镜像）构建并推送：

```bash
docker tag <your-image> $(terraform output -raw swr_repository):latest
docker push $(terraform output -raw swr_repository):latest
```

3. 将 `infra/terraform.tfvars` 中的 `container_image` 更新为该 SWR 镜像地址，再次 `terraform apply`。

## 5. 验证

按 README [第 9 节「使用方法 / 验证」](../README.md#9-使用方法--验证) 执行：

1. `kubectl` 确认命名空间与 Job 状态；
2. `psql` 确认数据库可连接；
3. VPC 内访问内部负载均衡地址确认实时服务可达；
4. SMN 控制台添加订阅后，触发数据库高负载验证告警通道。

## 6. 清理资源

```bash
cd infra
terraform destroy -auto-approve
```

**预期输出**：`Destroy complete! Resources: 47 destroyed.`

> 注意：SWR 中已推送的镜像、控制台手动创建的 EIP / SMN 订阅等非 Terraform 资源需手动清理。