#!/bin/bash
# 创建EKS集群

set -e

# 加载配置
source ../configs/aws-config.env

echo "=== 创建EKS集群 ==="
echo "集群名称: $EKS_CLUSTER_NAME"
echo "区域: $AWS_REGION"
echo "节点类型: $EKS_NODE_TYPE"
echo "节点数量: $EKS_NODE_MIN-$EKS_NODE_MAX (期望: $EKS_NODE_DESIRED)"
echo ""

# 检查eksctl是否安装
if ! command -v eksctl &> /dev/null; then
    echo "安装eksctl..."
    curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
    sudo mv /tmp/eksctl /usr/local/bin
    echo "✅ eksctl安装完成"
fi

# 检查kubectl是否安装
if ! command -v kubectl &> /dev/null; then
    echo "安装kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
    echo "✅ kubectl安装完成"
fi

# 检查helm是否安装
if ! command -v helm &> /dev/null; then
    echo "安装Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    echo "✅ Helm安装完成"
fi

# 验证AWS配置
echo "验证AWS配置..."
aws sts get-caller-identity
echo ""

# 检查集群是否已存在
if eksctl get cluster --name $EKS_CLUSTER_NAME --region $AWS_REGION &> /dev/null; then
    echo "⚠️  集群 $EKS_CLUSTER_NAME 已存在"
    echo "是否要删除现有集群并重新创建? (y/N)"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        echo "删除现有集群..."
        eksctl delete cluster --name $EKS_CLUSTER_NAME --region $AWS_REGION --wait
        echo "✅ 现有集群已删除"
    else
        echo "使用现有集群"
        eksctl utils update-cluster-logging --enable-types=all --region=$AWS_REGION --cluster=$EKS_CLUSTER_NAME
        aws eks update-kubeconfig --region $AWS_REGION --name $EKS_CLUSTER_NAME
        echo "✅ 集群配置已更新"
        exit 0
    fi
fi

# 创建集群配置文件
cat > /tmp/cluster-config.yaml << EOF
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: $EKS_CLUSTER_NAME
  region: $AWS_REGION
  version: "1.28"

# 启用日志
cloudWatch:
  clusterLogging:
    enableTypes: ["*"]

# IAM配置
iam:
  withOIDC: true

# 节点组配置
managedNodeGroups:
  - name: $EKS_NODE_GROUP_NAME
    instanceType: $EKS_NODE_TYPE
    minSize: $EKS_NODE_MIN
    maxSize: $EKS_NODE_MAX
    desiredCapacity: $EKS_NODE_DESIRED
    volumeSize: 20
    volumeType: gp3
    amiFamily: AmazonLinux2
    iam:
      attachPolicyARNs:
        - arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy
        - arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy
        - arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
    tags:
      Environment: production
      Project: spring-cloud-nacos
      Owner: $AWS_USER

# 插件
addons:
  - name: vpc-cni
    version: latest
  - name: coredns
    version: latest
  - name: kube-proxy
    version: latest
EOF

echo "创建EKS集群 (预计需要15-20分钟)..."
eksctl create cluster -f /tmp/cluster-config.yaml

# 更新kubeconfig
echo "更新kubeconfig..."
aws eks update-kubeconfig --region $AWS_REGION --name $EKS_CLUSTER_NAME

# 验证集群
echo "验证集群状态..."
kubectl cluster-info
kubectl get nodes

echo ""
echo "✅ EKS集群创建完成!"
echo "集群名称: $EKS_CLUSTER_NAME"
echo "区域: $AWS_REGION"
echo "节点数量: $(kubectl get nodes --no-headers | wc -l)"

# 清理临时文件
rm -f /tmp/cluster-config.yaml

echo ""
echo "下一步: 运行 ./02-setup-cluster-components.sh 安装必要组件"
