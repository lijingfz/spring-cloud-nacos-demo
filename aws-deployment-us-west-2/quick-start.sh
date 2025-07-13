#!/bin/bash

# AWS us-west-2 Spring Cloud Nacos 项目快速开始脚本
# 版本: 1.0

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 显示欢迎信息
show_welcome() {
    echo ""
    echo "🚀 Spring Cloud Nacos AWS us-west-2 部署工具"
    echo "================================================"
    echo ""
    echo "本工具将帮助您将Spring Cloud微服务项目部署到AWS us-west-2区域"
    echo ""
    echo "部署架构："
    echo "Internet → ALB → EKS Cluster → [Gateway, User, Order, Notification, Nacos]"
    echo ""
    echo "预计部署时间: 45-60分钟"
    echo "预计费用: ~$6-8/天"
    echo ""
}

# 检查前置条件
check_prerequisites() {
    log_info "检查前置条件..."
    
    local missing_tools=()
    local tools=("aws" "kubectl" "docker" "helm" "eksctl" "jq" "curl")
    
    for tool in "${tools[@]}"; do
        if ! command -v $tool &> /dev/null; then
            missing_tools+=($tool)
        fi
    done
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "缺少必要工具: ${missing_tools[*]}"
        echo ""
        echo "请安装缺少的工具后重试："
        echo "  - AWS CLI: https://aws.amazon.com/cli/"
        echo "  - kubectl: https://kubernetes.io/docs/tasks/tools/"
        echo "  - Docker: https://docs.docker.com/get-docker/"
        echo "  - Helm: https://helm.sh/docs/intro/install/"
        echo "  - eksctl: https://eksctl.io/installation/"
        echo "  - jq: sudo apt-get install jq"
        echo "  - curl: sudo apt-get install curl"
        exit 1
    fi
    
    # 检查AWS配置
    if ! aws sts get-caller-identity --region us-west-2 &> /dev/null; then
        log_error "AWS CLI未正确配置或无权限访问us-west-2区域"
        echo ""
        echo "请配置AWS CLI："
        echo "  aws configure"
        echo "  或设置环境变量："
        echo "  export AWS_ACCESS_KEY_ID=your-key"
        echo "  export AWS_SECRET_ACCESS_KEY=your-secret"
        exit 1
    fi
    
    # 检查Docker是否运行
    if ! docker info &> /dev/null; then
        log_error "Docker未运行，请启动Docker服务"
        exit 1
    fi
    
    log_success "所有前置条件检查通过"
}

# 显示部署选项
show_deployment_options() {
    echo ""
    log_info "请选择操作："
    echo "  1) 🚀 完整部署 (部署所有资源)"
    echo "  2) ✅ 验证部署 (验证现有部署)"
    echo "  3) 🗑️  删除资源 (删除所有AWS资源)"
    echo "  4) 📊 查看状态 (查看当前部署状态)"
    echo "  5) 📖 查看文档 (显示详细文档)"
    echo "  6) 🚪 退出"
    echo ""
}

# 完整部署
full_deployment() {
    log_info "开始完整部署..."
    
    echo ""
    log_warning "⚠️  部署将创建以下AWS资源："
    echo "   - EKS集群 (3个t3.medium节点)"
    echo "   - Application Load Balancer"
    echo "   - ECR私有仓库 (4个)"
    echo "   - IAM角色和策略"
    echo "   - EBS存储卷"
    echo ""
    echo "预计费用: ~$6-8/天"
    echo "部署时间: 45-60分钟"
    echo ""
    
    read -p "确认开始部署？(y/N): " confirm
    if [[ $confirm =~ ^[Yy]$ ]]; then
        ./scripts/deploy-all.sh
    else
        log_info "部署已取消"
    fi
}

# 验证部署
verify_deployment() {
    log_info "开始验证部署..."
    
    if kubectl get namespace nacos-microservices &> /dev/null; then
        ./scripts/verify-deployment.sh
    else
        log_error "未找到部署，请先执行完整部署"
    fi
}

