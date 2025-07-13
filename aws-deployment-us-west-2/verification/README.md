# 功能验证测试指南

本文档详细描述了AWS us-west-2部署后的功能验证测试流程，确保所有微服务功能正常运行。

## 🎯 验证目标

- ✅ 所有服务健康状态正常
- ✅ 服务注册发现功能正常
- ✅ API网关路由功能正常
- ✅ 微服务间通信正常
- ✅ 数据持久化功能正常
- ✅ 负载均衡功能正常
- ✅ 熔断降级功能正常

## 📋 验证清单

### 1. 基础设施验证

#### 1.1 EKS集群状态检查
```bash
# 检查集群状态
aws eks describe-cluster --name nacos-microservices --region us-west-2 --query 'cluster.status'

# 检查节点状态
kubectl get nodes -o wide

# 检查系统Pod状态
kubectl get pods -n kube-system
```

**预期结果**: 
- 集群状态为 `ACTIVE`
- 所有节点状态为 `Ready`
- 系统Pod全部运行正常

#### 1.2 命名空间和资源检查
```bash
# 检查命名空间
kubectl get namespaces

# 检查所有Pod状态
kubectl get pods -n nacos-microservices -o wide

# 检查服务状态
kubectl get services -n nacos-microservices

# 检查Ingress状态
kubectl get ingress -n nacos-microservices
```

**预期结果**:
- 命名空间 `nacos-microservices` 存在
- 所有Pod状态为 `Running`
- 所有Service有正确的ClusterIP
- Ingress有有效的ALB地址

### 2. 服务健康检查

#### 2.1 获取ALB地址
```bash
ALB_ADDRESS=$(kubectl get ingress nacos-microservices-ingress -n nacos-microservices -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "ALB地址: $ALB_ADDRESS"
```

#### 2.2 健康端点检查
```bash
# Gateway Service健康检查
curl -f http://$ALB_ADDRESS/actuator/health
echo "Gateway Service健康状态: $?"

# User Service健康检查
curl -f http://$ALB_ADDRESS/api/users/actuator/health
echo "User Service健康状态: $?"

# Order Service健康检查
curl -f http://$ALB_ADDRESS/api/orders/actuator/health
echo "Order Service健康状态: $?"

# Notification Service健康检查
curl -f http://$ALB_ADDRESS/api/notifications/actuator/health
echo "Notification Service健康状态: $?"
```

**预期结果**: 所有健康检查返回状态码200，响应包含 `"status":"UP"`

#### 2.3 Nacos控制台访问
```bash
# 通过端口转发访问Nacos
kubectl port-forward svc/nacos-server 8848:8848 -n nacos-microservices &

# 检查Nacos健康状态
curl -f http://localhost:8848/nacos/actuator/health

# 检查服务注册情况
curl "http://localhost:8848/nacos/v1/ns/instance/list?serviceName=gateway-service"
curl "http://localhost:8848/nacos/v1/ns/instance/list?serviceName=user-service"
curl "http://localhost:8848/nacos/v1/ns/instance/list?serviceName=order-service"
curl "http://localhost:8848/nacos/v1/ns/instance/list?serviceName=notification-service"
```

**预期结果**: 
- Nacos控制台可访问
- 所有4个微服务都已注册到Nacos

### 3. API功能验证

#### 3.1 用户服务API测试
```bash
# 创建用户
USER_RESPONSE=$(curl -s -X POST http://$ALB_ADDRESS/api/users \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser001",
    "email": "test001@example.com",
    "password": "password123",
    "fullName": "测试用户001",
    "phoneNumber": "13800138001"
  }')

echo "创建用户响应: $USER_RESPONSE"

# 提取用户ID
USER_ID=$(echo $USER_RESPONSE | jq -r '.id')
echo "用户ID: $USER_ID"

# 获取用户列表
curl -s http://$ALB_ADDRESS/api/users | jq '.'

# 根据ID获取用户
curl -s http://$ALB_ADDRESS/api/users/$USER_ID | jq '.'
```

**预期结果**:
- 用户创建成功，返回用户信息包含ID
- 用户列表包含新创建的用户
- 根据ID可以正确获取用户信息

#### 3.2 订单服务API测试
```bash
# 创建订单
ORDER_RESPONSE=$(curl -s -X POST http://$ALB_ADDRESS/api/orders \
  -H "Content-Type: application/json" \
  -d '{
    "userId": '$USER_ID',
    "productName": "测试商品001",
    "quantity": 2,
    "unitPrice": 99.99
  }')

echo "创建订单响应: $ORDER_RESPONSE"

# 提取订单ID
ORDER_ID=$(echo $ORDER_RESPONSE | jq -r '.id')
echo "订单ID: $ORDER_ID"

# 获取订单列表
curl -s http://$ALB_ADDRESS/api/orders | jq '.'

# 根据用户ID获取订单
curl -s http://$ALB_ADDRESS/api/orders/user/$USER_ID | jq '.'
```

