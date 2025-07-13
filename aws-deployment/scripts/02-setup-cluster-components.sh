#!/bin/bash
# 安装EKS集群必要组件

set -e

# 加载配置
source ../configs/aws-config.env

echo "=== 安装EKS集群组件 ==="
echo "集群: $EKS_CLUSTER_NAME"
echo "区域: $AWS_REGION"
echo ""

# 验证集群连接
if ! kubectl cluster-info > /dev/null 2>&1; then
    echo "错误: 无法连接到EKS集群"
    echo "请先运行: aws eks update-kubeconfig --region $AWS_REGION --name $EKS_CLUSTER_NAME"
    exit 1
fi

echo "当前集群信息:"
kubectl cluster-info
echo ""

# 1. 安装AWS Load Balancer Controller
echo "=== 安装AWS Load Balancer Controller ==="

# 下载IAM策略
echo "下载IAM策略..."
curl -o /tmp/iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.2/docs/install/iam_policy.json

# 创建IAM策略
echo "创建IAM策略..."
aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file:///tmp/iam_policy.json \
    --region $AWS_REGION || echo "策略可能已存在"

# 创建服务账户
echo "创建服务账户..."
eksctl create iamserviceaccount \
  --cluster=$EKS_CLUSTER_NAME \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --attach-policy-arn=arn:aws:iam::$AWS_ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve \
  --region=$AWS_REGION || echo "服务账户可能已存在"

# 添加Helm仓库
echo "添加EKS Helm仓库..."
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# 安装Load Balancer Controller
echo "安装AWS Load Balancer Controller..."
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$EKS_CLUSTER_NAME \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=$AWS_REGION \
  --set vpcId=$(aws eks describe-cluster --name $EKS_CLUSTER_NAME --region $AWS_REGION --query "cluster.resourcesVpcConfig.vpcId" --output text)

echo "✅ AWS Load Balancer Controller安装完成"

# 2. 安装Metrics Server
echo ""
echo "=== 安装Metrics Server ==="
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
echo "✅ Metrics Server安装完成"

# 3. 安装Cluster Autoscaler
echo ""
echo "=== 安装Cluster Autoscaler ==="

# 创建IAM策略
cat > /tmp/cluster-autoscaler-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "autoscaling:DescribeAutoScalingGroups",
                "autoscaling:DescribeAutoScalingInstances",
                "autoscaling:DescribeLaunchConfigurations",
                "autoscaling:DescribeTags",
                "autoscaling:SetDesiredCapacity",
                "autoscaling:TerminateInstanceInAutoScalingGroup",
                "ec2:DescribeLaunchTemplateVersions"
            ],
            "Resource": "*"
        }
    ]
}
EOF

aws iam create-policy \
    --policy-name AmazonEKSClusterAutoscalerPolicy \
    --policy-document file:///tmp/cluster-autoscaler-policy.json \
    --region $AWS_REGION || echo "策略可能已存在"

# 创建服务账户
eksctl create iamserviceaccount \
  --cluster=$EKS_CLUSTER_NAME \
  --namespace=kube-system \
  --name=cluster-autoscaler \
  --attach-policy-arn=arn:aws:iam::$AWS_ACCOUNT_ID:policy/AmazonEKSClusterAutoscalerPolicy \
  --override-existing-serviceaccounts \
  --approve \
  --region=$AWS_REGION

# 部署Cluster Autoscaler
curl -o /tmp/cluster-autoscaler-autodiscover.yaml https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml

# 替换集群名称
sed -i "s/<YOUR CLUSTER NAME>/$EKS_CLUSTER_NAME/g" /tmp/cluster-autoscaler-autodiscover.yaml

kubectl apply -f /tmp/cluster-autoscaler-autodiscover.yaml

# 添加注解
kubectl annotate serviceaccount cluster-autoscaler \
  -n kube-system \
  eks.amazonaws.com/role-arn=arn:aws:iam::$AWS_ACCOUNT_ID:role/eksctl-$EKS_CLUSTER_NAME-addon-iamserviceaccount-kube-system-cluster-autoscaler

echo "✅ Cluster Autoscaler安装完成"

# 4. 创建存储类
echo ""
echo "=== 创建存储类 ==="
cat > /tmp/storage-class.yaml << EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3-encrypted
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  encrypted: "true"
  fsType: ext4
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
EOF

kubectl apply -f /tmp/storage-class.yaml
echo "✅ 存储类创建完成"

# 5. 等待所有组件就绪
echo ""
echo "=== 等待组件就绪 ==="
echo "等待AWS Load Balancer Controller..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=aws-load-balancer-controller -n kube-system --timeout=300s

echo "等待Metrics Server..."
kubectl wait --for=condition=ready pod -l k8s-app=metrics-server -n kube-system --timeout=300s

echo "等待Cluster Autoscaler..."
kubectl wait --for=condition=ready pod -l app=cluster-autoscaler -n kube-system --timeout=300s

# 验证安装
echo ""
echo "=== 验证安装 ==="
echo "集群节点:"
kubectl get nodes

echo ""
echo "系统组件:"
kubectl get pods -n kube-system | grep -E "(aws-load-balancer-controller|metrics-server|cluster-autoscaler)"

echo ""
echo "存储类:"
kubectl get storageclass

# 清理临时文件
rm -f /tmp/iam_policy.json /tmp/cluster-autoscaler-policy.json /tmp/cluster-autoscaler-autodiscover.yaml /tmp/storage-class.yaml

echo ""
echo "✅ 所有组件安装完成!"
echo ""
echo "下一步: 运行 ./03-create-ecr-repositories.sh 创建ECR仓库"
