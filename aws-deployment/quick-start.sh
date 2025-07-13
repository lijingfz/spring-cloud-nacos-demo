#!/bin/bash
# Spring Cloud Nacos 项目 AWS EKS 快速开始

set -e

echo "🚀 Spring Cloud Nacos 项目 AWS EKS 快速开始"
echo "=============================================="
echo ""

# 检查当前目录
if [ ! -f "configs/aws-config.env" ]; then
    echo "错误: 请在aws-deployment目录中运行此脚本"
    echo "cd aws-deployment && ./quick-start.sh"
    exit 1
fi

# 加载配置
source configs/aws-config.env

echo "📋 部署信息"
echo "=============================================="
echo "AWS账号: $AWS_ACCOUNT_ID"
echo "AWS区域: $AWS_REGION"
echo "EKS集群: $EKS_CLUSTER_NAME"
echo "应用版本: $APP_VERSION"
echo ""

# 检查前置条件
echo "🔍 检查前置条件"
echo "=============================================="

# 检查AWS CLI
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI未安装"
    echo "请安装AWS CLI: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    exit 1
fi

# 检查AWS配置
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "❌ AWS CLI未配置"
    echo "请运行: aws configure"
    exit 1
fi

echo "✅ AWS CLI已配置"

# 检查Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker未安装"
    echo "请安装Docker: https://docs.docker.com/get-docker/"
    exit 1
fi

if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker未运行"
    echo "请启动Docker服务"
    exit 1
fi

echo "✅ Docker已就绪"

# 检查项目结构
if [ ! -f "../pom.xml" ]; then
    echo "❌ 未找到项目根目录"
    echo "请确保在正确的目录中运行脚本"
    exit 1
fi

echo "✅ 项目结构正确"

# 显示将要创建的资源
echo ""
echo "📦 将要创建的AWS资源"
echo "=============================================="
echo "EKS集群:"
echo "  - 集群名称: $EKS_CLUSTER_NAME"
echo "  - 节点类型: $EKS_NODE_TYPE"
echo "  - 节点数量: $EKS_NODE_DESIRED"
echo ""
echo "ECR仓库:"
for REPO in "${ECR_REPOSITORIES[@]}"; do
    echo "  - $REPO"
done
echo ""
echo "其他资源:"
echo "  - Application Load Balancer"
echo "  - S3存储桶 (ALB日志)"
echo "  - 相关安全组和IAM角色"
echo ""

# 成本提醒
echo "💰 预估成本"
echo "=============================================="
echo "月度成本 (us-west-2区域):"
echo "  - EKS集群控制平面: ~$73"
echo "  - EC2实例 (3x t3.medium): ~$95"
echo "  - Application Load Balancer: ~$23"
echo "  - 其他 (ECR, S3等): ~$7"
echo "  - 总计: ~$198/月"
echo ""
echo "⚠️  请确保在测试完成后运行清理脚本以避免持续计费"
echo ""

# 确认部署
echo "是否继续部署? (y/N)"
read -r response
if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo "部署已取消"
    exit 0
fi

echo ""
echo "🎯 开始部署流程"
echo "=============================================="

# 进入scripts目录
cd scripts

# 执行一键部署
echo "执行一键部署脚本..."
./deploy-all.sh

echo ""
echo "🎉 快速开始完成!"
echo "=============================================="
echo ""
echo "后续步骤:"
echo "1. 等待Load Balancer分配地址 (约2-3分钟)"
echo "2. 测试API接口"
echo "3. 访问Nacos控制台"
echo "4. 完成后运行 ./cleanup.sh 清理资源"
echo ""
echo "获取访问地址:"
echo "kubectl get ingress -n microservices"
echo "kubectl get ingress -n nacos"
