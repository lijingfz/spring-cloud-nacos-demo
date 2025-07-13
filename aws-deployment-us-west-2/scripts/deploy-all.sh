#!/bin/bash

# AWS us-west-2 Spring Cloud Nacos 项目完整部署脚本
# 版本: 1.0
# 创建时间: $(date)

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# 检查必要工具
check_prerequisites() {
    log_info "检查必要工具..."
    
    local tools=("aws" "kubectl" "docker" "helm" "eksctl" "jq")
    for tool in "${tools[@]}"; do
        if ! command -v $tool &> /dev/null; then
            log_error "$tool 未安装，请先安装"
            exit 1
        fi
    done
    
    # 检查AWS配置
    if ! aws sts get-caller-identity --region us-west-2 &> /dev/null; then
        log_error "AWS CLI未正确配置或无权限"
        exit 1
    fi
    
    log_success "所有必要工具检查通过"
}

# 设置环境变量
setup_environment() {
    log_info "设置环境变量..."
    
    export AWS_DEFAULT_REGION=us-west-2
    export CLUSTER_NAME=nacos-microservices
    export NAMESPACE=nacos-microservices
    export ECR_REGISTRY=$(aws sts get-caller-identity --query Account --output text).dkr.ecr.us-west-2.amazonaws.com
    export ECR_REPOSITORY_PREFIX=nacos-demo
    
    log_success "环境变量设置完成"
    log_info "AWS区域: $AWS_DEFAULT_REGION"
    log_info "集群名称: $CLUSTER_NAME"
    log_info "ECR注册表: $ECR_REGISTRY"
}

# 创建IAM角色
create_iam_roles() {
    log_info "创建IAM角色..."
    
    # 创建EKS集群服务角色
    if ! aws iam get-role --role-name nacos-eks-cluster-role --region us-west-2 &> /dev/null; then
        aws iam create-role \
            --role-name nacos-eks-cluster-role \
            --assume-role-policy-document file://configs/eks-cluster-trust-policy.json \
            --region us-west-2
        
        aws iam attach-role-policy \
            --role-name nacos-eks-cluster-role \
            --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy \
            --region us-west-2
        
        log_success "EKS集群服务角色创建成功"
    else
        log_info "EKS集群服务角色已存在"
    fi
}

# 创建EKS集群
create_eks_cluster() {
    log_info "创建EKS集群..."
    
    if ! aws eks describe-cluster --name $CLUSTER_NAME --region us-west-2 &> /dev/null; then
        log_info "开始创建EKS集群，这可能需要15-20分钟..."
        
        eksctl create cluster \
            --name $CLUSTER_NAME \
            --region us-west-2 \
            --version 1.28 \
            --nodegroup-name standard-workers \
            --node-type t3.medium \
            --nodes 3 \
            --nodes-min 2 \
            --nodes-max 5 \
            --managed \
            --with-oidc \
            --ssh-access \
            --ssh-public-key ~/.ssh/id_rsa.pub 2>/dev/null || \
        eksctl create cluster \
            --name $CLUSTER_NAME \
            --region us-west-2 \
            --version 1.28 \
            --nodegroup-name standard-workers \
            --node-type t3.medium \
            --nodes 3 \
            --nodes-min 2 \
            --nodes-max 5 \
            --managed \
            --with-oidc
        
        log_success "EKS集群创建成功"
    else
        log_info "EKS集群已存在"
    fi
    
    # 更新kubeconfig
    aws eks update-kubeconfig --region us-west-2 --name $CLUSTER_NAME
    
    # 验证连接
    kubectl get nodes
    log_success "kubectl配置完成"
}

# 安装AWS Load Balancer Controller
install_alb_controller() {
    log_info "安装AWS Load Balancer Controller..."
    
    # 下载IAM策略
    if [ ! -f "iam_policy.json" ]; then
        curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.2/docs/install/iam_policy.json
    fi
    
    # 创建IAM策略
    if ! aws iam get-policy --policy-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/AWSLoadBalancerControllerIAMPolicy --region us-west-2 &> /dev/null; then
        aws iam create-policy \
            --policy-name AWSLoadBalancerControllerIAMPolicy \
            --policy-document file://iam_policy.json \
            --region us-west-2
    fi
    
    # 创建服务账户
    if ! kubectl get serviceaccount aws-load-balancer-controller -n kube-system &> /dev/null; then
        eksctl create iamserviceaccount \
            --cluster=$CLUSTER_NAME \
            --namespace=kube-system \
            --name=aws-load-balancer-controller \
            --role-name AmazonEKSLoadBalancerControllerRole \
            --attach-policy-arn=arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/AWSLoadBalancerControllerIAMPolicy \
            --approve \
            --region us-west-2
    fi
    
    # 安装Helm chart
    if ! helm list -n kube-system | grep aws-load-balancer-controller &> /dev/null; then
        helm repo add eks https://aws.github.io/eks-charts
        helm repo update
        helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
            -n kube-system \
            --set clusterName=$CLUSTER_NAME \
            --set serviceAccount.create=false \
            --set serviceAccount.name=aws-load-balancer-controller
    fi
    
    log_success "AWS Load Balancer Controller安装完成"
}

