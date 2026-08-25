# BountyApp 发布流程（标准 CI/CD）

> 原则：**GitHub = 唯一可信代码源**。本地只开发并 `git push`，HK 机器始终从 GitHub 拉取部署。未 `push` 的代码不会上生产。

---

## 0. 流程总览

```
[ 本地 Mac 开发 ]
   ├─ iOS 模拟器 ── 连 http://127.0.0.1:8080
   └─ Backend go run ── 本地 8080 (sqlite + memory)

        │ git push origin main
        ▼

[ GitHub: Actions ]
   ├─ CI  : lint → vet → build → test   (质量门禁)
   └─ CD  : CI 成功后 workflow_run 触发
            → SSH 到 HK → git pull → docker compose build → up → healthz

        │ 自动部署
        ▼

[ 腾讯云 HK CVM ]
   ├─ Docker: bountyapp (Go)  ── :8080
   │     ├─ SQLite 持久化 volume (appdata)  ← 重建不丢数据
   │     └─ /healthz 返回 version=commit SHA
   └─ Redis (验证码共享)

        │ 真机
        ▼
[ iPhone ] ── https://api.gotseeker.com ──> bountyapp:8080
```

---

## 1. 本地开发期（无变化）

- 后端：`cd backend && go run ./cmd/server`，读本地 `.env`，sqlite + memory。
- iOS：模拟器连 `127.0.0.1:8080`。

---

## 2. CI（push 即跑，失败阻断部署）

`.github/workflows/ci.yml` 在每次 push/PR 到 main 时：
1. `go vet ./...`
2. `CGO_ENABLED=1 go build`
3. `go test ./... -race`

任一失败 → CD 不会被触发，保护生产。

---

## 3. CD（CI 通过后自动部署到 HK）

`.github/workflows/cd.yml` 由 CI `workflow_run` 触发（仅 `conclusion == success`）：

1. SSH 到 HK（`secrets.HK_*`）。
2. 机器上执行 `scripts/deploy-remote.sh <sha>`：
   - `git fetch origin main && git reset --hard origin/main`（唯一可信源）
   - 确认 `.env` 存在（**绝不覆盖**机器本地敏感配置）
   - 打上一个镜像 `:prev` 标签
   - `docker compose -f deploy/docker-compose.prod.yml up -d --build`，注入 `GIT_SHA`
   - 轮询 `healthz` 直到新版本生效
3. 若部署失败 → 自动 `docker tag bountyapp:prev` 回滚。

### 3.1 GitHub Secrets 配置（一次性）

在仓库 **Settings → Secrets → Actions** 添加：

| Secret | 说明 |
|--------|------|
| `HK_HOST` | HK 机器 IP / 域名（如 `129.226.138.231`） |
| `HK_USER` | SSH 用户（如 `root`） |
| `HK_SSH_KEY` | SSH 私钥（CD 使用密钥登录，已在 Secrets 中配置） |
| `HK_DEPLOY_DIR` | 机器部署目录（如 `/opt/bountyapp`） |
| `HK_PUBLIC_BASE_URL` | 公网 base（如 `https://129.226.138.231`），用于部署后版本核对 |

> CD 当前使用**密钥登录**（`key: secrets.HK_SSH_KEY`）。手动调试仍可用密码（`root/Beijing@010`），但生产发布严禁手动 SSH。

> 不要把 `hk.host.env`（含 root 密码）提交进 git，它已被 `.gitignore` 忽略。CI 用 Secrets 注入，本地手动部署用 `hk.host.env`。

### 3.2 HK 机器首次准备（一次性）

```bash
# 在 HK 机器
git clone <repo> /opt/bountyapp
cd /opt/bountyapp
# 复制真实 .env（切勿用占位符启动）
cp backend/.env.example .env && vi .env   # 补全 JWT_SECRET / SMTP_* / MINIO_*
# 安装 docker + compose
```

> `JWT_SECRET` 务必固定且强随机，否则重启后已发 token 全部失效。

---

## 4. 本地手动部署（等价 CD）

标准流程是自动的；如需手动触发（等价行为，仍从 GitHub 拉取）：

```bash
./scripts/deploy.sh                 # 先 git push，再触发 HK 拉取部署
./scripts/deploy.sh status          # 查看容器 + 版本
./scripts/deploy.sh logs            # 跟随日志
./scripts/deploy.sh rollback        # 回滚到 :prev
```

> 手动部署前会校验本地 HEAD == origin/main，拒绝用未推送的改动上生产。

---

## 5. 部署后验证（e2e 冒烟）

```bash
./scripts/e2e-smoke.sh http://127.0.0.1:8080        # 针对 HK 本机
./scripts/e2e-smoke.sh https://api.gotseeker.com    # 针对公网域名
```

测试数据使用 `e2e_smoke_` 前缀，清理仅删该前缀，不伤真实/demo 数据。

---

## 6. 版本核对

任何时候核对线上跑的是哪个 commit：

```bash
curl https://api.gotseeker.com/healthz
# {"status":"ok","driver":"sqlite","version":"<git-sha>"}
```

与 GitHub 最新 main SHA 比对即可确认“线上 = 最新代码”。

---

## 7. 回滚

- **自动**：CD 部署失败自动回滚到 `:prev`。
- **手动**：`./scripts/deploy.sh rollback`，或机器上
  `docker tag bountyapp:prev bountyapp:latest && docker compose -f deploy/docker-compose.prod.yml up -d`。

> 镜像按 `GIT_SHA` 不可变标记，可跨多次回退到任意历史版本（保留历史镜像即可）。

---

## 8. 正式期升级（流量起来后）

| 项 | 验证期 | 正式期 |
|----|--------|--------|
| 数据库 | SQLite（volume 持久化） | 腾讯云 PostgreSQL（`DB_DRIVER=postgres`，改 `.env` 即可，无需改 compose） |
| 缓存 | Redis（容器内） | 腾讯云 Redis |
| 对象存储 | 本地 volume | 腾讯云 COS（开 CDN） |
| 多实例 | 单容器 | 多容器 + Redis 共享 session（compose 已预留） |
| 监控 | healthz | 云监控 + 日志服务 |
