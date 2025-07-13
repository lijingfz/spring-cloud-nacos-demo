# Spring Cloud Nacos 项目 AWS us-west-2 部署方案

## 🚀 快速开始

```bash
cd /home/ubuntu/qdemo/spring-cloud-nacos-demo/aws-deployment-us-west-2
./quick-start.sh
```

## 📋 项目概述

本项目提供了将Spring Cloud Nacos微服务完整部署到AWS us-west-2区域的解决方案，包括：

- ✅ **完整的部署脚本** - 一键部署所有AWS资源
- ✅ **详细的文档** - 涵盖部署、验证、故障排查、删除的完整流程
- ✅ **问题记录** - 记录部署过程中的问题和解决方案
- ✅ **功能验证** - 自动化验证所有微服务功能
- ✅ **资源清理** - 完整的删除步骤，避免产生费用

## 🏗️ 部署架构

```
Internet → Application Load Balancer → EKS Cluster (us-west-2)
                                          ├── Gateway Service (2 replicas)
                                          ├── User Service (2 replicas)  
                                          ├── Order Service (2 replicas)
                                          ├── Notification Service (2 replicas)
                                          └── Nacos Server (1 replica)
```

## 📁 目录结构

```
aws-deployment-us-west-2/
├── README.md                    # 主文档 (本文件)
├── DEPLOYMENT_SUMMARY.md        # 部署总结
├── USAGE_GUIDE.md              # 使用指南
├── quick-start.sh              # 🚀 快速开始脚本
├── deployment-steps/           # 📖 详细部署步骤
├── issues-and-fixes/          # 🔧 问题记录和解决方案
├── verification/              # ✅ 功能验证测试
├── cleanup/                   # 🗑️ 删除步骤
├── configs/                   # ⚙️ Kubernetes配置文件
├── scripts/                   # 🤖 自动化脚本
└── logs/                      # 📊 部署日志
```

## 🎯 主要功能

### 1. 一键部署
- **完整部署**: `./scripts/deploy-all.sh`
- **交互式部署**: `./quick-start.sh`
- **状态检查**: `./scripts/check-status.sh`

### 2. 功能验证
- **自动验证**: `./scripts/verify-deployment.sh`
- **健康检查**: 所有服务的健康状态检查
- **API测试**: 完整的微服务API功能测试

### 3. 问题解决
- **问题记录**: 详细记录部署过程中的问题
- **解决方案**: 提供具体的解决步骤
- **故障排查**: 常见问题的诊断和修复

### 4. 资源管理
- **成本控制**: 预计费用 ~$6-8/天
- **完整删除**: `./scripts/cleanup-all.sh`
- **资源监控**: 实时查看AWS资源状态

## 💰 成本预估

| 资源类型 | 规格 | 数量 | 费用/天 |
|---------|------|------|---------|
| EKS集群 | 控制平面 | 1 | $2.40 |
| EC2实例 | t3.medium | 3 | $2.99 |
| ALB | 负载均衡器 | 1 | $0.54 |
| ECR | 私有仓库 | 4 | $0.10 |
| EBS | 存储卷 | 5+ | $0.50 |
| **总计** | | | **~$6-8** |

## ⏱️ 部署时间

- **完整部署**: 45-60分钟
- **功能验证**: 10-15分钟
- **资源删除**: 20-30分钟

## 🔧 使用方法

### 方式1: 交互式操作 (推荐)
```bash
./quick-start.sh
```
选择相应的操作：
1. 🚀 完整部署
2. ✅ 验证部署
3. 🗑️ 删除资源
4. 📊 查看状态

### 方式2: 直接执行脚本
```bash
# 完整部署
./scripts/deploy-all.sh

# 验证功能
./scripts/verify-deployment.sh

# 检查状态
./scripts/check-status.sh

# 删除资源
./scripts/cleanup-all.sh
```

### 方式3: 分步执行 (高级用户)
参考 [详细部署步骤](deployment-steps/README.md)

## 📖 详细文档

| 文档 | 描述 |
|------|------|
| [DEPLOYMENT_SUMMARY.md](DEPLOYMENT_SUMMARY.md) | 部署总结和架构说明 |
| [USAGE_GUIDE.md](USAGE_GUIDE.md) | 详细使用指南 |
| [deployment-steps/](deployment-steps/) | 分步部署说明 |
| [issues-and-fixes/](issues-and-fixes/) | 问题记录和解决方案 |
| [verification/](verification/) | 功能验证指南 |
| [cleanup/](cleanup/) | 资源删除指南 |

