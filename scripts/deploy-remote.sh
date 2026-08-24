#!/usr/bin/env bash
# ============================================================
# deploy-remote.sh — HK 机器上执行的部署脚本（从 GitHub 拉取）
#
# 由 GitHub Actions CD 工作流 (cd.yml) 通过 SSH 调用，也可在机器上手动运行。
# 设计原则：
#  - 代码唯一可信源 = GitHub main（CI 已通过才会触发本脚本）
#  - .env 由机器本地维护，本脚本绝不覆盖（敏感配置安全）
#  - 重建前打 :prev 标签，部署失败可回滚
#  - 注入 GIT_SHA 编译进镜像，/healthz 可核对线上版本
#
# 用法:
#   ./scripts/deploy-remote.sh <git-sha> [deploy-dir]
# ============================================================
set -euo pipefail

GIT_SHA="${1:?用法: deploy-remote.sh <git-sha> [deploy-dir]}"
DEPLOY_DIR="${2:-/opt/bountyapp}"
COMPOSE_FILE="$DEPLOY_DIR/deploy/docker-compose.prod.yml"

echo "==> 部署目录: $DEPLOY_DIR"
echo "==> 目标 commit: $GIT_SHA"

cd "$DEPLOY_DIR"

# ---------- 1. 从 GitHub 拉取（唯一可信源）----------
echo "==> 从 GitHub 拉取最新 main..."
git fetch origin main
git reset --hard origin/main
echo "$GIT_SHA" > .deployed_sha

# ---------- 2. 确保 .env 存在（绝不覆盖，保护敏感配置）----------
if [ ! -f "$DEPLOY_DIR/.env" ]; then
  echo "==> [首次] 从 backend/.env.example 生成占位 .env ..."
  cp "$DEPLOY_DIR/backend/.env.example" "$DEPLOY_DIR/.env"
  echo "!!! 部署中止: 检测到机器上缺少 .env。"
  echo "    已生成占位文件 $DEPLOY_DIR/.env，请补全以下真实配置后再部署："
  echo "      - JWT_SECRET (强随机, 且部署后保持固定, 否则已发 token 失效)"
  echo "      - SMTP_* (真实邮箱授权码)"
  echo "      - MINIO_* / COS 等对象存储"
  echo "    补全后重新运行部署。"
  exit 1
fi
echo "==> .env 已存在，保留机器本地配置（不覆盖）。"

# ---------- 2.5 同步静态页到 nginx root（幂等，保留 /opt/bountyapp/www 之外的内容）----------
echo "==> 同步隐私/条款静态页到 /opt/bountyapp/www ..."
mkdir -p /opt/bountyapp/www
cp -f "$DEPLOY_DIR/scripts/www/privacy.html" /opt/bountyapp/www/ 2>/dev/null || true
cp -f "$DEPLOY_DIR/scripts/www/terms.html" /opt/bountyapp/www/ 2>/dev/null || true

# ---------- 3. 保留上一个镜像用于回滚 ----------
# 当前线上运行的是 bountyapp:latest（上一次部署产物），先打 :prev 备份
echo "==> 标记上一个镜像为 :prev ..."
docker tag "bountyapp:latest" "bountyapp:prev" 2>/dev/null || true

# ---------- 4. 构建并零停机重启（健康检查通过后接管）----------
echo "==> 构建并启动 (GIT_SHA=$GIT_SHA)..."
GIT_SHA="$GIT_SHA" docker compose -f "$COMPOSE_FILE" up -d --build

# ---------- 5. 健康检查（带重试，确认新版本生效）----------
echo "==> 等待服务就绪..."
for i in $(seq 1 10); do
  if curl -fsS "http://127.0.0.1:8080/healthz" >/dev/null 2>&1; then
    echo " [OK] backend up (version=$(curl -fsS http://127.0.0.1:8080/healthz | grep -o '"version":"[^"]*"'))"
    exit 0
  fi
  sleep 3
done
echo " [WARN] healthz 未通过，请查看日志: docker compose -f $COMPOSE_FILE logs app"
exit 1
