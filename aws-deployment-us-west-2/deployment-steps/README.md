# AWS us-west-2 详细部署步骤

## 阶段1: 环境准备

### 1.1 AWS CLI配置验证
```bash
# 验证AWS CLI配置
aws sts get-caller-identity --region us-west-2

# 设置默认区域
export AWS_DEFAULT_REGION=us-west-2
```

### 1.2 必要工具安装检查
```bash
# 检查必要工具
which aws kubectl docker helm

# 安装eksctl (如果未安装)
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
```

### 1.3 创建IAM角色和策略
```bash
# 创建EKS集群服务角色
aws iam create-role \
  --role-name nacos-eks-cluster-role \
  --assume-role-policy-document file://configs/eks-cluster-trust-policy.json \
  --region us-west-2

# 附加必要策略
aws iam attach-role-policy \
  --role-name nacos-eks-cluster-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy \
  --region us-west-2
```

## 阶段2: EKS集群创建

### 2.1 创建EKS集群
```bash
# 使用eksctl创建集群
eksctl create cluster \
  --name nacos-microservices \
  --region us-west-2 \
  --version 1.28 \
  --nodegroup-name standard-workers \
  --node-type t3.medium \
  --nodes 3 \
  --nodes-min 2 \
  --nodes-max 5 \
  --managed \
  --with-oidc \
  --ssh-access \
  --ssh-public-key ~/.ssh/id_rsa.pub
```

### 2.2 配置kubectl
```bash
# 更新kubeconfig
aws eks update-kubeconfig --region us-west-2 --name nacos-microservices

# 验证连接
kubectl get nodes
kubectl get namespaces
```

### 2.3 安装AWS Load Balancer Controller
```bash
# 下载IAM策略
curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.2/docs/install/iam_policy.json

# 创建IAM策略
aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam_policy.json \
    --region us-west-2

# 创建服务账户
eksctl create iamserviceaccount \
  --cluster=nacos-microservices \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --attach-policy-arn=arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/AWSLoadBalancerControllerIAMPolicy \
  --approve \
  --region us-west-2

# 安装AWS Load Balancer Controller
helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=nacos-microservices \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

## 阶段3: 容器镜像构建和推送

### 3.1 创建ECR仓库
```bash
# 为每个服务创建ECR仓库
services=("gateway-service" "user-service" "order-service" "notification-service")

for service in "${services[@]}"; do
  aws ecr create-repository \
    --repository-name nacos-demo/$service \
    --region us-west-2 \
    --image-scanning-configuration scanOnPush=true
done

# 创建Nacos仓库
aws ecr create-repository \
  --repository-name nacos-demo/nacos-server \
  --region us-west-2 \
  --image-scanning-configuration scanOnPush=true
```

### 3.2 构建和推送镜像
```bash
# 获取ECR登录令牌
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin $(aws sts get-caller-identity --query Account --output text).dkr.ecr.us-west-2.amazonaws.com

# 设置ECR仓库前缀
ECR_REGISTRY=$(aws sts get-caller-identity --query Account --output text).dkr.ecr.us-west-2.amazonaws.com
ECR_REPOSITORY_PREFIX=nacos-demo

# 构建所有服务镜像
./scripts/build-and-push-images.sh
```

## 阶段4: Kubernetes资源部署

### 4.1 创建命名空间
```bash
kubectl create namespace nacos-microservices
kubectl label namespace nacos-microservices name=nacos-microservices
```

### 4.2 部署Nacos服务
```bash
# 创建ConfigMap和Secret
kubectl apply -f configs/nacos-configmap.yaml -n nacos-microservices
kubectl apply -f configs/nacos-secret.yaml -n nacos-microservices

# 部署Nacos StatefulSet
kubectl apply -f configs/nacos-statefulset.yaml -n nacos-microservices
kubectl apply -f configs/nacos-service.yaml -n nacos-microservices

# 等待Nacos启动
kubectl wait --for=condition=ready pod -l app=nacos-server -n nacos-microservices --timeout=300s
```

### 4.3 部署微服务
```bash
# 按顺序部署微服务
services=("user-service" "order-service" "notification-service" "gateway-service")

for service in "${services[@]}"; do
  echo "部署 $service..."
  kubectl apply -f configs/$service-deployment.yaml -n nacos-microservices
  kubectl apply -f configs/$service-service.yaml -n nacos-microservices
  
  # 等待服务就绪
  kubectl wait --for=condition=available deployment/$service -n nacos-microservices --timeout=300s
done
```

### 4.4 配置Ingress和负载均衡器
```bash
# 部署ALB Ingress
kubectl apply -f configs/alb-ingress.yaml -n nacos-microservices

# 等待ALB创建完成
kubectl wait --for=condition=ready ingress/nacos-microservices-ingress -n nacos-microservices --timeout=600s

# 获取ALB地址
ALB_ADDRESS=$(kubectl get ingress nacos-microservices-ingress -n nacos-microservices -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "ALB地址: $ALB_ADDRESS"
```

## 阶段5: 配置和验证

### 5.1 配置Nacos
```bash
# 等待Nacos完全启动
sleep 60

# 通过端口转发访问Nacos控制台
kubectl port-forward svc/nacos-server 8848:8848 -n nacos-microservices &

# 创建Nacos配置
./scripts/setup-nacos-config.sh
```

### 5.2 验证服务注册
```bash
# 检查所有Pod状态
kubectl get pods -n nacos-microservices

# 检查服务状态
kubectl get services -n nacos-microservices

# 检查Ingress状态
kubectl get ingress -n nacos-microservices
```

## 阶段6: 功能验证

### 6.1 健康检查
```bash
# 检查所有服务健康状态
./scripts/health-check.sh $ALB_ADDRESS
```

### 6.2 API功能测试
```bash
# 运行完整的API测试
./scripts/api-test.sh $ALB_ADDRESS
```

### 6.3 负载测试
```bash
# 运行负载测试
./scripts/load-test.sh $ALB_ADDRESS
```

## 部署完成检查清单

- [ ] EKS集群创建成功
- [ ] 所有Pod运行正常
- [ ] 服务注册到Nacos成功
- [ ] ALB配置正确
- [ ] API功能测试通过
- [ ] 健康检查通过
- [ ] 监控配置完成

---
**预计部署时间**: 45-60分钟
**资源成本**: 约$50-80/天 (t3.medium * 3节点)
