#!/usr/bin/env bash
# ============================================================
#  一键部署 / 更新
#
#  用法（在 /opt/apps/deploy 目录下执行）：
#    bash deploy.sh            # 首次部署或代码更新后重建
#    bash deploy.sh --logs     # 只看日志
#    bash deploy.sh --down     # 停止全部
# ============================================================
set -euo pipefail
cd "$(dirname "$0")"

if [ ! -f .env ]; then
  echo "✗ 没有 .env 文件。先执行： cp .env.example .env && vi .env"
  exit 1
fi

case "${1:-}" in
  --logs)
    docker compose logs -f --tail=100
    exit 0
    ;;
  --down)
    docker compose down
    exit 0
    ;;
esac

echo "==> 拉取最新代码"
for d in ../ai-app ../order-app; do
  if [ -d "$d/.git" ]; then
    echo "    $d"
    git -C "$d" pull --ff-only || echo "    ⚠ $d 拉取失败，用现有代码继续"
  else
    echo "    ⚠ $d 不是 git 仓库，跳过"
  fi
done

echo "==> 构建并启动（首次会比较慢，Maven 要下依赖）"
docker compose up -d --build

echo "==> 等待服务就绪"
sleep 20

echo "==> 当前状态"
docker compose ps

echo ""
echo "============================================"
echo " 访问地址（.env 里配置的域名）："
grep -E '^(AI_DOMAIN|ORDER_DOMAIN)=' .env | sed 's/^/   /'
echo ""
echo " 如果打不开："
echo "   bash deploy.sh --logs     # 看日志"
echo "   bash smoke-test.sh        # 跑自检"
echo "============================================"
