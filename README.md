# Spring Cloud 微服务示例项目 (Nacos 版本)

这是一个基于 Spring Cloud 2023.0.x + Nacos 的完整微服务架构示例项目，展示了现代微服务开发的核心特性和最佳实践。

## 🚀 项目特性

- **Spring Boot 3.1.5** + **Spring Cloud 2023.0.3** + **JDK 21**
- **服务注册与发现** (Nacos)
- **配置中心管理** (Nacos Config)
- **API 网关路由** (Spring Cloud Gateway)
- **服务间通信** (OpenFeign)
- **熔断降级** (Resilience4j)
- **负载均衡** (Spring Cloud LoadBalancer)
- **分布式追踪** (Micrometer Tracing)
- **健康检查** (Spring Boot Actuator)

## 📋 系统架构

```
Client → API Gateway → [User Service, Order Service, Notification Service]
                    ↓
              [Nacos Server (服务发现 + 配置管理)]
```

### 服务列表

| 服务名称 | 端口 | 功能描述 |
|---------|------|----------|
| nacos-server | 8848 | 服务注册中心 + 配置中心 |
| gateway-service | 8080 | API网关 |
| user-service | 8081 | 用户管理服务 |
| order-service | 8082 | 订单管理服务 |
| notification-service | 8083 | 通知服务 |

## 🛠️ 环境要求

- **JDK 21** (最低 JDK 17)
- **Maven 3.6+**
- **Nacos Server 2.3.0+**

## 🚀 快速开始

### 1. 启动 Nacos Server

**方式一：下载二进制包**
```bash
# 下载并解压 Nacos
wget https://github.com/alibaba/nacos/releases/download/2.3.0/nacos-server-2.3.0.tar.gz
tar -xzf nacos-server-2.3.0.tar.gz
cd nacos

# 启动 Nacos (单机模式)
sh bin/startup.sh -m standalone
```

**方式二：Docker 启动**
```bash
docker run -d \
  --name nacos-server \
  -p 8848:8848 \
  -p 9848:9848 \
  -e MODE=standalone \
  nacos/nacos-server:v2.3.0
```

### 2. 配置 Nacos

1. 访问 Nacos 控制台: http://localhost:8848/nacos
2. 登录 (用户名/密码: nacos/nacos)
3. 创建命名空间 `dev`
4. 参考 [NACOS_SETUP.md](./NACOS_SETUP.md) 创建配置文件

### 3. 启动微服务

**⚠️ 重要提示**: 确保所有服务的配置文件都包含正确的Nacos配置导入设置。

```bash
# 克隆项目
git clone <repository-url>
cd spring-cloud-nacos-demo

# 一键启动所有服务
./start-services.sh
```

**启动过程说明**：
1. 脚本会自动检查Nacos服务状态
2. 构建所有微服务模块
3. 按顺序启动各个服务：
   - Gateway Service (端口 8080)
   - User Service (端口 8081) 
   - Order Service (端口 8082)
   - Notification Service (端口 8083)
4. 等待每个服务完全启动后再启动下一个

### 4. 验证服务状态

**基础检查**：
```bash
# 检查所有服务端口
ss -tlnp | grep -E "(8080|8081|8082|8083|8848)"

# 检查服务健康状态
curl http://localhost:8080/actuator/health
curl http://localhost:8081/actuator/health  
curl http://localhost:8082/actuator/health
curl http://localhost:8083/actuator/health
```

**服务访问地址**：
- **Nacos 控制台**: http://localhost:8848/nacos (nacos/nacos)
- **API 网关**: http://localhost:8080
- **用户服务**: http://localhost:8081
- **订单服务**: http://localhost:8082  
- **通知服务**: http://localhost:8083

**Nacos服务注册检查**：
- 访问 Nacos 控制台 → 服务管理 → 服务列表
- 确认所有4个服务都已注册到 `dev` 命名空间

### 5. 完整功能测试

**自动化测试**：
```bash
# 运行完整的API功能测试
./test-apis.sh
```

**手动测试示例**：
```bash
# 1. 创建用户
curl -X POST http://localhost:8080/api/users \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "email": "test@example.com", 
    "password": "password123",
    "fullName": "测试用户",
    "phoneNumber": "13800138000"
  }'

# 2. 创建订单
curl -X POST http://localhost:8080/api/orders \
  -H "Content-Type: application/json" \
  -d '{
    "userId": 1,
    "productName": "测试商品",
    "quantity": 2,
    "unitPrice": 99.99
  }'

# 3. 发送通知
curl -X POST http://localhost:8080/api/notifications/send \
  -H "Content-Type: application/json" \
  -d '{
    "recipient": "test@example.com",
    "type": "EMAIL", 
    "title": "测试通知",
    "content": "这是一条测试通知消息"
  }'
```

### 6. 停止所有服务
```bash
./stop-services.sh
```

### 7. 故障排查

**常见启动问题**：

1. **服务启动失败 - 缺少Nacos配置导入**
   ```
   错误: No spring.config.import property has been defined
   解决: 确保application.yml包含 spring.config.import: optional:nacos:{service-name}.yaml
   ```

