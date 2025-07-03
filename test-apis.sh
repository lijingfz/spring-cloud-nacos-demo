#!/bin/bash

# API 测试脚本
# 测试各个微服务的主要功能

echo "=== Spring Cloud 微服务 API 测试 ==="
echo ""

# 基础 URL
GATEWAY_URL="http://localhost:8080"
USER_SERVICE_URL="http://localhost:8081"
ORDER_SERVICE_URL="http://localhost:8082"
NOTIFICATION_SERVICE_URL="http://localhost:8083"

# 测试函数
test_api() {
    local name=$1
    local url=$2
    local method=${3:-GET}
    local data=$4
    
    echo "测试: $name"
    echo "URL: $url"
    
    if [ "$method" = "POST" ]; then
        response=$(curl -s -X POST -H "Content-Type: application/json" -d "$data" "$url")
    else
        response=$(curl -s "$url")
    fi
    
    echo "响应: $response"
    echo "---"
    echo ""
}

echo "等待服务启动完成..."
sleep 5

echo "=== 1. 服务健康检查 ==="

# 直接访问各服务
test_api "用户服务健康检查" "$USER_SERVICE_URL/api/users/health"
test_api "订单服务健康检查" "$ORDER_SERVICE_URL/api/orders/health"
test_api "通知服务健康检查" "$NOTIFICATION_SERVICE_URL/api/notifications/health"

echo "=== 2. 通过网关访问服务 ==="

# 通过网关访问
test_api "网关 -> 用户服务健康检查" "$GATEWAY_URL/api/users/health"
test_api "网关 -> 订单服务健康检查" "$GATEWAY_URL/api/orders/health"
test_api "网关 -> 通知服务健康检查" "$GATEWAY_URL/api/notifications/health"

echo "=== 3. 用户服务功能测试 ==="

# 创建用户
user_data='{
    "username": "testuser",
    "email": "test@example.com",
    "password": "password123",
    "fullName": "测试用户",
    "phoneNumber": "13800138000"
}'

test_api "创建用户" "$GATEWAY_URL/api/users" "POST" "$user_data"

# 获取所有用户
test_api "获取所有用户" "$GATEWAY_URL/api/users"

# 根据用户名获取用户
test_api "根据用户名获取用户" "$GATEWAY_URL/api/users/username/testuser"

echo "=== 4. 订单服务功能测试 ==="

# 创建订单
order_data='{
    "userId": 1,
    "productName": "测试商品",
    "quantity": 2,
    "unitPrice": 99.99
}'

test_api "创建订单" "$GATEWAY_URL/api/orders" "POST" "$order_data"

# 获取所有订单
test_api "获取所有订单" "$GATEWAY_URL/api/orders"

# 获取订单统计
test_api "获取订单统计" "$GATEWAY_URL/api/orders/statistics"

echo "=== 5. 通知服务功能测试 ==="

# 发送通知
notification_data='{
    "recipient": "test@example.com",
    "type": "EMAIL",
    "title": "测试通知",
    "content": "这是一条测试通知消息"
}'

test_api "发送通知" "$GATEWAY_URL/api/notifications/send" "POST" "$notification_data"

# 批量发送通知
batch_notification_data='{
    "recipients": ["user1@example.com", "user2@example.com"],
    "type": "EMAIL",
    "title": "批量通知",
    "content": "这是一条批量通知消息"
}'

test_api "批量发送通知" "$GATEWAY_URL/api/notifications/send/batch" "POST" "$batch_notification_data"

# 获取通知统计
test_api "获取通知统计" "$GATEWAY_URL/api/notifications/statistics"

echo "=== 6. 服务间调用测试 ==="

# 创建订单时会调用用户服务验证用户
order_data2='{
    "userId": 1,
    "productName": "服务间调用测试商品",
    "quantity": 1,
    "unitPrice": 199.99
}'

test_api "测试服务间调用（订单->用户）" "$GATEWAY_URL/api/orders" "POST" "$order_data2"

echo "=== API 测试完成 ==="
echo ""
echo "如需查看详细日志，请检查 ./logs/ 目录下的日志文件"
echo "Eureka 控制台: http://localhost:8761"
