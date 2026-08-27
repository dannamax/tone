#!/bin/bash
# 启动本地开发后端（供 iOS 模拟器使用）
# 用法: ./scripts/dev-server.sh
# 模拟器的 baseHost 硬编码为 http://127.0.0.1:8080，
# 所以模拟器测试前必须先跑本脚本。Ctrl+C 停止。
set -e
cd "$(dirname "$0")/../backend"

echo "[dev] 构建最新后端..."
go build -o /tmp/seeker-dev-server ./cmd/server

echo "[dev] 清理旧进程..."
lsof -ti :8080 | xargs kill -9 2>/dev/null || true
sleep 1

echo "[dev] 启动 http://127.0.0.1:8080 （模拟器专用）"
echo "[dev] 验证码查看: grep 'code=' /tmp/seeker-dev.log | tail -1"
CODE_STORE=memory SERVER_PORT=8080 DB_NAME=/tmp/seeker_dev.db \
  /tmp/seeker-dev-server 2>&1 | tee /tmp/seeker-dev.log
