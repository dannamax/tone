# BountyApp 待办清单 (TODO)

> 维护说明：本文件记录已知架构问题、发布前阻断项、以及后续优化项。
> 优先级：P0=发布阻断 / P1=发布后紧接 / P2=优化。

---

## 🔴 P0 — 发布前阻断项（须解决才能上 App Store）

无（核心功能链路已验证可用，详见下方「发布就绪核对」）。

---

## 🟡 P1 — 已知架构问题（已分析，发布后可择机修复）

### P1.1 文件上传存储于 HK 机器本地盘（非对象存储）
- **现状**：`POST /api/v1/upload` 把文件写入容器 `/app/uploads`（bind mount 到 HK 宿主机 `/opt/bountyapp/uploads`），返回相对 URL `/uploads/xxx.jpg`。`config.go` 的 `MinIOConfig` 未被使用。
- **风险**：
  1. 磁盘空间上限（系统盘 50–100GB，图片堆积无清理 → 写满后上传失败、连带 SQLite 异常）。
  2. 容器/机器重建时本地盘图片有丢失风险（SQLite 已用 volume，uploads 仍是 bind mount，不一致）。
  3. 无 CDN，图片经后端回源，真机加载慢、占带宽。
  4. 返回相对 URL，换域名/CDN 时前端拼接要改。
  5. 无 MIME/大小校验，有恶意上传风险。
  6. 多实例水平扩展时本地盘图片不共享。
- **方案**：接入腾讯云 COS（或兼容 S3 的 MinIO）。`internal/service/storage.go` 提供统一接口（cos/minio/local 三后端），upload handler 改为传 COS 并返回绝对 URL；compose 去掉 `./uploads` bind mount；`.env.example` / DEPLOY.md 补充 COS 配置。
- **状态**：✅ 已完成并验证（2026-08-24）。
  - 新增 `internal/storage` 抽象层：`Storage` 接口 + `LocalStorage`(开发/CI) + `COSStorage`(生产)，引入 `github.com/tencentyun/cos-go-sdk-v5 v0.7.75`。
  - `config.go` 的 `MinIOConfig` 替换为 `StorageConfig`（`STORAGE_BACKEND` 开关 + `COS_SECRET_ID/KEY/BUCKET/REGION`）。
  - upload handler 改用 Storage 接口，返回完整 COS 公网 URL（对象级 `public-read`，桶保持私有）。
  - HK `.env` 已配置 `STORAGE_BACKEND=cos` + COS 凭据（不提交 git）。
  - 端到端验证：上传 1x1 PNG → 返回 `https://seekerhub-1301056533.cos.ap-hongkong.myqcloud.com/...png` → 公网 `curl` 返回 200。
  - iOS `buildImageURL` 已兼容完整 http(s) URL，无需改动。
  - ⚠️ **历史数据迁移提示**：迁移前已上传到 HK 本地 `/uploads/` 的旧图片，其 URL 为相对路径 `/uploads/xxx.jpg`，在 COS 模式下这些旧图片已无法访问（前端会拼成 `https://api.gotseeker.com/uploads/...` 但后端不再提供该静态路由对应的旧文件）。当前为早期发布阶段、历史图片量极少，影响可忽略；若需保留旧图，可脚本批量迁移至 COS。

### P1.2 上传接口缺 MIME/大小校验
- 依赖 `PhotoUpload` model 限制（证据图 `max=3`），但 `/upload` 接口本身不限类型/大小。
- **方案**：加 `image/*` 白名单 + 单文件大小上限（如 5MB）。

---

## 🟢 P2 — 后续优化项

- P2.1 上传走前端 STS 直传 COS，后端只签发临时凭证（降带宽压力）。
- P2.2 COS 图片处理生成缩略图，提升真机加载。
- P2.3 WebSocket 推送稳定性与重连策略压测。
- P2.4 配额购买（Apple IAP）端到端沙盒验证。
- P2.5 SQLite → 腾讯云 PostgreSQL（正式期，compose 已预留 `DB_DRIVER` 切换）。
- P2.6 监控/日志接入云监控。

---

## ✅ 发布就绪核对（核心功能可用）

后端 API 全链路已通过 e2e 冒烟 + 自测清单覆盖，下列核心能力可用：

| 模块 | 状态 | 说明 |
|------|------|------|
| 认证（发码/登录/注册） | ✅ | redis 存码 + JWT |
| 任务发布（校验/冻结） | ✅ | 位置、金额、枚举校验齐全 |
| 广场（半径过滤） | ✅ | Haversine 距离 |
| 认领/提交/确认 | ✅ | 确认含余额不足拦截 |
| 取消/放弃/争议/退款 | ✅ | 状态机完整 |
| 钱包（余额/累计/充值/提现/交易） | ✅ | 累计字段已修复 |
| 发布配额（套餐/下单/Apple 校验） | ✅ | IAP 接口齐，待沙盒验证 |
| 消息协作 | ✅ | |
| 通知（列表/已读） | ✅ | |
| 配置（汇率/邮箱域名） | ✅ | |
| 健康检查 + 版本核对 | ✅ | `/healthz` 返回 version |
| CI/CD 自动部署 | ✅ | push → CI → CD(HK) |

**发布前仍建议人工核对（iOS 端）**：
- [x] App Store 隐私清单（PrivacyInfo.xcprivacy）齐备 ✅ 已核对（2026-08-24）：覆盖 NSLocation/NSCamera/NSUserDefaults/NSFileManager 访问 API + Email/Phone/Location/UserContent/Photos/DeviceID 数据类型，Tracking=false；图片用 PHPicker 不触发额外声明；无第三方 SDK 需补充。仅需确认 UserDefaults 是否用 App Group（否则用 CA92.1 正确）
- [x] 隐私政策/服务条款页面可公网访问（已修复：HK `/opt/bountyapp/www` 缺失 + caddy 自签证书缺失导致 nginx reload 失败；2026-08-24 已部署并验证 `https://gotseeker.com/privacy` `/terms` 均 200）
- [x] Apple 登录/邮箱登录合规（✅ 已核对：App 仅用自建邮箱验证码登录，无第三方 SSO，依 Apple Guideline 4.8/5.1.1 不强制提供 Sign in with Apple；GDPR 同意流 `PrivacyConsentView` 已存在，首次启动弹窗且 `interactiveDismissDisabled`；2026-08-24 修复：① 同意页内的隐私/条款链接由占位 `WebViewPlaceholder` 改为真实 `WKWebView` 加载 `gotseeker.com` 页面；② 拒绝时由 `exit(0)` 改为停留同意页并提示「必须接受才能继续使用」，避免被审质疑强制退出）
- [x] 真机 HTTPS 连通（✅ 已核对：Info.plist `BackendBaseHost = https://api.gotseeker.com`（域名+有效 Let's Encrypt 证书，此前 e2e 验证 200）；`PrivacyPolicyURL`/`TermsOfServiceURL` 指向 `gotseeker.com`；无 ATS 例外、不依赖 IP 自签证书，全部标准 HTTPS）
- [~] IAP 沙盒购买回归（✅ 后端已打通 StoreKit 2 JWS 本地验签：新增 `pkg/appleiap/jws.go` 用 Apple Root CA - G3 校验证书链 + ECDSA 验签 + productId 匹配 + 防篡改/防重放，5 个单元测试全过；iOS `StoreKitManager` 改为发送 `transaction.jwsRepresentation`；legacy `verify.go`（receipt_data）作为回退保留。仍需在真机用沙盒账号实际购买一次做端到端回归——此项为人工真机测试，非静态核对可完成，建议在提审前用 TestFlight 沙盒账号验证）
