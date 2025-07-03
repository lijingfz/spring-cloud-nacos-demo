#!/bin/bash

# Spring Cloud 微服务启动脚本 (使用 Nacos)
# 按照依赖顺序启动各个服务

echo "=== Spring Cloud 微服务启动脚本 (Nacos 版本) ==="
echo "开始启动微服务..."

# 检查 Java 版本
java_version=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
echo "当前 Java 版本: $java_version"

if [[ ! $java_version =~ ^(21|17) ]]; then
    echo "警告: 建议使用 JDK 17 或 JDK 21"
fi

# 检查 Nacos 是否运行
echo ""
echo "检查 Nacos 服务状态..."
if curl -s http://localhost:8848/nacos > /dev/null 2>&1; then
    echo "✅ Nacos 服务正在运行"
else
    echo "❌ Nacos 服务未运行，请先启动 Nacos Server"
    echo ""
    echo "启动 Nacos 的方法："
    echo "1. 下载 Nacos: https://github.com/alibaba/nacos/releases"
    echo "2. 解压后进入 bin 目录"
    echo "3. 执行: sh startup.sh -m standalone (Linux/Mac)"
    echo "4. 或执行: startup.cmd -m standalone (Windows)"
    echo "5. 访问控制台: http://localhost:8848/nacos (用户名/密码: nacos/nacos)"
    echo ""
    read -p "Nacos 启动完成后，按回车键继续..." -r
fi

# 构建项目
echo ""
echo "1. 构建项目..."
mvn clean install -DskipTests
if [ $? -ne 0 ]; then
    echo "项目构建失败，请检查错误信息"
    exit 1
fi

# 启动服务的函数
start_service() {
    local service_name=$1
    local port=$2
    local wait_time=${3:-30}
    
    echo ""
    echo "启动 $service_name (端口: $port)..."
    cd $service_name
    nohup mvn spring-boot:run > ../logs/${service_name}.log 2>&1 &
    local pid=$!
    echo "$service_name PID: $pid"
    cd ..
    
    # 等待服务启动
    echo "等待 $service_name 启动完成..."
    for i in $(seq 1 $wait_time); do
        if curl -s http://localhost:$port/actuator/health > /dev/null 2>&1; then
            echo "$service_name 启动成功！"
            return 0
        fi
        sleep 2
        echo -n "."
    done
    
    echo ""
    echo "警告: $service_name 可能启动失败，请检查日志"
    return 1
}

# 创建日志目录
mkdir -p logs

echo ""
echo "=== 开始启动服务 ==="

# 1. 启动 Gateway Service
start_service "gateway-service" 8080 30

# 2. 启动 User Service
start_service "user-service" 8081 30

# 3. 启动 Order Service
start_service "order-service" 8082 30

# 4. 启动 Notification Service
start_service "notification-service" 8083 30

echo ""
echo "=== 所有服务启动完成 ==="
echo ""
echo "服务访问地址："
echo "- Nacos 控制台:       http://localhost:8848/nacos (nacos/nacos)"
echo "- API Gateway:        http://localhost:8080"
echo "- User Service:       http://localhost:8081"
echo "- Order Service:      http://localhost:8082"
echo "- Notification Svc:   http://localhost:8083"
echo ""
echo "API 测试地址（通过网关访问）："
echo "- 用户服务健康检查:    http://localhost:8080/api/users/health"
echo "- 订单服务健康检查:    http://localhost:8080/api/orders/health"
echo "- 通知服务健康检查:    http://localhost:8080/api/notifications/health"
echo ""
echo "日志文件位置: ./logs/"
echo ""
echo "停止所有服务请运行: ./stop-services.sh"
