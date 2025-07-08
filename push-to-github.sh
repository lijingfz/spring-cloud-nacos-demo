#!/bin/bash

# Spring Cloud Nacos Demo - GitHub 推送脚本
# 使用方法: ./push-to-github.sh [your-github-username] [your-personal-access-token]

echo "=== Spring Cloud Nacos Demo - GitHub 推送脚本 ==="

# 检查参数
if [ $# -ne 2 ]; then
    echo "❌ 使用方法: $0 <GitHub用户名> <Personal-Access-Token>"
    echo ""
    echo "📋 获取 Personal Access Token:"
    echo "1. 访问: https://github.com/settings/tokens"
    echo "2. 点击 'Generate new token (classic)'"
    echo "3. 选择 'repo' 权限"
    echo "4. 复制生成的 token"
    echo ""
    echo "💡 示例: $0 lijingfz ghp_xxxxxxxxxxxxxxxxxxxx"
    exit 1
fi

USERNAME=$1
TOKEN=$2

echo "📋 当前状态检查..."
echo "仓库: $(git remote get-url origin)"
echo "分支: $(git branch --show-current)"
echo "最新提交: $(git log --oneline -1)"

echo ""
echo "🔧 配置 Git 用户信息..."
git config user.name "$USERNAME"
git config user.email "$USERNAME@users.noreply.github.com"

echo ""
echo "🚀 推送到 GitHub..."
git push https://$USERNAME:$TOKEN@github.com/lijingfz/spring-cloud-nacos-demo.git main

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ 推送成功！"
    echo "🌐 查看仓库: https://github.com/lijingfz/spring-cloud-nacos-demo"
    echo ""
    echo "📋 本次更新内容:"
    echo "- 🔧 修复服务启动配置问题"
    echo "- 📚 更新完整的 README 文档"
    echo "- 📊 添加详细的测试报告"
    echo "- ✨ 新增 Feign 客户端 DTO 类"
    echo "- 🐛 解决 Nacos 配置导入问题"
else
    echo ""
    echo "❌ 推送失败！"
    echo "💡 请检查:"
    echo "1. GitHub 用户名是否正确"
    echo "2. Personal Access Token 是否有效"
    echo "3. Token 是否有 'repo' 权限"
    echo "4. 网络连接是否正常"
fi
