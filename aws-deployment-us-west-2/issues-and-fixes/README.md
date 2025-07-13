# 部署问题记录和解决方案

本文档记录在AWS us-west-2部署过程中遇到的所有问题及其解决方案。

## 🔍 问题分类

- [环境配置问题](#环境配置问题)
- [EKS集群问题](#eks集群问题)
- [容器镜像问题](#容器镜像问题)
- [网络配置问题](#网络配置问题)
- [服务发现问题](#服务发现问题)
- [性能问题](#性能问题)

---

## 环境配置问题

### 问题1: AWS CLI权限不足
**现象**: 
```
An error occurred (AccessDenied) when calling the CreateCluster operation
```

**原因**: IAM用户缺少EKS相关权限

**解决方案**:
```bash
# 创建并附加EKS管理策略
aws iam attach-user-policy \
  --user-name your-username \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy

aws iam attach-user-policy \
  --user-name your-username \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy

aws iam attach-user-policy \
  --user-name your-username \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy

aws iam attach-user-policy \
  --user-name your-username \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
```

**记录时间**: 待记录
**解决状态**: ✅ 已解决

---

### 问题2: kubectl配置错误
**现象**: 
```
The connection to the server localhost:8080 was refused
```

**原因**: kubeconfig未正确配置

**解决方案**:
```bash
# 重新配置kubeconfig
aws eks update-kubeconfig --region us-west-2 --name nacos-microservices

# 验证配置
kubectl config current-context
kubectl get nodes
```

**记录时间**: 待记录
**解决状态**: ✅ 已解决

---

## EKS集群问题

### 问题3: 节点组创建失败
**现象**: 
```
NodeCreationFailure: Instances failed to join the kubernetes cluster
```

**原因**: 安全组配置或IAM角色问题

**解决方案**:
```bash
# 检查节点组状态
aws eks describe-nodegroup \
  --cluster-name nacos-microservices \
  --nodegroup-name standard-workers \
  --region us-west-2

# 如果需要，删除并重新创建节点组
eksctl delete nodegroup \
  --cluster nacos-microservices \
  --name standard-workers \
  --region us-west-2

eksctl create nodegroup \
  --cluster nacos-microservices \
  --name standard-workers \
  --node-type t3.medium \
  --nodes 3 \
  --nodes-min 2 \
  --nodes-max 5 \
  --region us-west-2
```

**记录时间**: 待记录
**解决状态**: 🔄 待解决

---

### 问题4: AWS Load Balancer Controller安装失败
**现象**: 
```
Error: failed to install chart: unable to build kubernetes objects
```

**原因**: OIDC提供程序未正确配置

**解决方案**:
```bash
# 检查OIDC提供程序
aws eks describe-cluster \
  --name nacos-microservices \
  --region us-west-2 \
  --query "cluster.identity.oidc.issuer" \
  --output text

# 如果没有OIDC，创建它
eksctl utils associate-iam-oidc-provider \
  --cluster nacos-microservices \
  --region us-west-2 \
  --approve

# 重新安装Load Balancer Controller
helm uninstall aws-load-balancer-controller -n kube-system
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=nacos-microservices \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

**记录时间**: 待记录
**解决状态**: 🔄 待解决

---

## 容器镜像问题

### 问题5: ECR推送权限被拒绝
**现象**: 
```
denied: User: arn:aws:iam::xxx:user/xxx is not authorized to perform: ecr:BatchCheckLayerAvailability
```

**原因**: ECR权限不足

**解决方案**:
```bash
# 附加ECR权限
aws iam attach-user-policy \
  --user-name your-username \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess

# 重新登录ECR
aws ecr get-login-password --region us-west-2 | \
docker login --username AWS --password-stdin \
$(aws sts get-caller-identity --query Account --output text).dkr.ecr.us-west-2.amazonaws.com
```

**记录时间**: 待记录
**解决状态**: ✅ 已解决

---

### 问题6: 镜像构建失败
**现象**: 
```
Error: failed to solve: failed to read dockerfile
```

**原因**: Dockerfile路径或语法错误

**解决方案**:
```bash
# 检查Dockerfile语法
docker build --no-cache -t test-build ./gateway-service/

# 修复Dockerfile中的路径问题
# 确保COPY指令使用正确的相对路径
```

**记录时间**: 待记录
**解决状态**: 🔄 待解决

---

## 网络配置问题

### 问题7: ALB创建失败
**现象**: 
```
Failed to create ALB: InvalidSubnet
```

**原因**: 子网标签配置不正确

**解决方案**:
```bash
# 获取集群的子网ID
aws eks describe-cluster \
  --name nacos-microservices \
  --region us-west-2 \
  --query 'cluster.resourcesVpcConfig.subnetIds' \
  --output table

# 为公共子网添加标签
for subnet in $(aws eks describe-cluster --name nacos-microservices --region us-west-2 --query 'cluster.resourcesVpcConfig.subnetIds' --output text); do
  aws ec2 create-tags \
    --resources $subnet \
    --tags Key=kubernetes.io/role/elb,Value=1 \
    --region us-west-2
done
```

**记录时间**: 待记录
**解决状态**: 🔄 待解决

---

### 问题8: 服务间通信失败
**现象**: 
```
Connection refused when calling user-service from order-service
```

**原因**: Kubernetes DNS或网络策略问题

**解决方案**:
```bash
# 检查DNS解析
kubectl exec -it deployment/order-service -n nacos-microservices -- nslookup user-service.nacos-microservices.svc.cluster.local

# 检查网络策略
kubectl get networkpolicies -n nacos-microservices

# 如果有网络策略阻止通信，修改或删除它们
kubectl delete networkpolicy --all -n nacos-microservices
```

**记录时间**: 待记录
**解决状态**: 🔄 待解决

---

## 服务发现问题

### 问题9: 服务无法注册到Nacos
**现象**: 
```
Failed to register service to nacos: Connection timed out
```

**原因**: Nacos服务地址配置错误或网络不通

**解决方案**:
```bash
# 检查Nacos服务状态
kubectl get pods -l app=nacos-server -n nacos-microservices
kubectl logs -l app=nacos-server -n nacos-microservices

# 检查服务配置
kubectl get configmap nacos-config -n nacos-microservices -o yaml

# 修正Nacos服务地址配置
kubectl patch configmap nacos-config -n nacos-microservices --patch '
data:
  nacos.server.addr: "nacos-server.nacos-microservices.svc.cluster.local:8848"
'

# 重启相关服务
kubectl rollout restart deployment/user-service -n nacos-microservices
kubectl rollout restart deployment/order-service -n nacos-microservices
kubectl rollout restart deployment/notification-service -n nacos-microservices
```

**记录时间**: 待记录
**解决状态**: 🔄 待解决

---

### 问题10: Nacos配置获取失败
**现象**: 
```
Failed to get config from nacos: timeout
```

**原因**: Nacos配置中心连接问题

**解决方案**:
```bash
# 检查Nacos配置
kubectl port-forward svc/nacos-server 8848:8848 -n nacos-microservices &
curl http://localhost:8848/nacos/v1/cs/configs?dataId=gateway-service.yaml&group=DEFAULT_GROUP

# 重新创建配置
./scripts/setup-nacos-config.sh

# 验证配置是否正确加载
kubectl logs deployment/gateway-service -n nacos-microservices | grep -i nacos
```

**记录时间**: 待记录
**解决状态**: 🔄 待解决

---

## 性能问题

### 问题11: Pod启动缓慢
**现象**: Pod启动时间超过5分钟

**原因**: 资源限制过低或镜像拉取慢

**解决方案**:
```bash
# 增加资源限制
kubectl patch deployment gateway-service -n nacos-microservices --patch '
spec:
  template:
    spec:
      containers:
      - name: gateway-service
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
'

# 检查镜像拉取策略
kubectl get deployment gateway-service -n nacos-microservices -o yaml | grep imagePullPolicy
```

**记录时间**: 待记录
**解决状态**: 🔄 待解决

---

### 问题12: 内存不足导致Pod重启
**现象**: 
```
OOMKilled: Container was killed due to memory limit
```

**原因**: JVM堆内存配置不当

**解决方案**:
```bash
# 调整JVM参数
kubectl patch deployment user-service -n nacos-microservices --patch '
spec:
  template:
    spec:
      containers:
      - name: user-service
        env:
        - name: JAVA_OPTS
          value: "-Xms256m -Xmx512m -XX:+UseG1GC"
        resources:
          requests:
            memory: "512Mi"
          limits:
            memory: "1Gi"
'
```

**记录时间**: 待记录
**解决状态**: 🔄 待解决

---

## 问题统计

| 问题类型 | 总数 | 已解决 | 待解决 |
|---------|------|--------|--------|
| 环境配置 | 2 | 2 | 0 |
| EKS集群 | 2 | 0 | 2 |
| 容器镜像 | 2 | 1 | 1 |
| 网络配置 | 2 | 0 | 2 |
| 服务发现 | 2 | 0 | 2 |
| 性能问题 | 2 | 0 | 2 |
| **总计** | **12** | **3** | **9** |

---

## 问题上报模板

```markdown
### 问题X: [问题简述]
**现象**: 
```
[错误信息或现象描述]
```

**原因**: [问题根本原因]

**解决方案**:
```bash
[解决步骤]
```

**记录时间**: [YYYY-MM-DD HH:MM:SS]
**解决状态**: [✅ 已解决 | 🔄 待解决 | ❌ 无法解决]
```

---
**文档更新时间**: $(date)
**负责人**: 部署团队
