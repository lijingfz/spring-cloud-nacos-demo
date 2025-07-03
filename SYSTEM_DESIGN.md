# Spring Cloud 微服务系统设计文档

## 1. 项目概述

### 1.1 项目简介
本项目是一个基于 Spring Cloud 2023.0.x 的微服务架构示例，展示了现代微服务架构的核心特性和最佳实践。

### 1.2 技术栈
- **Spring Boot**: 3.1.5
- **Spring Cloud**: 2023.0.3 (Leyton)
- **JDK**: 21
- **数据库**: H2 (内存数据库，便于演示)
- **构建工具**: Maven 3.x

### 1.3 架构特点
- 微服务架构
- 服务注册与发现
- 配置中心管理
- API 网关路由
- 服务间通信
- 熔断降级
- 分布式追踪

## 2. 系统架构

### 2.1 整体架构图
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Client Apps   │    │   Web Browser   │    │   Mobile Apps   │
└─────────┬───────┘    └─────────┬───────┘    └─────────┬───────┘
          │                      │                      │
          └──────────────────────┼──────────────────────┘
                                 │
                    ┌─────────────▼─────────────┐
                    │     API Gateway          │
                    │   (gateway-service)      │
                    │   Port: 8080            │
                    └─────────────┬─────────────┘
                                 │
        ┌────────────────────────┼────────────────────────┐
        │                       │                        │
┌───────▼────────┐    ┌─────────▼────────┐    ┌─────────▼────────┐
│  User Service  │    │  Order Service   │    │Notification Svc  │
│   Port: 8081   │    │   Port: 8082     │    │   Port: 8083     │
└───────┬────────┘    └─────────┬────────┘    └─────────┬────────┘
        │                       │                        │
        └───────────────────────┼────────────────────────┘
                               │
        ┌──────────────────────┼──────────────────────┐
        │                      │                      │
┌───────▼────────┐    ┌────────▼────────┐    ┌───────▼────────┐
│ Eureka Server  │    │  Config Server  │    │   H2 Database  │
│   Port: 8761   │    │   Port: 8888    │    │   (In-Memory)  │
└────────────────┘    └─────────────────┘    └────────────────┘
```

### 2.2 服务清单

| 服务名称 | 端口 | 功能描述 | 关键特性 |
|---------|------|----------|----------|
| eureka-server | 8761 | 服务注册中心 | 服务发现、健康检查 |
| config-server | 8888 | 配置管理中心 | 集中配置、动态刷新 |
| gateway-service | 8080 | API网关 | 路由转发、负载均衡、熔断 |
| user-service | 8081 | 用户管理服务 | 用户CRUD、认证 |
| order-service | 8082 | 订单管理服务 | 订单CRUD、服务调用 |
| notification-service | 8083 | 通知服务 | 消息推送、事件处理 |

## 3. 核心组件详解

### 3.1 服务注册与发现 (Eureka)

**功能特性:**
- 服务自动注册
- 健康状态检查
- 服务实例管理
- 故障转移支持

**配置要点:**
```yaml
eureka:
  server:
    enable-self-preservation: false  # 开发环境关闭自我保护
    eviction-interval-timer-in-ms: 10000  # 清理间隔
  client:
    register-with-eureka: false  # 服务端不注册自己
    fetch-registry: false        # 服务端不获取注册表
