#!/bin/bash
# 检查EKS中微服务的健康状态

set -e

NAMESPACE="microservices"
NACOS_NAMESPACE="nacos"
SERVICES=("gateway-service" "user-service" "order-service" "notification-service")

echo "=== Spring Cloud 微服务健康检查 ==="
echo "检查时间: $(date)"
echo ""

# 检查集群连接
echo "🔍 检查集群连接..."
if ! kubectl cluster-info > /dev/null 2>&1; then
    echo "❌ 无法连接到Kubernetes集群"
    exit 1
fi
echo "✅ 集群连接正常"
echo ""

# 检查命名空间
echo "🔍 检查命名空间..."
if kubectl get namespace $NAMESPACE > /dev/null 2>&1; then
    echo "✅ 命名空间 $NAMESPACE 存在"
else
    echo "❌ 命名空间 $NAMESPACE 不存在"
    exit 1
fi

if kubectl get namespace $NACOS_NAMESPACE > /dev/null 2>&1; then
    echo "✅ 命名空间 $NACOS_NAMESPACE 存在"
else
    echo "⚠️  命名空间 $NACOS_NAMESPACE 不存在"
fi
echo ""

# 检查Nacos状态
echo "🔍 检查Nacos服务状态..."
NACOS_PODS=$(kubectl get pods -n $NACOS_NAMESPACE -l app=nacos --no-headers 2>/dev/null | wc -l)
if [ $NACOS_PODS -gt 0 ]; then
    NACOS_READY=$(kubectl get pods -n $NACOS_NAMESPACE -l app=nacos -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' | grep -o True | wc -l)
    echo "Nacos Pods: $NACOS_READY/$NACOS_PODS 就绪"
    
    if [ $NACOS_READY -gt 0 ]; then
        echo "✅ Nacos 服务运行正常"
    else
        echo "❌ Nacos 服务未就绪"
    fi
else
    echo "⚠️  未找到Nacos服务"
fi
echo ""

# 检查微服务状态
echo "🔍 检查微服务状态..."
for SERVICE in "${SERVICES[@]}"; do
    echo "--- $SERVICE ---"
    
    # 检查Deployment是否存在
    if ! kubectl get deployment $SERVICE -n $NAMESPACE > /dev/null 2>&1; then
        echo "❌ Deployment $SERVICE 不存在"
        continue
    fi
    
    # 检查Pod状态
    READY_PODS=$(kubectl get pods -n $NAMESPACE -l app=$SERVICE -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -o True | wc -l)
    TOTAL_PODS=$(kubectl get pods -n $NAMESPACE -l app=$SERVICE --no-headers 2>/dev/null | wc -l)
    
    if [ $TOTAL_PODS -eq 0 ]; then
        echo "❌ 没有找到 $SERVICE 的Pod"
        continue
    fi
    
    echo "Pod状态: $READY_PODS/$TOTAL_PODS 就绪"
    
    # 检查Service是否存在
    if kubectl get svc $SERVICE -n $NAMESPACE > /dev/null 2>&1; then
        SERVICE_PORT=$(kubectl get svc $SERVICE -n $NAMESPACE -o jsonpath='{.spec.ports[0].port}')
        echo "Service端口: $SERVICE_PORT"
    else
        echo "⚠️  Service $SERVICE 不存在"
    fi
    
    # 检查健康端点（如果Pod就绪）
    if [ $READY_PODS -gt 0 ]; then
        POD_NAME=$(kubectl get pods -n $NAMESPACE -l app=$SERVICE -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
        if [ ! -z "$POD_NAME" ]; then
            # 获取服务端口
            case $SERVICE in
                "gateway-service") PORT=8080 ;;
                "user-service") PORT=8081 ;;
                "order-service") PORT=8082 ;;
                "notification-service") PORT=8083 ;;
                *) PORT=8080 ;;
            esac
            
            echo "检查健康端点..."
            HEALTH_STATUS=$(kubectl exec -n $NAMESPACE $POD_NAME -- curl -s -f http://localhost:$PORT/actuator/health 2>/dev/null | jq -r '.status' 2>/dev/null || echo "UNKNOWN")
            
            if [ "$HEALTH_STATUS" = "UP" ]; then
                echo "✅ 健康状态: $HEALTH_STATUS"
            else
                echo "❌ 健康状态: $HEALTH_STATUS"
            fi
        fi
    fi
    
    echo ""
done

# 检查Ingress状态
echo "🔍 检查Ingress状态..."
if kubectl get ingress -n $NAMESPACE > /dev/null 2>&1; then
    INGRESS_COUNT=$(kubectl get ingress -n $NAMESPACE --no-headers | wc -l)
    echo "Ingress数量: $INGRESS_COUNT"
    
    if [ $INGRESS_COUNT -gt 0 ]; then
        INGRESS_HOST=$(kubectl get ingress -n $NAMESPACE -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
        if [ ! -z "$INGRESS_HOST" ]; then
            echo "✅ 外部访问地址: http://$INGRESS_HOST"
        else
            echo "⚠️  Load Balancer地址分配中..."
        fi
    fi
else
    echo "⚠️  未配置Ingress"
fi
echo ""

# 检查HPA状态
echo "🔍 检查自动扩缩容状态..."
HPA_COUNT=$(kubectl get hpa -n $NAMESPACE --no-headers 2>/dev/null | wc -l)
if [ $HPA_COUNT -gt 0 ]; then
    echo "HPA配置数量: $HPA_COUNT"
    kubectl get hpa -n $NAMESPACE
else
    echo "⚠️  未配置HPA"
fi
echo ""

# 资源使用情况
echo "🔍 检查资源使用情况..."
echo "节点资源使用:"
kubectl top nodes 2>/dev/null || echo "⚠️  Metrics Server未安装或未就绪"

echo ""
echo "Pod资源使用:"
kubectl top pods -n $NAMESPACE 2>/dev/null || echo "⚠️  无法获取Pod资源使用情况"
echo ""

# 检查最近的事件
echo "🔍 最近的集群事件..."
kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' | tail -10
echo ""

# 总结
echo "=== 健康检查总结 ==="
TOTAL_SERVICES=${#SERVICES[@]}
HEALTHY_SERVICES=0

for SERVICE in "${SERVICES[@]}"; do
    READY_PODS=$(kubectl get pods -n $NAMESPACE -l app=$SERVICE -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -o True | wc -l)
    if [ $READY_PODS -gt 0 ]; then
        ((HEALTHY_SERVICES++))
    fi
done

echo "健康服务: $HEALTHY_SERVICES/$TOTAL_SERVICES"

if [ $HEALTHY_SERVICES -eq $TOTAL_SERVICES ]; then
    echo "✅ 所有服务运行正常!"
    exit 0
elif [ $HEALTHY_SERVICES -gt 0 ]; then
    echo "⚠️  部分服务存在问题"
    exit 1
else
    echo "❌ 所有服务都存在问题"
    exit 2
fi
