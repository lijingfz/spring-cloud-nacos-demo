# 实际部署问题记录

## 问题1: EBS CSI驱动程序缺失
**时间**: 2024-07-13 06:55:00
**现象**: 
```
error: timed out waiting for the condition on pods/nacos-server-0
PVC状态: Pending
```

**原因**: EKS集群默认不包含EBS CSI驱动程序，导致PVC无法创建PV

**解决方案**:
```bash
# 1. 创建EBS CSI驱动程序的IAM角色
eksctl create iamserviceaccount \
  --name ebs-csi-controller-sa \
  --namespace kube-system \
  --cluster nacos-microservices \
  --region us-west-2 \
  --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
  --role-name AmazonEKS_EBS_CSI_DriverRole \
  --approve

# 2. 使用Helm安装EBS CSI驱动程序
helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver
helm repo update
helm install aws-ebs-csi-driver aws-ebs-csi-driver/aws-ebs-csi-driver \
  --namespace kube-system \
  --set controller.serviceAccount.create=true \
  --set controller.serviceAccount.name=ebs-csi-controller-sa \
  --set controller.serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=arn:aws:iam::890717383483:role/AmazonEKS_EBS_CSI_DriverRole
```

**结果**: ✅ 已解决 - PVC成功绑定，Nacos Pod正常启动

---

## 问题2: 微服务健康检查端口配置错误
**时间**: 2024-07-13 07:10:00
**现象**: 
```
Readiness probe failed: Get "http://192.168.52.53:8080/actuator/health": dial tcp 192.168.52.53:8080: connect: connection refused
```

**原因**: 部署配置中的健康检查端口与实际应用端口不匹配
- user-service实际运行在8081端口，但健康检查配置为8080端口
- 其他服务可能也有类似问题

**解决方案**:
1. 检查每个服务的实际端口配置
2. 修正部署配置中的containerPort和健康检查端口
3. 重新部署服务

**状态**: 🔄 正在解决

---

## 问题3: 服务启动顺序依赖
**时间**: 2024-07-13 06:50:00
**现象**: 微服务在Nacos启动前尝试注册，导致CrashLoopBackOff

**原因**: 微服务启动时Nacos还未完全就绪

**解决方案**: 
```bash
# Nacos启动后重启所有微服务
kubectl rollout restart deployment/gateway-service -n nacos-microservices
kubectl rollout restart deployment/user-service -n nacos-microservices
kubectl rollout restart deployment/order-service -n nacos-microservices
kubectl rollout restart deployment/notification-service -n nacos-microservices
```

**结果**: ✅ 已解决 - Gateway服务成功启动并注册到Nacos

---

## 改进建议

### 1. 部署脚本改进
- 添加EBS CSI驱动程序检查和自动安装
- 添加服务端口配置验证
- 改进服务启动顺序控制

### 2. 配置文件改进
- 统一端口配置策略
- 添加更详细的健康检查配置
- 改进资源限制配置

### 3. 监控改进
- 添加部署状态检查
- 改进错误诊断信息
- 添加自动重试机制

---
**记录人**: 自动化部署系统
**最后更新**: $(date)
