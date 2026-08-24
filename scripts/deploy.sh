#!/usr/bin/env bash
# ============================================================
# deploy.sh — 本地触发 HK 部署（统一入口）
#
# 标准 CI/CD 流程下，推荐直接 git push 由 GitHub Actions 自动部署。
# 本脚本用于本地手动触发等价部署：SSH 到 HK 机器后，由其从 GitHub 拉取并部署。
# 代码唯一可信源 = GitHub main（不会上传本地未提交改动）。
#
# 用法:
#   ./scripts/deploy.sh                 # 部署到 hk.host.env 配置的机器
#   ./scripts/deploy.sh rollback        # 回滚到上一个镜像
#   ./scripts/deploy.sh status          # 健康检查 + 版本
#   ./scripts/deploy.sh logs            # 跟随容器日志
#
# 前置: 已配置仓库根 hk.host.env（含 HK_HOST/HK_USER/HK_PASSWORD/HK_DEPLOY_DIR/HK_PORT）
# ============================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ -f "$ROOT/hk.host.env" ]; then source "$ROOT/hk.host.env"; fi

HK_HOST="${HK_HOST:?请在 hk.host.env 配置 HK_HOST}"
HK_USER="${HK_USER:-root}"
HK_PASSWORD="${HK_PASSWORD:-}"
HK_DEPLOY_DIR="${HK_DEPLOY_DIR:-/opt/bountyapp}"
HK_PORT="${HK_PORT:-8080}"
HK_AUTH="${HK_AUTH:-password}"
HK_KEY="${HK_KEY:-}"

REMOTE="$HK_USER@$HK_HOST"
SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)
if [ "$HK_AUTH" = "key" ] && [ -n "$HK_KEY" ]; then
  SSH_OPTS=(-i "$HK_KEY" "${SSH_OPTS[@]}")
  SSH=(ssh "${SSH_OPTS[@]}")
else
  SSH=(sshpass -p "$HK_PASSWORD" ssh "${SSH_OPTS[@]}")
fi

# ---------- 回滚 ----------
if [ "${1:-}" = "rollback" ]; then
  echo "==> 回滚到上一个镜像..."
  "${SSH[@]}" "$REMOTE" "cd $HK_DEPLOY_DIR && docker tag bountyapp:prev bountyapp:latest 2>/dev/null || true && docker compose -f deploy/docker-compose.prod.yml up -d"
  exit 0
fi

# ---------- 状态 ----------
if [ "${1:-}" = "status" ]; then
  "${SSH[@]}" "$REMOTE" "cd $HK_DEPLOY_DIR && docker compose -f deploy/docker-compose.prod.yml ps && echo '--- healthz ---' && curl -fsS http://127.0.0.1:$HK_PORT/healthz || echo 'healthz FAILED'"
  exit 0
fi

# ---------- 日志 ----------
if [ "${1:-}" = "logs" ]; then
  "${SSH[@]}" "$REMOTE" "cd $HK_DEPLOY_DIR && docker compose -f deploy/docker-compose.prod.yml logs -f --tail=100 app"
  exit 0
fi

# ---------- 部署：先确认本地已 push，再让 HK 从 GitHub 拉取 ----------
DEPLOY_SHA="$(git -C "$ROOT" rev-parse HEAD)"
echo "==> 本地 HEAD: $DEPLOY_SHA"
echo "==> 确认已推送到 origin/main ..."
git -C "$ROOT" fetch origin main >/dev/null 2>&1
REMOTE_SHA="$(git -C "$ROOT" rev-parse origin/main)"
if [ "$DEPLOY_SHA" != "$REMOTE_SHA" ]; then
  echo "!! 本地 HEAD 与 origin/main 不一致，请先 'git push' 再部署。"
  echo "   本地=$DEPLOY_SHA  远端=$REMOTE_SHA"
  exit 1
fi

echo "==> 触发 HK 从 GitHub 拉取并部署..."
"${SSH[@]}" "$REMOTE" "cd $HK_DEPLOY_DIR && bash scripts/deploy-remote.sh $DEPLOY_SHA $HK_DEPLOY_DIR"
