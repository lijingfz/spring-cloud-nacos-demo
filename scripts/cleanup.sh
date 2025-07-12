#!/bin/bash
# 清理EKS中的微服务部署

set -e

NAMESPACE="microservices"
NACOS_NAMESPACE="nacos"
SERVICES=("gateway-service" "user-service" "order-service" "notification-service")

echo "=== Spring Cloud 微服务清理脚本 ==="
echo "⚠️  警告: 此脚本将删除所有相关的Kubernetes资源"
echo ""

# 确认操作
read -p "确定要继续吗? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "操作已取消"
    exit 0
fi

echo "开始清理..."
echo ""

# 删除HPA
echo "🗑️  删除HPA配置..."
kubectl delete hpa --all -n $NAMESPACE 2>/dev/null || echo "没有找到HPA配置"

# 删除Ingress
echo "🗑️  删除Ingress..."
kubectl delete ingress --all -n $NAMESPACE 2>/dev/null || echo "没有找到Ingress"

# 删除微服务
echo "🗑️  删除微服务..."
for SERVICE in "${SERVICES[@]}"; do
    echo "删除 $SERVICE..."
    kubectl delete deployment $SERVICE -n $NAMESPACE 2>/dev/null || echo "$SERVICE deployment 不存在"
    kubectl delete service $SERVICE -n $NAMESPACE 2>/dev/null || echo "$SERVICE service 不存在"
done

# 删除ConfigMap和Secret
echo "🗑️  删除配置文件..."
kubectl delete configmap --all -n $NAMESPACE 2>/dev/null || echo "没有找到ConfigMap"
kubectl delete secret --all -n $NAMESPACE 2>/dev/null || echo "没有找到Secret"

# 删除网络策略
echo "🗑️  删除网络策略..."
kubectl delete networkpolicy --all -n $NAMESPACE 2>/dev/null || echo "没有找到网络策略"

# 询问是否删除Nacos
echo ""
read -p "是否删除Nacos服务? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🗑️  删除Nacos服务..."
    kubectl delete statefulset --all -n $NACOS_NAMESPACE 2>/dev/null || echo "没有找到Nacos StatefulSet"
    kubectl delete service --all -n $NACOS_NAMESPACE 2>/dev/null || echo "没有找到Nacos Service"
    kubectl delete configmap --all -n $NACOS_NAMESPACE 2>/dev/null || echo "没有找到Nacos ConfigMap"
    kubectl delete secret --all -n $NACOS_NAMESPACE 2>/dev/null || echo "没有找到Nacos Secret"
    kubectl delete pvc --all -n $NACOS_NAMESPACE 2>/dev/null || echo "没有找到Nacos PVC"
fi

# 询问是否删除命名空间
echo ""
read -p "是否删除命名空间? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🗑️  删除命名空间..."
    kubectl delete namespace $NAMESPACE 2>/dev/null || echo "命名空间 $NAMESPACE 不存在"
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        kubectl delete namespace $NACOS_NAMESPACE 2>/dev/null || echo "命名空间 $NACOS_NAMESPACE 不存在"
    fi
    
    kubectl delete namespace database 2>/dev/null || echo "命名空间 database 不存在"
    kubectl delete namespace monitoring 2>/dev/null || echo "命名空间 monitoring 不存在"
fi

echo ""
echo "✅ 清理完成!"
echo ""

# 显示剩余资源
echo "剩余资源:"
kubectl get all -n $NAMESPACE 2>/dev/null || echo "命名空间 $NAMESPACE 已删除或为空"

if kubectl get namespace $NACOS_NAMESPACE > /dev/null 2>&1; then
    echo ""
    echo "Nacos命名空间剩余资源:"
    kubectl get all -n $NACOS_NAMESPACE 2>/dev/null || echo "命名空间 $NACOS_NAMESPACE 为空"
fi

echo ""
echo "如需重新部署，请运行: ./scripts/deploy.sh"
