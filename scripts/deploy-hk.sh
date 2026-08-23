#!/usr/bin/env bash
# ============================================================
# deploy-hk.sh — 部署 BountyApp 后端到香港云主机 (免备案)
#
# 读取仓库根目录的 hk.host.env 获取主机信息（密码/密钥登录均支持）。
# 用法:
#   ./scripts/deploy-hk.sh            # 构建并发布（保留上一个镜像用于回滚）
#   ./scripts/deploy-hk.sh rollback   # 回滚到上一个镜像
#   ./scripts/deploy-hk.sh logs       # 跟随查看容器日志
#   ./scripts/deploy-hk.sh status     # 健康检查 + 容器状态
#
# 前置:
#   - 本地已安装 docker（仅用于本地交叉构建可省略，本脚本走云端 build）
#   - 密码登录需要 sshpass:  brew install hpass (macOS) / apt-get install sshpass
#   - 云主机安全组已放行 22/80/443/8080
# ============================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/hk.host.env"

REMOTE="$HK_USER@$HK_HOST"
SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)
if [ "$HK_AUTH" = "key" ] && [ -n "$HK_KEY" ]; then
  SSH_OPTS=(-i "$HK_KEY" "${SSH_OPTS[@]}")
  SSH=(ssh "${SSH_OPTS[@]}")
  SCP=(scp "${SSH_OPTS[@]}")
else
  SSH=(sshpass -p "$HK_PASSWORD" ssh "${SSH_OPTS[@]}")
  SCP=(sshpass -p "$HK_PASSWORD" scp "${SSH_OPTS[@]}")
fi

BACKEND_DIR="$ROOT/backend"
ARCHIVE="/tmp/bountyapp-src.tgz"

echo "==> 目标主机: $REMOTE  部署目录: $HK_DEPLOY_DIR"

# ---------- 回滚 ----------
if [ "${1:-}" = "rollback" ]; then
  echo "==> 回滚到上一个镜像 $HK_IMAGE:prev"
  ${SSH[@]} "$REMOTE" "cd $HK_DEPLOY_DIR && docker tag $HK_IMAGE:prev $HK_IMAGE 2>/dev/null || true && docker compose up -d app && docker compose ps"
  exit 0
fi

# ---------- 查看日志 ----------
if [ "${1:-}" = "logs" ]; then
  ${SSH[@]} "$REMOTE" "cd $HK_DEPLOY_DIR && docker compose logs -f --tail=100 app"
  exit 0
fi

# ---------- 状态检查 ----------
if [ "${1:-}" = "status" ]; then
  ${SSH[@]} "$REMOTE" "cd $HK_DEPLOY_DIR && docker compose ps && echo '--- healthz ---' && curl -fsS http://127.0.0.1:$HK_PORT/healthz || echo 'healthz FAILED'"
  exit 0
fi

# ---------- 打包后端源码（使用工作区，包含未提交改动） ----------
echo "==> 打包后端源码..."
# git archive HEAD 只包含已提交文件，会漏掉当前开发中的未提交改动；
# 因此直接从仓库根目录打包 backend/ 目录（含未提交改动），与 compose build: ./backend 对齐。
cd "$ROOT" && tar --exclude='backend/.git' --exclude='backend/uploads' -czf "$ARCHIVE" backend

# ---------- 远程准备目录 ----------
echo "==> 准备远程目录..."
${SSH[@]} "$REMOTE" "mkdir -p $HK_DEPLOY_DIR/uploads $HK_DEPLOY_DIR/certs"

# ---------- 上传源码 ----------
echo "==> 上传源码包..."
${SCP[@]} "$ARCHIVE" "$REMOTE:$HK_DEPLOY_DIR/src.tgz"
${SSH[@]} "$REMOTE" "cd $HK_DEPLOY_DIR && rm -rf backend && tar -xzf src.tgz && rm -f src.tgz"