# 创建ECR仓库
create_ecr_repositories() {
    log_info "创建ECR仓库..."
    
    local services=("gateway-service" "user-service" "order-service" "notification-service")
    
    for service in "${services[@]}"; do
        if ! aws ecr describe-repositories --repository-names $ECR_REPOSITORY_PREFIX/$service --region us-west-2 &> /dev/null; then
            aws ecr create-repository \
                --repository-name $ECR_REPOSITORY_PREFIX/$service \
                --region us-west-2 \
                --image-scanning-configuration scanOnPush=true
            log_success "ECR仓库 $ECR_REPOSITORY_PREFIX/$service 创建成功"
        else
            log_info "ECR仓库 $ECR_REPOSITORY_PREFIX/$service 已存在"
        fi
    done
}

# 构建和推送镜像
build_and_push_images() {
    log_info "构建和推送Docker镜像..."
    
    # ECR登录
    aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin $ECR_REGISTRY
    
    # 构建项目
    cd /home/ubuntu/qdemo/spring-cloud-nacos-demo
    mvn clean package -DskipTests
    
    local services=("gateway-service" "user-service" "order-service" "notification-service")
    
    for service in "${services[@]}"; do
        log_info "构建 $service 镜像..."
        
        # 创建Dockerfile（如果不存在）
        if [ ! -f "$service/Dockerfile" ]; then
            create_dockerfile $service
        fi
        
        # 构建镜像
        docker build -t $ECR_REGISTRY/$ECR_REPOSITORY_PREFIX/$service:latest $service/
        
        # 推送镜像
        docker push $ECR_REGISTRY/$ECR_REPOSITORY_PREFIX/$service:latest
        
        log_success "$service 镜像构建和推送完成"
    done
    
    cd aws-deployment-us-west-2
}

