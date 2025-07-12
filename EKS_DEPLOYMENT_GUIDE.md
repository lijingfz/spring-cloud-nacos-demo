# Spring Cloud Nacos 项目 EKS 部署完整指南

本指南详细介绍如何将当前的Spring Cloud微服务项目部署到Amazon EKS (Elastic Kubernetes Service)中运行。

## 📋 项目概述

当前项目是一个基于Spring Cloud 2023.0.x + Nacos的微服务架构，包含以下服务：

| 服务名称 | 端口 | 功能描述 |
|---------|------|----------|
| gateway-service | 8080 | API网关 |
| user-service | 8081 | 用户管理服务 |
| order-service | 8082 | 订单管理服务 |
| notification-service | 8083 | 通知服务 |
| nacos-server | 8848 | 服务注册中心 + 配置中心 |

## 🎯 部署目标架构

```
Internet → ALB → EKS Cluster
                    ├── Gateway Service (Pod)
                    ├── User Service (Pods)
                    ├── Order Service (Pods)
                    ├── Notification Service (Pods)
                    └── Nacos Cluster (StatefulSet)
```

## 📝 部署步骤概览

1. [容器化准备阶段](#1-容器化准备阶段)
2. [Nacos服务处理](#2-nacos服务处理)
3. [Kubernetes资源清单创建](#3-kubernetes资源清单创建)
4. [镜像构建与推送](#4-镜像构建与推送)
5. [EKS集群准备](#5-eks集群准备)
6. [网络和存储配置](#6-网络和存储配置)
7. [监控和日志](#7-监控和日志)
8. [CI/CD流水线](#8-cicd流水线)

---

## 1. 容器化准备阶段

### 1.1 为每个微服务创建Dockerfile

#### 通用的多阶段Dockerfile模板

```dockerfile
# 构建阶段
FROM maven:3.9-openjdk-21-slim AS builder
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN mvn clean package -DskipTests

# 运行阶段
FROM openjdk:21-jre-slim
WORKDIR /app
COPY --from=builder /app/target/*.jar app.jar

# 创建非root用户
RUN groupadd -r appuser && useradd -r -g appuser appuser
RUN chown -R appuser:appuser /app
USER appuser

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health || exit 1

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
```

#### 为每个服务创建特定的Dockerfile

**gateway-service/Dockerfile**
```dockerfile
FROM openjdk:21-jre-slim
WORKDIR /app
COPY target/gateway-service-*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
```

**user-service/Dockerfile**
```dockerfile
FROM openjdk:21-jre-slim
WORKDIR /app
COPY target/user-service-*.jar app.jar
EXPOSE 8081
ENTRYPOINT ["java", "-jar", "app.jar"]
```

**order-service/Dockerfile**
```dockerfile
FROM openjdk:21-jre-slim
WORKDIR /app
COPY target/order-service-*.jar app.jar
EXPOSE 8082
ENTRYPOINT ["java", "-jar", "app.jar"]
```

**notification-service/Dockerfile**
```dockerfile
FROM openjdk:21-jre-slim
WORKDIR /app
COPY target/notification-service-*.jar app.jar
EXPOSE 8083
ENTRYPOINT ["java", "-jar", "app.jar"]
```

### 1.2 创建.dockerignore文件

```dockerignore
target/
.git/
.gitignore
README.md
*.md
.mvn/
mvnw
mvnw.cmd
logs/
.idea/
*.iml
.vscode/
```

---

## 2. Nacos服务处理

### 2.1 在EKS中部署Nacos集群（推荐方案）

#### Nacos StatefulSet配置

```yaml
# k8s/nacos/nacos-statefulset.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: nacos
  namespace: nacos
spec:
  serviceName: nacos-headless
  replicas: 3
  selector:
    matchLabels:
      app: nacos
  template:
    metadata:
      labels:
        app: nacos
    spec:
      containers:
      - name: nacos
        image: nacos/nacos-server:v2.3.0
        ports:
        - containerPort: 8848
        - containerPort: 9848
        env:
        - name: NACOS_SERVERS
          value: "nacos-0.nacos-headless.nacos.svc.cluster.local:8848 nacos-1.nacos-headless.nacos.svc.cluster.local:8848 nacos-2.nacos-headless.nacos.svc.cluster.local:8848"
        - name: MYSQL_SERVICE_HOST
          value: "mysql-service"
        - name: MYSQL_SERVICE_DB_NAME
          value: "nacos"
        - name: MYSQL_SERVICE_USER
          value: "nacos"
        - name: MYSQL_SERVICE_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: password
        volumeMounts:
        - name: nacos-data
          mountPath: /home/nacos/data
  volumeClaimTemplates:
  - metadata:
      name: nacos-data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 10Gi
```

#### Nacos Service配置

```yaml
# k8s/nacos/nacos-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: nacos-service
  namespace: nacos
spec:
  selector:
    app: nacos
  ports:
  - name: http
    port: 8848
    targetPort: 8848
  - name: grpc
    port: 9848
    targetPort: 9848
  type: ClusterIP
---
apiVersion: v1
kind: Service
metadata:
  name: nacos-headless
  namespace: nacos
spec:
  selector:
    app: nacos
  ports:
  - name: http
    port: 8848
    targetPort: 8848
  clusterIP: None
```

### 2.2 修改微服务配置

更新各服务的application.yml配置以适配Kubernetes环境：

```yaml
spring:
  cloud:
    nacos:
      discovery:
        server-addr: nacos-service.nacos.svc.cluster.local:8848
        namespace: dev
        group: DEFAULT_GROUP
      config:
        server-addr: nacos-service.nacos.svc.cluster.local:8848
        namespace: dev
        group: DEFAULT_GROUP
        file-extension: yaml
```

---

## 3. Kubernetes资源清单创建

### 3.1 Gateway Service部署

```yaml
# k8s/gateway-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gateway-service
  namespace: microservices
spec:
  replicas: 2
  selector:
    matchLabels:
      app: gateway-service
  template:
    metadata:
      labels:
        app: gateway-service
    spec:
      containers:
      - name: gateway-service
        image: your-registry/gateway-service:latest
        ports:
        - containerPort: 8080
        env:
        - name: SPRING_PROFILES_ACTIVE
          value: "k8s"
        - name: NACOS_SERVER_ADDR
          value: "nacos-service.nacos.svc.cluster.local:8848"
        livenessProbe:
          httpGet:
            path: /actuator/health
            port: 8080
          initialDelaySeconds: 60
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /actuator/health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
---
apiVersion: v1
kind: Service
metadata:
  name: gateway-service
  namespace: microservices
spec:
  selector:
    app: gateway-service
  ports:
  - port: 8080
    targetPort: 8080
  type: ClusterIP
```

### 3.2 业务服务部署（以User Service为例）

```yaml
# k8s/user-service-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-service
  namespace: microservices
spec:
  replicas: 3
  selector:
    matchLabels:
      app: user-service
  template:
    metadata:
      labels:
        app: user-service
    spec:
      containers:
      - name: user-service
        image: your-registry/user-service:latest
        ports:
        - containerPort: 8081
        env:
        - name: SPRING_PROFILES_ACTIVE
          value: "k8s"
        - name: NACOS_SERVER_ADDR
          value: "nacos-service.nacos.svc.cluster.local:8848"
        - name: DB_HOST
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: db.host
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: password
        livenessProbe:
          httpGet:
            path: /actuator/health
            port: 8081
          initialDelaySeconds: 60
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /actuator/health
            port: 8081
          initialDelaySeconds: 30
          periodSeconds: 10
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
---
apiVersion: v1
kind: Service
metadata:
  name: user-service
  namespace: microservices
spec:
  selector:
    app: user-service
  ports:
  - port: 8081
    targetPort: 8081
  type: ClusterIP
```

### 3.3 ConfigMap和Secret配置

```yaml
# k8s/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: microservices
data:
  db.host: "mysql-service.database.svc.cluster.local"
  db.port: "3306"
  nacos.namespace: "dev"
  logging.level: "INFO"
---
apiVersion: v1
kind: Secret
metadata:
  name: db-secret
  namespace: microservices
type: Opaque
data:
  username: dXNlcg==  # base64 encoded 'user'
  password: cGFzc3dvcmQ=  # base64 encoded 'password'
```

### 3.4 Ingress配置

```yaml
# k8s/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: microservices-ingress
  namespace: microservices
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/healthcheck-path: /actuator/health
spec:
  rules:
  - host: api.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: gateway-service
            port:
              number: 8080
```

### 3.5 HPA配置

```yaml
# k8s/hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: gateway-service-hpa
  namespace: microservices
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: gateway-service
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

---

## 4. 镜像构建与推送

### 4.1 创建ECR仓库

```bash
# 创建ECR仓库
aws ecr create-repository --repository-name gateway-service --region us-west-2
aws ecr create-repository --repository-name user-service --region us-west-2
aws ecr create-repository --repository-name order-service --region us-west-2
aws ecr create-repository --repository-name notification-service --region us-west-2

# 获取登录令牌
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin 123456789012.dkr.ecr.us-west-2.amazonaws.com
```

### 4.2 构建和推送脚本

```bash
#!/bin/bash
# scripts/build-and-push.sh

REGION="us-west-2"
ACCOUNT_ID="123456789012"
REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
TAG="v1.0.0"

# 构建项目
echo "Building Maven project..."
mvn clean package -DskipTests

# 服务列表
SERVICES=("gateway-service" "user-service" "order-service" "notification-service")

# 构建并推送每个服务
for SERVICE in "${SERVICES[@]}"; do
    echo "Building and pushing $SERVICE..."
    
    # 构建镜像
    docker build -t $SERVICE:$TAG ./$SERVICE
    
    # 标记镜像
    docker tag $SERVICE:$TAG $REGISTRY/$SERVICE:$TAG
    docker tag $SERVICE:$TAG $REGISTRY/$SERVICE:latest
    
    # 推送镜像
    docker push $REGISTRY/$SERVICE:$TAG
    docker push $REGISTRY/$SERVICE:latest
    
    echo "$SERVICE pushed successfully!"
done

echo "All services built and pushed successfully!"
```

---

## 5. EKS集群准备

### 5.1 创建EKS集群

```bash
# 使用eksctl创建集群
eksctl create cluster \
  --name spring-cloud-cluster \
  --region us-west-2 \
  --version 1.28 \
  --nodegroup-name standard-workers \
  --node-type t3.medium \
  --nodes 3 \
  --nodes-min 1 \
  --nodes-max 4 \
  --managed
```

### 5.2 安装必要组件

#### AWS Load Balancer Controller

```bash
# 下载IAM策略
curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.2/docs/install/iam_policy.json

# 创建IAM策略
aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam_policy.json

# 创建服务账户
eksctl create iamserviceaccount \
  --cluster=spring-cloud-cluster \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --attach-policy-arn=arn:aws:iam::ACCOUNT-ID:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve

# 安装Load Balancer Controller
helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=spring-cloud-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

#### Metrics Server

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

#### Cluster Autoscaler

```bash
curl -o cluster-autoscaler-autodiscover.yaml https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml

# 编辑文件，替换集群名称
sed -i 's/<YOUR CLUSTER NAME>/spring-cloud-cluster/g' cluster-autoscaler-autodiscover.yaml

kubectl apply -f cluster-autoscaler-autodiscover.yaml
```

---

## 6. 网络和存储配置

### 6.1 创建命名空间

```bash
# 创建命名空间
kubectl create namespace nacos
kubectl create namespace microservices
kubectl create namespace database
kubectl create namespace monitoring
```

### 6.2 网络策略配置

```yaml
# k8s/network-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: microservices-network-policy
  namespace: microservices
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: microservices
    - namespaceSelector:
        matchLabels:
          name: nacos
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: nacos
  - to:
    - namespaceSelector:
        matchLabels:
          name: database
  - to: []
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
```

### 6.3 存储类配置

```yaml
# k8s/storage-class.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3-encrypted
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  encrypted: "true"
  fsType: ext4
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
```

---

## 7. 监控和日志

### 7.1 CloudWatch配置

```yaml
# k8s/monitoring/cloudwatch-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluent-bit-config
  namespace: amazon-cloudwatch
data:
  fluent-bit.conf: |
    [SERVICE]
        Flush         1
        Log_Level     info
        Daemon        off
        Parsers_File  parsers.conf
        HTTP_Server   On
        HTTP_Listen   0.0.0.0
        HTTP_Port     2020

    [INPUT]
        Name              tail
        Tag               application.*
        Path              /var/log/containers/*.log
        Parser            docker
        DB                /var/log/flb_kube.db
        Mem_Buf_Limit     50MB
        Skip_Long_Lines   On
        Refresh_Interval  10

    [OUTPUT]
        Name                cloudwatch_logs
        Match               application.*
        region              us-west-2
        log_group_name      /aws/eks/spring-cloud-cluster/application
        log_stream_prefix   ${hostname}-
        auto_create_group   true
```

### 7.2 Prometheus和Grafana部署

```bash
# 使用Helm安装Prometheus和Grafana
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# 安装Prometheus
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set grafana.adminPassword=admin123

# 获取Grafana访问地址
kubectl get svc -n monitoring prometheus-grafana
```

---

## 8. CI/CD流水线

### 8.1 GitHub Actions配置

```yaml
# .github/workflows/deploy.yml
name: Deploy to EKS

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

env:
  AWS_REGION: us-west-2
  EKS_CLUSTER_NAME: spring-cloud-cluster
  ECR_REPOSITORY_PREFIX: 123456789012.dkr.ecr.us-west-2.amazonaws.com

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v3

    - name: Set up JDK 21
      uses: actions/setup-java@v3
      with:
        java-version: '21'
        distribution: 'temurin'

    - name: Cache Maven packages
      uses: actions/cache@v3
      with:
        path: ~/.m2
        key: ${{ runner.os }}-m2-${{ hashFiles('**/pom.xml') }}

    - name: Build with Maven
      run: mvn clean package -DskipTests

    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v2
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: ${{ env.AWS_REGION }}

    - name: Login to Amazon ECR
      id: login-ecr
      uses: aws-actions/amazon-ecr-login@v1

    - name: Build and push Docker images
      run: |
        SERVICES=("gateway-service" "user-service" "order-service" "notification-service")
        for SERVICE in "${SERVICES[@]}"; do
          docker build -t $SERVICE:$GITHUB_SHA ./$SERVICE
          docker tag $SERVICE:$GITHUB_SHA $ECR_REPOSITORY_PREFIX/$SERVICE:$GITHUB_SHA
          docker tag $SERVICE:$GITHUB_SHA $ECR_REPOSITORY_PREFIX/$SERVICE:latest
          docker push $ECR_REPOSITORY_PREFIX/$SERVICE:$GITHUB_SHA
          docker push $ECR_REPOSITORY_PREFIX/$SERVICE:latest
        done

    - name: Update kube config
      run: aws eks update-kubeconfig --name $EKS_CLUSTER_NAME --region $AWS_REGION

    - name: Deploy to EKS
      run: |
        # 更新镜像标签
        sed -i "s|your-registry|$ECR_REPOSITORY_PREFIX|g" k8s/*.yaml
        sed -i "s|:latest|:$GITHUB_SHA|g" k8s/*.yaml
        
        # 应用Kubernetes配置
        kubectl apply -f k8s/
        
        # 等待部署完成
        kubectl rollout status deployment/gateway-service -n microservices
        kubectl rollout status deployment/user-service -n microservices
        kubectl rollout status deployment/order-service -n microservices
        kubectl rollout status deployment/notification-service -n microservices
```

---

## 🚀 快速部署脚本

### 完整部署脚本

```bash
#!/bin/bash
# scripts/deploy.sh

set -e

NAMESPACE="microservices"
REGISTRY="123456789012.dkr.ecr.us-west-2.amazonaws.com"
TAG=${1:-latest}

echo "Deploying Spring Cloud microservices to EKS..."

# 创建命名空间（如果不存在）
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# 应用ConfigMap和Secret
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secrets.yaml

# 部署Nacos（如果需要）
kubectl apply -f k8s/nacos/

# 等待Nacos就绪
echo "Waiting for Nacos to be ready..."
kubectl wait --for=condition=ready pod -l app=nacos -n nacos --timeout=300s

# 部署微服务
SERVICES=("gateway-service" "user-service" "order-service" "notification-service")

for SERVICE in "${SERVICES[@]}"; do
    echo "Deploying $SERVICE..."
    
    # 更新镜像标签
    sed "s|IMAGE_TAG|$TAG|g" k8s/$SERVICE-deployment.yaml | \
    sed "s|REGISTRY|$REGISTRY|g" | \
    kubectl apply -f -
    
    # 等待部署完成
    kubectl rollout status deployment/$SERVICE -n $NAMESPACE --timeout=300s
    
    echo "$SERVICE deployed successfully!"
done

# 应用Ingress
kubectl apply -f k8s/ingress.yaml

# 应用HPA
kubectl apply -f k8s/hpa.yaml

echo "Deployment completed successfully!"

# 显示服务状态
echo "Service status:"
kubectl get pods -n $NAMESPACE
kubectl get svc -n $NAMESPACE
kubectl get ingress -n $NAMESPACE
```

### 健康检查脚本

```bash
#!/bin/bash
# scripts/health-check.sh

NAMESPACE="microservices"
SERVICES=("gateway-service" "user-service" "order-service" "notification-service")

echo "Checking service health..."

for SERVICE in "${SERVICES[@]}"; do
    echo "Checking $SERVICE..."
    
    # 检查Pod状态
    READY_PODS=$(kubectl get pods -n $NAMESPACE -l app=$SERVICE -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' | grep -o True | wc -l)
    TOTAL_PODS=$(kubectl get pods -n $NAMESPACE -l app=$SERVICE --no-headers | wc -l)
    
    echo "$SERVICE: $READY_PODS/$TOTAL_PODS pods ready"
    
    # 检查健康端点
    POD_NAME=$(kubectl get pods -n $NAMESPACE -l app=$SERVICE -o jsonpath='{.items[0].metadata.name}')
    if [ ! -z "$POD_NAME" ]; then
        HEALTH_STATUS=$(kubectl exec -n $NAMESPACE $POD_NAME -- curl -s http://localhost:8080/actuator/health | jq -r '.status' 2>/dev/null || echo "UNKNOWN")
        echo "$SERVICE health status: $HEALTH_STATUS"
    fi
    
    echo "---"
done

# 检查Ingress
echo "Ingress status:"
kubectl get ingress -n $NAMESPACE

# 检查HPA
echo "HPA status:"
kubectl get hpa -n $NAMESPACE
```

---

## 📊 成本优化建议

### 1. 资源配置优化
- 根据实际负载调整Pod的CPU和内存请求/限制
- 使用Spot实例作为工作节点以降低成本
- 配置合适的HPA策略避免过度扩容

### 2. 存储优化
- 使用gp3存储类型替代gp2
- 合理配置存储大小，避免过度分配
- 定期清理不用的PVC

### 3. 网络优化
- 使用VPC CNI的IP前缀委派功能
- 合理配置安全组规则
- 考虑使用PrivateLink减少数据传输成本

---

## 🔧 故障排查指南

### 常见问题及解决方案

#### 1. Pod启动失败
```bash
# 查看Pod状态
kubectl get pods -n microservices

# 查看Pod详细信息
kubectl describe pod <pod-name> -n microservices

# 查看Pod日志
kubectl logs <pod-name> -n microservices
```

#### 2. 服务无法访问
```bash
# 检查Service状态
kubectl get svc -n microservices

# 检查Endpoints
kubectl get endpoints -n microservices

# 测试服务连通性
kubectl run test-pod --image=busybox -it --rm -- /bin/sh
```

#### 3. Nacos连接问题
```bash
# 检查Nacos Pod状态
kubectl get pods -n nacos

# 查看Nacos日志
kubectl logs -f nacos-0 -n nacos

# 测试Nacos连接
kubectl exec -it <app-pod> -n microservices -- curl http://nacos-service.nacos.svc.cluster.local:8848/nacos
```

---

## 📚 相关文档

- [AWS EKS 官方文档](https://docs.aws.amazon.com/eks/)
- [Kubernetes 官方文档](https://kubernetes.io/docs/)
- [Spring Cloud Kubernetes](https://spring.io/projects/spring-cloud-kubernetes)
- [Nacos Kubernetes 部署](https://nacos.io/zh-cn/docs/use-nacos-with-kubernetes.html)

---

## 📝 更新日志

- **v1.0.0** (2025-07-12): 初始版本，包含完整的EKS部署指南
- 支持Spring Boot 3.1.5 + Spring Cloud 2023.0.3
- 集成Nacos 2.3.0服务发现和配置管理
- 包含完整的CI/CD流水线配置

---

**作者**: Amazon Q  
**最后更新**: 2025-07-12  
**版本**: 1.0.0
