# BountyApp 发布标准规范（强制）

> **核心铁律：每次生产发布必须经由 GitHub Actions CD 自动部署。禁止任何手动 `docker` / `ssh` / `deploy-remote.sh` 直推生产。**
> 本地手工部署脚本（`scripts/deploy*.sh`）仅限**验证期本地调试**使用，绝不用于把未走 CI 的代码上生产。

---

## 0. 为什么必须走 CD

- **GitHub = 唯一可信代码源**。CD 从 `origin/main` 拉取，保证"线上 = 最新已评审代码"。
- **CI 是质量门禁**。`cd.yml` 仅在 CI（vet → build → test）成功后触发，未通过的代码无法上生产。
- **可审计、可回滚**。每次部署记录 commit SHA、自动打 `:prev` 镜像、失败自动回滚。
- 手动部署会绕过上述所有保护，且容易用"未 push 的本地改动"污染生产。

---

## 1. 标准发布流程（每次必走）

```
┌─────────────────────────────────────────────────────────────┐
│ 1. 本地开发 + 自测                                            │
│    - 分支开发或直接 main，确保 `go build ./...` / `go vet` 通过 │
│    - iOS 改动需在模拟器/真机至少跑通一次相关流程                │
└───────────────────────────┬─────────────────────────────────┘
                            │ git push origin main
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. CI 自动运行 (ci.yml)                                      │
│    go vet → go build → go test -race                         │
│    ✅ success → 进入第 3 步                                   │
│    ❌ failure → 阻断，修复后重新 push                          │
└───────────────────────────┬─────────────────────────────────┘
                            │ workflow_run (success, branch=main)
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. CD 自动部署 (cd.yml)                                      │
│    SSH(HK 私钥) → deploy-remote.sh <sha>                     │
│    git reset --hard origin/main → 打 :prev → compose build   │
│    → up → 轮询 healthz                                       │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ 4. 部署后自动核对 (cd.yml verify 步骤)                       │
│    curl /healthz 的 version == 目标 commit SHA → 才算成功    │
│    不一致 → CD 标红失败，需人工介入                           │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ 5. 人工冒烟 (必须，发布负责人执行)                            │
│    - 公网 healthz 版本核对                                    │
│    - 真实邮件发送（Resend）一次                               │
│    - 关键链路手测（注册/登录/发任务/聊天/提现/IAP 沙盒）      │
│    - 见 FUNCTIONAL_TEST_CHECKLIST.md                         │
└─────────────────────────────────────────────────────────────┘
```

**流程断言**：第 3、4 步完全自动，发布负责人**不得**用 SSH 手动执行 `deploy-remote.sh` 或 `docker` 命令代替。若 CD 故障，修复流水线本身，而非改用手动部署。

---

## 2. GitHub Secrets（一次性配置，缺失则 CD 失败）

仓库 **Settings → Secrets and variables → Actions**：

| Secret | 值 | 说明 |
|--------|----|------|
| `HK_HOST` | `129.226.138.231` | HK 机器公网 IP |
| `HK_USER` | `root` | SSH 用户 |
| `HK_SSH_KEY` | `<private-key>` | SSH 私钥（**勿硬编码**，配置在 GitHub Secrets） |
| `HK_DEPLOY_DIR` | `/opt/bountyapp` | 部署目录 |
| `HK_PUBLIC_BASE_URL` | `https://api.gotseeker.com` | 公网 base，用于部署后版本核对；建议用域名（HK 证书对裸 IP 无效，verify 会回退到 -k 探测） |

> 机器上的 `.env`（含 JWT_SECRET / RESEND_API_KEY / COS 密钥等）**由机器本地维护**，CD 脚本绝不覆盖。密钥轮换只改机器 `.env` + 重启，不动代码。

---

## 3. 发布前自检清单（Push 前）

- [ ] `go build ./...` 与 `go vet ./...` 本地通过
- [ ] 新增/修改的 handler 有对应单测或已在本地手测
- [ ] 数据库迁移（如有）已就绪，SQLite → Postgres 切换只在 `.env` 改 `DB_DRIVER`
- [ ] 涉及 IAP / 隐私 / 安全（上传、URL 白名单、邮件）的改动已在本地验证
- [ ] `.env.example` 与文档同步（不提交真实密钥）
- [ ] iOS 端如需发版：App Store Connect 元数据、加密声明、隐私标签已就绪

---

## 4. 发布后核对（CD 自动 + 人工）

1. **自动**：CD 的 verify 步骤比对 `healthz.version` 与目标 SHA。
2. **人工**：
   ```bash
   curl https://129.226.138.231/healthz
   # 期望 {"status":"ok","version":"<本次 push 的 SHA>"}
   ```
3. 真实邮件冒烟（Resend）：调一次 `/api/v1/auth/send-code` 到你的 163 邮箱，确认收到。
4. 跑 `scripts/e2e-smoke.sh https://129.226.138.231`（注意：涉及真实邮件发送需 `E2E_ALLOW_REAL_EMAIL=1`，默认走 mock 保护通道）。

---

## 5. 回滚

- **自动**：CD 部署失败 → 自动 `docker tag bountyapp:prev` 回滚并重启。
- **手动（仅在 CD 完全不可用时的最后手段）**：
  ```bash
  ssh root@129.226.138.231
  cd /opt/bountyapp
  GIT_SHA=prev docker compose -f deploy/docker-compose.prod.yml up -d
  ```
  > 手动回滚后**必须**补一个修复 commit 重新走 CD，使"线上 = 最新 main"。

---

## 6. 违规处理

- 任何绕过 CD 手动上生产的操作，视为**发布事故**。
- 事后必须：① 说明原因；② 立即用 CD 重新部署最新 main 覆盖；③ 修复导致 CD 失败的 root cause（通常是 Secrets 缺失或 CI 红）。

---

## 7. 与 iOS App Store 发布的关系

CD 只负责**后端**自动部署。iOS 客户端发布是独立流程：
1. 后端先经 CD 上线（本规范）。
2. iOS 在 Xcode 本地 Archive → App Store Connect 提交（需要 IAP 沙盒真机验证通过）。
3. 两端版本在发布说明里对应记录。

详见 `DEPLOY.md`（部署架构）与 `TODO.md`（发布前代码项）。