**预期结果**:
- 订单创建成功，返回订单信息包含ID
- 订单列表包含新创建的订单
- 可以根据用户ID正确获取该用户的订单

#### 3.3 通知服务API测试
```bash
# 发送邮件通知
NOTIFICATION_RESPONSE=$(curl -s -X POST http://$ALB_ADDRESS/api/notifications/send \
  -H "Content-Type: application/json" \
  -d '{
    "recipient": "test001@example.com",
    "type": "EMAIL",
    "title": "订单创建通知",
    "content": "您的订单 '$ORDER_ID' 已成功创建，总金额: 199.98元"
  }')

echo "发送通知响应: $NOTIFICATION_RESPONSE"

# 发送短信通知
SMS_RESPONSE=$(curl -s -X POST http://$ALB_ADDRESS/api/notifications/send \
  -H "Content-Type: application/json" \
  -d '{
    "recipient": "13800138001",
    "type": "SMS",
    "title": "订单提醒",
    "content": "您有新订单待处理"
  }')

echo "发送短信响应: $SMS_RESPONSE"

# 获取通知历史
curl -s http://$ALB_ADDRESS/api/notifications/history | jq '.'
```

**预期结果**:
- 邮件通知发送成功
- 短信通知发送成功
- 通知历史记录正确保存

### 4. 服务间通信验证

#### 4.1 订单服务调用用户服务
```bash
# 创建订单时会调用用户服务验证用户存在
ORDER_WITH_INVALID_USER=$(curl -s -X POST http://$ALB_ADDRESS/api/orders \
  -H "Content-Type: application/json" \
  -d '{
    "userId": 99999,
    "productName": "测试商品002",
    "quantity": 1,
    "unitPrice": 50.00
  }')

echo "无效用户订单响应: $ORDER_WITH_INVALID_USER"
```

**预期结果**: 应该返回用户不存在的错误信息

#### 4.2 网关路由验证
```bash
# 直接访问各服务（绕过网关）
kubectl port-forward svc/user-service 8081:8080 -n nacos-microservices &
kubectl port-forward svc/order-service 8082:8080 -n nacos-microservices &
kubectl port-forward svc/notification-service 8083:8080 -n nacos-microservices &

# 验证直接访问
curl -s http://localhost:8081/actuator/health | jq '.status'
curl -s http://localhost:8082/actuator/health | jq '.status'
curl -s http://localhost:8083/actuator/health | jq '.status'

# 验证网关路由
curl -s http://$ALB_ADDRESS/api/users/actuator/health | jq '.status'
curl -s http://$ALB_ADDRESS/api/orders/actuator/health | jq '.status'
curl -s http://$ALB_ADDRESS/api/notifications/actuator/health | jq '.status'
```

**预期结果**: 直接访问和通过网关访问都应该返回相同的健康状态

### 5. 负载均衡验证

#### 5.1 多实例验证
```bash
# 扩展用户服务到3个实例
kubectl scale deployment user-service --replicas=3 -n nacos-microservices

# 等待扩展完成
kubectl wait --for=condition=available deployment/user-service -n nacos-microservices --timeout=300s

# 检查Pod分布
kubectl get pods -l app=user-service -n nacos-microservices -o wide

# 多次调用API验证负载均衡
for i in {1..10}; do
  curl -s http://$ALB_ADDRESS/api/users | jq -r '.[] | select(.username=="testuser001") | .id'
  sleep 1
done
```

**预期结果**: 
- 用户服务成功扩展到3个实例
- API调用在多个实例间负载均衡

#### 5.2 故障转移验证
```bash
# 获取一个用户服务Pod名称
USER_POD=$(kubectl get pods -l app=user-service -n nacos-microservices -o jsonpath='{.items[0].metadata.name}')

# 删除一个Pod模拟故障
kubectl delete pod $USER_POD -n nacos-microservices

# 立即测试API可用性
for i in {1..5}; do
  curl -s http://$ALB_ADDRESS/api/users >/dev/null && echo "API调用成功 $i" || echo "API调用失败 $i"
  sleep 2
done

# 检查Pod自动重建
kubectl get pods -l app=user-service -n nacos-microservices
```

**预期结果**: 
- Pod被删除后自动重建
- API调用在故障期间仍然可用（可能有短暂中断）