# ---------- 生成云端 .env ----------
# 重要: 优先使用本地 backend/.env(含真实 SMTP 授权码等敏感配置, 已被 .gitignore 忽略),
# 避免每次部署用占位符 .env.example 覆盖掉已配置的真实凭据(曾导致反复需重填邮箱/授权码)。
# 本地 .env 不存在时回退到 .env.example 占位符。
echo "==> 写入云端 .env (使用本地 backend/.env 真实配置)..."
${SSH[@]} "$REMOTE" "cat > $HK_DEPLOY_DIR/.env <<'EOF'
# 自动生成 by deploy-hk.sh @ $(date -u +%Y-%m-%dT%H:%M:%SZ)
$(grep -vE '^\s*#|^\s*$' "$BACKEND_DIR/.env" 2>/dev/null || grep -vE '^\s*#|^\s*$' "$BACKEND_DIR/.env.example" 2>/dev/null || true)
# ---- HK 覆盖项 (最后写入, 确保生效) ----
SERVER_PORT=$HK_PORT
CODE_STORE=$HK_CODE_STORE
REDIS_ADDR=redis:6379
JWT_SECRET=$(openssl rand -hex 32)
DOMAIN=$HK_HOST
PORT=443
EMAIL_PORT=465
# 对象存储用本地盘（验证期）
UPLOAD_DIR=./uploads
PUBLIC_BASE=$HK_PUBLIC_BASE
EOF"

# ---------- 生成 docker-compose.yml（云端 build）----------
echo "==> 写入云端 docker-compose.yml..."
# 注意：不要把 ./seekerdb.sqlite 作为宿主机卷挂载。若该路径在宿主机是目录，
# 容器启动会报 "unable to open database file: is a directory" 并崩溃循环。
# 改为让容器在 /app 内直接创建数据库文件（已持久化在镜像层/容器可写层）。
${SSH[@]} "$REMOTE" "cat > $HK_DEPLOY_DIR/docker-compose.yml <<'EOF'
services:
  redis:
    image: redis:7-alpine
    container_name: ${HK_CONTAINER}-redis
    restart: unless-stopped
    command: redis-server --appendonly yes
    volumes:
      - redisdata:/data
    healthcheck:
      test: [\"CMD\", \"redis-cli\", \"ping\"]
      interval: 5s
      timeout: 3s
      retries: 5

  app:
    build: ./backend
    image: $HK_IMAGE
    container_name: $HK_CONTAINER
    restart: unless-stopped
    env_file: ./.env
    ports:
      - \"$HK_PORT:$HK_PORT\"
    volumes:
      - ./uploads:/app/uploads
    depends_on:
      - redis
volumes:
  redisdata:
EOF"

# ---------- 自签证书（供 Caddy/HTTPS 直连 IP 用，可选）----------
# 若只用 http://IP:8080 调试可跳过；真机 HTTPS 需要证书
echo "==> 生成自签证书 (用于 https://$HK_HOST)..."
${SSH[@]} "$REMOTE" "openssl req -x509 -newkey rsa:2048 -nodes -keyout $HK_DEPLOY_DIR/certs/key.pem -out $HK_DEPLOY_DIR/certs/cert.pem -days 365 -subj \"/CN=$HK_HOST\" 2>/dev/null || true"

# ---------- 云端构建并启动 ----------
echo "==> 云端 docker compose build & up..."
${SSH[@]} "$REMOTE" "cd $HK_DEPLOY_DIR && docker tag $HK_IMAGE $HK_IMAGE:prev 2>/dev/null || true && docker compose build app && docker compose up -d --force-recreate app"

# ---------- 健康检查 ----------
echo "==> 等待服务就绪..."
sleep 5
${SSH[@]} "$REMOTE" "curl -fsS http://127.0.0.1:$HK_PORT/healthz && echo ' [OK] backend up' || echo ' [WARN] healthz 未通过，请查看日志: ./scripts/deploy-hk.sh logs'"

echo ""
echo "==> 部署完成。"
echo "    后端地址(公网): $HK_PUBLIC_BASE"
echo "    健康检查:       http://$HK_HOST:$HK_PORT/healthz"
echo "    查看日志:       ./scripts/deploy-hk.sh logs"
echo "    回滚:           ./scripts/deploy-hk.sh rollback"
echo ""
echo "==> iOS 端: 把 Info.plist 的 BackendBaseHost 设为 $HK_PUBLIC_BASE"
echo "    (若用 IP+自签证书，真机需关闭 ATS 严格校验或信任自签 CA)"
