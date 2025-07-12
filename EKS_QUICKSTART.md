# EKS 快速部署指南

本指南帮助你快速将Spring Cloud Nacos项目部署到Amazon EKS。

## 🚀 快速开始

### 前置条件

1. **AWS CLI 已配置**
   ```bash
   aws configure
   aws sts get-caller-identity  # 验证配置
   ```

2. **Docker 已安装并运行**
   ```bash
   docker --version
   docker info
   ```

3. **kubectl 已安装**
   ```bash
   kubectl version --client
   ```

4. **eksctl 已安装** (可选，用于创建集群)
   ```bash
   eksctl version
   ```

### 步骤1: 创建EKS集群

```bash
# 使用eksctl创建集群 (约15-20分钟)
eksctl create cluster \
  --name spring-cloud-cluster \
  --region us-west-2 \
  --version 1.28 \
  --nodegroup-name standard-workers \
  --node-type t3.medium \
  --nodes 3 \
  --nodes-min 1 \
  --nodes-max 4 \
  --managed

# 验证集群连接
kubectl cluster-info
```

### 步骤2: 安装必要组件

```bash
# 安装AWS Load Balancer Controller
curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.2/docs/install/iam_policy.json

aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam_policy.json

# 替换ACCOUNT-ID为你的AWS账户ID
eksctl create iamserviceaccount \
  --cluster=spring-cloud-cluster \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --attach-policy-arn=arn:aws:iam::ACCOUNT-ID:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve

# 安装Load Balancer Controller
helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=spring-cloud-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

# 安装Metrics Server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

### 步骤3: 创建ECR仓库

```bash
# 创建ECR仓库
aws ecr create-repository --repository-name gateway-service --region us-west-2
aws ecr create-repository --repository-name user-service --region us-west-2
aws ecr create-repository --repository-name order-service --region us-west-2
aws ecr create-repository --repository-name notification-service --region us-west-2
```

### 步骤4: 配置项目

1. **更新脚本中的配置**
   ```bash
   # 编辑 scripts/build-and-push.sh
   # 替换 ACCOUNT_ID="123456789012" 为你的AWS账户ID
   
   # 编辑 scripts/deploy.sh  
   # 替换 REGISTRY="123456789012.dkr.ecr.us-west-2.amazonaws.com" 为你的ECR地址
   ```

2. **更新Kubernetes配置**
   ```bash
   # 编辑 k8s/ingress.yaml
   # 替换域名或删除host配置使用默认域名
   ```

### 步骤5: 构建和推送镜像

```bash
# 构建并推送所有服务镜像
./scripts/build-and-push.sh
```

### 步骤6: 部署到EKS

```bash
# 部署所有服务
./scripts/deploy.sh

# 检查部署状态
./scripts/health-check.sh
```

### 步骤7: 访问应用

```bash
# 获取Load Balancer地址
kubectl get ingress -n microservices

# 等待Load Balancer就绪 (约2-3分钟)
# 然后通过浏览器或curl访问
curl http://your-load-balancer-url/actuator/health
```

## 🔧 常用命令

### 查看服务状态
```bash
# 查看所有Pod
kubectl get pods -n microservices

# 查看服务
kubectl get svc -n microservices

# 查看Ingress
kubectl get ingress -n microservices

# 查看HPA
kubectl get hpa -n microservices
```

### 查看日志
```bash
# 查看Gateway日志
kubectl logs -f deployment/gateway-service -n microservices

# 查看User Service日志
kubectl logs -f deployment/user-service -n microservices
```

### 扩缩容
```bash
# 手动扩容
kubectl scale deployment gateway-service --replicas=5 -n microservices

# 查看自动扩缩容状态
kubectl describe hpa gateway-service-hpa -n microservices
```

## 🧪 测试API

```bash
# 获取Load Balancer地址
LB_URL=$(kubectl get ingress microservices-ingress -n microservices -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# 测试健康检查
curl http://$LB_URL/actuator/health

# 创建用户
curl -X POST http://$LB_URL/api/users \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "email": "test@example.com",
    "password": "password123",
    "fullName": "测试用户",
    "phoneNumber": "13800138000"
  }'

# 获取用户列表
curl http://$LB_URL/api/users
```

## 🗑️ 清理资源

```bash
# 清理应用资源
./scripts/cleanup.sh

# 删除EKS集群 (可选)
eksctl delete cluster --name spring-cloud-cluster --region us-west-2
```

## ❗ 故障排查

### 常见问题

1. **Pod启动失败**
   ```bash
   kubectl describe pod <pod-name> -n microservices
   kubectl logs <pod-name> -n microservices
   ```

2. **Load Balancer未分配地址**
   ```bash
   # 检查AWS Load Balancer Controller状态
   kubectl get pods -n kube-system | grep aws-load-balancer-controller
   
   # 查看Ingress事件
   kubectl describe ingress microservices-ingress -n microservices
   ```

3. **服务无法访问**
   ```bash
   # 检查Service和Endpoints
   kubectl get svc,endpoints -n microservices
   
   # 测试Pod内部连接
   kubectl exec -it <pod-name> -n microservices -- curl localhost:8080/actuator/health
   ```

### 获取帮助

- 查看详细部署指南: [EKS_DEPLOYMENT_GUIDE.md](./EKS_DEPLOYMENT_GUIDE.md)
- 运行健康检查: `./scripts/health-check.sh`
- 查看AWS文档: https://docs.aws.amazon.com/eks/

## 📊 成本估算

基础配置的大概成本 (us-west-2区域):
- EKS集群: ~$73/月
- 3个t3.medium节点: ~$95/月  
- Application Load Balancer: ~$23/月
- **总计: ~$191/月**

> 实际成本可能因使用量和配置而异，建议使用[AWS定价计算器](https://calculator.aws)进行准确估算。
