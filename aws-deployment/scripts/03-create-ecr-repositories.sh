#!/bin/bash
# 创建ECR仓库

set -e

# 加载配置
source ../configs/aws-config.env

echo "=== 创建ECR仓库 ==="
echo "区域: $AWS_REGION"
echo "账号: $AWS_ACCOUNT_ID"
echo ""

# 验证AWS配置
aws sts get-caller-identity

echo ""
echo "创建ECR仓库..."

# 创建每个服务的ECR仓库
for REPO in "${ECR_REPOSITORIES[@]}"; do
    echo "创建仓库: $REPO"
    
    # 检查仓库是否已存在
    if aws ecr describe-repositories --repository-names $REPO --region $AWS_REGION &> /dev/null; then
        echo "⚠️  仓库 $REPO 已存在"
    else
        # 创建仓库
        aws ecr create-repository \
            --repository-name $REPO \
            --region $AWS_REGION \
            --image-scanning-configuration scanOnPush=true \
            --encryption-configuration encryptionType=AES256
        
        echo "✅ 仓库 $REPO 创建成功"
    fi
    
    # 设置生命周期策略
    cat > /tmp/lifecycle-policy.json << EOF
{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Keep last 10 images",
            "selection": {
                "tagStatus": "tagged",
                "countType": "imageCountMoreThan",
                "countNumber": 10
            },
            "action": {
                "type": "expire"
            }
        },
        {
            "rulePriority": 2,
            "description": "Delete untagged images older than 1 day",
            "selection": {
                "tagStatus": "untagged",
                "countType": "sinceImagePushed",
                "countUnit": "days",
                "countNumber": 1
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
EOF

    aws ecr put-lifecycle-policy \
        --repository-name $REPO \
        --lifecycle-policy-text file:///tmp/lifecycle-policy.json \
        --region $AWS_REGION > /dev/null
    
    echo "  - 生命周期策略已设置"
done

# 获取登录令牌并登录Docker
echo ""
echo "登录到ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY

echo ""
echo "✅ ECR仓库创建完成!"
echo ""
echo "创建的仓库:"
for REPO in "${ECR_REPOSITORIES[@]}"; do
    echo "  - $ECR_REGISTRY/$REPO"
done

echo ""
echo "ECR仓库列表:"
aws ecr describe-repositories --region $AWS_REGION --query 'repositories[].repositoryName' --output table

# 清理临时文件
rm -f /tmp/lifecycle-policy.json

echo ""
echo "下一步: 运行 ./04-build-and-push-images.sh 构建并推送镜像"