### 6. 配置管理验证

#### 6.1 动态配置更新
```bash
# 通过Nacos API更新配置
curl -X POST "http://localhost:8848/nacos/v1/cs/configs" \
  -d "dataId=gateway-service.yaml&group=DEFAULT_GROUP&content=server:%0A%20%20port:%208080%0Aspring:%0A%20%20application:%0A%20%20%20%20name:%20gateway-service%0A%20%20cloud:%0A%20%20%20%20nacos:%0A%20%20%20%20%20%20discovery:%0A%20%20%20%20%20%20%20%20server-addr:%20nacos-server:8848%0A%20%20%20%20gateway:%0A%20%20%20%20%20%20routes:%0A%20%20%20%20%20%20%20%20-%20id:%20user-service%0A%20%20%20%20%20%20%20%20%20%20uri:%20lb://user-service%0A%20%20%20%20%20%20%20%20%20%20predicates:%0A%20%20%20%20%20%20%20%20%20%20%20%20-%20Path=/api/users/**%0Amanagement:%0A%20%20endpoints:%0A%20%20%20%20web:%0A%20%20%20%20%20%20exposure:%0A%20%20%20%20%20%20%20%20include:%20health,info,metrics"

# 检查配置是否更新
curl "http://localhost:8848/nacos/v1/cs/configs?dataId=gateway-service.yaml&group=DEFAULT_GROUP"
```

**预期结果**: 配置更新成功，服务能够动态加载新配置

### 7. 监控和日志验证

#### 7.1 应用指标检查
```bash
# 检查各服务的指标端点
curl -s http://$ALB_ADDRESS/actuator/metrics | jq '.names | length'
curl -s http://$ALB_ADDRESS/api/users/actuator/metrics | jq '.names | length'
curl -s http://$ALB_ADDRESS/api/orders/actuator/metrics | jq '.names | length'
curl -s http://$ALB_ADDRESS/api/notifications/actuator/metrics | jq '.names | length'
```

**预期结果**: 每个服务都暴露了丰富的指标信息

#### 7.2 日志检查
```bash
# 检查各服务日志
kubectl logs deployment/gateway-service -n nacos-microservices --tail=50
kubectl logs deployment/user-service -n nacos-microservices --tail=50
kubectl logs deployment/order-service -n nacos-microservices --tail=50
kubectl logs deployment/notification-service -n nacos-microservices --tail=50
kubectl logs statefulset/nacos-server -n nacos-microservices --tail=50
```

**预期结果**: 日志输出正常，无严重错误信息

### 8. 性能验证

#### 8.1 响应时间测试
```bash
# 测试API响应时间
for endpoint in "/api/users" "/api/orders" "/api/notifications/history"; do
  echo "测试端点: $endpoint"
  curl -w "响应时间: %{time_total}s\n" -s -o /dev/null http://$ALB_ADDRESS$endpoint
done
```

**预期结果**: 所有API响应时间应在2秒以内

#### 8.2 并发测试
```bash
# 使用ab工具进行并发测试（如果可用）
if command -v ab &> /dev/null; then
  ab -n 100 -c 10 http://$ALB_ADDRESS/api/users
else
  echo "ab工具未安装，跳过并发测试"
fi
```

**预期结果**: 系统能够处理适度的并发请求

## 📊 验证报告模板

### 验证结果汇总

| 验证项目 | 状态 | 备注 |
|---------|------|------|
| EKS集群状态 | ✅/❌ | |
| Pod运行状态 | ✅/❌ | |
| 服务健康检查 | ✅/❌ | |
| Nacos服务注册 | ✅/❌ | |
| 用户服务API | ✅/❌ | |
| 订单服务API | ✅/❌ | |
| 通知服务API | ✅/❌ | |
| 服务间通信 | ✅/❌ | |
| 网关路由 | ✅/❌ | |
| 负载均衡 | ✅/❌ | |
| 故障转移 | ✅/❌ | |
| 配置管理 | ✅/❌ | |
| 监控指标 | ✅/❌ | |
| 日志输出 | ✅/❌ | |
| 性能表现 | ✅/❌ | |

### 问题记录

| 问题描述 | 严重程度 | 解决状态 | 备注 |
|---------|----------|----------|------|
| | 高/中/低 | 已解决/待解决 | |

### 验证结论

- **总体状态**: ✅ 通过 / ❌ 未通过
- **关键功能**: 全部正常 / 部分异常 / 严重问题
- **性能表现**: 优秀 / 良好 / 需优化
- **建议**: 

---
**验证时间**: $(date)
**验证人员**: 
**ALB地址**: 
**集群名称**: nacos-microservices
