#!/usr/bin/env bash
#
# BountyApp 一键发布脚本
# 用法: ./scripts/deploy.sh root@<公网IP>
#
# 前置:
#   - 本机可 ssh 到目标主机（密钥或密码）
#   - 目标主机已安装 docker / docker-compose / caddy
#   - 目标主机 /opt/bountyapp/.env 已配置好（含真实 SMTP/COS/JWT_SECRET）
#
set -euo pipefail

REMOTE="${1:?用法: deploy.sh root@<公网IP>}"
REMOTE_DIR="/opt/bountyapp"
LOCAL_BACKEND="$(cd "$(dirname "$0")/.." && pwd)/backend"

echo "==> [1/4] 打包后端代码"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
git -C "$(cd "$(dirname "$0")/.." && pwd)" archive --format=tar.gz HEAD:backend -o "$TMP/backend.tar.gz" \
  || tar --exclude='._*' --exclude='.DS_Store' -czf "$TMP/backend.tar.gz" -C "$(cd "$(dirname "$0")/.." && pwd)" backend

echo "==> [2/4] 上传到 $REMOTE:$REMOTE_DIR"
ssh "$REMOTE" "mkdir -p $REMOTE_DIR"
scp "$TMP/backend.tar.gz" "$REMOTE:$REMOTE_DIR/backend.tar.gz"
# 注意: 不覆盖 .env (保留云主机上的真实配置)
# 解包时排除 macOS AppleDouble (._*) 并清理残留, 避免被当成迁移 SQL 执行
ssh "$REMOTE" "cd $REMOTE_DIR && tar --exclude='._*' -xzf backend.tar.gz && rm -f backend.tar.gz ._*.sqlite* ._*.db && find . -name '._*' -delete && ls"

echo "==> [3/4] 远端重建容器 (保留上一个镜像用于回滚)"
ssh "$REMOTE" "cd $REMOTE_DIR && \
  docker tag bountyapp-app:latest bountyapp-app:prev 2>/dev/null || true && \
  docker compose -f docker-compose.cloud.yml build && \
  docker compose -f docker-compose.cloud.yml up -d"

echo "==> [4/4] 健康检查"
sleep 5
ssh "$REMOTE" "curl -fsS http://127.0.0.1:8080/healthz && echo ' [local ok]' || echo ' [local FAIL]'"

echo "==> 完成。真机请访问 https://api.gotseeker.com (Caddy 自动 HTTPS)"
echo "==> 回滚: ssh $REMOTE 'cd $REMOTE_DIR && docker tag bountyapp-app:prev bountyapp-app:latest && docker compose -f docker-compose.cloud.yml up -d'"
