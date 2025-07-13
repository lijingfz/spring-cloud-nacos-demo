# AWS us-west-2 部署总结

## 📋 项目概述

本文档总结了Spring Cloud Nacos微服务项目在AWS us-west-2区域的完整部署方案。

### 项目信息
- **项目名称**: Spring Cloud Nacos 微服务示例
- **技术栈**: Spring Boot 3.1.5 + Spring Cloud 2023.0.3 + Nacos 2.3.0 + JDK 21
- **部署区域**: AWS us-west-2
- **容器平台**: Amazon EKS
- **镜像仓库**: Amazon ECR

## 🏗️ 部署架构

```
Internet
    ↓
Application Load Balancer (ALB)
    ↓
Amazon EKS Cluster (us-west-2)
    ├── Gateway Service (2 replicas)
    ├── User Service (2 replicas)
    ├── Order Service (2 replicas)
    ├── Notification Service (2 replicas)
    └── Nacos Server (1 replica - StatefulSet)
```

### 服务映射

| 本地端口 | 服务名称 | EKS端口 | ALB路径 | 功能描述 |
|---------|----------|---------|---------|----------|
| 8080 | gateway-service | 8080 | / | API网关 |
| 8081 | user-service | 8080 | /api/users | 用户管理 |
| 8082 | order-service | 8080 | /api/orders | 订单管理 |
| 8083 | notification-service | 8080 | /api/notifications | 通知服务 |
| 8848 | nacos-server | 8848 | - | 服务注册中心 |

## 📁 文件结构

```
aws-deployment-us-west-2/
├── README.md                    # 主文档
├── DEPLOYMENT_SUMMARY.md        # 部署总结 (本文档)
├── quick-start.sh              # 快速开始脚本
├── deployment-steps/           # 详细部署步骤
│   └── README.md
├── issues-and-fixes/          # 问题记录和解决方案
│   └── README.md
├── verification/              # 功能验证测试
│   └── README.md
├── cleanup/                   # 删除步骤
│   └── README.md
├── configs/                   # Kubernetes配置文件
│   ├── eks-cluster-trust-policy.json
│   ├── nacos-statefulset.yaml
│   ├── nacos-service.yaml
│   ├── *-deployment.yaml
│   ├── *-service.yaml
│   └── alb-ingress.yaml
├── scripts/                   # 自动化脚本
│   ├── deploy-all.sh         # 完整部署脚本
│   ├── verify-deployment.sh  # 功能验证脚本
│   └── cleanup-all.sh        # 资源删除脚本
├── logs/                      # 部署日志
└── verification/              # 验证报告
```

## 🚀 快速开始

### 方式一：交互式部署
```bash
cd aws-deployment-us-west-2
./quick-start.sh
```

### 方式二：直接部署
```bash
cd aws-deployment-us-west-2
./scripts/deploy-all.sh
```

### 方式三：分步部署
```bash
# 1. 查看详细步骤
cat deployment-steps/README.md

# 2. 按步骤执行
# (参考详细部署文档)
```

## 📊 资源清单

### AWS资源

| 资源类型 | 资源名称 | 数量 | 规格 | 预计费用/天 |
|---------|----------|------|------|-------------|
| EKS集群 | nacos-microservices | 1 | - | $2.40 |
| EC2实例 | Worker节点 | 3 | t3.medium | $2.99 |
| ALB | 负载均衡器 | 1 | - | $0.54 |
| ECR仓库 | 私有仓库 | 4 | - | $0.10 |
| EBS卷 | 存储卷 | 5+ | gp2 | $0.50 |
| **总计** | | | | **~$6-8** |

### Kubernetes资源

| 资源类型 | 名称 | 命名空间 | 副本数 |
|---------|------|----------|--------|
| Deployment | gateway-service | nacos-microservices | 2 |
| Deployment | user-service | nacos-microservices | 2 |
| Deployment | order-service | nacos-microservices | 2 |
| Deployment | notification-service | nacos-microservices | 2 |
| StatefulSet | nacos-server | nacos-microservices | 1 |
| Service | 各服务Service | nacos-microservices | 5 |
| Ingress | ALB Ingress | nacos-microservices | 1 |

## ⏱️ 部署时间线

| 阶段 | 预计时间 | 主要任务 |
|------|----------|----------|
| 环境准备 | 5分钟 | 检查工具、配置AWS |
| EKS集群创建 | 15-20分钟 | 创建集群和节点组 |
| 镜像构建推送 | 10-15分钟 | 构建Docker镜像并推送到ECR |
| 服务部署 | 10-15分钟 | 部署Kubernetes资源 |
| 配置和验证 | 5-10分钟 | 配置Nacos、验证功能 |
| **总计** | **45-65分钟** | |

