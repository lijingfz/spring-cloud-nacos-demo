# AWS us-west-2 部署使用指南

## 🎯 快速开始

### 1. 一键部署
```bash
cd /home/ubuntu/qdemo/spring-cloud-nacos-demo/aws-deployment-us-west-2
./quick-start.sh
```

### 2. 选择操作
- **选项1**: 🚀 完整部署 - 部署所有AWS资源
- **选项2**: ✅ 验证部署 - 验证现有部署功能
- **选项3**: 🗑️ 删除资源 - 完全清理所有资源
- **选项4**: 📊 查看状态 - 查看当前部署状态

## 📋 部署前检查清单

### 必要条件
- [ ] AWS CLI已安装并配置
- [ ] kubectl已安装
- [ ] Docker已安装并运行
- [ ] helm已安装
- [ ] eksctl已安装
- [ ] jq已安装
- [ ] 具有足够的AWS权限

### AWS权限要求
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "eks:*",
                "ec2:*",
                "iam:*",
                "ecr:*",
                "elasticloadbalancing:*",
                "autoscaling:*",
                "cloudformation:*"
            ],
            "Resource": "*"
        }
    ]
}
```

## 🚀 详细部署步骤

### 步骤1: 环境准备
```bash
# 验证AWS配置
aws sts get-caller-identity --region us-west-2

# 检查Docker状态
docker info

# 验证工具安装
kubectl version --client
helm version
eksctl version
```

### 步骤2: 执行部署
```bash
# 方式1: 交互式部署
./quick-start.sh

# 方式2: 直接部署
./scripts/deploy-all.sh

# 方式3: 分步部署 (高级用户)
# 参考 deployment-steps/README.md
```

### 步骤3: 验证部署
```bash
# 自动验证
./scripts/verify-deployment.sh

# 手动验证
kubectl get pods -n nacos-microservices
kubectl get services -n nacos-microservices
kubectl get ingress -n nacos-microservices
```

### 步骤4: 获取访问地址
```bash
# 获取ALB地址
ALB_ADDRESS=$(kubectl get ingress nacos-microservices-ingress -n nacos-microservices -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "访问地址: http://$ALB_ADDRESS"
```

## 🔧 常用操作

### 查看服务状态
```bash
# 查看所有Pod
kubectl get pods -n nacos-microservices

# 查看服务详情
kubectl describe service gateway-service -n nacos-microservices

# 查看Ingress状态
kubectl get ingress -n nacos-microservices -o wide
```

### 查看日志
```bash
# 查看Gateway服务日志
kubectl logs deployment/gateway-service -n nacos-microservices

# 查看用户服务日志
kubectl logs deployment/user-service -n nacos-microservices --tail=100

# 实时查看日志
kubectl logs -f deployment/order-service -n nacos-microservices
```

### 服务扩缩容
```bash
# 扩展用户服务到3个实例
kubectl scale deployment user-service --replicas=3 -n nacos-microservices

# 查看扩容状态
kubectl get deployment user-service -n nacos-microservices
```

### 访问Nacos控制台
```bash
# 端口转发
kubectl port-forward svc/nacos-server 8848:8848 -n nacos-microservices

# 在浏览器中访问 http://localhost:8848/nacos
# 用户名/密码: nacos/nacos
```

## 🧪 API测试

### 获取ALB地址
```bash
ALB_ADDRESS=$(kubectl get ingress nacos-microservices-ingress -n nacos-microservices -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
```

### 健康检查
```bash
# Gateway健康检查
curl http://$ALB_ADDRESS/actuator/health

# 各服务健康检查
curl http://$ALB_ADDRESS/api/users/actuator/health
curl http://$ALB_ADDRESS/api/orders/actuator/health
curl http://$ALB_ADDRESS/api/notifications/actuator/health
```

### 功能测试
```bash
# 创建用户
curl -X POST http://$ALB_ADDRESS/api/users \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "email": "test@example.com",
    "password": "password123",
    "fullName": "测试用户",
    "phoneNumber": "13800138000"
  }'

# 获取用户列表
curl http://$ALB_ADDRESS/api/users

# 创建订单
curl -X POST http://$ALB_ADDRESS/api/orders \
  -H "Content-Type: application/json" \
  -d '{
    "userId": 1,
    "productName": "测试商品",
    "quantity": 2,
    "unitPrice": 99.99
  }'

# 发送通知
curl -X POST http://$ALB_ADDRESS/api/notifications/send \
  -H "Content-Type: application/json" \
  -d '{
    "recipient": "test@example.com",
    "type": "EMAIL",
    "title": "测试通知",
    "content": "这是一条测试通知"
  }'
