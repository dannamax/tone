# BountyApp 待办清单 (TODO)

> 维护说明：本文件记录已知架构问题、发布前阻断项、以及后续优化项。
> 优先级：P0=发布阻断 / P1=发布后紧接 / P2=优化。

---

## 🔴 P0 — 发布前阻断项（须解决才能提审 App Store）

### P0.1 IAP 沙盒真机端到端验证
- **现状**：后端 StoreKit 2 JWS 本地验签已完成（Apple Root CA - G3 证书链 + ECDSA 验签 + productId 匹配 + 防重放，5 个单测全过）；iOS 发送 `transaction.jwsRepresentation`；ASC 三 SKU（pkg_usd_2/5/10）已配置为"可供审核"。
- **缺口**：**从未在真机 + 沙盒账号完成一次实际购买闭环**（购买 → JWS 提交 → 验签 → 豆子到账 → 钱包余额更新）。
- **步骤**：真机装 Release 构建 → 设置登录沙盒账号（Settings → App Store → Sandbox Account）→ 钱包购买 $1.99/10豆 → 确认余额 +10 → 重复购买确认幂等 → 退款路径（沙盒可选）。
- **这是唯一拦提审的代码侧事项**（人工真机操作，约 15 分钟）。

### P0.2 App Store Connect 提审材料
- [ ] **截图**：6.7"（iPhone 17 Pro Max 等）+ 6.5" 两组；`scripts/generate_review_screenshot.py` 可生成占位图，建议用真机/模拟器截真实界面（广场、发布、钱包、任务详情）
- [ ] **版本页**：1.0 — 描述文案（PRD 1.1/1.2 可提炼）、关键词、推广文本、支持 URL（support@gotseeker.com 或 gotseeker.com）
- [ ] **App 隐私标签**：Data Collection 问卷（对照 PrivacyInfo.xcprivacy：位置/照片/邮箱/设备 ID，不追踪）
- [ ] **年龄分级**：问卷（任务交易类，预期 12+/17+）
- [ ] **价格与地区**：免费 + 排除中国大陆/香港/台湾，其余全开
- [ ] **出口合规**：Info.plist 已设 `ITSAppUsesNonExemptEncryption=false` ✅（ASC 问卷同步选"仅 HTTPS"）

---

## 🟡 P1 — 已知架构问题（已分析，发布后可择机修复）

### P1.1 文件上传存储于 HK 机器本地盘（非对象存储）
- **状态**：✅ 已完成并验证（2026-08-24，COS 上线，对象级 public-read + 完整 URL）。

### P1.2 上传接口缺 MIME/大小校验
- **状态**：✅ 已完成并验证（2026-08-26 核对代码）：5MB 上限 + PNG/JPEG/GIF/WebP 魔数嗅探白名单 + 强制 `image/*` Content-Type + Content-Disposition + 禁路径穿越。

---

## 🟢 P2 — 后续优化项

- P2.1 上传走前端 STS 直传 COS，后端只签发临时凭证（降带宽压力）。
- P2.2 COS 图片处理生成缩略图，提升真机加载。
- P2.3 WebSocket 推送稳定性与重连策略压测。
- P2.5 SQLite → 腾讯云 PostgreSQL（正式期，compose 已预留 `DB_DRIVER` 切换）。
- P2.6 监控/日志接入云监控；CD 失败告警（2026-08-26 曾发生 CD SSH 会话中断导致容器被 down 未 up，人工恢复；建议加部署失败重试/告警）。
- P2.7 **App Store 服务器通知（ASN V2）**：后端新增 `POST /api/v1/apple/webhook`（Apple Root CA 校验 signedPayload），ASC 配置生产/沙盒通知 URL。首提审核可暂时不填，上线后建议补——**退款感知是金豆经济的财务完整性依赖**。
- P2.8 奖励中心 V2 兑换实现（触发条件：累计 IAP 收入 ≥ $1K 且月活猎人 ≥ 300）：redeem 流水类型 + 兑换订单表 + 双门槛校验（50 任务 + 50 earned 豆）+ Stripe Connect payout。

---

## ✅ 发布就绪核对（已验证）

| 模块 | 状态 | 说明 |
|------|------|------|
| 后端全链路 e2e | ✅ | **53 项全绿**（HK 生产实跑，金豆守恒断言：发布扣豆/确认入账/退款退豆/豆不足拦截/假 JWS 拒绝） |
| iOS 模拟器 UI 测试 | ✅ | iPhone 17 全绿（登录→发布→我的任务→消息 + mock 冒烟 5 项） |
| 认证（发码/登录/注册） | ✅ | redis 存码 + 60s 冷却 + 注册礼 5 豆（代码显式发放） |
| 金豆经济闭环 | ✅ | 双账本（purchased/earned）原子扣减、IAP 三 SKU 映射 |
| 奖励中心 | ✅ | 双门槛规则预告（50 任务 + 50 豆）+ 进度展示，合规措辞 |
| 任务状态机 | ✅ | 发布/领取/提交/确认/争议/退款/取消/放弃全链路 + 24h 自动确认 |
| 广场三排序 | ✅ | distance/beans/newest（服务端白名单） |
| CI/CD | ✅ | push → CI(vet/build/test) → CD(HK) → 版本核对 → 失败回滚 |
| 隐私合规 | ✅ | 隐私政策/条款公网 200、GDPR 同意流、PrivacyInfo.xcprivacy、加密声明 false |
| App 图标 | ✅ | 全尺寸 + 1024 marketing |
| 权限描述 | ✅ | 相机/定位（前后台）文案齐备 |
| IAP 配置 | ✅ | ASC 三 SKU 可供审核；后端 JWS 验签就绪；待沙盒真机闭环（→ P0.1） |