```

### 3.2 配置中心 (Spring Cloud Config)

**功能特性:**
- 集中化配置管理
- 环境隔离
- 配置版本控制
- 动态配置刷新

**配置结构:**
```
config-repo/
├── user-service.yml      # 用户服务配置
├── order-service.yml     # 订单服务配置
└── application.yml       # 公共配置
```

### 3.3 API 网关 (Spring Cloud Gateway)

**功能特性:**
- 路由转发
- 负载均衡
- 熔断降级
- 请求过滤
- 限流控制

**路由配置:**
```yaml
spring:
  cloud:
    gateway:
      routes:
        - id: user-service
          uri: lb://user-service
          predicates:
            - Path=/api/users/**
          filters:
            - name: CircuitBreaker
              args:
                name: user-service-cb
```

### 3.4 服务间通信 (OpenFeign)

**功能特性:**
- 声明式HTTP客户端
- 负载均衡
- 熔断降级
- 请求/响应拦截

**使用示例:**
```java
@FeignClient(name = "user-service", fallback = UserServiceClientFallback.class)
public interface UserServiceClient {
    @GetMapping("/api/users/{id}")
    UserDto getUserById(@PathVariable("id") Long id);
}
```

## 4. 数据模型设计

### 4.1 用户服务数据模型

```sql
CREATE TABLE users (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    full_name VARCHAR(100),
    phone_number VARCHAR(20),
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);
```

### 4.2 订单服务数据模型

```sql
CREATE TABLE orders (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    order_number VARCHAR(50) UNIQUE NOT NULL,
    user_id BIGINT NOT NULL,
    product_name VARCHAR(200) NOT NULL,
    quantity INTEGER NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL,
    status VARCHAR(20) NOT NULL,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);
```

## 5. API 接口设计

### 5.1 用户服务 API

| 方法 | 路径 | 描述 |
|------|------|------|
| GET | /api/users | 获取所有用户 |
| GET | /api/users/{id} | 根据ID获取用户 |
| POST | /api/users | 创建用户 |
| PUT | /api/users/{id} | 更新用户信息 |
| DELETE | /api/users/{id} | 删除用户 |
| POST | /api/users/login | 用户登录 |

### 5.2 订单服务 API

| 方法 | 路径 | 描述 |
|------|------|------|
| GET | /api/orders | 获取所有订单 |
| GET | /api/orders/{id} | 根据ID获取订单 |
| POST | /api/orders | 创建订单 |
| PUT | /api/orders/{id}/status | 更新订单状态 |
| DELETE | /api/orders/{id} | 删除订单 |
| GET | /api/orders/user/{userId} | 获取用户订单 |

## 6. 容错与监控

### 6.1 熔断降级

**Resilience4j 配置:**
```yaml
resilience4j:
  circuitbreaker:
    instances:
      user-service-cb:
        sliding-window-size: 10
        minimum-number-of-calls: 5
        failure-rate-threshold: 50
        wait-duration-in-open-state: 10s
```

### 6.2 健康检查

所有服务都集成了 Spring Boot Actuator，提供：
- 健康状态检查 `/actuator/health`
- 服务信息 `/actuator/info`
- 指标监控 `/actuator/metrics`

### 6.3 分布式追踪

集成 Micrometer Tracing，支持：
- 请求链路追踪
- 性能监控
- 错误定位

## 7. 部署架构

### 7.1 本地开发环境

**启动顺序:**
1. Eureka Server (8761)
2. Config Server (8888)
3. Gateway Service (8080)
4. User Service (8081)
5. Order Service (8082)
6. Notification Service (8083)

**启动命令:**
```bash
# 根目录执行
mvn clean install

# 分别启动各服务
cd eureka-server && mvn spring-boot:run
cd config-server && mvn spring-boot:run
cd gateway-service && mvn spring-boot:run
cd user-service && mvn spring-boot:run
cd order-service && mvn spring-boot:run
cd notification-service && mvn spring-boot:run
```

### 7.2 生产环境建议

**容器化部署:**
- 使用 Docker 容器化各服务
- Kubernetes 编排管理
- 配置外部化存储

**数据库:**
- 替换 H2 为生产级数据库 (MySQL/PostgreSQL)
- 数据库连接池优化
- 读写分离

**监控告警:**
- 集成 Prometheus + Grafana
- 日志聚合 (ELK Stack)
- 告警通知机制

## 8. 安全考虑

### 8.1 认证授权
- JWT Token 认证
- OAuth2 集成
- 角色权限控制

### 8.2 网络安全
- HTTPS 通信
- API 限流
- 防止 SQL 注入

### 8.3 数据安全
- 敏感数据加密
- 数据脱敏
- 审计日志

## 9. 性能优化

### 9.1 缓存策略
- Redis 分布式缓存
- 本地缓存 (Caffeine)
- 缓存预热

### 9.2 数据库优化
- 索引优化
- 查询优化
- 连接池调优

### 9.3 JVM 调优
- 内存参数调整
- GC 策略选择
- 性能监控

## 10. 扩展性设计

### 10.1 水平扩展
- 无状态服务设计
- 负载均衡
- 自动伸缩

### 10.2 功能扩展
- 插件化架构
- 事件驱动
- 消息队列集成

## 11. 测试策略

### 11.1 单元测试
- JUnit 5
- Mockito
- TestContainers

### 11.2 集成测试
- Spring Boot Test
- WireMock
- 契约测试

### 11.3 性能测试
- JMeter
- 压力测试
- 性能基准

## 12. 运维监控

### 12.1 日志管理
- 结构化日志
- 日志聚合
- 日志分析

### 12.2 指标监控
- 业务指标
- 技术指标
- 告警规则

### 12.3 故障处理
- 故障定位
- 快速恢复
- 事后分析

---

**文档版本**: 1.0.0  
**最后更新**: 2025-07-01  
**维护人员**: Spring Cloud Demo Team