## 🔍 状态检查

### 快速检查
```bash
# 检查EKS集群
aws eks describe-cluster --name nacos-microservices --region us-west-2

# 检查Pod状态
kubectl get pods -n nacos-microservices

# 检查服务访问
ALB_ADDRESS=$(kubectl get ingress nacos-microservices-ingress -n nacos-microservices -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl http://$ALB_ADDRESS/actuator/health
```

### 完整状态检查
```bash
./scripts/check-status.sh
```

## 🧪 API测试示例

获取ALB地址后，可以测试以下API：

```bash
# 获取ALB地址
ALB_ADDRESS=$(kubectl get ingress nacos-microservices-ingress -n nacos-microservices -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# 健康检查
curl http://$ALB_ADDRESS/actuator/health

# 创建用户
curl -X POST http://$ALB_ADDRESS/api/users \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","email":"test@example.com","password":"password123","fullName":"测试用户","phoneNumber":"13800138000"}'

# 获取用户列表
curl http://$ALB_ADDRESS/api/users

# 创建订单
curl -X POST http://$ALB_ADDRESS/api/orders \
  -H "Content-Type: application/json" \
  -d '{"userId":1,"productName":"测试商品","quantity":2,"unitPrice":99.99}'

# 发送通知
curl -X POST http://$ALB_ADDRESS/api/notifications/send \
  -H "Content-Type: application/json" \
  -d '{"recipient":"test@example.com","type":"EMAIL","title":"测试通知","content":"这是一条测试通知"}'
```

## 🔧 故障排查

### 常见问题
1. **Pod启动失败**: 查看 [issues-and-fixes/README.md](issues-and-fixes/README.md)
2. **服务无法访问**: 检查Ingress和ALB状态
3. **Nacos连接问题**: 验证服务注册和网络连通性

### 获取帮助
```bash
# 查看Pod日志
kubectl logs deployment/gateway-service -n nacos-microservices

# 查看事件
kubectl get events -n nacos-microservices --sort-by='.lastTimestamp'

# 运行诊断
./scripts/check-status.sh
```

## 🗑️ 资源清理

### ⚠️ 重要提醒
删除操作不可逆转，请确保已备份重要数据！

### 完整删除
```bash
./scripts/cleanup-all.sh
```

### 验证删除
```bash
# 检查EKS集群
aws eks list-clusters --region us-west-2

# 检查ECR仓库
aws ecr describe-repositories --region us-west-2 | grep nacos-demo

# 检查负载均衡器
aws elbv2 describe-load-balancers --region us-west-2 | grep k8s-nacos
```

## 📊 监控和维护

### 基础监控
```bash
# 资源使用情况
kubectl top nodes
kubectl top pods -n nacos-microservices

# 服务状态
kubectl get pods,services,ingress -n nacos-microservices
```

### Nacos控制台
```bash
# 端口转发
kubectl port-forward svc/nacos-server 8848:8848 -n nacos-microservices

# 访问 http://localhost:8848/nacos
# 用户名/密码: nacos/nacos
```

## 🆘 获取支持

### 自助解决
1. 查看 [问题记录](issues-and-fixes/README.md)
2. 运行 [功能验证](scripts/verify-deployment.sh)
3. 检查 [使用指南](USAGE_GUIDE.md)

### 联系支持
- AWS问题: 查看AWS文档或联系AWS支持
- Kubernetes问题: 查看Kubernetes官方文档
- 应用问题: 检查应用日志和配置

## 📝 版本信息

- **版本**: 1.0
- **创建时间**: 2024-07-13
- **适用区域**: AWS us-west-2
- **技术栈**: Spring Boot 3.1.5 + Spring Cloud 2023.0.3 + Nacos 2.3.0 + EKS 1.28

## 🎉 开始使用

准备好了吗？让我们开始部署：

```bash
cd /home/ubuntu/qdemo/spring-cloud-nacos-demo/aws-deployment-us-west-2
./quick-start.sh
```

---

**🚀 祝您部署顺利！如有问题，请查看相关文档或运行状态检查脚本。**
