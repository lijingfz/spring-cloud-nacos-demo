#!/bin/bash
# 部署Spring Cloud微服务到EKS

set -e

# 加载配置
source ../configs/aws-config.env

echo "=== 部署Spring Cloud Nacos项目到EKS ==="
echo "集群: $EKS_CLUSTER_NAME"
echo "区域: $AWS_REGION"
echo "ECR Registry: $ECR_REGISTRY"
echo "版本: $APP_VERSION"
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

# 创建命名空间
echo "=== 创建命名空间 ==="
kubectl create namespace $K8S_NAMESPACE_MICROSERVICES --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace $K8S_NAMESPACE_NACOS --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace $K8S_NAMESPACE_DATABASE --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace $K8S_NAMESPACE_MONITORING --dry-run=client -o yaml | kubectl apply -f -

# 标记命名空间
kubectl label namespace $K8S_NAMESPACE_MICROSERVICES name=$K8S_NAMESPACE_MICROSERVICES --overwrite
kubectl label namespace $K8S_NAMESPACE_NACOS name=$K8S_NAMESPACE_NACOS --overwrite
kubectl label namespace $K8S_NAMESPACE_DATABASE name=$K8S_NAMESPACE_DATABASE --overwrite
kubectl label namespace $K8S_NAMESPACE_MONITORING name=$K8S_NAMESPACE_MONITORING --overwrite

echo "✅ 命名空间创建完成"

# 应用基础配置
echo ""
echo "=== 应用基础配置 ==="
kubectl apply -f ../k8s/configmap.yaml
kubectl apply -f ../k8s/secrets.yaml
echo "✅ 基础配置应用完成"

# 第一阶段：部署Nacos集群
echo ""
echo "=== 第一阶段：部署Nacos集群 ==="

if [ -d "../k8s/nacos" ]; then
    echo "部署Nacos集群..."
    kubectl apply -f ../k8s/nacos/
    
    echo "等待Nacos集群就绪 (最多10分钟)..."
    kubectl wait --for=condition=ready pod -l app=nacos -n $K8S_NAMESPACE_NACOS --timeout=600s || {
        echo "错误: Nacos启动失败，检查日志..."
        kubectl get pods -n $K8S_NAMESPACE_NACOS
        kubectl logs -l app=nacos -n $K8S_NAMESPACE_NACOS --tail=50
        exit 1
    }
    
    # 验证Nacos服务
    echo "验证Nacos服务..."
    kubectl run nacos-test --image=busybox:1.35 --rm -i --restart=Never -- \
        sh -c "nc -z nacos-service.nacos.svc.cluster.local 8848 && echo 'Nacos服务可访问'" || {
        echo "错误: Nacos服务不可访问"
        exit 1
    }
    
    echo "✅ Nacos集群部署完成并验证通过"
else
    echo "警告: 未找到Nacos配置目录"
fi

# 第二阶段：部署核心业务服务
echo ""
echo "=== 第二阶段：部署核心业务服务 ==="

# 定义服务部署顺序
CORE_SERVICES=("user-service" "notification-service")

for SERVICE in "${CORE_SERVICES[@]}"; do
    echo ""
    echo "=== 部署 $SERVICE ==="
    
    DEPLOYMENT_FILE="../k8s/${SERVICE}-deployment.yaml"
    if [ -f "$DEPLOYMENT_FILE" ]; then
        # 更新镜像标签
        sed "s|your-registry|$ECR_REGISTRY|g" $DEPLOYMENT_FILE | \
        sed "s|:latest|:$APP_VERSION|g" | \
        kubectl apply -f -
        
        # 等待部署完成
        echo "等待 $SERVICE 部署完成..."
        kubectl rollout status deployment/$SERVICE -n $K8S_NAMESPACE_MICROSERVICES --timeout=300s
        
        # 验证服务健康
        echo "验证 $SERVICE 健康状态..."
        kubectl wait --for=condition=ready pod -l app=$SERVICE -n $K8S_NAMESPACE_MICROSERVICES --timeout=120s
        
        echo "✅ $SERVICE 部署成功!"
    else
        echo "警告: 未找到 $DEPLOYMENT_FILE"
    fi
done

# 第三阶段：部署依赖业务服务
echo ""
echo "=== 第三阶段：部署依赖业务服务 ==="

DEPENDENT_SERVICES=("order-service")

for SERVICE in "${DEPENDENT_SERVICES[@]}"; do
    echo ""
    echo "=== 部署 $SERVICE ==="
    
    DEPLOYMENT_FILE="../k8s/${SERVICE}-deployment.yaml"
    if [ -f "$DEPLOYMENT_FILE" ]; then
        # 更新镜像标签
        sed "s|your-registry|$ECR_REGISTRY|g" $DEPLOYMENT_FILE | \
        sed "s|:latest|:$APP_VERSION|g" | \
        kubectl apply -f -
        
        # 等待部署完成
        echo "等待 $SERVICE 部署完成..."
        kubectl rollout status deployment/$SERVICE -n $K8S_NAMESPACE_MICROSERVICES --timeout=300s
        
        # 验证服务健康
        echo "验证 $SERVICE 健康状态..."
        kubectl wait --for=condition=ready pod -l app=$SERVICE -n $K8S_NAMESPACE_MICROSERVICES --timeout=120s
        
        echo "✅ $SERVICE 部署成功!"
    else
        echo "警告: 未找到 $DEPLOYMENT_FILE"
    fi
