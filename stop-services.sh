#!/bin/bash

# Spring Cloud 微服务停止脚本 (Nacos 版本)

echo "=== Spring Cloud 微服务停止脚本 (Nacos 版本) ==="

# 查找并停止 Spring Boot 应用
echo "正在查找运行中的 Spring Boot 应用..."

# 通过端口查找并停止服务
stop_service_by_port() {
    local port=$1
    local service_name=$2
    
    local pid=$(lsof -ti:$port)
    if [ ! -z "$pid" ]; then
        echo "停止 $service_name (PID: $pid, Port: $port)..."
        kill -15 $pid
        sleep 2
        
        # 如果进程仍在运行，强制杀死
        if kill -0 $pid 2>/dev/null; then
            echo "强制停止 $service_name..."
            kill -9 $pid
        fi
        echo "$service_name 已停止"
    else
        echo "$service_name 未运行 (端口 $port)"
    fi
}

# 停止各个服务
stop_service_by_port 8083 "Notification Service"
stop_service_by_port 8082 "Order Service"
stop_service_by_port 8081 "User Service"
stop_service_by_port 8080 "Gateway Service"

# 额外检查：通过进程名停止
echo ""
echo "检查是否还有遗留的 Spring Boot 进程..."
spring_pids=$(ps aux | grep 'spring-boot:run' | grep -v grep | awk '{print $2}')

if [ ! -z "$spring_pids" ]; then
    echo "发现遗留进程，正在停止..."
    for pid in $spring_pids; do
        echo "停止进程 PID: $pid"
        kill -15 $pid
    done
    sleep 3
    
    # 再次检查并强制杀死
    spring_pids=$(ps aux | grep 'spring-boot:run' | grep -v grep | awk '{print $2}')
    if [ ! -z "$spring_pids" ]; then
        echo "强制停止遗留进程..."
        for pid in $spring_pids; do
            kill -9 $pid
        done
    fi
fi

echo ""
echo "=== 所有服务已停止 ==="
echo ""
echo "注意: Nacos Server 需要手动停止"
echo "如需重新启动，请运行: ./start-services.sh"
