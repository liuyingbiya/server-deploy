#!/usr/bin/env bash
# ============================================================
#  试用机一键部署（无域名，用 IP + 端口访问）
#
#  在 /opt/apps/deploy 目录下执行：
#    bash deploy-ip.sh
# ============================================================
set -euo pipefail
cd "$(dirname "$0")"

if [ ! -f .env ]; then
  echo "✗ 没有 .env。先执行： cp .env.example .env && vi .env"
  exit 1
fi

echo "==> 构建并启动（首次约 5-10 分钟，Maven 要下依赖）"
docker compose -f docker-compose.ip.yml up -d --build

echo "==> 等待应用启动（MySQL 初始化 + Spring Boot 启动约 40 秒）"
sleep 40

echo "==> 容器状态"
docker compose -f docker-compose.ip.yml ps

IP=$(curl -s -m 5 ifconfig.me || echo "服务器IP")
echo ""
echo "============================================"
echo " 访问地址："
echo "   点餐系统      http://$IP:8080"
echo "   考研复习助手  http://$IP:8081"
echo ""
echo " 打不开的话："
echo "   1. 阿里云安全组要放行 8080 和 8081"
echo "   2. 看日志： docker compose -f docker-compose.ip.yml logs -f app-ai"
echo "============================================"
