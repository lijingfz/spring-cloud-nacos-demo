# AWS us-west-2 资源删除指南

本文档提供了完整的AWS资源删除步骤，确保彻底清理所有部署的资源，避免产生不必要的费用。

## ⚠️ 重要提醒

- **数据备份**: 删除前请确保已备份重要数据
- **费用检查**: 删除后请检查AWS账单确认资源已完全清理
- **顺序执行**: 请按照指定顺序执行删除步骤
- **确认删除**: 每个步骤执行后请验证资源确实已删除

## 🗂️ 删除步骤概览

1. [应用资源删除](#1-应用资源删除)
2. [Kubernetes资源清理](#2-kubernetes资源清理)
3. [EKS集群删除](#3-eks集群删除)
4. [ECR仓库清理](#4-ecr仓库清理)
5. [IAM角色和策略清理](#5-iam角色和策略清理)
6. [网络资源清理](#6-网络资源清理)
7. [最终验证](#7-最终验证)

---

## 1. 应用资源删除

### 1.1 删除Kubernetes应用资源
```bash
# 设置上下文
kubectl config use-context arn:aws:eks:us-west-2:$(aws sts get-caller-identity --query Account --output text):cluster/nacos-microservices

# 删除Ingress（这会删除ALB）
kubectl delete ingress nacos-microservices-ingress -n nacos-microservices
echo "等待ALB删除完成..."
sleep 60

# 删除所有Deployment
kubectl delete deployment --all -n nacos-microservices

# 删除StatefulSet（Nacos）
kubectl delete statefulset nacos-server -n nacos-microservices

# 删除所有Service
kubectl delete service --all -n nacos-microservices

# 删除ConfigMap和Secret
kubectl delete configmap --all -n nacos-microservices
kubectl delete secret --all -n nacos-microservices

# 删除PVC（如果有）
kubectl delete pvc --all -n nacos-microservices

# 验证资源删除
kubectl get all -n nacos-microservices
```

**预期结果**: 命名空间中应该没有任何资源

### 1.2 删除命名空间
```bash
# 删除应用命名空间
kubectl delete namespace nacos-microservices

# 验证命名空间删除
kubectl get namespace nacos-microservices
```

**预期结果**: 命名空间不存在

### 1.3 删除AWS Load Balancer Controller
```bash
# 删除AWS Load Balancer Controller
helm uninstall aws-load-balancer-controller -n kube-system

# 删除相关的ServiceAccount
kubectl delete serviceaccount aws-load-balancer-controller -n kube-system
```

**预期结果**: Load Balancer Controller已删除

---

## 2. Kubernetes资源清理

### 2.1 清理集群级别资源
```bash
# 删除ClusterRole和ClusterRoleBinding（如果有自定义的）
kubectl get clusterrole | grep nacos
kubectl get clusterrolebinding | grep nacos

# 如果有相关资源，删除它们
# kubectl delete clusterrole <role-name>
# kubectl delete clusterrolebinding <binding-name>

# 清理自定义资源定义（如果有）
kubectl get crd | grep nacos
# kubectl delete crd <crd-name>
```

### 2.2 验证Kubernetes资源清理
```bash
# 检查是否还有相关资源
kubectl get all --all-namespaces | grep nacos
kubectl get pv | grep nacos
kubectl get storageclass | grep nacos
```

**预期结果**: 没有任何nacos相关的Kubernetes资源

---

## 3. EKS集群删除

### 3.1 删除节点组
```bash
# 列出所有节点组
aws eks list-nodegroups --cluster-name nacos-microservices --region us-west-2

# 删除节点组
eksctl delete nodegroup \
  --cluster nacos-microservices \
  --name standard-workers \
  --region us-west-2

# 等待节点组删除完成
echo "等待节点组删除完成，这可能需要5-10分钟..."
aws eks wait nodegroup-deleted \
  --cluster-name nacos-microservices \
  --nodegroup-name standard-workers \
  --region us-west-2
```

**预期结果**: 节点组删除成功

### 3.2 删除EKS集群
```bash
# 删除EKS集群
eksctl delete cluster \
  --name nacos-microservices \
  --region us-west-2

# 或者使用AWS CLI删除
# aws eks delete-cluster --name nacos-microservices --region us-west-2

echo "等待集群删除完成，这可能需要10-15分钟..."
```

**预期结果**: EKS集群完全删除

### 3.3 验证EKS集群删除
```bash
# 验证集群已删除
aws eks list-clusters --region us-west-2 | grep nacos-microservices
echo "如果没有输出，说明集群已删除"

# 清理本地kubeconfig
kubectl config delete-context arn:aws:eks:us-west-2:$(aws sts get-caller-identity --query Account --output text):cluster/nacos-microservices
kubectl config delete-cluster arn:aws:eks:us-west-2:$(aws sts get-caller-identity --query Account --output text):cluster/nacos-microservices
```

**预期结果**: 集群不在列表中，本地配置已清理

---

## 4. ECR仓库清理

### 4.1 删除ECR镜像
```bash
# 列出所有相关的ECR仓库
aws ecr describe-repositories --region us-west-2 | grep nacos-demo

# 删除所有镜像（保留仓库）
services=("gateway-service" "user-service" "order-service" "notification-service" "nacos-server")

for service in "${services[@]}"; do
  echo "清理 nacos-demo/$service 仓库中的镜像..."
  
  # 获取所有镜像标签
  IMAGE_TAGS=$(aws ecr list-images \
    --repository-name nacos-demo/$service \
    --region us-west-2 \
    --query 'imageIds[*].imageTag' \
    --output text)
  
  if [ ! -z "$IMAGE_TAGS" ]; then
    # 删除所有镜像
    aws ecr batch-delete-image \
      --repository-name nacos-demo/$service \
      --image-ids imageTag=$IMAGE_TAGS \
      --region us-west-2
  fi
done
```

### 4.2 删除ECR仓库
```bash
# 删除所有ECR仓库
for service in "${services[@]}"; do
  echo "删除 nacos-demo/$service 仓库..."
  aws ecr delete-repository \
    --repository-name nacos-demo/$service \
    --force \
    --region us-west-2
done
```

### 4.3 验证ECR清理
```bash
# 验证仓库已删除
aws ecr describe-repositories --region us-west-2 | grep nacos-demo
echo "如果没有输出，说明ECR仓库已全部删除"
```

**预期结果**: 所有nacos-demo相关的ECR仓库已删除

---

## 5. IAM角色和策略清理

### 5.1 删除EKS相关的IAM角色
```bash
# 删除EKS集群服务角色
aws iam detach-role-policy \
  --role-name nacos-eks-cluster-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy \
  --region us-west-2

aws iam delete-role \
  --role-name nacos-eks-cluster-role \
  --region us-west-2

# 删除Load Balancer Controller角色
aws iam detach-role-policy \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --policy-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/AWSLoadBalancerControllerIAMPolicy \
  --region us-west-2

aws iam delete-role \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --region us-west-2
```

### 5.2 删除自定义IAM策略
```bash
# 删除Load Balancer Controller策略
aws iam delete-policy \
  --policy-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/AWSLoadBalancerControllerIAMPolicy \
  --region us-west-2
```

### 5.3 清理OIDC身份提供程序
```bash
# 获取OIDC提供程序ARN
OIDC_ARN=$(aws iam list-open-id-connect-providers \
  --query 'OpenIDConnectProviderList[?contains(Arn, `nacos-microservices`)].Arn' \
  --output text \
  --region us-west-2)

# 如果存在，删除OIDC提供程序
if [ ! -z "$OIDC_ARN" ]; then
  aws iam delete-open-id-connect-provider \
    --open-id-connect-provider-arn $OIDC_ARN \
    --region us-west-2
fi
```

### 5.4 验证IAM资源清理
```bash
# 检查是否还有相关的IAM资源
aws iam list-roles --query 'Roles[?contains(RoleName, `nacos`) || contains(RoleName, `EKS`)].RoleName' --output table --region us-west-2
aws iam list-policies --scope Local --query 'Policies[?contains(PolicyName, `LoadBalancer`)].PolicyName' --output table --region us-west-2
```

**预期结果**: 没有相关的IAM角色和策略

---

## 6. 网络资源清理

### 6.1 检查和清理安全组
```bash
# 查找EKS相关的安全组
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=*nacos-microservices*" \
  --query 'SecurityGroups[*].{GroupId:GroupId,GroupName:GroupName}' \
  --output table \
  --region us-west-2

# 注意：通常EKS集群删除时会自动清理安全组，手动删除需谨慎
```

### 6.2 检查和清理负载均衡器
```bash
# 检查是否还有相关的ALB
aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[?contains(LoadBalancerName, `nacos`) || contains(LoadBalancerName, `k8s`)].LoadBalancerArn' \
  --output table \
  --region us-west-2

# 如果有遗留的ALB，手动删除
# aws elbv2 delete-load-balancer --load-balancer-arn <arn> --region us-west-2
```

### 6.3 检查EBS卷
```bash
# 检查是否有遗留的EBS卷
aws ec2 describe-volumes \
  --filters "Name=tag:kubernetes.io/cluster/nacos-microservices,Values=owned" \
  --query 'Volumes[*].{VolumeId:VolumeId,State:State,Size:Size}' \
  --output table \
  --region us-west-2

# 如果有遗留卷且状态为available，可以删除
# aws ec2 delete-volume --volume-id <volume-id> --region us-west-2
```

**预期结果**: 没有相关的网络资源遗留

---

## 7. 最终验证

### 7.1 全面资源检查
```bash
# 检查EKS资源
echo "=== EKS集群检查 ==="
aws eks list-clusters --region us-west-2

# 检查ECR资源
echo "=== ECR仓库检查 ==="
aws ecr describe-repositories --region us-west-2 | grep nacos-demo || echo "无nacos-demo相关仓库"

# 检查IAM资源
echo "=== IAM角色检查 ==="
aws iam list-roles --query 'Roles[?contains(RoleName, `nacos`) || contains(RoleName, `EKS`)].RoleName' --output text --region us-west-2 || echo "无相关IAM角色"

# 检查EC2实例
echo "=== EC2实例检查 ==="
aws ec2 describe-instances \
  --filters "Name=tag:kubernetes.io/cluster/nacos-microservices,Values=owned" "Name=instance-state-name,Values=running,pending,stopping,stopped" \
  --query 'Reservations[*].Instances[*].InstanceId' \
  --output text \
  --region us-west-2 || echo "无相关EC2实例"

# 检查负载均衡器
echo "=== 负载均衡器检查 ==="
aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[?contains(LoadBalancerName, `k8s-nacos`)].LoadBalancerName' \
  --output text \
  --region us-west-2 || echo "无相关负载均衡器"
```

### 7.2 费用影响评估
```bash
echo "=== 费用影响评估 ==="
echo "已删除的主要资源："
echo "- EKS集群: nacos-microservices"
echo "- EC2实例: 3个t3.medium节点"
echo "- ALB: 1个Application Load Balancer"
echo "- ECR仓库: 5个私有仓库"
echo "- EBS卷: 节点存储卷"
echo ""
echo "预计节省费用（每天）："
echo "- EKS集群: $0.10/小时 × 24 = $2.40"
echo "- EC2实例: $0.0416/小时 × 3 × 24 = $2.99"
echo "- ALB: $0.0225/小时 × 24 = $0.54"
echo "- 总计约: $6-8/天"
echo ""
echo "请在24小时后检查AWS账单确认资源已完全清理"
```

### 7.3 清理本地文件
```bash
# 清理本地Docker镜像
echo "=== 清理本地Docker镜像 ==="
docker images | grep nacos-demo
docker rmi $(docker images | grep nacos-demo | awk '{print $3}') 2>/dev/null || echo "无本地nacos-demo镜像"

# 清理临时文件
echo "=== 清理临时文件 ==="
rm -f iam_policy.json
rm -rf ~/.kube/cache/discovery/$(aws sts get-caller-identity --query Account --output text).dkr.ecr.us-west-2.amazonaws.com_*
```

---

## 📋 删除检查清单

### 必须验证的删除项目

- [ ] **EKS集群**: `aws eks list-clusters --region us-west-2` 无nacos-microservices
- [ ] **EC2实例**: 无相关的worker节点实例
- [ ] **ECR仓库**: 无nacos-demo相关仓库
- [ ] **IAM角色**: 无EKS和LoadBalancer相关角色
- [ ] **负载均衡器**: 无相关的ALB
- [ ] **安全组**: 无EKS相关的安全组（自动清理）
- [ ] **EBS卷**: 无遗留的存储卷
- [ ] **本地配置**: kubeconfig已清理
- [ ] **本地镜像**: Docker镜像已清理

### 费用监控

- [ ] **24小时后检查**: AWS账单中无相关资源费用
- [ ] **一周后确认**: 确保没有隐藏的费用产生

---

## 🚨 紧急回滚

如果在删除过程中需要紧急停止：

```bash
# 停止所有正在进行的删除操作
# 按Ctrl+C停止当前命令

# 检查当前状态
aws eks describe-cluster --name nacos-microservices --region us-west-2
kubectl get all -n nacos-microservices

# 如果需要恢复，重新运行部署脚本
# ./scripts/deploy-all.sh
```

---

## 📞 支持联系

如果在删除过程中遇到问题：

1. **检查AWS CloudTrail**: 查看详细的API调用日志
2. **AWS Support**: 如果有支持计划，可以联系AWS技术支持
3. **社区支持**: 查看AWS EKS和eksctl的GitHub Issues

---

**删除指南版本**: 1.0  
**适用区域**: us-west-2  
**最后更新**: $(date)  
**预计删除时间**: 30-45分钟
