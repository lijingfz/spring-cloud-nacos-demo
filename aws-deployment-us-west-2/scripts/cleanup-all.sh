#!/bin/bash

# AWS us-west-2 Spring Cloud Nacos 项目完整删除脚本
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

# 环境变量
CLUSTER_NAME=nacos-microservices
NAMESPACE=nacos-microservices
ECR_REGISTRY=$(aws sts get-caller-identity --query Account --output text).dkr.ecr.us-west-2.amazonaws.com
ECR_REPOSITORY_PREFIX=nacos-demo

# 确认删除
confirm_deletion() {
    log_warning "⚠️  即将删除以下AWS资源："
    echo "   - EKS集群: $CLUSTER_NAME"
    echo "   - ECR仓库: nacos-demo/*"
    echo "   - IAM角色和策略"
    echo "   - 负载均衡器和相关网络资源"
    echo ""
    log_warning "此操作不可逆转！"
    echo ""
    
    read -p "确认删除所有资源？(输入 'DELETE' 确认): " confirmation
    
    if [ "$confirmation" != "DELETE" ]; then
        log_info "删除操作已取消"
        exit 0
    fi
    
    log_info "开始删除资源..."
}

# 删除Kubernetes应用资源
delete_kubernetes_resources() {
    log_info "删除Kubernetes应用资源..."
    
    # 检查集群是否存在
    if ! kubectl config current-context | grep -q $CLUSTER_NAME 2>/dev/null; then
        log_warning "kubectl未配置或集群不存在，跳过Kubernetes资源删除"
        return 0
    fi
    
    # 删除Ingress（这会删除ALB）
    log_info "删除ALB Ingress..."
    kubectl delete ingress nacos-microservices-ingress -n $NAMESPACE --ignore-not-found=true
    
    log_info "等待ALB删除完成..."
    sleep 60
    
    # 删除所有Deployment
    log_info "删除所有Deployment..."
    kubectl delete deployment --all -n $NAMESPACE --ignore-not-found=true
    
    # 删除StatefulSet
    log_info "删除Nacos StatefulSet..."
    kubectl delete statefulset nacos-server -n $NAMESPACE --ignore-not-found=true
    
    # 删除所有Service
    log_info "删除所有Service..."
    kubectl delete service --all -n $NAMESPACE --ignore-not-found=true
    
    # 删除ConfigMap和Secret
    log_info "删除ConfigMap和Secret..."
    kubectl delete configmap --all -n $NAMESPACE --ignore-not-found=true
    kubectl delete secret --all -n $NAMESPACE --ignore-not-found=true
    
    # 删除PVC
    log_info "删除PVC..."
    kubectl delete pvc --all -n $NAMESPACE --ignore-not-found=true
    
    # 删除命名空间
    log_info "删除命名空间..."
    kubectl delete namespace $NAMESPACE --ignore-not-found=true
    
    log_success "Kubernetes应用资源删除完成"
}

# 删除AWS Load Balancer Controller
delete_alb_controller() {
    log_info "删除AWS Load Balancer Controller..."
    
    # 删除Helm release
    if helm list -n kube-system | grep -q aws-load-balancer-controller; then
        helm uninstall aws-load-balancer-controller -n kube-system
        log_success "AWS Load Balancer Controller Helm release已删除"
    fi
    
    # 删除ServiceAccount
    kubectl delete serviceaccount aws-load-balancer-controller -n kube-system --ignore-not-found=true
    
    log_success "AWS Load Balancer Controller删除完成"
}

# 删除EKS集群
delete_eks_cluster() {
    log_info "删除EKS集群..."
    
    if aws eks describe-cluster --name $CLUSTER_NAME --region us-west-2 &> /dev/null; then
        log_info "开始删除EKS集群，这可能需要10-15分钟..."
        
        # 使用eksctl删除集群（推荐方式）
        eksctl delete cluster --name $CLUSTER_NAME --region us-west-2 --wait
        
        log_success "EKS集群删除完成"
    else
        log_info "EKS集群不存在，跳过删除"
    fi
    
    # 清理本地kubeconfig
    log_info "清理本地kubeconfig..."
    kubectl config delete-context arn:aws:eks:us-west-2:$(aws sts get-caller-identity --query Account --output text):cluster/$CLUSTER_NAME 2>/dev/null || true
    kubectl config delete-cluster arn:aws:eks:us-west-2:$(aws sts get-caller-identity --query Account --output text):cluster/$CLUSTER_NAME 2>/dev/null || true
    
    log_success "本地kubeconfig清理完成"
}

