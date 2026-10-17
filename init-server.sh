#!/usr/bin/env bash
# ============================================================
#  服务器初始化脚本（Ubuntu 22.04 / Debian 12）
#
#  作用：装 Docker、设时区、加 swap、建目录、配镜像加速。
#  只跑一次，之后用 deploy.sh 启动应用。
#
#  用法：
#    bash init-server.sh                                  # 默认（用公共加速镜像）
#    bash init-server.sh https://你的ID.mirror.aliyuncs.com  # 指定阿里云加速器
#
#  ★ 为什么必须配加速器：
#    服务器在国内，直连 Docker Hub 拉 MySQL/JDK 镜像经常几 KB/s 甚至超时。
#    配了镜像加速器之后通常几分钟就能拉完。
#    阿里云用户在「容器镜像服务 → 镜像工具 → 镜像加速器」里能拿到专属地址。
# ============================================================
set -euo pipefail

MIRROR="${1:-https://docker.m.daocloud.io}"

echo "==> 1/6 系统更新"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq git curl ca-certificates tzdata

echo "==> 2/6 设置时区为 Asia/Shanghai"
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
echo "Asia/Shanghai" > /etc/timezone

echo "==> 3/6 安装 Docker（用阿里云镜像下载安装包）"
if command -v docker >/dev/null 2>&1; then
  echo "    Docker 已安装，跳过"
else
  curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun
fi
systemctl enable --now docker
docker --version

echo "==> 4/6 配置镜像加速器: $MIRROR"
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<EOF
{
  "registry-mirrors": ["$MIRROR", "https://docker.1ms.run", "https://dockerproxy.net"],
  "log-driver": "json-file",
  "log-opts": { "max-size": "20m", "max-file": "3" }
}
EOF
systemctl restart docker
sleep 3
docker compose version || {
  echo "    未自带 compose 插件，正在安装…"
  apt-get install -y -qq docker-compose-plugin || true
  docker compose version
}

echo "==> 5/6 创建 2G swap（2G/4G 内存跑 MySQL + 两个 Java 应用会吃紧）"
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

echo "==> 6/6 创建应用目录"
mkdir -p /opt/apps

echo ""
echo "============================================"
echo " 初始化完成"
echo ""
echo " 下一步（假设代码已 clone 到 /opt/apps）："
echo "   cd /opt/apps/deploy"
echo "   cp .env.example .env && vi .env"
echo "   bash deploy-ip.sh        # 试用机（IP + 端口，无域名）"
echo "   bash deploy.sh           # 正式机（域名 + HTTPS）"
echo ""
echo " 别忘了在阿里云『安全组』里放行对应端口。"
echo "============================================"
free -h
df -h /
