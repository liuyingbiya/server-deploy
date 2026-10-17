#!/usr/bin/env bash
# ============================================================
#  上线后的自检：容器状态 / 端口 / 应用响应 / HTTPS 证书
#
#  用法：bash smoke-test.sh
# ============================================================
set -uo pipefail
cd "$(dirname "$0")"

PASS=0
FAIL=0
ok()   { PASS=$((PASS+1)); echo "  ✓ $1"; }
bad()  { FAIL=$((FAIL+1)); echo "  ✗ $1"; }

AI_DOMAIN=$(grep -E '^AI_DOMAIN=' .env | cut -d= -f2-)
ORDER_DOMAIN=$(grep -E '^ORDER_DOMAIN=' .env | cut -d= -f2-)

echo "============================================"
echo " 部署自检"
echo "============================================"

echo ""
echo "[1] 容器状态"
for c in aiorder-mysql aiorder-ai aiorder-order aiorder-caddy; do
  state=$(docker inspect -f '{{.State.Status}}' "$c" 2>/dev/null || echo "missing")
  if [ "$state" = "running" ]; then ok "$c 运行中"; else bad "$c 状态=$state"; fi
done

echo ""
echo "[2] 端口监听"
if command -v ss >/dev/null 2>&1; then
  ss -ltnp 2>/dev/null | grep -E ':(80|443)\b' >/dev/null && ok "80/443 已监听" || bad "80/443 未监听"
fi

echo ""
echo "[3] 内部健康检查"
if docker exec aiorder-ai sh -c 'wget -qO- http://127.0.0.1:8081/api/chat/status' 2>/dev/null | grep -q 'model'; then
  ok "考研复习助手接口正常"
else
  bad "考研复习助手接口无响应"
fi
if docker exec aiorder-order sh -c 'wget -qO- http://127.0.0.1:8080/' 2>/dev/null | grep -q 'title'; then
  ok "点餐系统首页正常"
else
  bad "点餐系统首页无响应"
fi

echo ""
echo "[4] 外网访问（HTTP 会 301 跳 HTTPS）"
for d in "$AI_DOMAIN" "$ORDER_DOMAIN"; do
  code=$(curl -s -o /dev/null -w '%{http_code}' -m 15 "https://$d/" || echo "000")
  if [ "$code" = "200" ] || [ "$code" = "302" ]; then
    ok "https://$d/ -> $code"
  else
    bad "https://$d/ -> $code（证书没申请下来？域名没解析？）"
  fi
done

echo ""
echo "[5] 证书"
for d in "$AI_DOMAIN" "$ORDER_DOMAIN"; do
  end=$(echo | openssl s_client -servername "$d" -connect "$d:443" 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
  if [ -n "$end" ]; then ok "$d 证书到期：$end"; else bad "$d 取不到证书"; fi
done

echo ""
echo "============================================"
echo " 结果：$PASS 项通过，$FAIL 项失败"
echo "============================================"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
