#!/usr/bin/env bash
# ============================================================
#  服务器初始化脚本（Ubuntu 22.04 / Debian 12）
#
#  作用：装 Docker、设时区、加 swap、建目录。
#  只跑一次，之后用 deploy.sh 启动应用。
#
#  用法：
#    scp init-server.sh root@你的服务器IP:/root/
#    ssh root@你的服务器IP "bash /root/init-server.sh"
# ============================================================
set -euo pipefail

echo "==> 1/5 系统更新"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq git curl ca-certificates tzdata

echo "==> 2/5 设置时区为 Asia/Shanghai"
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
echo "Asia/Shanghai" > /etc/timezone

echo "==> 3/5 安装 Docker（用阿里云镜像加速下载）"
if command -v docker >/dev/null 2>&1; then
  echo "    Docker 已安装，跳过"
else
  curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun
fi
systemctl enable --now docker
docker --version
docker compose version

echo "==> 4/5 创建 2G swap（2G 内存的机器跑 MySQL + 两个 Java 应用会吃紧）"
if swapon --show | grep -q '/swapfile'; then
  echo "    swap 已存在，跳过"
else
  fallocate -l 2G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=2048
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  grep -q '/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
  echo "    swap 已启用：" && swapon --show
fi

echo "==> 5/5 创建应用目录"
mkdir -p /opt/apps
echo ""
echo "============================================"
echo " 初始化完成。接下来："
echo "   1. 把两个仓库 clone 到 /opt/apps/"
echo "   2. 把 deploy/ 目录上传到 /opt/apps/deploy/"
echo "   3. cd /opt/apps/deploy && cp .env.example .env && vi .env"
echo "   4. bash deploy.sh"
echo ""
echo " 别忘了在阿里云控制台的『防火墙』里放行 80 和 443 端口。"
echo "============================================"
free -h
df -h /
