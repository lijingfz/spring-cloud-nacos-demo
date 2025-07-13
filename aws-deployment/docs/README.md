# Spring Cloud Nacos 项目 AWS EKS 部署指南

本目录包含将Spring Cloud Nacos微服务项目部署到Amazon EKS的完整自动化脚本和配置文件。

## 📋 部署概览

### 目标架构
```
Internet → ALB → EKS Cluster
                    ├── Gateway Service (2 replicas)
                    ├── User Service (3 replicas)
                    ├── Order Service (2 replicas)
                    ├── Notification Service (2 replicas)
                    └── Nacos Cluster (3 replicas)
```

### AWS资源
- **EKS集群**: spring-cloud-nacos-cluster
- **节点组**: 3个 t3.medium 实例
- **ECR仓库**: 4个微服务镜像仓库
- **ALB**: 用于外部访问
- **S3存储桶**: ALB访问日志

## 🚀 快速开始

### 前置条件
1. **AWS CLI已配置**
   ```bash
   aws configure
   aws sts get-caller-identity  # 验证配置
   ```

2. **Docker已安装并运行**
   ```bash
   docker --version
   docker info
   ```

3. **必要工具** (脚本会自动安装)
   - kubectl
   - eksctl
   - helm

### 一键部署
```bash
cd aws-deployment/scripts
./deploy-all.sh
```

这个脚本会自动执行以下步骤：
1. 创建EKS集群 (15-20分钟)
2. 安装必要组件 (5分钟)
3. 创建ECR仓库 (1分钟)
4. 构建并推送镜像 (5-10分钟)
5. 部署到EKS (5分钟)

**总耗时**: 约30-40分钟

## 📁 目录结构

```
aws-deployment/
├── configs/
│   └── aws-config.env          # AWS配置文件
├── scripts/
│   ├── 01-create-eks-cluster.sh    # 创建EKS集群
│   ├── 02-setup-cluster-components.sh # 安装集群组件
│   ├── 03-create-ecr-repositories.sh  # 创建ECR仓库
│   ├── 04-build-and-push-images.sh    # 构建推送镜像
│   ├── 05-deploy-to-eks.sh            # 部署到EKS
│   ├── deploy-all.sh                  # 一键部署
│   └── cleanup.sh                     # 清理资源
├── k8s/
│   ├── configmap.yaml          # 配置映射
│   ├── secrets.yaml            # 密钥配置
│   ├── ingress.yaml            # ALB Ingress配置
│   ├── hpa.yaml                # 自动扩缩容
│   ├── *-deployment.yaml      # 各服务部署配置
│   └── nacos/                  # Nacos集群配置
└── docs/
    └── README.md               # 本文档
```

## ⚙️ 配置说明

### AWS配置 (configs/aws-config.env)
```bash
# 当前配置
AWS_ACCOUNT_ID=890717383483
AWS_REGION=us-west-2
EKS_CLUSTER_NAME=spring-cloud-nacos-cluster
EKS_NODE_TYPE=t3.medium
EKS_NODE_DESIRED=3
```

### 应用配置
- **Spring Profile**: aws
- **Nacos命名空间**: dev
- **应用版本**: v1.0.0
- **副本数**: Gateway(2), User(3), Order(2), Notification(2)

## 🔧 分步部署 (可选)

如果需要分步执行或自定义配置：

### 1. 创建EKS集群
```bash
./01-create-eks-cluster.sh
```

### 2. 安装集群组件
```bash
./02-setup-cluster-components.sh
```

### 3. 创建ECR仓库
```bash
./03-create-ecr-repositories.sh
```

### 4. 构建并推送镜像
```bash
./04-build-and-push-images.sh
```

### 5. 部署到EKS
```bash
./05-deploy-to-eks.sh
```

## 🌐 访问应用

部署完成后，获取访问地址：

```bash
# 获取微服务API地址
kubectl get ingress microservices-ingress -n microservices

# 获取Nacos控制台地址
kubectl get ingress nacos-console-ingress -n nacos
```

