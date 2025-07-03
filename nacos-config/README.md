# Nacos 配置管理

## 配置文件说明

在 Nacos 控制台中，需要创建以下配置文件：

### 1. 用户服务配置
- **Data ID**: `user-service.yaml`
- **Group**: `DEFAULT_GROUP`
- **配置格式**: `YAML`

```yaml
# 数据库配置
spring:
  datasource:
    url: jdbc:h2:mem:userdb
    driver-class-name: org.h2.Driver
    username: sa
    password: 
  jpa:
    hibernate:
      ddl-auto: create-drop
    show-sql: true

# 自定义配置
app:
  name: "用户服务"
  version: "1.0.0"
  description: "提供用户管理功能"
```

### 2. 订单服务配置
- **Data ID**: `order-service.yaml`
- **Group**: `DEFAULT_GROUP`
- **配置格式**: `YAML`

```yaml
# 数据库配置
spring:
  datasource:
    url: jdbc:h2:mem:orderdb
    driver-class-name: org.h2.Driver
    username: sa
    password: 
  jpa:
    hibernate:
      ddl-auto: create-drop
    show-sql: true

# 自定义配置
app:
  name: "订单服务"
  version: "1.0.0"
  description: "提供订单管理功能"
```

### 3. 通知服务配置
- **Data ID**: `notification-service.yaml`
- **Group**: `DEFAULT_GROUP`
- **配置格式**: `YAML`

```yaml
# 自定义配置
app:
  name: "通知服务"
  version: "1.0.0"
  description: "提供消息通知功能"
```

## 配置管理优势

1. **集中管理**: 所有配置在 Nacos 控制台统一管理
2. **动态刷新**: 配置修改后自动推送到服务实例
3. **环境隔离**: 通过 namespace 实现不同环境的配置隔离
4. **版本管理**: 支持配置的版本管理和回滚
5. **权限控制**: 支持用户权限管理

## 使用方式

1. 启动 Nacos Server
2. 访问 Nacos 控制台: http://localhost:8848/nacos
3. 登录 (默认用户名/密码: nacos/nacos)
4. 在配置管理中创建上述配置文件
5. 启动微服务，服务会自动从 Nacos 获取配置
