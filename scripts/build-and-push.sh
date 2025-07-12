#!/bin/bash
# 构建和推送Docker镜像到ECR

set -e

# 配置变量
REGION="us-west-2"
ACCOUNT_ID="123456789012"  # 替换为你的AWS账户ID
REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
TAG=${1:-"v1.0.0"}

echo "=== Spring Cloud Nacos 项目 Docker 镜像构建和推送 ==="
echo "Registry: $REGISTRY"
echo "Tag: $TAG"
echo "Region: $REGION"
echo ""

# 检查Docker是否运行
if ! docker info > /dev/null 2>&1; then
    echo "错误: Docker 未运行，请启动Docker服务"
    exit 1
fi

# 检查AWS CLI是否配置
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "错误: AWS CLI 未配置，请运行 'aws configure'"
    exit 1
fi

# 登录到ECR
echo "登录到Amazon ECR..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $REGISTRY

# 构建Maven项目
echo "构建Maven项目..."
mvn clean package -DskipTests

# 服务列表
SERVICES=("gateway-service" "user-service" "order-service" "notification-service")

# 构建并推送每个服务
for SERVICE in "${SERVICES[@]}"; do
    echo ""
    echo "=== 处理服务: $SERVICE ==="
    
    # 检查JAR文件是否存在
    JAR_FILE=$(find ./$SERVICE/target -name "*.jar" -not -name "*sources.jar" | head -1)
    if [ -z "$JAR_FILE" ]; then
        echo "错误: 未找到 $SERVICE 的JAR文件"
        continue
    fi
    
    echo "找到JAR文件: $JAR_FILE"
    
    # 构建镜像
    echo "构建Docker镜像..."
    docker build -t $SERVICE:$TAG ./$SERVICE
    
    # 标记镜像
    echo "标记镜像..."
    docker tag $SERVICE:$TAG $REGISTRY/$SERVICE:$TAG
    docker tag $SERVICE:$TAG $REGISTRY/$SERVICE:latest
    
    # 推送镜像
    echo "推送镜像到ECR..."
    docker push $REGISTRY/$SERVICE:$TAG
    docker push $REGISTRY/$SERVICE:latest
    
    echo "✅ $SERVICE 镜像推送成功!"
done

echo ""
echo "=== 所有服务镜像构建和推送完成! ==="
echo ""
echo "推送的镜像:"
for SERVICE in "${SERVICES[@]}"; do
    echo "  - $REGISTRY/$SERVICE:$TAG"
    echo "  - $REGISTRY/$SERVICE:latest"
done

echo ""
echo "下一步:"
echo "1. 更新 k8s/*.yaml 文件中的镜像地址"
echo "2. 运行 './scripts/deploy.sh' 部署到EKS"
