#!/bin/bash
# 清理AWS资源

set -e

# 加载配置
source ../configs/aws-config.env

echo "🗑️  清理AWS资源"
echo "=============================================="
echo ""
echo "⚠️  这将删除以下资源:"
echo "  - EKS集群: $EKS_CLUSTER_NAME"
echo "  - ECR仓库及所有镜像"
echo "  - S3存储桶: spring-cloud-nacos-alb-logs-$AWS_ACCOUNT_ID"
echo "  - 相关的Load Balancer、安全组等"
echo ""
echo "是否确认删除? (y/N)"
read -r response
if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo "清理已取消"
    exit 0
fi

echo ""
echo "开始清理资源..."

# 1. 删除Kubernetes资源
echo ""
echo "📋 删除Kubernetes资源"
echo "================================"

if kubectl cluster-info > /dev/null 2>&1; then
    echo "删除应用资源..."
    
    # 删除Ingress (这会删除Load Balancer)
    kubectl delete ingress --all -n microservices || true
    kubectl delete ingress --all -n nacos || true
    
    # 删除应用
    kubectl delete namespace microservices || true
    kubectl delete namespace nacos || true
    kubectl delete namespace database || true
    kubectl delete namespace monitoring || true
    
    echo "等待Load Balancer删除..."
    sleep 60
    
    echo "✅ Kubernetes资源删除完成"
else
    echo "⚠️  无法连接到集群，跳过Kubernetes资源清理"
fi

# 2. 删除EKS集群
echo ""
echo "🏗️  删除EKS集群"
echo "================================"

if eksctl get cluster --name $EKS_CLUSTER_NAME --region $AWS_REGION &> /dev/null; then
    echo "删除EKS集群 $EKS_CLUSTER_NAME (预计需要10-15分钟)..."
    eksctl delete cluster --name $EKS_CLUSTER_NAME --region $AWS_REGION --wait
    echo "✅ EKS集群删除完成"
else
    echo "⚠️  集群 $EKS_CLUSTER_NAME 不存在"
fi

# 3. 删除ECR仓库
echo ""
echo "📦 删除ECR仓库"
echo "================================"

for REPO in "${ECR_REPOSITORIES[@]}"; do
    echo "删除ECR仓库: $REPO"
    
    if aws ecr describe-repositories --repository-names $REPO --region $AWS_REGION &> /dev/null; then
        # 删除所有镜像
        aws ecr list-images --repository-name $REPO --region $AWS_REGION --query 'imageIds[*]' --output json | \
        jq '.[] | select(.imageTag != null) | {imageTag: .imageTag}' | \
        jq -s '.' > /tmp/images-to-delete.json
        
        if [ -s /tmp/images-to-delete.json ] && [ "$(cat /tmp/images-to-delete.json)" != "[]" ]; then
            aws ecr batch-delete-image --repository-name $REPO --region $AWS_REGION --image-ids file:///tmp/images-to-delete.json > /dev/null
        fi
        
        # 删除仓库
        aws ecr delete-repository --repository-name $REPO --region $AWS_REGION --force
        echo "✅ 仓库 $REPO 删除完成"
    else
        echo "⚠️  仓库 $REPO 不存在"
    fi
done

# 4. 删除S3存储桶
echo ""
echo "🪣 删除S3存储桶"
echo "================================"

BUCKET_NAME="spring-cloud-nacos-alb-logs-$AWS_ACCOUNT_ID"
if aws s3 ls "s3://$BUCKET_NAME" &> /dev/null; then
    echo "清空并删除S3存储桶: $BUCKET_NAME"
    aws s3 rm "s3://$BUCKET_NAME" --recursive || true
    aws s3 rb "s3://$BUCKET_NAME" || true
    echo "✅ S3存储桶删除完成"
else
    echo "⚠️  S3存储桶 $BUCKET_NAME 不存在"
fi

# 5. 删除IAM策略和角色
echo ""
echo "🔐 清理IAM资源"
echo "================================"

echo "删除IAM策略..."

# 删除Load Balancer Controller策略
aws iam delete-policy --policy-arn "arn:aws:iam::$AWS_ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy" || echo "策略可能不存在"

# 删除Cluster Autoscaler策略
aws iam delete-policy --policy-arn "arn:aws:iam::$AWS_ACCOUNT_ID:policy/AmazonEKSClusterAutoscalerPolicy" || echo "策略可能不存在"

echo "✅ IAM资源清理完成"

# 6. 清理本地配置
echo ""
echo "🧹 清理本地配置"
echo "================================"

# 删除kubeconfig中的集群配置
kubectl config delete-cluster "arn:aws:eks:$AWS_REGION:$AWS_ACCOUNT_ID:cluster/$EKS_CLUSTER_NAME" || true
kubectl config delete-context "arn:aws:eks:$AWS_REGION:$AWS_ACCOUNT_ID:cluster/$EKS_CLUSTER_NAME" || true

# 清理临时文件
rm -f /tmp/images-to-delete.json
rm -f /tmp/lifecycle-policy.json

echo "✅ 本地配置清理完成"

echo ""
echo "🎉 资源清理完成!"
echo "=============================================="
echo ""
echo "已删除的资源:"
echo "  ✅ EKS集群: $EKS_CLUSTER_NAME"
echo "  ✅ ECR仓库: ${#ECR_REPOSITORIES[@]}个"
echo "  ✅ S3存储桶: $BUCKET_NAME"
echo "  ✅ 相关的Load Balancer和安全组"
echo "  ✅ IAM策略和角色"
echo ""
echo "💰 这将停止所有相关的AWS费用计费"
echo ""
echo "如需重新部署，请运行: ./deploy-all.sh"
