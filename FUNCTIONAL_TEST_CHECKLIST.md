# BountyApp 功能自测清单

> 用途：每次发版前按此清单逐项验证后端 API 全链路正确性。
> 基础路径前缀：`/api/v1`（除 `/health`、`/healthz`、`/ws`）。
> 鉴权：除 `send-code`/`login`/`config/*`/`health*` 外，所有接口需在 Header 带 `Authorization: Bearer <access_token>`。
> 验证对象：`https://api.gotseeker.com`（HK 生产）或本地 `http://127.0.0.1:8080`。
> 经济模型：**金豆 beans**（发布时原子预扣 → 确认后入账接单人 → 取消/退款返还发布者）。

图例：✅ 通过 / ❌ 失败 / ⏭️ 跳过 / ⚠️ 需注意

---

## 0. 基础设施

| # | 项目 | 验证方法 | 预期 |
|---|------|----------|------|
| 0.1 | 健康检查 | `GET /healthz` | `{"status":"ok","service":"bountyapp","version":"<git-sha>"}` |
| 0.2 | 版本一致性 | 对比 `/healthz` 的 `version` 与 GitHub `main` 最新 SHA | 一致 |
| 0.3 | 依赖健康 | 容器 `bountyapp` + `bountyapp-redis` 均 `healthy` | 无重启循环 |
| 0.4 | 数据持久化 | 重建容器后查用户/任务数是否保留 | SQLite volume 不丢数据 |

---

## 1. 认证 Auth

| # | 接口 | 方法 | 关键校验 | 预期结果 |
|---|------|------|----------|----------|
| 1.1 | `/auth/send-code` | POST | body `{"email","country_code","phone"}` | 200，验证码写入 redis `seeker:code:<email>` |
| 1.2 | 发码冷却 | 同邮箱 60s 内两次 send-code | 第二次返回 429 |
| 1.3 | `/auth/login` | POST | `{"email","code","device_id"}` | 200，返回 `access_token` + beans 字段 |
| 1.4 | 错误验证码 | login 用错误 code | 返回无效凭证 |
| 1.5 | 新用户注册 | 首次 login | 自动创建用户，注册礼 5 豆（`beans_purchased=5`） |
| 1.6 | `/me` | GET | 带 token | 返回当前用户 profile（含 beans） |
| 1.7 | 无 token 访问 | `/me` 不带 Header | 401 |

---

## 2. 任务生命周期 Task（金豆经济）

| # | 接口 | 方法 | 关键校验 | 预期结果 |
|---|------|------|----------|----------|
| 2.1 | `/tasks` 发布 | POST | `title,bounty_beans∈[5,50],target_lat,lng,target_addr,radius∈{1000,3000,5000,10000},time_limit∈{5,15,30,60,120}` | 201，**发布即预扣金豆**（purchased 优先） |
| 2.2 | 发布校验-金豆区间 | `bounty_beans=4` 或 `=51` | 参数错误 4xx |
| 2.3 | 豆不足拦截 | 用户 beans_total=0 时发布 | 4xx `insufficient_beans`，豆数不变 |
| 2.4 | 发布校验-位置 | 缺 `target_addr` 且 lat=lng=0 | 返回 `no_location` |
| 2.5 | `/tasks/square` 广场 | GET | `?lat&lng&radius&sort`，sort∈{distance,beans,newest} | 返回附近 `published` 任务列表 |
| 2.6 | 金豆排序 | `sort=beans` | 按 `bounty_beans DESC` 返回 |
| 2.7 | 半径过滤 | 任务在 radius 外 | 不出现在广场 |
| 2.8 | `/tasks/:id/claim` 认领 | POST | 非发布者本人 | 状态→`claimed` |
| 2.9 | `/tasks/:id/submit` 提交 | POST | `note,images,submit_lat,submit_lng`（围栏内） | 状态→`submitted` |
| 2.10 | `/tasks/:id/submission` 查提交 | GET | — | 返回提交内容 |
| 2.11 | `/tasks/:id/confirm` 确认 | POST | 发布者确认 | 状态→`confirmed`，**接单人 `beans_earned += bounty_beans`** |
| 2.12 | `/tasks/:id/dispute` 争议 | POST | 发布者，submitted 态，带 reason | 状态→`disputed` |
| 2.13 | `/tasks/:id/refund` 退款 | POST | 争议后发布者 | 状态→`refunded`，**发布者退豆**（purchased） |
| 2.14 | `/tasks/:id/cancel` 取消 | POST | 发布者，published 态 | 状态→`cancelled`，**发布者退豆**（purchased） |
| 2.15 | `/tasks/:id/abandon` 放弃 | POST | 接单者 | 状态回退 released |
| 2.16 | `/tasks/mine` 我的任务 | GET | — | 返回我发布/认领的任务分页 |

