#!/bin/bash

# AWS us-west-2 部署状态检查脚本
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
REGION=us-west-2

# 显示标题
show_header() {
    echo ""
    echo "🔍 AWS us-west-2 部署状态检查"
    echo "================================"
    echo "集群: $CLUSTER_NAME"
    echo "区域: $REGION"
    echo "时间: $(date)"
    echo ""
}

# 检查AWS连接
check_aws_connection() {
    log_info "检查AWS连接..."
    
    if aws sts get-caller-identity --region $REGION &> /dev/null; then
        local account_id=$(aws sts get-caller-identity --query Account --output text)
        local user_arn=$(aws sts get-caller-identity --query Arn --output text)
        log_success "AWS连接正常"
        echo "  账户ID: $account_id"
        echo "  用户ARN: $user_arn"
    else
        log_error "AWS连接失败"
        return 1
    fi
}

# 检查EKS集群状态
check_eks_cluster() {
    log_info "检查EKS集群状态..."
    
    if aws eks describe-cluster --name $CLUSTER_NAME --region $REGION &> /dev/null; then
        local cluster_status=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query 'cluster.status' --output text)
        local cluster_version=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query 'cluster.version' --output text)
        local cluster_endpoint=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query 'cluster.endpoint' --output text)
        
        if [ "$cluster_status" = "ACTIVE" ]; then
            log_success "EKS集群运行正常"
            echo "  状态: $cluster_status"
            echo "  版本: $cluster_version"
            echo "  端点: $cluster_endpoint"
        else
            log_warning "EKS集群状态异常: $cluster_status"
        fi
        
        # 检查节点组
        local nodegroups=$(aws eks list-nodegroups --cluster-name $CLUSTER_NAME --region $REGION --query 'nodegroups' --output text)
        if [ ! -z "$nodegroups" ]; then
            log_info "节点组: $nodegroups"
            for ng in $nodegroups; do
                local ng_status=$(aws eks describe-nodegroup --cluster-name $CLUSTER_NAME --nodegroup-name $ng --region $REGION --query 'nodegroup.status' --output text)
                echo "  $ng: $ng_status"
            done
        fi
    else
        log_error "EKS集群不存在"
        return 1
    fi
}

# 检查kubectl连接
check_kubectl_connection() {
    log_info "检查kubectl连接..."
    
    if kubectl cluster-info &> /dev/null; then
        log_success "kubectl连接正常"
        kubectl cluster-info | head -2
    else
        log_error "kubectl连接失败"
        echo "请运行: aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME"
        return 1
    fi
}

# 检查节点状态
check_nodes() {
    log_info "检查节点状态..."
    
    local nodes_output=$(kubectl get nodes --no-headers 2>/dev/null || echo "")
    if [ ! -z "$nodes_output" ]; then
        local total_nodes=$(echo "$nodes_output" | wc -l)
        local ready_nodes=$(echo "$nodes_output" | grep -c Ready || echo "0")
        
        if [ "$ready_nodes" -eq "$total_nodes" ] && [ "$total_nodes" -gt 0 ]; then
            log_success "节点状态正常: $ready_nodes/$total_nodes 个节点就绪"
        else
            log_warning "节点状态异常: $ready_nodes/$total_nodes 个节点就绪"
        fi
        
        echo ""
        kubectl get nodes -o wide
    else
        log_error "无法获取节点信息"
        return 1
    fi
}

# 检查命名空间
check_namespace() {
    log_info "检查命名空间..."
    
    if kubectl get namespace $NAMESPACE &> /dev/null; then
        log_success "命名空间 $NAMESPACE 存在"
    else
        log_error "命名空间 $NAMESPACE 不存在"
        return 1
    fi
}

