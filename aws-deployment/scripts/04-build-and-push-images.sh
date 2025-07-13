#!/bin/bash
# 构建并推送Docker镜像到ECR

set -e

# 加载配置
source ../configs/aws-config.env

echo "=== 构建并推送Docker镜像 ==="
echo "ECR Registry: $ECR_REGISTRY"
echo "版本: $APP_VERSION"
echo ""

# 检查Docker是否运行
if ! docker info > /dev/null 2>&1; then
    echo "错误: Docker未运行，请启动Docker服务"
    exit 1
fi

# 回到项目根目录
cd ../../

# 检查项目结构
if [ ! -f "pom.xml" ]; then
    echo "错误: 未找到项目根目录的pom.xml文件"
    exit 1
fi

# 登录到ECR
echo "登录到ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY

# 构建Maven项目
echo ""
echo "构建Maven项目..."
mvn clean package -DskipTests -q

echo "✅ Maven构建完成"

# 构建并推送每个服务的镜像
for SERVICE in "${ECR_REPOSITORIES[@]}"; do
    echo ""
    echo "=== 处理服务: $SERVICE ==="
    
    # 检查服务目录是否存在
    if [ ! -d "$SERVICE" ]; then
        echo "错误: 服务目录 $SERVICE 不存在"
        continue
    fi
    
    # 检查Dockerfile是否存在
    if [ ! -f "$SERVICE/Dockerfile" ]; then
        echo "错误: $SERVICE/Dockerfile 不存在"
        continue
    fi
    
    # 检查JAR文件是否存在
    JAR_FILE=$(find ./$SERVICE/target -name "*.jar" -not -name "*sources.jar" | head -1)
    if [ -z "$JAR_FILE" ]; then
        echo "错误: 未找到 $SERVICE 的JAR文件"
        continue
    fi
    
    echo "找到JAR文件: $JAR_FILE"
    
    # 构建镜像
    echo "构建Docker镜像..."
    docker build -t $SERVICE:$APP_VERSION ./$SERVICE
    docker build -t $SERVICE:latest ./$SERVICE
    
    # 标记镜像
    echo "标记镜像..."
    docker tag $SERVICE:$APP_VERSION $ECR_REGISTRY/$SERVICE:$APP_VERSION
    docker tag $SERVICE:latest $ECR_REGISTRY/$SERVICE:latest
    
    # 推送镜像
    echo "推送镜像到ECR..."
    docker push $ECR_REGISTRY/$SERVICE:$APP_VERSION
    docker push $ECR_REGISTRY/$SERVICE:latest
    
    # 清理本地镜像以节省空间
    docker rmi $SERVICE:$APP_VERSION $SERVICE:latest || true
    
    echo "✅ $SERVICE 镜像推送成功!"
done

echo ""
echo "=== 镜像构建和推送完成! ==="
echo ""
echo "推送的镜像:"
for SERVICE in "${ECR_REPOSITORIES[@]}"; do
    echo "  - $ECR_REGISTRY/$SERVICE:$APP_VERSION"
    echo "  - $ECR_REGISTRY/$SERVICE:latest"
done

echo ""
echo "验证ECR中的镜像:"
for SERVICE in "${ECR_REPOSITORIES[@]}"; do
    echo ""
    echo "$SERVICE 镜像:"
    aws ecr list-images --repository-name $SERVICE --region $AWS_REGION --query 'imageIds[].imageTag' --output table || echo "  无镜像"
done

echo ""
echo "下一步: 运行 ./05-deploy-to-eks.sh 部署到EKS集群"