# 删除资源
cleanup_resources() {
    log_warning "⚠️  即将删除所有AWS资源！"
    echo ""
    echo "这将删除："
    echo "   - EKS集群和所有节点"
    echo "   - ECR仓库和镜像"
    echo "   - 负载均衡器"
    echo "   - IAM角色和策略"
    echo "   - 所有相关的AWS资源"
    echo ""
    echo "此操作不可逆转！"
    echo ""
    
    read -p "确认删除所有资源？(输入 'DELETE' 确认): " confirm
    if [ "$confirm" = "DELETE" ]; then
        ./scripts/cleanup-all.sh
    else
        log_info "删除操作已取消"
    fi
}

# 查看状态
show_status() {
    log_info "查看当前部署状态..."
    
    echo ""
    echo "=== EKS集群状态 ==="
    if aws eks describe-cluster --name nacos-microservices --region us-west-2 &> /dev/null; then
        local cluster_status=$(aws eks describe-cluster --name nacos-microservices --region us-west-2 --query 'cluster.status' --output text)
        echo "集群状态: $cluster_status"
        
        if [ "$cluster_status" = "ACTIVE" ]; then
            echo ""
            echo "=== Pod状态 ==="
            kubectl get pods -n nacos-microservices 2>/dev/null || echo "无法获取Pod状态"
            
            echo ""
            echo "=== 服务状态 ==="
            kubectl get services -n nacos-microservices 2>/dev/null || echo "无法获取服务状态"
            
            echo ""
            echo "=== Ingress状态 ==="
            kubectl get ingress -n nacos-microservices 2>/dev/null || echo "无法获取Ingress状态"
            
            # 获取ALB地址
            local alb_address=$(kubectl get ingress nacos-microservices-ingress -n nacos-microservices -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
            if [ ! -z "$alb_address" ]; then
                echo ""
                echo "=== 访问地址 ==="
                echo "ALB地址: http://$alb_address"
                echo "API网关: http://$alb_address"
                echo "用户服务: http://$alb_address/api/users"
                echo "订单服务: http://$alb_address/api/orders"
                echo "通知服务: http://$alb_address/api/notifications"
            fi
        fi
    else
        echo "EKS集群不存在"
    fi
    
    echo ""
    echo "=== ECR仓库状态 ==="
    aws ecr describe-repositories --region us-west-2 2>/dev/null | grep nacos-demo || echo "无ECR仓库"
}

# 显示文档
show_documentation() {
    echo ""
    log_info "📖 详细文档位置："
    echo ""
    echo "主要文档："
    echo "  - 部署指南: deployment-steps/README.md"
    echo "  - 问题记录: issues-and-fixes/README.md"
    echo "  - 功能验证: verification/README.md"
    echo "  - 删除指南: cleanup/README.md"
    echo ""
    echo "配置文件："
    echo "  - Kubernetes配置: configs/"
    echo "  - 自动化脚本: scripts/"
    echo ""
    echo "日志文件："
    echo "  - 部署日志: logs/"
    echo "  - 验证报告: verification/"
    echo ""
    
    read -p "是否打开主要文档？(y/N): " open_doc
    if [[ $open_doc =~ ^[Yy]$ ]]; then
        if command -v less &> /dev/null; then
            less README.md
        else
            cat README.md
        fi
    fi
}

# 主菜单循环
main_menu() {
    while true; do
        show_deployment_options
        read -p "请选择操作 (1-6): " choice
        
        case $choice in
            1)
                full_deployment
                ;;
            2)
                verify_deployment
                ;;
            3)
                cleanup_resources
                ;;
            4)
                show_status
                ;;
            5)
                show_documentation
                ;;
            6)
                log_info "退出程序"
                exit 0
                ;;
            *)
                log_error "无效选择，请输入1-6"
                ;;
        esac
        
        echo ""
        read -p "按Enter键继续..."
    done
}

# 主函数
main() {
    show_welcome
    check_prerequisites
    main_menu
}

# 执行主函数
main "$@"