# 检查Pod状态
check_pods() {
    log_info "检查Pod状态..."
    
    local pods_output=$(kubectl get pods -n $NAMESPACE --no-headers 2>/dev/null || echo "")
    if [ ! -z "$pods_output" ]; then
        local total_pods=$(echo "$pods_output" | wc -l)
        local running_pods=$(echo "$pods_output" | grep -c Running || echo "0")
        local pending_pods=$(echo "$pods_output" | grep -c Pending || echo "0")
        local failed_pods=$(echo "$pods_output" | grep -c -E "(Error|CrashLoopBackOff|ImagePullBackOff)" || echo "0")
        
        log_info "Pod统计: 总数=$total_pods, 运行=$running_pods, 等待=$pending_pods, 失败=$failed_pods"
        
        if [ "$running_pods" -eq "$total_pods" ] && [ "$total_pods" -gt 0 ]; then
            log_success "所有Pod运行正常"
        elif [ "$failed_pods" -gt 0 ]; then
            log_error "有Pod运行失败"
        elif [ "$pending_pods" -gt 0 ]; then
            log_warning "有Pod等待启动"
        fi
        
        echo ""
        kubectl get pods -n $NAMESPACE -o wide
        
        # 显示失败的Pod详情
        if [ "$failed_pods" -gt 0 ]; then
            echo ""
            log_warning "失败Pod详情:"
            kubectl get pods -n $NAMESPACE | grep -E "(Error|CrashLoopBackOff|ImagePullBackOff)"
        fi
    else
        log_error "命名空间中没有Pod"
        return 1
    fi
}

# 检查服务状态
check_services() {
    log_info "检查服务状态..."
    
    local services_output=$(kubectl get services -n $NAMESPACE --no-headers 2>/dev/null || echo "")
    if [ ! -z "$services_output" ]; then
        local service_count=$(echo "$services_output" | wc -l)
        log_success "发现 $service_count 个服务"
        
        echo ""
        kubectl get services -n $NAMESPACE -o wide
    else
        log_error "命名空间中没有服务"
        return 1
    fi
}