### API测试示例
```bash
# 替换 <ALB_URL> 为实际的Load Balancer地址

# 健康检查
curl http://<ALB_URL>/actuator/health

# 创建用户
curl -X POST http://<ALB_URL>/api/users \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","email":"test@example.com","fullName":"测试用户"}'

# 获取用户列表
curl http://<ALB_URL>/api/users

# 创建订单
curl -X POST http://<ALB_URL>/api/orders \
  -H "Content-Type: application/json" \
  -d '{"userId":1,"productName":"测试商品","quantity":2,"unitPrice":99.99}'
```

## 📊 监控和管理

### 查看资源状态
```bash
# 查看所有Pod
kubectl get pods -n microservices

# 查看服务
kubectl get svc -n microservices

# 查看Ingress
kubectl get ingress -n microservices

# 查看HPA状态
kubectl get hpa -n microservices
```

### 查看日志
```bash
# Gateway服务日志
kubectl logs -f deployment/gateway-service -n microservices

# User服务日志
kubectl logs -f deployment/user-service -n microservices

# 所有服务日志
kubectl logs -f -l app=gateway-service -n microservices
```

### 扩缩容
```bash
# 手动扩容Gateway服务
kubectl scale deployment gateway-service --replicas=5 -n microservices

# 查看自动扩缩容状态
kubectl describe hpa gateway-service-hpa -n microservices
```

## 💰 成本估算

基于us-west-2区域的预估成本：

| 资源 | 配置 | 月成本 (USD) |
|------|------|-------------|
| EKS集群 | 控制平面 | $73 |
| EC2实例 | 3x t3.medium | $95 |
| ALB | Application Load Balancer | $23 |
| ECR | 镜像存储 | $5 |
| S3 | 日志存储 | $2 |
| **总计** | | **~$198** |

> 实际成本可能因使用量而异。建议使用[AWS定价计算器](https://calculator.aws)进行精确估算。

## 🗑️ 清理资源

完成测试后，清理所有AWS资源以避免持续计费：

```bash
./cleanup.sh
```

这将删除：
- EKS集群及所有节点
- ECR仓库及镜像
- Load Balancer和安全组
- S3存储桶
- 相关IAM策略

## 🔧 故障排查

### 常见问题

1. **集群创建失败**
   ```bash
   # 检查AWS配置
   aws sts get-caller-identity
   
   # 检查区域配额
   aws service-quotas get-service-quota --service-code eks --quota-code L-1194D53C
   ```

2. **Pod启动失败**
   ```bash
   # 查看Pod详情
   kubectl describe pod <pod-name> -n microservices
   
   # 查看Pod日志
   kubectl logs <pod-name> -n microservices
   ```

3. **Load Balancer未分配地址**
   ```bash
   # 检查AWS Load Balancer Controller
   kubectl get pods -n kube-system | grep aws-load-balancer-controller
   
   # 查看Ingress事件
   kubectl describe ingress microservices-ingress -n microservices
   ```

4. **镜像拉取失败**
   ```bash
   # 检查ECR登录
   aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin 890717383483.dkr.ecr.us-west-2.amazonaws.com
   
   # 验证镜像存在
   aws ecr list-images --repository-name gateway-service --region us-west-2
   ```

### 获取帮助

- **AWS文档**: https://docs.aws.amazon.com/eks/
- **Kubernetes文档**: https://kubernetes.io/docs/
- **项目Issues**: 在GitHub仓库中创建Issue

## 📝 更新日志

- **v1.0.0** (2025-07-12): 初始版本
  - 完整的EKS部署自动化
  - 支持一键部署和清理
  - 集成ALB和自动扩缩容
  - 完善的监控和日志配置

---

**作者**: Amazon Q  
**最后更新**: 2025-07-12  
**AWS账号**: 890717383483 (jingamz)  
**部署区域**: us-west-2