done

# 第四阶段：部署网关服务
echo ""
echo "=== 第四阶段：部署网关服务 ==="

echo "部署Gateway Service..."
DEPLOYMENT_FILE="../k8s/gateway-deployment.yaml"
if [ -f "$DEPLOYMENT_FILE" ]; then
    # 更新镜像标签
    sed "s|your-registry|$ECR_REGISTRY|g" $DEPLOYMENT_FILE | \
    sed "s|:latest|:$APP_VERSION|g" | \
    kubectl apply -f -
    
    # 等待部署完成
    echo "等待Gateway Service部署完成..."
    kubectl rollout status deployment/gateway-service -n $K8S_NAMESPACE_MICROSERVICES --timeout=300s
    
    # 验证网关健康
    echo "验证Gateway Service健康状态..."
    kubectl wait --for=condition=ready pod -l app=gateway-service -n $K8S_NAMESPACE_MICROSERVICES --timeout=120s
    
    echo "✅ Gateway Service部署成功!"
else
    echo "警告: 未找到Gateway部署文件"
fi

# 第五阶段：配置外部访问
echo ""
echo "=== 第五阶段：配置外部访问 ==="

# 创建S3存储桶用于ALB访问日志
echo "创建S3存储桶用于ALB访问日志..."
aws s3 mb s3://spring-cloud-nacos-alb-logs-$AWS_ACCOUNT_ID --region $AWS_REGION || echo "存储桶可能已存在"

# 应用Ingress
echo "配置Ingress..."
if [ -f "../k8s/ingress.yaml" ]; then
    kubectl apply -f ../k8s/ingress.yaml
    echo "✅ Ingress配置完成"
fi

# 应用HPA
echo "配置自动扩缩容..."
if [ -f "../k8s/hpa.yaml" ]; then
    kubectl apply -f ../k8s/hpa.yaml
    echo "✅ HPA配置完成"
fi

# 应用网络策略
if [ -f "../k8s/network-policy.yaml" ]; then
    kubectl apply -f ../k8s/network-policy.yaml
    echo "✅ 网络策略配置完成"
fi

echo ""
echo "=== 部署完成! ==="

# 最终验证
echo ""
echo "=== 最终验证 ==="

echo "服务状态:"
kubectl get pods -n $K8S_NAMESPACE_MICROSERVICES -o wide

echo ""
echo "服务列表:"
kubectl get svc -n $K8S_NAMESPACE_MICROSERVICES

echo ""
echo "Ingress状态:"
kubectl get ingress -n $K8S_NAMESPACE_MICROSERVICES
kubectl get ingress -n $K8S_NAMESPACE_NACOS

echo ""
echo "HPA状态:"
kubectl get hpa -n $K8S_NAMESPACE_MICROSERVICES

# 等待Load Balancer就绪
echo ""
echo "等待Load Balancer就绪..."
sleep 30

# 获取外部访问地址
MICROSERVICES_LB=$(kubectl get ingress microservices-ingress -n $K8S_NAMESPACE_MICROSERVICES -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending...")
NACOS_LB=$(kubectl get ingress nacos-console-ingress -n $K8S_NAMESPACE_NACOS -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending...")

echo ""
echo "=== 访问信息 ==="
if [ "$MICROSERVICES_LB" != "pending..." ] && [ ! -z "$MICROSERVICES_LB" ]; then
    echo "微服务访问地址: http://$MICROSERVICES_LB"
    echo "健康检查: curl http://$MICROSERVICES_LB/actuator/health"
    echo ""
    echo "API测试:"
    echo "  创建用户: curl -X POST http://$MICROSERVICES_LB/api/users -H 'Content-Type: application/json' -d '{\"username\":\"test\",\"email\":\"test@example.com\"}'"
    echo "  获取用户: curl http://$MICROSERVICES_LB/api/users"
else
    echo "微服务访问地址: 等待Load Balancer分配... (约2-3分钟)"
fi

if [ "$NACOS_LB" != "pending..." ] && [ ! -z "$NACOS_LB" ]; then
    echo ""
    echo "Nacos控制台: http://$NACOS_LB/nacos"
    echo "登录账号: nacos/nacos"
else
    echo "Nacos控制台: 等待Load Balancer分配..."
fi

echo ""
echo "监控命令:"
echo "  查看Pod状态: kubectl get pods -n $K8S_NAMESPACE_MICROSERVICES"
echo "  查看服务日志: kubectl logs -f deployment/gateway-service -n $K8S_NAMESPACE_MICROSERVICES"
echo "  查看Ingress状态: kubectl describe ingress microservices-ingress -n $K8S_NAMESPACE_MICROSERVICES"

echo ""
echo "🎉 部署完成！所有服务已成功部署到EKS集群。"
