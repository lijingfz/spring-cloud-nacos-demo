# Spring Cloud 微服务系统设计文档 (Nacos 版本)

## 1. 项目概述

### 1.1 项目简介
本项目是一个基于 Spring Cloud 2023.0.x + Nacos 的微服务架构示例，展示了现代微服务架构的核心特性和最佳实践。

### 1.2 技术栈
- **Spring Boot**: 3.1.5
- **Spring Cloud**: 2023.0.3 (Leyton)
- **Nacos**: 2.3.0 (服务发现 + 配置中心)
- **JDK**: 21
- **数据库**: H2 (内存数据库，便于演示)
- **构建工具**: Maven 3.x

### 1.3 架构特点
- 微服务架构
- 服务注册与发现 (Nacos)
- 配置中心管理 (Nacos Config)
- API 网关路由 (Spring Cloud Gateway)
- 服务间通信 (OpenFeign)
- 熔断降级 (Resilience4j)
- 负载均衡 (Spring Cloud LoadBalancer)
- 分布式追踪 (Micrometer Tracing)

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
┌───────▼────────┐    ┌────────▼────────┐
│  Nacos Server  │    │   H2 Database   │
│   Port: 8848   │    │   (In-Memory)   │
│ 服务发现+配置中心 │    │                 │
└────────────────┘    └─────────────────┘
```

### 2.2 服务清单

| 服务名称 | 端口 | 功能描述 | 关键特性 |
|---------|------|----------|----------|
| nacos-server | 8848 | 服务注册中心 + 配置中心 | 服务发现、配置管理、健康检查 |
| gateway-service | 8080 | API网关 | 路由转发、负载均衡、熔断 |
| user-service | 8081 | 用户管理服务 | 用户CRUD、认证 |
| order-service | 8082 | 订单管理服务 | 订单CRUD、服务调用 |
| notification-service | 8083 | 通知服务 | 消息推送、事件处理 |

## 3. 核心组件详解

### 3.1 服务注册与发现 (Nacos Discovery)

**功能特性:**
- 服务自动注册
- 健康状态检查
- 服务实例管理
- 故障转移支持
- 支持 CP 和 AP 一致性模型
- 多环境隔离 (namespace)

**配置要点:**
```yaml
spring:
  cloud:
    nacos:
      discovery:
        server-addr: localhost:8848
        namespace: dev
        group: DEFAULT_GROUP
        service: ${spring.application.name}
        register-enabled: true
        heart-beat-interval: 5000
        heart-beat-timeout: 15000
```

### 3.2 配置中心 (Nacos Config)

**功能特性:**
- 集中化配置管理
- 环境隔离 (namespace)
- 配置分组管理 (group)
- 动态配置刷新
- 配置版本管理和回滚
- 配置监听和推送

**配置结构:**
```
Nacos Config (dev namespace):
├── user-service.yaml        # 用户服务配置
├── order-service.yaml       # 订单服务配置
├── notification-service.yaml # 通知服务配置
└── gateway-service.yaml     # 网关服务配置
```

**配置导入:**
```yaml
spring:
  config:
    import: optional:nacos:${spring.application.name}.yaml
  cloud:
    nacos:
      config:
        server-addr: localhost:8848
        namespace: dev
        group: DEFAULT_GROUP
        file-extension: yaml
        refresh-enabled: true
```

### 3.3 API 网关 (Spring Cloud Gateway)

**功能特性:**
- 路由转发
- 负载均衡 (Spring Cloud LoadBalancer)
- 熔断降级 (Resilience4j)
- 请求过滤
- 限流控制
- 与 Nacos 集成的服务发现

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
                fallbackUri: forward:/fallback/user-service
        - id: order-service
          uri: lb://order-service
          predicates:
            - Path=/api/orders/**
          filters:
            - name: CircuitBreaker
              args:
                name: order-service-cb
                fallbackUri: forward:/fallback/order-service
        - id: notification-service
          uri: lb://notification-service
          predicates:
            - Path=/api/notifications/**
          filters:
            - name: CircuitBreaker
              args:
                name: notification-service-cb
                fallbackUri: forward:/fallback/notification-service
```

### 3.4 服务间通信 (OpenFeign + Nacos)

**功能特性:**
- 声明式HTTP客户端
- 与 Nacos 集成的负载均衡
- 熔断降级 (Resilience4j)
- 请求/响应拦截
- 自动服务发现

