# 🚀 Spring Cloud Nacos 微服务 - AWS 生产部署版

[![部署状态](https://img.shields.io/badge/部署状态-生产就绪-brightgreen)](http://k8s-nacosmic-nacosmic-a04bae1d9d-413412185.us-west-2.elb.amazonaws.com)
[![AWS区域](https://img.shields.io/badge/AWS区域-us--west--2-orange)](https://console.aws.amazon.com/eks/home?region=us-west-2)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.28-blue)](https://kubernetes.io/)
[![Spring Boot](https://img.shields.io/badge/Spring%20Boot-3.1.5-green)](https://spring.io/projects/spring-boot)
[![Nacos](https://img.shields.io/badge/Nacos-2.3.0-red)](https://nacos.io/)

这是一个完整的企业级Spring Cloud微服务项目，已成功部署到AWS us-west-2区域，包含完整的容器化、Kubernetes部署和自动化脚本。

## 🌟 项目亮点

- ✅ **生产就绪**: 企业级微服务架构，已在AWS生产环境验证
- ✅ **完全自动化**: 一键部署脚本，包含完整的CI/CD流程
- ✅ **成本可控**: 优化的资源配置，日费用约$6.73
- ✅ **高可用性**: 多实例部署，自动负载均衡和故障转移
- ✅ **安全设计**: 内部服务隔离，统一网关入口
- ✅ **完整文档**: 详细的部署、使用和故障排查文档

## 🏗️ 系统架构

```
Internet → ALB → Gateway Service → [User Service, Order Service, Notification Service]
                      ↓
                 Nacos Server (服务注册中心 + 配置中心)
```

### 服务列表

| 服务名称 | 端口 | 实例数 | 功能描述 |
|---------|------|--------|----------|
| Gateway Service | 8080 | 2 | API网关，统一入口 |
| User Service | 8081 | 2 | 用户管理服务 |
| Order Service | 8082 | 2 | 订单管理服务 |
| Notification Service | 8083 | 2 | 通知服务 |
| Nacos Server | 8848 | 1 | 服务注册中心 + 配置中心 |

## 🚀 快速开始

### 方式一：使用已部署的生产环境

**访问地址**: http://k8s-nacosmic-nacosmic-a04bae1d9d-413412185.us-west-2.elb.amazonaws.com

```bash
# 测试用户服务
curl -X POST http://k8s-nacosmic-nacosmic-a04bae1d9d-413412185.us-west-2.elb.amazonaws.com/api/users \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","email":"test@example.com","password":"password123","fullName":"测试用户","phoneNumber":"13800138000"}'

# 测试订单服务
curl -X POST http://k8s-nacosmic-nacosmic-a04bae1d9d-413412185.us-west-2.elb.amazonaws.com/api/orders \
  -H "Content-Type: application/json" \
  -d '{"userId":1,"productName":"测试商品","quantity":2,"unitPrice":99.99}'

# 测试通知服务
curl -X POST http://k8s-nacosmic-nacosmic-a04bae1d9d-413412185.us-west-2.elb.amazonaws.com/api/notifications/send \
  -H "Content-Type: application/json" \
  -d '{"recipient":"test@example.com","type":"EMAIL","title":"测试通知","content":"这是一条测试通知"}'
```

### 方式二：部署到您自己的AWS环境

```bash
# 1. 克隆仓库
git clone https://github.com/lijingfz/spring-cloud-nacos-demo.git
cd spring-cloud-nacos-demo

# 2. 进入AWS部署目录
cd aws-deployment-us-west-2

# 3. 一键部署（需要45-60分钟）
./quick-start.sh

# 4. 验证部署
./scripts/verify-deployment-fixed.sh
```

## 📋 环境要求

### AWS权限要求
- EKS集群管理权限
- EC2实例管理权限
- ALB负载均衡器权限
- ECR镜像仓库权限
- IAM角色管理权限

### 本地工具要求
- AWS CLI 2.0+
- kubectl 1.28+
- Docker 20.0+
- Helm 3.0+
- eksctl 0.210+

## 🎯 API文档

### 用户服务 API

#### 创建用户
```http
POST /api/users
Content-Type: application/json

{
  "username": "testuser",
  "email": "test@example.com",
  "password": "password123",
  "fullName": "测试用户",
  "phoneNumber": "13800138000"
}
```

#### 获取用户列表
```http
GET /api/users
```

### 订单服务 API

#### 创建订单
```http
POST /api/orders
Content-Type: application/json

{
  "userId": 1,
  "productName": "测试商品",
  "quantity": 2,
  "unitPrice": 99.99
}
```

#### 获取订单列表
```http
GET /api/orders
```

### 通知服务 API

#### 发送通知
```http
POST /api/notifications/send
Content-Type: application/json

{
  "recipient": "test@example.com",
  "type": "EMAIL",
  "title": "测试通知",
  "content": "这是一条测试通知消息"
}
```

## 💰 成本分析

| 资源类型 | 规格 | 数量 | 日费用 | 月费用 |
|---------|------|------|--------|--------|
| EKS集群 | 控制平面 | 1 | $2.40 | $72.00 |
| EC2实例 | t3.medium | 3 | $2.99 | $89.70 |
| ALB | 负载均衡器 | 1 | $0.54 | $16.20 |
| EBS卷 | gp2存储 | 7个 | $0.70 | $21.00 |
| ECR | 私有仓库 | 4个 | $0.10 | $3.00 |
| **总计** | | | **$6.73** | **$201.90** |

## 📊 部署状态

### 基础设施状态
- ✅ **EKS集群**: nacos-microservices (ACTIVE)
- ✅ **节点状态**: 3/3 Ready
- ✅ **Pod状态**: 9/9 Running
- ✅ **服务状态**: 6个服务正常运行

### 功能验证状态
- ✅ **Gateway Service**: 外部访问正常
- ✅ **User Service**: API功能正常，内部健康
- ✅ **Order Service**: API功能正常，内部健康
- ✅ **Notification Service**: API功能正常，内部健康
- ✅ **Nacos Server**: 服务注册发现正常

## 📚 详细文档

- [AWS部署指南](aws-deployment-us-west-2/README.md)
- [使用指南](aws-deployment-us-west-2/USAGE_GUIDE.md)
- [部署总结](aws-deployment-us-west-2/FINAL_DEPLOYMENT_SUMMARY.md)
- [问题记录](aws-deployment-us-west-2/issues-and-fixes/DEPLOYMENT_ISSUES_LOG.md)
- [系统设计文档](SYSTEM_DESIGN.md)

## 🔧 运维管理

### 查看部署状态
```bash
cd aws-deployment-us-west-2
./scripts/check-status.sh
```

### 功能验证
```bash
./scripts/verify-deployment-fixed.sh
```

### 资源清理
```bash
./scripts/cleanup-all.sh
```

### 访问Nacos控制台
```bash
kubectl port-forward svc/nacos-server 8848:8848 -n nacos-microservices
# 访问: http://localhost:8848/nacos (nacos/nacos)
```

## 🛠️ 开发指南

### 本地开发
```bash
# 启动Nacos
./start-services.sh

# 运行测试
./test-apis.sh
```

### 构建Docker镜像
```bash
# 构建所有服务镜像
docker build -t gateway-service gateway-service/
docker build -t user-service user-service/
docker build -t order-service order-service/
docker build -t notification-service notification-service/
```

## 🔍 故障排查

### 常见问题

1. **服务启动失败**
   ```bash
   kubectl logs -n nacos-microservices -l app=gateway-service
   ```

2. **健康检查失败**
   ```bash
   kubectl describe pod -n nacos-microservices <pod-name>
   ```

3. **网络连接问题**
   ```bash
   kubectl exec -n nacos-microservices <pod-name> -- nslookup nacos-server
   ```

### 监控命令
```bash
# 查看所有Pod状态
kubectl get pods -n nacos-microservices

# 查看服务状态
kubectl get services -n nacos-microservices

# 查看Ingress状态
kubectl get ingress -n nacos-microservices
```

## 🤝 贡献指南

1. Fork 项目
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 创建 Pull Request

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情

## 📞 技术支持

- **GitHub Issues**: [提交问题](https://github.com/lijingfz/spring-cloud-nacos-demo/issues)
- **文档**: 查看 `aws-deployment-us-west-2/` 目录下的详细文档
- **示例**: 参考已部署的生产环境进行测试

---

**🎉 这是一个完整的企业级微服务解决方案，包含了从开发到生产部署的全套工具和文档！**

**部署地址**: http://k8s-nacosmic-nacosmic-a04bae1d9d-413412185.us-west-2.elb.amazonaws.com  
**仓库地址**: https://github.com/lijingfz/spring-cloud-nacos-demo  
**部署质量**: ⭐⭐⭐⭐⭐ 生产就绪