# 检查Ingress状态
check_ingress() {
    log_info "检查Ingress状态..."
    
    if kubectl get ingress -n $NAMESPACE &> /dev/null; then
        local ingress_output=$(kubectl get ingress -n $NAMESPACE --no-headers)
        if [ ! -z "$ingress_output" ]; then
            log_success "Ingress配置存在"
            
            # 获取ALB地址
            local alb_address=$(kubectl get ingress nacos-microservices-ingress -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
            if [ ! -z "$alb_address" ]; then
                log_success "ALB地址: $alb_address"
                echo "  访问地址: http://$alb_address"
            else
                log_warning "ALB地址未分配，可能还在创建中"
            fi
            
            echo ""
            kubectl get ingress -n $NAMESPACE -o wide
        else
            log_error "没有Ingress配置"
        fi
    else
        log_error "无法获取Ingress信息"
        return 1
    fi
}

# 检查ECR仓库
check_ecr_repositories() {
    log_info "检查ECR仓库..."
    
    local ecr_repos=$(aws ecr describe-repositories --region $REGION 2>/dev/null | grep nacos-demo || echo "")
    if [ ! -z "$ecr_repos" ]; then
        local repo_count=$(echo "$ecr_repos" | wc -l)
        log_success "发现 $repo_count 个ECR仓库"
        
        # 列出所有nacos-demo仓库
        aws ecr describe-repositories --region $REGION --query 'repositories[?contains(repositoryName, `nacos-demo`)].{Name:repositoryName,URI:repositoryUri}' --output table
    else
        log_warning "没有找到nacos-demo相关的ECR仓库"
    fi
}

# 检查负载均衡器
check_load_balancers() {
    log_info "检查负载均衡器..."
    
    local albs=$(aws elbv2 describe-load-balancers --region $REGION --query 'LoadBalancers[?contains(LoadBalancerName, `k8s-nacos`)].{Name:LoadBalancerName,DNS:DNSName,State:State.Code}' --output table 2>/dev/null || echo "")
    
    if [ ! -z "$albs" ] && [ "$albs" != "[]" ]; then
        log_success "发现相关的负载均衡器"
        echo "$albs"
    else
        log_warning "没有找到相关的负载均衡器"
    fi
}

# 健康检查
health_check() {
    log_info "执行健康检查..."
    
    local alb_address=$(kubectl get ingress nacos-microservices-ingress -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    
    if [ ! -z "$alb_address" ]; then
        local endpoints=("" "/api/users" "/api/orders" "/api/notifications")
        local endpoint_names=("Gateway" "User" "Order" "Notification")
        
        for i in "${!endpoints[@]}"; do
            local endpoint="${endpoints[$i]}/actuator/health"
            local service_name="${endpoint_names[$i]}"
            
            if curl -f -s --max-time 10 "http://$alb_address$endpoint" > /dev/null 2>&1; then
                log_success "$service_name Service 健康检查通过"
            else
                log_warning "$service_name Service 健康检查失败"
            fi
        done
    else
        log_warning "无法获取ALB地址，跳过健康检查"
    fi
}

# 生成状态报告
generate_status_report() {
    log_info "生成状态报告..."
    
    local report_file="logs/status-report-$(date +%Y%m%d-%H%M%S).txt"
    mkdir -p logs
    
    cat > $report_file << EOF
AWS us-west-2 部署状态报告

检查时间: $(date)
集群名称: $CLUSTER_NAME
命名空间: $NAMESPACE
AWS区域: $REGION

=== EKS集群状态 ===
$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query 'cluster.{Status:status,Version:version,Endpoint:endpoint}' --output table 2>/dev/null || echo "集群不存在")

=== 节点状态 ===
$(kubectl get nodes 2>/dev/null || echo "无法获取节点信息")

=== Pod状态 ===
$(kubectl get pods -n $NAMESPACE 2>/dev/null || echo "无法获取Pod信息")

=== 服务状态 ===
$(kubectl get services -n $NAMESPACE 2>/dev/null || echo "无法获取服务信息")

=== Ingress状态 ===
$(kubectl get ingress -n $NAMESPACE 2>/dev/null || echo "无法获取Ingress信息")

=== ECR仓库 ===
$(aws ecr describe-repositories --region $REGION --query 'repositories[?contains(repositoryName, `nacos-demo`)].repositoryName' --output text 2>/dev/null || echo "无ECR仓库")

=== 访问地址 ===
ALB地址: $(kubectl get ingress nacos-microservices-ingress -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "未分配")

报告生成时间: $(date)
EOF
    
    log_success "状态报告已生成: $report_file"
}

# 显示总结
show_summary() {
    echo ""
    echo "📊 状态检查总结"
    echo "================"
    
    # 计算各项状态
    local total_checks=8
    local passed_checks=0
    
    # 这里应该根据实际检查结果计算，简化处理
    if aws eks describe-cluster --name $CLUSTER_NAME --region $REGION &> /dev/null; then
        ((passed_checks++))
    fi
    
    if kubectl cluster-info &> /dev/null; then
        ((passed_checks++))
    fi
    
    if kubectl get namespace $NAMESPACE &> /dev/null; then
        ((passed_checks++))
    fi
    
    local pods_running=$(kubectl get pods -n $NAMESPACE --no-headers 2>/dev/null | grep -c Running || echo "0")
    if [ "$pods_running" -gt 0 ]; then
        ((passed_checks++))
    fi
    
    if kubectl get services -n $NAMESPACE &> /dev/null; then
        ((passed_checks++))
    fi
    
    if kubectl get ingress -n $NAMESPACE &> /dev/null; then
        ((passed_checks++))
    fi
    
    local ecr_repos=$(aws ecr describe-repositories --region $REGION 2>/dev/null | grep -c nacos-demo || echo "0")
    if [ "$ecr_repos" -gt 0 ]; then
        ((passed_checks++))
    fi
    
    local alb_address=$(kubectl get ingress nacos-microservices-ingress -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    if [ ! -z "$alb_address" ]; then
        ((passed_checks++))
    fi
    
    echo "检查项目: $passed_checks/$total_checks 通过"
    
    if [ "$passed_checks" -eq "$total_checks" ]; then
        log_success "🎉 所有检查项目通过，部署状态良好！"
    elif [ "$passed_checks" -ge $((total_checks * 3 / 4)) ]; then
        log_warning "⚠️  大部分检查项目通过，部分功能可能异常"
    else
        log_error "❌ 多个检查项目失败，部署可能存在问题"
    fi
    
    echo ""
    echo "💡 建议操作:"
    echo "  - 查看详细日志: logs/status-report-*.txt"
    echo "  - 运行功能验证: ./scripts/verify-deployment.sh"
    echo "  - 查看问题解决: issues-and-fixes/README.md"
}

# 主函数
main() {
    show_header
    
    local start_time=$(date +%s)
    
    # 执行检查
    check_aws_connection
    check_eks_cluster
    check_kubectl_connection
    check_nodes
    check_namespace
    check_pods
    check_services
    check_ingress
    check_ecr_repositories
    check_load_balancers
    health_check
    generate_status_report
    show_summary
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo ""
    log_info "状态检查完成，耗时: ${duration}秒"
}

# 执行主函数
main "$@"