```

## 🔍 故障排查

### 常见问题

#### 1. Pod启动失败
```bash
# 查看Pod状态
kubectl get pods -n nacos-microservices

# 查看Pod详情
kubectl describe pod <pod-name> -n nacos-microservices

# 查看Pod日志
kubectl logs <pod-name> -n nacos-microservices
```

#### 2. 服务无法访问
```bash
# 检查Service
kubectl get services -n nacos-microservices

# 检查Ingress
kubectl describe ingress nacos-microservices-ingress -n nacos-microservices

# 检查ALB状态
aws elbv2 describe-load-balancers --region us-west-2
```

#### 3. Nacos连接问题
```bash
# 检查Nacos Pod状态
kubectl get pods -l app=nacos-server -n nacos-microservices

# 检查DNS解析
kubectl exec -it deployment/user-service -n nacos-microservices -- nslookup nacos-server

# 检查网络连通性
kubectl exec -it deployment/user-service -n nacos-microservices -- telnet nacos-server 8848
```

#### 4. 镜像拉取失败
```bash
# 检查ECR登录
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin $(aws sts get-caller-identity --query Account --output text).dkr.ecr.us-west-2.amazonaws.com

# 检查镜像是否存在
aws ecr list-images --repository-name nacos-demo/gateway-service --region us-west-2

# 检查Secret
kubectl get secret ecr-secret -n nacos-microservices -o yaml
```

### 日志收集
```bash
# 收集所有服务日志
mkdir -p troubleshooting-logs
kubectl logs deployment/gateway-service -n nacos-microservices > troubleshooting-logs/gateway.log
kubectl logs deployment/user-service -n nacos-microservices > troubleshooting-logs/user.log
kubectl logs deployment/order-service -n nacos-microservices > troubleshooting-logs/order.log
kubectl logs deployment/notification-service -n nacos-microservices > troubleshooting-logs/notification.log
kubectl logs statefulset/nacos-server -n nacos-microservices > troubleshooting-logs/nacos.log
```

## 💰 成本管理

### 查看当前资源
```bash
# 查看EKS集群
aws eks describe-cluster --name nacos-microservices --region us-west-2

# 查看EC2实例
aws ec2 describe-instances --filters "Name=tag:kubernetes.io/cluster/nacos-microservices,Values=owned" --region us-west-2

# 查看负载均衡器
aws elbv2 describe-load-balancers --region us-west-2 | grep k8s-nacos
```

### 成本优化建议
1. **使用Spot实例**: 可节省60-90%的EC2成本
2. **调整实例类型**: 根据实际负载选择合适的实例类型
3. **自动扩缩容**: 配置HPA和CA自动调整资源
4. **定期清理**: 删除不需要的资源和镜像

## 🗑️ 资源清理

### 完整清理
```bash
# 交互式清理
./quick-start.sh
# 选择选项3

# 直接清理
./scripts/cleanup-all.sh
```

### 部分清理
```bash
# 只删除应用，保留集群
kubectl delete namespace nacos-microservices

# 只删除特定服务
kubectl delete deployment user-service -n nacos-microservices
kubectl delete service user-service -n nacos-microservices
```

### 验证清理结果
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
# 查看资源使用情况
kubectl top nodes
kubectl top pods -n nacos-microservices

# 查看事件
kubectl get events -n nacos-microservices --sort-by='.lastTimestamp'
```

### 健康检查脚本
```bash
#!/bin/bash
# health-check.sh

ALB_ADDRESS=$(kubectl get ingress nacos-microservices-ingress -n nacos-microservices -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

services=("" "/api/users" "/api/orders" "/api/notifications")
for service in "${services[@]}"; do
    if curl -f -s "http://$ALB_ADDRESS$service/actuator/health" > /dev/null; then
        echo "✅ $service 健康"
    else
        echo "❌ $service 异常"
    fi
done
```

## 📚 参考文档

- [详细部署步骤](deployment-steps/README.md)
- [问题记录和解决方案](issues-and-fixes/README.md)
- [功能验证指南](verification/README.md)
- [资源删除指南](cleanup/README.md)
- [部署总结](DEPLOYMENT_SUMMARY.md)

## 🆘 获取帮助

### 自助排查
1. 查看 `issues-and-fixes/README.md`
2. 运行 `./scripts/verify-deployment.sh`
3. 检查日志文件

### 联系支持
- 技术问题: 查看AWS文档和Kubernetes文档
- 部署问题: 检查脚本输出和日志
- 性能问题: 查看监控指标

---
**使用指南版本**: 1.0  
**最后更新**: 2024-07-13  
**适用区域**: AWS us-west-2