# 删除ECR仓库
delete_ecr_repositories() {
    log_info "删除ECR仓库..."
    
    local services=("gateway-service" "user-service" "order-service" "notification-service")
    
    for service in "${services[@]}"; do
        local repo_name="$ECR_REPOSITORY_PREFIX/$service"
        
        if aws ecr describe-repositories --repository-names $repo_name --region us-west-2 &> /dev/null; then
            log_info "删除ECR仓库: $repo_name"
            
            # 删除所有镜像
            local image_tags=$(aws ecr list-images --repository-name $repo_name --region us-west-2 --query 'imageIds[*].imageTag' --output text 2>/dev/null || echo "")
            
            if [ ! -z "$image_tags" ]; then
                aws ecr batch-delete-image \
                    --repository-name $repo_name \
                    --image-ids imageTag=$image_tags \
                    --region us-west-2 &> /dev/null || true
            fi
            
            # 删除仓库
            aws ecr delete-repository \
                --repository-name $repo_name \
                --force \
                --region us-west-2
            
            log_success "ECR仓库 $repo_name 删除完成"
        else
            log_info "ECR仓库 $repo_name 不存在，跳过删除"
        fi
    done
}

# 删除IAM角色和策略
delete_iam_resources() {
    log_info "删除IAM角色和策略..."
    
    # 删除Load Balancer Controller角色
    if aws iam get-role --role-name AmazonEKSLoadBalancerControllerRole --region us-west-2 &> /dev/null; then
        log_info "删除Load Balancer Controller角色..."
        
        # 分离策略
        aws iam detach-role-policy \
            --role-name AmazonEKSLoadBalancerControllerRole \
            --policy-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/AWSLoadBalancerControllerIAMPolicy \
            --region us-west-2 2>/dev/null || true
        
        # 删除角色
        aws iam delete-role \
            --role-name AmazonEKSLoadBalancerControllerRole \
            --region us-west-2
        
        log_success "Load Balancer Controller角色删除完成"
    fi
    
    # 删除EKS集群服务角色
    if aws iam get-role --role-name nacos-eks-cluster-role --region us-west-2 &> /dev/null; then
        log_info "删除EKS集群服务角色..."
        
        # 分离策略
        aws iam detach-role-policy \
            --role-name nacos-eks-cluster-role \
            --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy \
            --region us-west-2 2>/dev/null || true
        
        # 删除角色
        aws iam delete-role \
            --role-name nacos-eks-cluster-role \
            --region us-west-2
        
        log_success "EKS集群服务角色删除完成"
    fi
    
    # 删除Load Balancer Controller策略
    local policy_arn="arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/AWSLoadBalancerControllerIAMPolicy"
    if aws iam get-policy --policy-arn $policy_arn --region us-west-2 &> /dev/null; then
        log_info "删除Load Balancer Controller策略..."
        aws iam delete-policy --policy-arn $policy_arn --region us-west-2
        log_success "Load Balancer Controller策略删除完成"
    fi
}

# 清理OIDC身份提供程序
delete_oidc_provider() {
    log_info "清理OIDC身份提供程序..."
    
    local oidc_arn=$(aws iam list-open-id-connect-providers \
        --query "OpenIDConnectProviderList[?contains(Arn, '$CLUSTER_NAME')].Arn" \
        --output text \
        --region us-west-2 2>/dev/null || echo "")
    
    if [ ! -z "$oidc_arn" ]; then
        aws iam delete-open-id-connect-provider \
            --open-id-connect-provider-arn $oidc_arn \
            --region us-west-2
        log_success "OIDC身份提供程序删除完成"
    else
        log_info "未找到相关的OIDC身份提供程序"
    fi
}

