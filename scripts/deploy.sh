#!/bin/bash
# 部署Spring Cloud微服务到EKS

set -e

# 配置变量
NAMESPACE="microservices"
NACOS_NAMESPACE="nacos"
REGISTRY="123456789012.dkr.ecr.us-west-2.amazonaws.com"  # 替换为你的ECR地址
TAG=${1:-"latest"}

echo "=== Spring Cloud Nacos 项目 EKS 部署 ==="
echo "Namespace: $NAMESPACE"
echo "Registry: $REGISTRY"
echo "Tag: $TAG"
echo ""

# 检查kubectl是否配置
if ! kubectl cluster-info > /dev/null 2>&1; then
    echo "错误: kubectl 未配置或无法连接到集群"
    echo "请运行: aws eks update-kubeconfig --region us-west-2 --name your-cluster-name"
    exit 1
fi

# 显示当前集群信息
echo "当前集群信息:"
kubectl cluster-info
echo ""

# 创建命名空间
echo "创建命名空间..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace $NACOS_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace database --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# 标记命名空间
kubectl label namespace $NAMESPACE name=$NAMESPACE --overwrite
kubectl label namespace $NACOS_NAMESPACE name=$NACOS_NAMESPACE --overwrite

echo "✅ 命名空间创建完成"

# 检查k8s目录是否存在
if [ ! -d "k8s" ]; then
    echo "错误: k8s 目录不存在，请先创建Kubernetes配置文件"
    exit 1
fi

# 应用ConfigMap和Secret
echo ""
echo "应用配置文件..."
if [ -f "k8s/configmap.yaml" ]; then
    kubectl apply -f k8s/configmap.yaml
    echo "✅ ConfigMap 应用完成"
fi

if [ -f "k8s/secrets.yaml" ]; then
    kubectl apply -f k8s/secrets.yaml
    echo "✅ Secrets 应用完成"
fi

# 部署Nacos（如果配置文件存在）
if [ -d "k8s/nacos" ]; then
    echo ""
    echo "部署Nacos集群..."
    kubectl apply -f k8s/nacos/
    
    echo "等待Nacos就绪..."
    kubectl wait --for=condition=ready pod -l app=nacos -n $NACOS_NAMESPACE --timeout=300s || {
        echo "警告: Nacos启动超时，继续部署微服务..."
    }
    echo "✅ Nacos 部署完成"
fi

# 部署微服务
SERVICES=("gateway-service" "user-service" "order-service" "notification-service")

echo ""
echo "部署微服务..."
for SERVICE in "${SERVICES[@]}"; do
    echo ""
    echo "=== 部署 $SERVICE ==="
    
    DEPLOYMENT_FILE="k8s/${SERVICE}-deployment.yaml"
    if [ -f "$DEPLOYMENT_FILE" ]; then
        # 更新镜像标签
        sed "s|your-registry|$REGISTRY|g" $DEPLOYMENT_FILE | \
        sed "s|:latest|:$TAG|g" | \
        kubectl apply -f -
        
        # 等待部署完成
        echo "等待 $SERVICE 部署完成..."
        kubectl rollout status deployment/$SERVICE -n $NAMESPACE --timeout=300s
        
        echo "✅ $SERVICE 部署成功!"
    else
        echo "警告: 未找到 $DEPLOYMENT_FILE"
    fi
done

# 应用Ingress
echo ""
echo "配置Ingress..."
if [ -f "k8s/ingress.yaml" ]; then
    kubectl apply -f k8s/ingress.yaml
    echo "✅ Ingress 配置完成"
fi

# 应用HPA
echo ""
echo "配置自动扩缩容..."
if [ -f "k8s/hpa.yaml" ]; then
    kubectl apply -f k8s/hpa.yaml
    echo "✅ HPA 配置完成"
fi

# 应用网络策略
if [ -f "k8s/network-policy.yaml" ]; then
    kubectl apply -f k8s/network-policy.yaml
    echo "✅ 网络策略配置完成"
fi

echo ""
echo "=== 部署完成! ==="
echo ""

# 显示服务状态
echo "服务状态:"
kubectl get pods -n $NAMESPACE -o wide
echo ""

echo "服务列表:"
kubectl get svc -n $NAMESPACE
echo ""

echo "Ingress状态:"
kubectl get ingress -n $NAMESPACE
echo ""

echo "HPA状态:"
kubectl get hpa -n $NAMESPACE
echo ""

# 显示访问信息
echo "=== 访问信息 ==="
INGRESS_HOST=$(kubectl get ingress -n $NAMESPACE -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending...")
if [ "$INGRESS_HOST" != "pending..." ] && [ ! -z "$INGRESS_HOST" ]; then
    echo "外部访问地址: http://$INGRESS_HOST"
else
    echo "外部访问地址: 等待Load Balancer分配..."
    echo "运行以下命令查看状态: kubectl get ingress -n $NAMESPACE"
fi

echo ""
echo "内部服务地址:"
for SERVICE in "${SERVICES[@]}"; do
    PORT=$(kubectl get svc $SERVICE -n $NAMESPACE -o jsonpath='{.spec.ports[0].port}' 2>/dev/null || echo "N/A")
    echo "  - $SERVICE: http://$SERVICE.$NAMESPACE.svc.cluster.local:$PORT"
done

echo ""
echo "健康检查:"
echo "运行 './scripts/health-check.sh' 检查服务健康状态"

echo ""
echo "日志查看:"
echo "kubectl logs -f deployment/gateway-service -n $NAMESPACE"
echo "kubectl logs -f deployment/user-service -n $NAMESPACE"