2. **端口被占用**
   ```bash
   # 查找占用端口的进程
   ss -tlnp | grep 8080
   # 杀死进程
   kill -9 <PID>
   ```

3. **Nacos连接失败**
   ```bash
   # 检查Nacos服务状态
   curl http://localhost:8848/nacos
   # 检查网络连接
   telnet localhost 8848
   ```

**日志查看**：
```bash
# 查看所有服务日志
ls -la logs/

# 实时查看特定服务日志
tail -f logs/gateway-service.log
tail -f logs/user-service.log
tail -f logs/order-service.log  
tail -f logs/notification-service.log
```

## 📖 手动启动（可选）

### 1. 构建项目
```bash
mvn clean install
```

### 2. 启动服务（按顺序）

**启动 Gateway Service**
```bash
cd gateway-service
mvn spring-boot:run
```

**启动业务服务**
```bash
# 用户服务
cd user-service
mvn spring-boot:run

# 订单服务
cd order-service
mvn spring-boot:run

# 通知服务
cd notification-service
mvn spring-boot:run
```

## 🔧 API 测试示例

### 用户服务 API

**创建用户**
```bash
curl -X POST http://localhost:8080/api/users \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "email": "test@example.com",
    "password": "password123",
    "fullName": "测试用户",
    "phoneNumber": "13800138000"
  }'
```

**获取所有用户**
```bash
curl http://localhost:8080/api/users
```

### 订单服务 API

**创建订单**
```bash
curl -X POST http://localhost:8080/api/orders \
  -H "Content-Type: application/json" \
  -d '{
    "userId": 1,
    "productName": "测试商品",
    "quantity": 2,
    "unitPrice": 99.99
  }'
```

**获取所有订单**
```bash
curl http://localhost:8080/api/orders
```

### 通知服务 API

**发送通知**
```bash
curl -X POST http://localhost:8080/api/notifications/send \
  -H "Content-Type: application/json" \
  -d '{
    "recipient": "test@example.com",
    "type": "EMAIL",
    "title": "测试通知",
    "content": "这是一条测试通知消息"
  }'
```

## 🎯 Nacos 核心特性演示

### 1. 服务注册与发现
- 所有服务自动注册到 Nacos
- 支持服务健康检查和故障转移
- 访问: http://localhost:8848/nacos

### 2. 配置中心
- 集中管理所有服务配置
- 支持配置动态刷新
- 多环境配置隔离 (通过 namespace)
- 配置版本管理和回滚

### 3. API 网关
- 统一入口，路由转发
- 负载均衡和熔断降级
- 所有 API 通过 http://localhost:8080 访问

### 4. 服务间通信
- 订单服务通过 Feign 调用用户服务
- 支持熔断降级和重试机制
- 演示了微服务间的协作

## 📊 Nacos vs Eureka 对比

| 特性 | Nacos | Eureka |
|------|-------|--------|
| 服务发现 | ✅ | ✅ |
| 配置管理 | ✅ | ❌ (需要Config Server) |
| 管理界面 | 功能丰富 | 基础 |
| 一致性模型 | CP + AP | AP |
| 多环境支持 | ✅ (namespace) | ❌ |
| 动态配置 | ✅ | ❌ |

## 📊 监控端点

每个服务都提供以下监控端点：

- `/actuator/health` - 健康检查
- `/actuator/info` - 服务信息
- `/actuator/metrics` - 指标数据
- `/actuator/env` - 环境变量

## 🐛 故障排查

### 常见问题

**1. Nacos 连接失败**
- 确认 Nacos Server 已启动 (http://localhost:8848/nacos)
- 检查网络连接
- 验证配置文件中的 server-addr

**2. 服务注册失败**
- 查看服务日志
- 确认 namespace 和 group 配置正确
- 检查 Nacos 控制台的服务列表

**3. 配置获取失败**
- 确认配置文件的 Data ID 和 Group 正确
- 检查命名空间配置
- 验证配置格式 (YAML)

### 日志查看
```bash
# 查看所有服务日志
ls -la logs/

# 查看特定服务日志
tail -f logs/user-service.log

# 查看 Nacos 日志
tail -f nacos/logs/nacos.log
```

## 📚 技术文档

- [系统设计文档](./SYSTEM_DESIGN.md)
- [Nacos 安装配置指南](./NACOS_SETUP.md)

## 🔄 扩展开发

### 添加新服务

1. 在根 `pom.xml` 中添加新模块
2. 创建服务目录和基础结构
3. 配置 Nacos 客户端
4. 在网关中添加路由规则
5. 在 Nacos 中创建配置文件

### 配置管理最佳实践

1. **环境隔离**: 使用不同的 namespace
2. **配置分组**: 使用 Group 进行分类
3. **动态刷新**: 使用 @RefreshScope 注解
4. **版本管理**: 利用 Nacos 的配置历史功能

## 🤝 贡献指南

1. Fork 项目
2. 创建特性分支
3. 提交更改
4. 推送到分支
5. 创建 Pull Request

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情

---

**项目版本**: 2.0.0 (Nacos 版本)  
**最后更新**: 2025-07-01  
**技术栈**: Spring Boot 3.1.5 + Spring Cloud 2023.0.3 + Nacos 2.3.0 + JDK 21