# 检查遗留资源
check_remaining_resources() {
    log_info "检查遗留资源..."
    
    # 检查EKS集群
    if aws eks list-clusters --region us-west-2 | grep -q $CLUSTER_NAME; then
        log_warning "EKS集群仍然存在"
    else
        log_success "EKS集群已完全删除"
    fi
    
    # 检查ECR仓库
    local remaining_repos=$(aws ecr describe-repositories --region us-west-2 2>/dev/null | grep -c nacos-demo || echo "0")
    if [ "$remaining_repos" -eq 0 ]; then
        log_success "所有ECR仓库已删除"
    else
        log_warning "仍有 $remaining_repos 个ECR仓库存在"
    fi
    
    # 检查IAM角色
    local remaining_roles=$(aws iam list-roles --query 'Roles[?contains(RoleName, `nacos`) || contains(RoleName, `EKSLoadBalancer`)].RoleName' --output text --region us-west-2 2>/dev/null || echo "")
    if [ -z "$remaining_roles" ]; then
        log_success "所有相关IAM角色已删除"
    else
        log_warning "仍有IAM角色存在: $remaining_roles"
    fi
    
    # 检查负载均衡器
    local remaining_albs=$(aws elbv2 describe-load-balancers \
        --query "LoadBalancers[?contains(LoadBalancerName, 'k8s-nacos')].LoadBalancerName" \
        --output text \
        --region us-west-2 2>/dev/null || echo "")
    if [ -z "$remaining_albs" ]; then
        log_success "所有相关负载均衡器已删除"
    else
        log_warning "仍有负载均衡器存在: $remaining_albs"
    fi
}

# 清理本地文件
cleanup_local_files() {
    log_info "清理本地文件..."
    
    # 清理Docker镜像
    local nacos_images=$(docker images | grep nacos-demo | awk '{print $3}' 2>/dev/null || echo "")
    if [ ! -z "$nacos_images" ]; then
        echo "$nacos_images" | xargs docker rmi -f 2>/dev/null || true
        log_success "本地Docker镜像清理完成"
    fi
    
    # 清理临时文件
    rm -f iam_policy.json 2>/dev/null || true
    rm -rf ~/.kube/cache/discovery/$(aws sts get-caller-identity --query Account --output text).dkr.ecr.us-west-2.amazonaws.com_* 2>/dev/null || true
    
    log_success "本地文件清理完成"
}

# 生成删除报告
generate_cleanup_report() {
    log_info "生成删除报告..."
    
    local report_file="logs/cleanup-report-$(date +%Y%m%d-%H%M%S).txt"
    mkdir -p logs
    
    cat > $report_file << EOF
AWS us-west-2 资源删除报告

删除时间: $(date)
AWS区域: us-west-2
集群名称: $CLUSTER_NAME

已删除的资源:
- EKS集群: $CLUSTER_NAME
- ECR仓库: nacos-demo/gateway-service, nacos-demo/user-service, nacos-demo/order-service, nacos-demo/notification-service
- IAM角色: nacos-eks-cluster-role, AmazonEKSLoadBalancerControllerRole
- IAM策略: AWSLoadBalancerControllerIAMPolicy
- Kubernetes资源: 所有Pod、Service、Ingress、ConfigMap、Secret
- 负载均衡器: ALB (通过Ingress删除)

预计节省费用（每天）:
- EKS集群: \$0.10/小时 × 24 = \$2.40
- EC2实例: \$0.0416/小时 × 3 × 24 = \$2.99
- ALB: \$0.0225/小时 × 24 = \$0.54
- 总计约: \$6-8/天

注意事项:
- 请在24小时后检查AWS账单确认资源已完全清理
- 如有异常费用，请联系AWS支持
- 本地Docker镜像和配置文件已清理

删除状态: 完成
EOF
    
    log_success "删除报告已生成: $report_file"
}

# 费用提醒
cost_reminder() {
    log_info "费用提醒..."
    
    echo ""
    log_success "🎉 所有AWS资源删除完成！"
    echo ""
    log_info "💰 预计节省费用："
    echo "   - EKS集群: ~\$2.40/天"
    echo "   - EC2实例: ~\$2.99/天"
    echo "   - ALB: ~\$0.54/天"
    echo "   - 总计: ~\$6-8/天"
    echo ""
    log_warning "⏰ 重要提醒："
    echo "   - 请在24小时后检查AWS账单"
    echo "   - 确认所有资源费用已停止"
    echo "   - 如有异常，请联系AWS支持"
    echo ""
}

# 主函数
main() {
    log_info "开始AWS资源删除..."
    
    local start_time=$(date +%s)
    
    # 确认删除
    confirm_deletion
    
    # 执行删除步骤
    delete_kubernetes_resources
    delete_alb_controller
    delete_eks_cluster
    delete_ecr_repositories
    delete_iam_resources
    delete_oidc_provider
    check_remaining_resources
    cleanup_local_files
    generate_cleanup_report
    cost_reminder
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))
    
    log_success "资源删除完成！总耗时: ${minutes}分${seconds}秒"
}

# 错误处理
trap 'log_error "删除过程中发生错误，请检查日志"; exit 1' ERR

# 执行主函数
main "$@"
