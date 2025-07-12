#!/bin/bash

# Nacos 服务注册状态检查脚本
# 使用命令行方式查看 Nacos 中的服务注册情况

NACOS_SERVER="http://localhost:8848"
NAMESPACE="dev"

echo "=== Nacos 服务注册状态检查 ==="
echo "Nacos 服务器: $NACOS_SERVER"
echo "命名空间: $NAMESPACE"
echo ""

# 检查 Nacos 服务是否可用
echo "1. 检查 Nacos 服务状态..."
if curl -s "$NACOS_SERVER/nacos" > /dev/null 2>&1; then
    echo "✅ Nacos 服务正常运行"
else
    echo "❌ Nacos 服务不可用"
    exit 1
fi
echo ""

# 获取命名空间信息
echo "2. 获取命名空间信息..."
curl -s "$NACOS_SERVER/nacos/v1/console/namespaces" | jq -r '.data[] | select(.namespace=="'$NAMESPACE'") | "命名空间: \(.namespace) (\(.namespaceShowName)) - 配置数量: \(.configCount)"'
echo ""

# 获取服务列表
echo "3. 获取服务列表..."
SERVICES=$(curl -s "$NACOS_SERVER/nacos/v1/ns/service/list?pageNo=1&pageSize=20&namespaceId=$NAMESPACE" | jq -r '.doms[]')

if [ -z "$SERVICES" ]; then
    echo "❌ 未发现任何注册的服务"
    exit 1
fi

echo "发现 $(echo "$SERVICES" | wc -l) 个注册的服务:"
echo "$SERVICES" | sed 's/^/  - /'
echo ""

# 获取每个服务的详细信息
echo "4. 服务实例详细信息..."
echo ""

for service in $SERVICES; do
    echo "=== $service ==="
    
    # 获取服务实例信息
    INSTANCE_INFO=$(curl -s "$NACOS_SERVER/nacos/v1/ns/instance/list?serviceName=$service&namespaceId=$NAMESPACE")
    
    # 解析并显示实例信息
    echo "$INSTANCE_INFO" | jq -r '
        "服务名称: " + .name,
        "服务组: " + .groupName,
        "实例数量: " + (.hosts | length | tostring),
        "健康实例: " + ([.hosts[] | select(.healthy == true)] | length | tostring),
        "实例详情:"
    '
    
    echo "$INSTANCE_INFO" | jq -r '.hosts[] | 
        "  - IP: " + .ip + 
        ":" + (.port | tostring) + 
        " | 健康: " + (if .healthy then "✅" else "❌" end) + 
        " | 权重: " + (.weight | tostring) + 
        " | 启用: " + (if .enabled then "是" else "否" end)'
    
    echo ""
done

# 获取配置信息
echo "5. 配置文件信息..."
CONFIG_LIST=$(curl -s "$NACOS_SERVER/nacos/v1/cs/configs?dataId=&group=&appName=&config_tags=&pageNo=1&pageSize=20&tenant=$NAMESPACE&search=accurate")

echo "$CONFIG_LIST" | jq -r '
    if .totalCount > 0 then
        "发现 " + (.totalCount | tostring) + " 个配置文件:",
        (.pageItems[] | "  - " + .dataId + " (组: " + .group + ")")
    else
        "❌ 未发现任何配置文件"
    end'

echo ""
echo "=== 检查完成 ==="
echo ""
echo "💡 提示:"
echo "- Nacos 控制台: $NACOS_SERVER/nacos (用户名/密码: nacos/nacos)"
echo "- 如需查看更多详情，请访问 Nacos Web 控制台"