# 创建Dockerfile
create_dockerfile() {
    local service=$1
    log_info "为 $service 创建Dockerfile..."
    
    cat > $service/Dockerfile << EOF
# 多阶段构建
FROM maven:3.9-openjdk-21-slim AS builder
WORKDIR /app

# 复制pom文件
COPY pom.xml .
COPY ../pom.xml ../pom.xml

# 下载依赖
RUN mvn dependency:go-offline -B

# 复制源代码
COPY src ./src

# 构建应用
RUN mvn clean package -DskipTests

# 运行阶段
FROM openjdk:21-jre-slim
WORKDIR /app

# 安装必要工具
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# 复制jar文件
COPY --from=builder /app/target/*.jar app.jar

# 创建非root用户
RUN addgroup --system spring && adduser --system spring --ingroup spring
USER spring:spring

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/actuator/health || exit 1

# 启动应用
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
EOF
    
    log_success "$service Dockerfile创建完成"
}

# 部署Kubernetes资源
deploy_kubernetes_resources() {
    log_info "部署Kubernetes资源..."
    
    # 创建命名空间
    kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    
    # 创建ECR Secret
    kubectl create secret docker-registry ecr-secret \
        --docker-server=$ECR_REGISTRY \
        --docker-username=AWS \
        --docker-password=$(aws ecr get-login-password --region us-west-2) \
        --namespace=$NAMESPACE \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # 替换配置文件中的变量
    for file in configs/*-deployment.yaml; do
        envsubst < $file > /tmp/$(basename $file)
        kubectl apply -f /tmp/$(basename $file)
    done
    
    # 部署Nacos
    log_info "部署Nacos服务..."
    kubectl apply -f configs/nacos-statefulset.yaml
    kubectl apply -f configs/nacos-service.yaml
    
    # 等待Nacos启动
    log_info "等待Nacos服务启动..."
    kubectl wait --for=condition=ready pod -l app=nacos-server -n $NAMESPACE --timeout=300s
    
    # 部署微服务
    local services=("user-service" "order-service" "notification-service" "gateway-service")
    
    for service in "${services[@]}"; do
        log_info "部署 $service..."
        kubectl apply -f configs/$service-service.yaml
        
        # 等待服务就绪
        kubectl wait --for=condition=available deployment/$service -n $NAMESPACE --timeout=300s
        log_success "$service 部署完成"
    done
    
    # 部署Ingress
    log_info "部署ALB Ingress..."
    kubectl apply -f configs/alb-ingress.yaml
    
    log_success "所有Kubernetes资源部署完成"
}

# 等待ALB就绪
wait_for_alb() {
    log_info "等待ALB创建完成..."
    
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if kubectl get ingress nacos-microservices-ingress -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null | grep -q amazonaws.com; then
            ALB_ADDRESS=$(kubectl get ingress nacos-microservices-ingress -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
            log_success "ALB创建完成: $ALB_ADDRESS"
            return 0
        fi
        
        log_info "等待ALB创建... (尝试 $attempt/$max_attempts)"
        sleep 30
        ((attempt++))
    done
    
    log_error "ALB创建超时"
    return 1
}

# 配置Nacos
setup_nacos_config() {
    log_info "配置Nacos..."
    
    # 端口转发到Nacos
    kubectl port-forward svc/nacos-server 8848:8848 -n $NAMESPACE &
    local port_forward_pid=$!
    
    sleep 30
    
    # 创建配置文件
    local configs=(
        "gateway-service.yaml:DEFAULT_GROUP"
        "user-service.yaml:DEFAULT_GROUP"
        "order-service.yaml:DEFAULT_GROUP"
        "notification-service.yaml:DEFAULT_GROUP"
    )
    
    for config in "${configs[@]}"; do
        IFS=':' read -r dataId group <<< "$config"
        
        # 这里应该包含实际的配置内容
        local config_content="server:
  port: 8080
spring:
  application:
    name: ${dataId%.yaml}
  cloud:
    nacos:
      discovery:
        server-addr: nacos-server:8848
management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics"
        
        curl -X POST "http://localhost:8848/nacos/v1/cs/configs" \
            -d "dataId=$dataId&group=$group&content=$(echo "$config_content" | sed ':a;N;$!ba;s/\n/%0A/g')"
        
        log_success "Nacos配置 $dataId 创建完成"
    done
    
    # 停止端口转发
    kill $port_forward_pid 2>/dev/null || true
}

# 验证部署
verify_deployment() {
    log_info "验证部署..."
    
    # 检查Pod状态
    kubectl get pods -n $NAMESPACE
    
    # 检查服务状态
    kubectl get services -n $NAMESPACE
    
    # 检查Ingress状态
    kubectl get ingress -n $NAMESPACE
    
    # 健康检查
    if [ ! -z "$ALB_ADDRESS" ]; then
        log_info "等待服务完全启动..."
        sleep 60
        
        if curl -f http://$ALB_ADDRESS/actuator/health &> /dev/null; then
            log_success "Gateway服务健康检查通过"
        else
            log_warning "Gateway服务健康检查失败，可能需要更多时间启动"
        fi
    fi
    
    log_success "部署验证完成"
}

# 记录部署信息
record_deployment_info() {
    log_info "记录部署信息..."
    
    cat > logs/deployment-info.txt << EOF
部署时间: $(date)
AWS区域: $AWS_DEFAULT_REGION
EKS集群: $CLUSTER_NAME
命名空间: $NAMESPACE
ALB地址: $ALB_ADDRESS
ECR注册表: $ECR_REGISTRY

服务状态:
$(kubectl get pods -n $NAMESPACE)

访问地址:
- API网关: http://$ALB_ADDRESS
- 用户服务: http://$ALB_ADDRESS/api/users
- 订单服务: http://$ALB_ADDRESS/api/orders
- 通知服务: http://$ALB_ADDRESS/api/notifications
- 健康检查: http://$ALB_ADDRESS/actuator/health

Nacos控制台访问:
kubectl port-forward svc/nacos-server 8848:8848 -n $NAMESPACE
然后访问: http://localhost:8848/nacos (nacos/nacos)
EOF
    
    log_success "部署信息已记录到 logs/deployment-info.txt"
}

# 主函数
main() {
    log_info "开始AWS us-west-2部署..."
    
    # 创建日志目录
    mkdir -p logs
    
    # 记录开始时间
    local start_time=$(date +%s)
    
    # 执行部署步骤
    check_prerequisites
    setup_environment
    create_iam_roles
    create_eks_cluster
    install_alb_controller
    create_ecr_repositories
    build_and_push_images
    deploy_kubernetes_resources
    wait_for_alb
    setup_nacos_config
    verify_deployment
    record_deployment_info
    
    # 计算部署时间
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))
    
    log_success "部署完成！总耗时: ${minutes}分${seconds}秒"
    log_info "ALB地址: $ALB_ADDRESS"
    log_info "请运行 './scripts/verify-deployment.sh' 进行功能验证"
}

# 错误处理
trap 'log_error "部署过程中发生错误，请检查日志"; exit 1' ERR

# 执行主函数
main "$@"