> 注：`/tasks/:id/activate` 为旧版兼容接口，金豆制下发布即生效（published），无需激活。

---

## 3. 钱包 Wallet

| # | 接口 | 方法 | 关键校验 | 预期结果 |
|---|------|------|----------|----------|
| 3.1 | `/wallet` 钱包信息 | GET | — | 返回 `beans_purchased,beans_earned,beans_total` 及余额字段 |
| 3.2 | 豆子流水正确 | 发布/确认/退款后查 wallet | 各字段精确增减 |
| 3.3 | `/wallet/recharge` 模拟充值 | POST | 金额 | 余额增加，生成交易记录 |
| 3.4 | `/wallet/withdraw` 提现 | POST | 达到 `MinWithdrawAmount` | 余额减少 |
| 3.5 | 提现门槛 | 余额 < 门槛 | 拒绝提现 |
| 3.6 | `/wallet/transactions` 交易列表 | GET | — | 返回 `items` 分页，含 `bean_spend/bean_reward/bean_refund` 类型 |

---

## 4. 金豆充值 IAP

| # | 接口 | 方法 | 预期结果 |
|---|------|------|----------|
| 4.1 | `/wallet/quota-packages` 套餐列表 | GET | `pkg_usd_2`(5豆/$0.99)、`pkg_usd_5`(10豆/$1.99)、`pkg_usd_10`(20豆/$4.99) |
| 4.2 | `/wallet/quota/order` 创建订单 | POST | 返回订单（pending） |
| 4.3 | `/wallet/quota/order/:id` 查订单 | GET | 返回订单状态 |
| 4.4 | `/wallet/quota/confirm-apple` Apple 校验 | POST | 真实 JWS：豆子入账（purchased）；**假 JWS：4xx 拒绝** |
| 4.5 | 重复确认幂等 | 已 paid 订单再 confirm | 幂等返回，不重复发豆 |

---

## 5. 消息与协作 Message

| # | 接口 | 方法 | 预期结果 |
|---|------|------|----------|
| 5.1 | `/tasks/:id/messages` 查消息 | GET | 返回任务内聊天记录 |
| 5.2 | `/tasks/:id/messages` 发消息 | POST | 消息入库，对方可见；链接类内容被拦截 |

---

## 6. 文件上传 Upload

| # | 接口 | 方法 | 预期结果 |
|---|------|------|----------|
| 6.1 | `/upload` 上传 | POST | 返回 COS URL，公网可读 |

---

## 7. 通知 Notification

| # | 接口 | 方法 | 预期结果 |
|---|------|------|----------|
| 7.1 | `/notifications` 列表 | GET | 返回分页通知 |
| 7.2 | `/notifications/:id/read` 标记已读 | POST | 单条已读 |
| 7.3 | `/notifications/read-all` 全部已读 | POST | 全部已读 |

---

## 8. 配置 Config

| # | 接口 | 方法 | 预期结果 |
|---|------|------|----------|
| 8.1 | `/config/exchange-rate` 汇率 | GET | 返回币种汇率 |
| 8.2 | `/config/email-domains` 邮箱域名 | GET | 返回支持的邮箱后缀 |

---

## 9. 实时通信 WebSocket

| # | 接口 | 方法 | 预期结果 |
|---|------|------|----------|
| 9.1 | `/ws` 连接 | GET | 带 token 升级协议成功，可收推送 |

---

## 10. 回归与边界

| # | 项目 | 验证 |
|---|------|------|
| 10.1 | 多语言错误包 | `Accept-Language` 返回英文文案 |
| 10.2 | 广场分页 | 大量任务时分页正确 |
| 10.3 | 并发确认 | 同一任务两次 confirm 幂等 |
| 10.4 | 数据清理 | 测试用户 `e2e_*`/`full_e2e_*` 前缀可安全删除 |

---

## 附：快速冒烟（自动化）

```bash
# HK 机器上执行（自动从 redis 取码）
ssh root@129.226.138.231
cd /opt/bountyapp && bash scripts/e2e-smoke.sh http://127.0.0.1:8080

# 完整自测（金豆经济全链路 + 豆子守恒断言）
bash scripts/full-e2e.sh
```

- `e2e-smoke.sh` 覆盖：发码 → 登录 → 发布 → 广场 → 取消
- `full-e2e.sh` 覆盖：双用户经济闭环（发布扣豆/认领/提交/确认入账/争议退款/取消退豆/豆不足拦截/假 JWS 拒绝/套餐映射）
