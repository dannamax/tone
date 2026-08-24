# BountyApp 功能自测清单

> 用途：每次发版前按此清单逐项验证后端 API 全链路正确性。
> 基础路径前缀：`/api/v1`（除 `/health`、`/healthz`、`/ws`）。
> 鉴权：除 `send-code`/`login`/`config/*`/`health*` 外，所有接口需在 Header 带 `Authorization: Bearer <access_token>`。
> 验证对象：`https://129.226.138.231:8080`（HK 生产）或本地 `http://127.0.0.1:8080`。

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
| 1.1 | `/auth/send-code` | POST | body `{"email":"x@y.com"}` | 200，验证码写入 redis `seeker:code:<email>`（JSON） |
| 1.2 | 发码冷却 | 连续两次 send-code | 第二次返回冷却中错误 |
| 1.3 | `/auth/login` | POST | `{"email","code","device_id"}` | 200，返回 `access_token` |
| 1.4 | 错误验证码 | login 用错误 code | 返回无效凭证 |
| 1.5 | 新用户注册 | 首次 login | 自动创建用户并返回 token |
| 1.6 | `/me` | GET | 带 token | 返回当前用户 profile |
| 1.7 | 无 token 访问 | `/me` 不带 Header | 401 |

---

## 2. 任务生命周期 Task

| # | 接口 | 方法 | 关键校验 | 预期结果 |
|---|------|------|----------|----------|
| 2.1 | `/tasks` 发布 | POST | `title,bounty,currency,target_lat,lng,target_addr,radius∈{1000,3000,5000,10000},time_limit∈{5,15,30,60,120}` | 201，返回 `id` |
| 2.2 | 发布校验-位置 | 缺 `target_addr` 且 `lat=lng=0` | 返回 `no_location` |
| 2.3 | 发布校验-金额 | `bounty` 超出上限(200) | 参数错误 |
| 2.4 | 发布校验-枚举 | `radius` 不在允许值 | 参数错误 |
| 2.5 | `/tasks/square` 广场 | GET | `?lat&lng&radius`，带 token | 返回附近 `published` 任务列表 |
| 2.6 | 半径过滤 | 任务在 10km 外 | 不出现在广场 |
| 2.7 | `/tasks/:id` 详情 | GET | 有效 id | 返回任务详情 |
| 2.8 | `/tasks/:id/claim` 认领 | POST | 非发布者本人 | 任务状态→`claimed`，冻结逻辑触发 |
| 2.9 | `/tasks/:id/submit` 提交证据 | POST | `task_id`、证据内容 | 状态→`submitted` |
| 2.10 | `/tasks/:id/submission` 查提交 | GET | — | 返回提交内容 |
| 2.11 | `/tasks/:id/confirm` 确认 | POST | 发布者确认，**余额不足拦截** | 状态→`confirmed`，余额扣减、收款人入账 |
| 2.12 | 确认余额不足 | 发布者余额 < bounty | 返回 `insufficient_funds`，余额不变负 |
| 2.13 | `/tasks/:id/cancel` 发布者取消 | POST | 发布者取消 | 状态→`cancelled`，恢复冻结 |
| 2.14 | `/tasks/:id/abandon` 接单者放弃 | POST | 接单者放弃 | 状态回退，释放 |
| 2.15 | `/tasks/:id/dispute` 争议 | POST | 带 reason | 状态→`disputed` |
| 2.16 | `/tasks/:id/refund` 退款 | POST | 争议后退款 | 状态→`refunded`，退款逻辑 |
| 2.17 | `/tasks/:id/activate` 激活 | POST | 重新上架 | 状态→`published` |
| 2.18 | `/tasks/mine` 我的任务 | GET | — | 返回我发布/认领的任务分页 |

---

## 3. 钱包 Wallet

| # | 接口 | 方法 | 关键校验 | 预期结果 |
|---|------|------|----------|----------|
| 3.1 | `/wallet` 钱包信息 | GET | — | 返回 `balance,frozen_balance,total_earned,total_spent,publish_quota,used_quota` |
| 3.2 | 累计字段正确 | 确认一笔任务后查 wallet | `total_spent`/`total_earned` 正确累加 |
| 3.3 | `/wallet/recharge` 充值 | POST | 金额 | 余额增加，生成交易记录 |
| 3.4 | `/wallet/withdraw` 提现 | POST | 达到 `MinWithdrawAmount` | 余额减少，`CanWithdraw` 翻转 |
| 3.5 | 提现门槛 | 余额 < 门槛 | 拒绝提现 |
| 3.6 | `/wallet/transactions` 交易列表 | GET | — | 返回 `items` 分页列表 |
| 3.7 | 币种换算 | 发布非 CNY 任务 | `ToCNY` 正确换算冻结额 |

---

## 4. 发布配额 Quota

| # | 接口 | 方法 | 预期结果 |
|---|------|------|----------|
| 4.1 | `/wallet/quota-packages` 套餐列表 | GET | 返回可用套餐 |
| 4.2 | `/wallet/quota/order` 创建订单 | POST | 返回订单（含支付参数） |
| 4.3 | `/wallet/quota/confirm-apple` Apple 校验 | POST | 校验收据后 `used_quota` 减少 |
| 4.4 | `/wallet/quota/order/:id` 查订单 | GET | 返回订单状态 |
| 4.5 | 配额耗尽拦截 | `used_quota >= publish_quota` 时发布 | 返回配额不足 |

---

## 5. 消息与协作 Message

| # | 接口 | 方法 | 预期结果 |
|---|------|------|----------|
| 5.1 | `/tasks/:id/messages` 查消息 | GET | 返回任务内聊天记录 |
| 5.2 | `/tasks/:id/messages` 发消息 | POST | 消息入库，对方可见 |

---

## 6. 文件上传 Upload

| # | 接口 | 方法 | 预期结果 |
|---|------|------|----------|
| 6.1 | `/upload` 上传 | POST | 返回文件 URL，持久化到 `uploads` volume |

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
| 10.1 | 多语言错误包 | 不同 `Accept-Language` 返回对应文案 |
| 10.2 | 广场分页 | 大量任务时分页正确 |
| 10.3 | 并发确认 | 同一任务两次 confirm 幂等 |
| 10.4 | 数据清理 | 测试用户 `e2e_*` 前缀可安全删除，不伤 demo 数据 |

---

## 附：快速冒烟（自动化）

```bash
# 本机跑（HK 环境，自动从 redis 取码）
ssh root@129.226.138.231
cd /opt/bountyapp && bash scripts/e2e-smoke.sh http://127.0.0.1:8080
```

覆盖：发码 → 注册/登录 → 发布 → 广场 → 取消（PASS=6）。其余项按上表人工核对。