**使用示例:**
```java
@FeignClient(name = "user-service", fallback = UserServiceClientFallback.class)
public interface UserServiceClient {
    @GetMapping("/api/users/{id}")
    UserDto getUserById(@PathVariable("id") Long id);
    
    @GetMapping("/api/users/username/{username}")
    UserDto getUserByUsername(@PathVariable("username") String username);
}

@Component
public class UserServiceClientFallback implements UserServiceClient {
    @Override
    public UserDto getUserById(Long id) {
        return UserDto.builder()
            .id(id)
            .username("fallback-user")
            .email("fallback@example.com")
            .fullName("Fallback User")
            .build();
    }
    
    @Override
    public UserDto getUserByUsername(String username) {
        return getUserById(-1L);
    }
}
```

**Feign 配置:**
```yaml
feign:
  client:
    config:
      default:
        connect-timeout: 5000
        read-timeout: 10000
        logger-level: basic
  circuitbreaker:
    enabled: true
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

### 6.1 熔断降级 (Resilience4j)

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
        permitted-number-of-calls-in-half-open-state: 3
        automatic-transition-from-open-to-half-open-enabled: true
      order-service-cb:
        sliding-window-size: 10
        minimum-number-of-calls: 5
        failure-rate-threshold: 50
        wait-duration-in-open-state: 10s
      notification-service-cb:
        sliding-window-size: 10
        minimum-number-of-calls: 5
        failure-rate-threshold: 50
        wait-duration-in-open-state: 10s
  retry:
    instances:
      user-service:
        max-attempts: 3
        wait-duration: 1s
        retry-exceptions:
          - java.net.ConnectException
          - java.net.SocketTimeoutException
  timelimiter:
    instances:
      user-service:
        timeout-duration: 5s
        cancel-running-future: true
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
1. Nacos Server (8848) - 服务发现 + 配置中心
2. Gateway Service (8080)
3. User Service (8081)
4. Order Service (8082)
5. Notification Service (8083)

**启动命令:**

**方式一：使用自动化脚本**
```bash
# 确保 Nacos Server 已启动
# 一键启动所有服务
./start-services.sh

# 停止所有服务
./stop-services.sh

# 测试所有 API
./test-apis.sh
```

**方式二：手动启动**
```bash
# 1. 启动 Nacos Server (Docker)
docker run -d \
  --name nacos-server \
  -p 8848:8848 \
  -p 9848:9848 \
  -e MODE=standalone \
  nacos/nacos-server:v2.3.0

# 2. 构建项目
mvn clean install

# 3. 分别启动各服务
cd gateway-service && mvn spring-boot:run &
cd user-service && mvn spring-boot:run &
cd order-service && mvn spring-boot:run &
cd notification-service && mvn spring-boot:run &
```

**服务验证:**
```bash
# 检查 Nacos 服务注册状态
curl http://localhost:8848/nacos/v1/ns/instance/list?serviceName=user-service&namespaceId=dev

# 检查服务健康状态
curl http://localhost:8080/actuator/health
curl http://localhost:8081/actuator/health
curl http://localhost:8082/actuator/health
curl http://localhost:8083/actuator/health
```

### 7.2 生产环境建议

**Nacos 集群部署:**
```yaml
# docker-compose.yml for Nacos Cluster
version: '3.8'
services:
  nacos1:
    image: nacos/nacos-server:v2.3.0
    environment:
      - PREFER_HOST_MODE=hostname
      - MODE=cluster
      - NACOS_SERVERS=nacos1:8848 nacos2:8848 nacos3:8848
      - MYSQL_SERVICE_HOST=mysql
      - MYSQL_SERVICE_DB_NAME=nacos
      - MYSQL_SERVICE_USER=nacos
      - MYSQL_SERVICE_PASSWORD=nacos
    ports:
      - "8848:8848"
      - "9848:9848"
  
  nacos2:
    image: nacos/nacos-server:v2.3.0
    environment:
      - PREFER_HOST_MODE=hostname
      - MODE=cluster
      - NACOS_SERVERS=nacos1:8848 nacos2:8848 nacos3:8848
      - MYSQL_SERVICE_HOST=mysql
      - MYSQL_SERVICE_DB_NAME=nacos
      - MYSQL_SERVICE_USER=nacos
      - MYSQL_SERVICE_PASSWORD=nacos
    ports:
      - "8849:8848"
      - "9849:9848"
  
  nacos3:
    image: nacos/nacos-server:v2.3.0
    environment:
      - PREFER_HOST_MODE=hostname
      - MODE=cluster
      - NACOS_SERVERS=nacos1:8848 nacos2:8848 nacos3:8848
      - MYSQL_SERVICE_HOST=mysql
      - MYSQL_SERVICE_DB_NAME=nacos
      - MYSQL_SERVICE_USER=nacos
      - MYSQL_SERVICE_PASSWORD=nacos
    ports:
      - "8850:8848"
      - "9850:9848"
  
  mysql:
    image: mysql:8.0
    environment:
      - MYSQL_ROOT_PASSWORD=root
      - MYSQL_DATABASE=nacos
      - MYSQL_USER=nacos
      - MYSQL_PASSWORD=nacos
    volumes:
      - ./mysql-data:/var/lib/mysql