## ✅ 验证清单

### 部署验证
- [ ] EKS集群状态为ACTIVE
- [ ] 所有Pod状态为Running
- [ ] 所有Service有ClusterIP
- [ ] Ingress有ALB地址
- [ ] 服务注册到Nacos成功

### 功能验证
- [ ] 用户服务API正常
- [ ] 订单服务API正常
- [ ] 通知服务API正常
- [ ] 服务间通信正常
- [ ] 负载均衡功能正常

### 性能验证
- [ ] API响应时间 < 2秒
- [ ] 健康检查通过
- [ ] 故障转移正常
- [ ] 监控指标正常

## 🔧 运维指南

### 日常操作

**查看服务状态**
```bash
kubectl get pods -n nacos-microservices
kubectl get services -n nacos-microservices
```

**查看日志**
```bash
kubectl logs deployment/gateway-service -n nacos-microservices
kubectl logs deployment/user-service -n nacos-microservices
```

**扩缩容**
```bash
kubectl scale deployment user-service --replicas=3 -n nacos-microservices
```

**访问Nacos控制台**
```bash
kubectl port-forward svc/nacos-server 8848:8848 -n nacos-microservices
# 访问 http://localhost:8848/nacos (nacos/nacos)
```

### 故障排查

**Pod启动失败**
```bash
kubectl describe pod <pod-name> -n nacos-microservices
kubectl logs <pod-name> -n nacos-microservices
```

**服务无法访问**
```bash
kubectl get ingress -n nacos-microservices
kubectl describe ingress nacos-microservices-ingress -n nacos-microservices
```

**Nacos连接问题**
```bash
kubectl exec -it deployment/user-service -n nacos-microservices -- nslookup nacos-server
```

## 📈 监控和告警

### 内置监控
- **健康检查**: `/actuator/health`
- **指标端点**: `/actuator/metrics`
- **应用信息**: `/actuator/info`

### 推荐监控方案
- **Prometheus + Grafana**: 指标收集和可视化
- **ELK Stack**: 日志聚合和分析
- **AWS CloudWatch**: AWS资源监控
- **Jaeger**: 分布式链路追踪

## 🔒 安全考虑

### 已实施的安全措施
- ✅ 非root用户运行容器
- ✅ 私有ECR仓库
- ✅ VPC内部通信
- ✅ IAM角色最小权限
- ✅ 安全组限制访问

### 建议的安全增强
- 🔄 启用Pod安全策略
- 🔄 配置网络策略
- 🔄 启用审计日志
- 🔄 定期更新镜像
- 🔄 配置密钥管理

## 💰 成本优化

### 当前成本结构
- **固定成本**: EKS集群控制平面 ($2.40/天)
- **可变成本**: EC2实例、存储、网络传输
- **优化空间**: 节点类型、存储类型、数据传输

### 优化建议
1. **使用Spot实例**: 降低EC2成本60-90%
2. **自动扩缩容**: 根据负载调整节点数量
3. **存储优化**: 使用gp3替代gp2
4. **预留实例**: 长期使用可考虑预留实例
5. **监控成本**: 设置成本告警和预算

## 🗑️ 资源清理

### 完整删除
```bash
./scripts/cleanup-all.sh
```

### 分步删除
```bash
# 1. 删除应用资源
kubectl delete namespace nacos-microservices

# 2. 删除EKS集群
eksctl delete cluster --name nacos-microservices --region us-west-2

# 3. 删除ECR仓库
aws ecr delete-repository --repository-name nacos-demo/gateway-service --force --region us-west-2
# ... (其他仓库)

# 4. 删除IAM资源
# (参考cleanup/README.md)
```

## 📞 支持和联系

### 文档资源
- [AWS EKS文档](https://docs.aws.amazon.com/eks/)
- [Kubernetes文档](https://kubernetes.io/docs/)
- [Spring Cloud文档](https://spring.io/projects/spring-cloud)
- [Nacos文档](https://nacos.io/zh-cn/docs/what-is-nacos.html)

### 问题反馈
- 部署问题: 查看 `issues-and-fixes/README.md`
- 功能问题: 运行 `./scripts/verify-deployment.sh`
- 性能问题: 检查监控指标和日志

## 📝 更新日志

### v1.0 (2024-07-13)
- ✅ 初始版本发布
- ✅ 完整的部署脚本
- ✅ 功能验证脚本
- ✅ 资源清理脚本
- ✅ 详细文档

### 计划功能
- 🔄 CI/CD集成
- 🔄 监控告警配置
- 🔄 安全加固
- 🔄 性能优化
- 🔄 多环境支持

---

**文档版本**: 1.0  
**创建时间**: 2024-07-13  
**适用区域**: AWS us-west-2  
**维护团队**: DevOps Team
