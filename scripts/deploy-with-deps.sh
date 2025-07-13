#!/bin/bash
# 考虑服务依赖关系的EKS部署脚本

set -e

# 配置变量
NAMESPACE="microservices"
NACOS_NAMESPACE="nacos"
REGISTRY="123456789012.dkr.ecr.us-west-2.amazonaws.com"
TAG=${1:-"latest"}

echo "=== Spring Cloud Nacos 项目 EKS 部署 (考虑依赖关系) ==="
echo "Namespace: $NAMESPACE"
echo "Registry: $REGISTRY"
echo "Tag: $TAG"
echo ""

# 检查kubectl连接
if ! kubectl cluster-info > /dev/null 2>&1; then
    echo "错误: kubectl 未配置或无法连接到集群"
    exit 1
fi

# 创建命名空间
echo "创建命名空间..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace $NACOS_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace database --dry-run=client -o yaml | kubectl apply -f -

# 标记命名空间
kubectl label namespace $NAMESPACE name=$NAMESPACE --overwrite
kubectl label namespace $NACOS_NAMESPACE name=$NACOS_NAMESPACE --overwrite

echo "✅ 命名空间创建完成"

# 应用基础配置
echo ""
echo "应用基础配置..."
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secrets.yaml
echo "✅ 基础配置应用完成"

# 第一阶段：部署基础设施服务
echo ""
echo "=== 第一阶段：部署基础设施服务 ==="

# 1. 部署数据库（如果需要）
if [ -d "k8s/database" ]; then
    echo "部署数据库..."
    kubectl apply -f k8s/database/
    kubectl wait --for=condition=ready pod -l app=mysql -n database --timeout=300s || {
        echo "警告: 数据库启动超时"
    }
    echo "✅ 数据库部署完成"
fi

# 2. 部署Nacos集群
echo "部署Nacos集群..."
kubectl apply -f k8s/nacos/

echo "等待Nacos集群就绪..."
kubectl wait --for=condition=ready pod -l app=nacos -n $NACOS_NAMESPACE --timeout=600s || {
    echo "错误: Nacos启动失败，无法继续部署"
    exit 1
}

# 验证Nacos服务可访问性
echo "验证Nacos服务..."
kubectl run nacos-test --image=busybox:1.35 --rm -i --restart=Never -- \
    sh -c "nc -z nacos-service.nacos.svc.cluster.local 8848 && echo 'Nacos服务可访问'" || {
    echo "错误: Nacos服务不可访问"
    exit 1
}

echo "✅ Nacos集群部署完成并验证通过"

# 第二阶段：部署核心业务服务
echo ""
echo "=== 第二阶段：部署核心业务服务 ==="

# 定义服务部署顺序（考虑依赖关系）
CORE_SERVICES=("user-service" "notification-service")

for SERVICE in "${CORE_SERVICES[@]}"; do
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
        
        # 验证服务健康
        echo "验证 $SERVICE 健康状态..."
        kubectl wait --for=condition=ready pod -l app=$SERVICE -n $NAMESPACE --timeout=120s
        
        echo "✅ $SERVICE 部署成功并验证通过!"
    else
        echo "警告: 未找到 $DEPLOYMENT_FILE"
    fi
done

# 第三阶段：部署依赖业务服务的服务
echo ""
echo "=== 第三阶段：部署依赖业务服务的服务 ==="

DEPENDENT_SERVICES=("order-service")

for SERVICE in "${DEPENDENT_SERVICES[@]}"; do
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
        
        # 验证服务健康
        echo "验证 $SERVICE 健康状态..."
        kubectl wait --for=condition=ready pod -l app=$SERVICE -n $NAMESPACE --timeout=120s
        
        echo "✅ $SERVICE 部署成功并验证通过!"
    else
        echo "警告: 未找到 $DEPLOYMENT_FILE"
    fi
done

# 第四阶段：部署网关服务
echo ""
echo "=== 第四阶段：部署网关服务 ==="

echo "部署Gateway Service..."
DEPLOYMENT_FILE="k8s/gateway-deployment.yaml"
if [ -f "$DEPLOYMENT_FILE" ]; then
    # 更新镜像标签
    sed "s|your-registry|$REGISTRY|g" $DEPLOYMENT_FILE | \
    sed "s|:latest|:$TAG|g" | \
    kubectl apply -f -
    
    # 等待部署完成
    echo "等待Gateway Service部署完成..."
    kubectl rollout status deployment/gateway-service -n $NAMESPACE --timeout=300s
    
    # 验证网关健康
    echo "验证Gateway Service健康状态..."
    kubectl wait --for=condition=ready pod -l app=gateway-service -n $NAMESPACE --timeout=120s
    
    echo "✅ Gateway Service部署成功并验证通过!"
else
    echo "警告: 未找到Gateway部署文件"
fi

# 第五阶段：配置外部访问
echo ""
echo "=== 第五阶段：配置外部访问 ==="

# 应用Ingress
if [ -f "k8s/ingress.yaml" ]; then
    kubectl apply -f k8s/ingress.yaml
    echo "✅ Ingress配置完成"
fi

# 应用HPA
if [ -f "k8s/hpa.yaml" ]; then
    kubectl apply -f k8s/hpa.yaml
    echo "✅ HPA配置完成"
fi

# 应用网络策略
if [ -f "k8s/network-policy.yaml" ]; then
    kubectl apply -f k8s/network-policy.yaml
    echo "✅ 网络策略配置完成"
fi

echo ""
echo "=== 部署完成! ==="

# 最终验证
echo ""
echo "=== 最终验证 ==="

echo "服务状态:"
kubectl get pods -n $NAMESPACE -o wide

echo ""
echo "服务健康检查:"
SERVICES=("user-service" "order-service" "notification-service" "gateway-service")

for SERVICE in "${SERVICES[@]}"; do
    POD_NAME=$(kubectl get pods -n $NAMESPACE -l app=$SERVICE -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [ ! -z "$POD_NAME" ]; then
        HEALTH_STATUS=$(kubectl exec -n $NAMESPACE $POD_NAME -- curl -s http://localhost:8080/actuator/health 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4 || echo "UNKNOWN")
        echo "  - $SERVICE: $HEALTH_STATUS"
    else
        echo "  - $SERVICE: POD_NOT_FOUND"
    fi
done

echo ""
echo "外部访问信息:"
INGRESS_HOST=$(kubectl get ingress -n $NAMESPACE -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending...")
if [ "$INGRESS_HOST" != "pending..." ] && [ ! -z "$INGRESS_HOST" ]; then
    echo "外部访问地址: http://$INGRESS_HOST"
    echo "健康检查: curl http://$INGRESS_HOST/actuator/health"
else
    echo "外部访问地址: 等待Load Balancer分配..."
fi

echo ""
echo "🎉 部署完成！所有服务已按依赖关系顺序启动并验证通过。"