```

**容器化部署:**
- 使用 Docker 容器化各服务
- Kubernetes 编排管理
- 配置外部化存储 (Nacos Config)
- 服务网格集成 (Istio)

**数据库:**
- 替换 H2 为生产级数据库 (MySQL/PostgreSQL)
- Nacos 使用 MySQL 集群存储
- 数据库连接池优化
- 读写分离

**监控告警:**
- 集成 Prometheus + Grafana
- Nacos 监控指标采集
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

## 13. Nacos vs Eureka 技术对比

### 13.1 功能对比

| 特性 | Nacos | Eureka |
|------|-------|--------|
| 服务发现 | ✅ | ✅ |
| 配置管理 | ✅ | ❌ (需要Config Server) |
| 管理界面 | 功能丰富的Web控制台 | 基础服务列表页面 |
| 一致性模型 | CP + AP (可选择) | AP |
| 多环境支持 | ✅ (namespace) | ❌ |
| 动态配置 | ✅ | ❌ |
| 服务分组 | ✅ (group) | ❌ |
| 权重配置 | ✅ | ❌ |
| 健康检查 | TCP/HTTP/MySQL | HTTP |
| 集群部署 | ✅ | ✅ |
| 数据持久化 | MySQL/Derby | 内存 |

### 13.2 架构优势

**Nacos 优势:**
1. **一体化解决方案**: 服务发现 + 配置管理
2. **更强的管理能力**: 丰富的Web控制台
3. **更好的扩展性**: 支持多种一致性模型
4. **生产级特性**: 权限控制、审计日志、监控告警
5. **云原生友好**: 支持Kubernetes、Docker

**选择 Nacos 的理由:**
- 减少组件复杂度 (无需单独的Config Server)
- 更好的运维体验
- 更强的配置管理能力
- 更适合大规模微服务架构

### 13.3 迁移建议

**从 Eureka + Config Server 迁移到 Nacos:**

1. **依赖替换**:
```xml
<!-- 移除 Eureka 依赖 -->
<!-- <dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-netflix-eureka-client</artifactId>
</dependency> -->

<!-- 添加 Nacos 依赖 -->
<dependency>
    <groupId>com.alibaba.cloud</groupId>
    <artifactId>spring-cloud-starter-alibaba-nacos-discovery</artifactId>
</dependency>
<dependency>
    <groupId>com.alibaba.cloud</groupId>
    <artifactId>spring-cloud-starter-alibaba-nacos-config</artifactId>
</dependency>
```

2. **配置迁移**:
```yaml
# 原 Eureka 配置
# eureka:
#   client:
#     service-url:
#       defaultZone: http://localhost:8761/eureka/

# 新 Nacos 配置
spring:
  cloud:
    nacos:
      discovery:
        server-addr: localhost:8848
        namespace: dev
      config:
        server-addr: localhost:8848
        namespace: dev
        file-extension: yaml
```

3. **配置文件迁移**:
   - 将 Git 仓库中的配置文件导入到 Nacos
   - 利用 Nacos 的配置导入/导出功能
   - 设置合适的 namespace 和 group

## 14. 运维监控

### 14.1 日志管理
- 结构化日志 (JSON格式)
- 日志聚合 (ELK Stack)
- 日志分析和告警
- Nacos 操作审计日志

### 14.2 指标监控

**业务指标:**
- API 调用量和响应时间
- 服务可用性
- 错误率统计

**技术指标:**
- JVM 内存使用率
- GC 频率和耗时
- 数据库连接池状态
- Nacos 服务注册数量

**Nacos 监控:**
```yaml
# Nacos 监控配置
management:
  endpoints:
    web:
      exposure:
        include: '*'
  endpoint:
    health:
      show-details: always
  metrics:
    export:
      prometheus:
        enabled: true
```

### 14.3 故障处理

**故障定位:**
- 分布式链路追踪 (Micrometer Tracing)
- 日志关联分析
- Nacos 服务状态检查

**快速恢复:**
- 服务自动重启
- 熔断降级机制
- 配置热更新

**事后分析:**
- 故障复盘
- 监控告警优化
- 系统改进建议

---

**文档版本**: 2.0.0 (Nacos 版本)  
**最后更新**: 2025-07-08  
**技术栈**: Spring Boot 3.1.5 + Spring Cloud 2023.0.3 + Nacos 2.3.0 + JDK 21  
**维护人员**: Spring Cloud Nacos Demo Team
