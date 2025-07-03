# Nacos 安装和配置指南

## 🚀 Nacos Server 安装

### 方式一：下载二进制包（推荐）

1. **下载 Nacos**
   ```bash
   # 下载最新版本
   wget https://github.com/alibaba/nacos/releases/download/2.3.0/nacos-server-2.3.0.tar.gz
   
   # 解压
   tar -xzf nacos-server-2.3.0.tar.gz
   cd nacos
   ```

2. **启动 Nacos Server**
   ```bash
   # Linux/Mac
   sh bin/startup.sh -m standalone
   
   # Windows
   bin/startup.cmd -m standalone
   ```

3. **验证启动**
   - 访问控制台: http://localhost:8848/nacos
   - 默认用户名/密码: `nacos/nacos`

### 方式二：Docker 启动

```bash
# 拉取镜像
docker pull nacos/nacos-server:v2.3.0

# 启动容器
docker run -d \
  --name nacos-server \
  -p 8848:8848 \
  -p 9848:9848 \
  -e MODE=standalone \
  nacos/nacos-server:v2.3.0
```

## 🔧 Nacos 配置管理

### 1. 访问控制台
- URL: http://localhost:8848/nacos
- 用户名: nacos
- 密码: nacos

### 2. 创建命名空间
1. 进入 **命名空间** 页面
2. 点击 **新建命名空间**
3. 填写信息：
   - 命名空间ID: `dev`
   - 命名空间名: `开发环境`
   - 描述: `开发环境配置`

### 3. 创建配置文件

在 **配置管理** → **配置列表** 中创建以下配置：

#### 用户服务配置
- **Data ID**: `user-service.yaml`
- **Group**: `DEFAULT_GROUP`
- **配置格式**: `YAML`
- **配置内容**:
```yaml
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
  h2:
    console:
      enabled: true

app:
  name: "用户服务"
  version: "1.0.0"
  description: "提供用户管理功能"
```

#### 订单服务配置
- **Data ID**: `order-service.yaml`
- **Group**: `DEFAULT_GROUP`
- **配置格式**: `YAML`
- **配置内容**:
```yaml
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
  h2:
    console:
      enabled: true

app:
  name: "订单服务"
  version: "1.0.0"
  description: "提供订单管理功能"
```

#### 通知服务配置
- **Data ID**: `notification-service.yaml`
- **Group**: `DEFAULT_GROUP`
- **配置格式**: `YAML`
- **配置内容**:
```yaml
app:
  name: "通知服务"
  version: "1.0.0"
  description: "提供消息通知功能"
```

## 📊 服务发现验证

启动微服务后，在 Nacos 控制台的 **服务管理** → **服务列表** 中可以看到：

- gateway-service
- user-service
- order-service
- notification-service

每个服务显示：
- 服务名称
- 分组信息
- 实例数量
- 健康实例数
- 触发保护阈值

## 🔄 配置动态刷新

Nacos 支持配置的动态刷新，修改配置后会自动推送到服务实例。

### 在 Spring Boot 中使用 @RefreshScope

```java
@RestController
@RefreshScope  // 支持配置动态刷新
public class ConfigController {
    
    @Value("${app.name}")
    private String appName;
    
    @GetMapping("/config")
    public String getConfig() {
        return "当前应用名称: " + appName;
    }
}
```

## 🛠️ 高级配置

### 1. 集群模式

如需部署 Nacos 集群，修改 `conf/cluster.conf`：
```
192.168.1.100:8848
192.168.1.101:8848
192.168.1.102:8848
```

### 2. 数据库配置

生产环境建议使用 MySQL 存储：

1. 创建数据库和表（使用 `conf/nacos-mysql.sql`）
2. 修改 `conf/application.properties`：
```properties
spring.datasource.platform=mysql
db.num=1
db.url.0=jdbc:mysql://localhost:3306/nacos?characterEncoding=utf8&connectTimeout=1000&socketTimeout=3000&autoReconnect=true&useUnicode=true&useSSL=false&serverTimezone=UTC
db.user.0=nacos
db.password.0=nacos
```

## 🔒 安全配置

### 1. 修改默认密码

在 `conf/application.properties` 中：
```properties
nacos.core.auth.enabled=true
nacos.core.auth.default.token.secret.key=your-secret-key
```

### 2. 用户管理

在控制台的 **权限控制** → **用户管理** 中：
- 修改默认用户密码
- 创建新用户
- 分配角色权限

## 📝 故障排查

### 常见问题

1. **启动失败**
   - 检查端口 8848 是否被占用
   - 查看 `logs/start.out` 日志

2. **服务注册失败**
   - 确认 Nacos Server 正常运行
   - 检查网络连接
   - 验证配置文件中的 server-addr

3. **配置获取失败**
   - 确认配置文件的 Data ID 和 Group 正确
   - 检查命名空间配置
   - 验证配置格式

### 日志查看

```bash
# 查看启动日志
tail -f logs/start.out

# 查看 Nacos 日志
tail -f logs/nacos.log
```

## 🎯 最佳实践

1. **环境隔离**: 使用不同的命名空间区分环境
2. **配置分组**: 使用 Group 对配置进行分类管理
3. **版本管理**: 利用 Nacos 的配置历史功能
4. **监控告警**: 集成监控系统，监控服务健康状态
5. **安全加固**: 修改默认密码，启用认证授权

---

**注意**: 本指南基于 Nacos 2.3.0 版本，不同版本可能有差异。
