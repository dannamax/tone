# BountyApp 云上发布流程

> 目标：本地开发完成后，一条命令把后端同步发布到云主机，真机 App 通过公网域名连通，跑通真实互联网场景验证。

---

## 0. 整体架构

```
[ 你的 Mac 本地开发 ]
   ├─ iOS (Xcode 模拟器) ── 连 http://127.0.0.1:8080
   └─ Backend (go run)   ── 本地 8080，sqlite + memory

            │  git push 后执行 ./scripts/deploy.sh
            ▼

[ 腾讯云 CVM 云主机 (公网 IP) ]
   ├─ Caddy (HTTPS :443) ── 自动 Let's Encrypt 证书
   └─ Docker: bountyapp (Go) ── :8080
        ├─ SQLite 文件 (验证期) / 云 PostgreSQL (正式期)
        ├─ COS (对象存储，替代 MinIO)
        └─ 163 SMTP (发码)

            │ 真机 TestFlight / Ad Hoc
            ▼

[ iPhone 真机 ] ── https://api.gotseeker.com ──> Caddy ──> bountyapp:8080
```

关键点：
- **模拟器始终连本机**（`APIClient.swift` 中 `#if targetEnvironment(simulator)`）。
- **上架构建连公网 HTTPS**：`productionBaseHost = "https://api.gotseeker.com"`（由 Info.plist 的 `BackendBaseHost` 注入，可改不重编译）。
- iOS 端只需在 `PRODUCTION` 编译宏下打包，无需改代码逻辑。

---

## 1. 本地开发期（现状，无需改动）

- 后端：`cd backend && go run ./cmd/server`，读本地 `.env`，sqlite + memory。
- iOS：模拟器直接跑，连 `127.0.0.1:8080`。
- 验证：`scripts/e2e.sh` / XCUITest 全功能测试。

---

## 2. 云端发布（每次开发完同步）

### 2.1 前置（一次性）
- 云主机已就绪（见 `TENCENT_CLOUD_SETUP.md`），已拿到公网 IP。
- 域名 `api.gotseeker.com` 已 A 记录解析到该 IP，且已完成 ICP 备案。
- 本机能 SSH 到云主机（`ssh root@<公网IP>`）。
- 云主机已安装 Docker + Docker Compose + Caddy（脚本会自动装 Caddy）。

### 2.2 配置云主机环境变量
在云主机创建 `/opt/bountyapp/.env`（内容与本地类似，但：
- `EMAIL_PROVIDER=smtp` + 真实 163 配置
- `DB_DRIVER=sqlite`（验证期）
- `CODE_STORE=memory`
- `MINIO_ENDPOINT/ACCESS_KEY/SECRET_KEY` → 改为腾讯云 COS 的 S3 兼容参数
- `JWT_SECRET` → 改成强随机值（**务必改，否则有安全风险**）
- `SERVER_PORT=8080`

### 2.3 本地执行发布
```bash
# 在仓库根目录
./scripts/deploy.sh root@<公网IP>
```
脚本会做：
1. `git archive` 打包后端代码传到云主机 `/opt/bountyapp`。
2. 云主机 `docker compose build && docker compose up -d` 重建容器。
3. 触发 Caddy 自动申请/续期 Let's Encrypt 证书。
4. 健康检查 `https://api.gotseeker.com/healthz`。

### 2.4 真机验证
- Xcode 用 `PRODUCTION` 宏打包（或 TestFlight 外部测试）。
- 真机打开 App → 注册/登录 → 发布任务 → 收验证码（真实 163 邮件）→ 全流程。
- 中英文切换验证（i18n 已就绪）。

### 2.5 Apple 开发者账号与 App ID 注册（上架前必须）

> Personal Team（免费账号）只能真机调试，**不能**上架 App Store 或发 TestFlight。
> 要发布必须加入 Apple Developer Program（99 美元/年）。

1. **加入开发者计划**
   - 登录 https://developer.apple.com/programs/ 用 Apple ID 订阅（个人/企业）。
   - 企业账号（$299/年）适合内部分发，个人/组织（$99/年）可上 App Store。

2. **在后台注册 App ID（Identifiers）**
   - 进入 Certificates, Identifiers & Profiles → Identifiers → `+` → App IDs。
   - 选 **App**，Bundle ID 选 **Explicit**，填 `com.gotseeker.app`（必须与 Xcode 的 `PRODUCT_BUNDLE_IDENTIFIER` 完全一致）。
   - Capabilities 勾选用到的：Push Notifications（若上推送）、Sign in with Apple（若接入）、Associated Domains（若用 Universal Link）。
   - 若用微信/支付宝等第三方登录 SDK，还需在其开放平台登记同一 Bundle ID。

3. **创建签名证书与 Provisioning Profile**
   - Certificates → `+` → Apple Distribution（发布用）。
   - Profiles → `+` → App Store → 选上面 App ID → 选证书 → 生成并下载 `GotSeeker_AppStore.mobileprovision`。
   - Xcode 登录该开发者账号后，General → Signing 选 Team = 你的组织，Provisioning Profile 选刚生成的。

4. **Xcode 工程侧确认**
   - Bundle ID：`com.gotseeker.app`（已统一改好，见前文）。
   - 若之前用 Personal Team 报错 "not available"，换成付费 Team 后此 ID 即可正常注册。
   - 真机调试也可在付费账号下用 Development Profile，无 7 天过期限制。

5. **上架资料（提交审核前准备）**
   - 隐私政策页：`https://gotseeker.com/privacy`（已改为 Info.plist 注入，需真实可访问）。
   - 条款页：`https://gotseeker.com/terms`。
   - 截图、描述、分级问卷、加密合规声明（用到 HTTPS/网络传输需回答）。

---

## 3. 回滚
```bash
ssh root@<公网IP> "cd /opt/bountyapp && docker compose down && docker compose up -d"
```
（deploy.sh 会保留上一个镜像 tag 用于回滚，详见脚本内注释。）

---

## 4. 正式期升级（流量起来后）
| 项 | 验证期 | 正式期 |
|----|--------|--------|
| 数据库 | SQLite 文件 | 腾讯云 PostgreSQL（自动备份） |
| 缓存 | memory | Redis（腾讯云 Redis） |
| 对象存储 | COS | COS（同，开 CDN） |
| 多实例 | 单容器 | 多容器 + Redis 共享 session |
| 监控 | 无 | 云监控 + 日志服务 |
