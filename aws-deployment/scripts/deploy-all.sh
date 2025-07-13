#!/bin/bash
# 一键部署Spring Cloud Nacos项目到AWS EKS

set -e

echo "🚀 Spring Cloud Nacos项目 AWS EKS 一键部署"
echo "=============================================="
echo ""

# 加载配置
source ../configs/aws-config.env

echo "部署配置:"
echo "  AWS账号: $AWS_ACCOUNT_ID"
echo "  AWS区域: $AWS_REGION"
echo "  EKS集群: $EKS_CLUSTER_NAME"
echo "  应用版本: $APP_VERSION"
echo ""

# 确认部署
echo "⚠️  这将创建以下AWS资源:"
echo "  - EKS集群 ($EKS_CLUSTER_NAME)"
echo "  - EC2实例 (3个 $EKS_NODE_TYPE 节点)"
echo "  - Application Load Balancer"
echo "  - ECR仓库 (4个)"
echo "  - S3存储桶 (ALB日志)"
echo ""
echo "预估成本: ~$200/月"
echo ""
echo "是否继续部署? (y/N)"
read -r response
if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo "部署已取消"
    exit 0
fi

echo ""
echo "开始部署..."

# 记录开始时间
START_TIME=$(date +%s)

# 步骤1: 创建EKS集群
echo ""
echo "📋 步骤 1/5: 创建EKS集群"
echo "================================"
./01-create-eks-cluster.sh

# 步骤2: 安装集群组件
echo ""
echo "🔧 步骤 2/5: 安装集群组件"
echo "================================"
./02-setup-cluster-components.sh

# 步骤3: 创建ECR仓库
echo ""
echo "📦 步骤 3/5: 创建ECR仓库"
echo "================================"
./03-create-ecr-repositories.sh

# 步骤4: 构建并推送镜像
echo ""
echo "🏗️  步骤 4/5: 构建并推送镜像"
echo "================================"
./04-build-and-push-images.sh

# 步骤5: 部署到EKS
echo ""
echo "🚀 步骤 5/5: 部署到EKS"
echo "================================"
./05-deploy-to-eks.sh

# 计算部署时间
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

echo ""
echo "🎉 部署完成!"
echo "=============================================="
echo "总耗时: ${MINUTES}分${SECONDS}秒"
echo ""

# 获取访问信息
echo "获取访问信息..."
sleep 10

MICROSERVICES_LB=$(kubectl get ingress microservices-ingress -n microservices -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending...")
NACOS_LB=$(kubectl get ingress nacos-console-ingress -n nacos -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending...")

echo ""
echo "🌐 访问信息"
echo "=============================================="

if [ "$MICROSERVICES_LB" != "pending..." ] && [ ! -z "$MICROSERVICES_LB" ]; then
    echo "✅ 微服务API: http://$MICROSERVICES_LB"
    echo "   健康检查: curl http://$MICROSERVICES_LB/actuator/health"
else
    echo "⏳ 微服务API: 等待Load Balancer分配 (约2-3分钟)"
    echo "   检查命令: kubectl get ingress microservices-ingress -n microservices"
fi

if [ "$NACOS_LB" != "pending..." ] && [ ! -z "$NACOS_LB" ]; then
    echo "✅ Nacos控制台: http://$NACOS_LB/nacos"
    echo "   登录账号: nacos/nacos"
else
    echo "⏳ Nacos控制台: 等待Load Balancer分配"
    echo "   检查命令: kubectl get ingress nacos-console-ingress -n nacos"
fi

echo ""
echo "📊 资源状态"
echo "=============================================="
echo "EKS集群节点:"
kubectl get nodes

echo ""
echo "微服务Pod状态:"
kubectl get pods -n microservices

echo ""
echo "🛠️  管理命令"
echo "=============================================="
echo "查看所有资源:"
echo "  kubectl get all -n microservices"
echo ""
echo "查看服务日志:"
echo "  kubectl logs -f deployment/gateway-service -n microservices"
echo "  kubectl logs -f deployment/user-service -n microservices"
echo ""
echo "扩缩容服务:"
echo "  kubectl scale deployment gateway-service --replicas=5 -n microservices"
echo ""
echo "删除部署:"
echo "  ./cleanup.sh"
echo ""

echo "🎯 API测试示例"
echo "=============================================="
if [ "$MICROSERVICES_LB" != "pending..." ] && [ ! -z "$MICROSERVICES_LB" ]; then
    echo "# 创建用户"
    echo "curl -X POST http://$MICROSERVICES_LB/api/users \\"
    echo "  -H 'Content-Type: application/json' \\"
    echo "  -d '{\"username\":\"testuser\",\"email\":\"test@example.com\",\"fullName\":\"测试用户\"}'"
    echo ""
    echo "# 获取用户列表"
    echo "curl http://$MICROSERVICES_LB/api/users"
    echo ""
    echo "# 创建订单"
    echo "curl -X POST http://$MICROSERVICES_LB/api/orders \\"
    echo "  -H 'Content-Type: application/json' \\"
    echo "  -d '{\"userId\":1,\"productName\":\"测试商品\",\"quantity\":2,\"unitPrice\":99.99}'"
else
    echo "等待Load Balancer就绪后可进行API测试"
fi

echo ""
echo "✨ 部署成功完成！"
