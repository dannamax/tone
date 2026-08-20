# 腾讯云资源申请指南（以 BountyApp 上云为例）

> 目标：申请一套能跑通真实互联网端到端验证的最小云资源。总预算约 **70 元/月**。

---

## 1. 账号与实名
1. 注册腾讯云账号：https://cloud.tencent.com
2. 完成**实名认证**（个人/企业均可，企业备案更快）。
3. 开通「费用中心」，建议预充 100 元。

---

## 2. 云主机 CVM（必须）
- 入口：云产品 → 云服务器 CVM → 新建实例。
- 地域：**广州 / 上海**（境内，国内邮箱发信 & 用户访问延迟低）。
- 机型：标准型 S5，**2 核 2G**（验证期够用）。
- 镜像：公共镜像 → Ubuntu 22.04 LTS。
- 公网带宽：按流量计费，**1~2 Mbps**（验证期），或固定 3Mbps。
- 系统盘：SSD 云硬盘 20GB。
- 安全组：放通 **22(SSH) / 80(HTTP) / 443(HTTPS)** 入站。
- 记下分配到的**公网 IP**。
- 费用：约 60 元/月（按量或包月）。

> 顺便在 CVM 控制台「SSH 密钥」创建密钥对，下载 `id_rsa`，本地 `ssh -i id_rsa root@<公网IP>`。

---

## 3. 域名 + 备案（必须，国内主机绑域名要备案）
1. 云产品 → 域名注册 → 搜索 `gotseeker.com`（.com 约 60 元/年）。
2. 实名认证域名（1 天内）。
3. **ICP 备案**：云产品 → 网站备案 → 新增备案（个人/企业）。
   - 需准备：身份证、手机号、应急手机号、域名、服务器 IP。
   - 腾讯云初审 + 管局审核，约 **1~2 周**。
   - 备案期间服务器可先部署调试（用 IP 直连，先用自签证书测试）。
4. 备案通过后：云解析 DNS → 添加 A 记录 `api` → 指向公网 IP。

> 若想**免备案快速验证**：选「中国香港 / 新加坡」地域的 CVM，域名不用备案，但国内 163 发信进垃圾箱概率略高、国内用户延迟略大。

---

## 4. HTTPS 证书（必须，iOS ATS 强制）
- 方案：**Let's Encrypt 免费证书**，由 Caddy 自动申请续期（见 `backend/Caddyfile`）。
- 不需要在腾讯云买证书。Caddy 首次访问 `api.gotseeker.com` 自动签发。
- 若想用腾讯云证书：云产品 → SSL 证书 → 免费 DV 证书 → 下载 Nginx 格式，手动配 Caddy/NGINX。

---

## 5. 对象存储 COS（图片上传必须）
1. 云产品 → 对象存储 COS → 创建存储桶。
   - 名称：`bountyapp-<APPID>` 唯一。
   - 地域：同 CVM（广州）。
   - 访问权限：**私有读写**（用临时密钥/预签名 URL）。
2. 访问管理 → API 密钥 → 新建「子账号 + COS 权限」，拿到：
   - `SecretId` / `SecretKey`
   - 桶名、地域、访问域名 `https://<bucket>.cos.<region>.myqcloud.com`
3. 把后端 `.env` 的 `MINIO_*` 改成 COS 的 S3 兼容参数：
   ```
   MINIO_ENDPOINT=cos.<region>.myqcloud.com
   MINIO_ACCESS_KEY=<SecretId>
   MINIO_SECRET_KEY=<SecretKey>
   MINIO_BUCKET=<bucket>
   MINIO_USE_SSL=true
   ```
   （代码已用 `minio-go` S3 客户端，COS 兼容，无需改代码。）

---

## 6. 数据库（验证期用 SQLite，跳过；正式期如下）
- 云产品 → 云数据库 PostgreSQL → 新建（2 核 4G，广州）。
- 拿到内网地址，改后端 `.env`：`DB_DRIVER=postgres` + `DB_HOST/DB_PORT/DB_USER/DB_PASSWORD`。
- 费用约 100+ 元/月，验证期不急着买。

---

## 7. Redis（验证期用 memory，跳过；正式期如下）
- 云产品 → 云数据库 Redis → 新建（1 主节点，广州）。
- 改 `.env`：`CODE_STORE=redis` + `REDIS_ADDR`。

---

## 8. 邮件 SMTP（已有 163，确认迁移）
- 把本地 `.env` 里 163 的 `SMTP_*` 配置原样复制到云主机 `.env`。
- 注意云主机安全组/防火墙**放通 25/465 出站**（465 SSL 通常默认放通）。
- 国内国际双通道 `RouterProvider` 已就绪，国际预留 `SMTP_INTL_*`。

---

## 9. 部署到云主机（一次性初始化）
SSH 进 CVM 后：
```bash
# 安装 docker
curl -fsSL https://get.daocloud.io/docker | bash
sudo systemctl enable --now docker

# 安装 docker compose 插件
sudo apt update && sudo apt install -y docker-compose-plugin

# 安装 caddy
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/caddy-stable-archive-keyring.gpg] https://dl.cloudsmith.io/public/caddy/stable/debian any-version main" | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update && sudo apt install -y caddy

# 创建项目目录并放入 .env
sudo mkdir -p /opt/bountyapp && sudo chown $USER:$USER /opt/bountyapp
```

把本地 `backend/Caddyfile` 放到 `/etc/caddy/Caddyfile`（改域名为你的），`sudo systemctl restart caddy`。

之后每次本地开发完，跑 `./scripts/deploy.sh root@<公网IP>` 即可同步。

---

## 10. 真机验证
> 注意：Personal Team（免费）只能真机调试，不能上架/发 TestFlight。上架需加入 Apple Developer Program（$99/年）并在后台注册 App ID `com.gotseeker.app`（详见 `DEPLOY.md` 2.5 节）。

1. Apple 开发者后台注册 App ID `com.gotseeker.app`，生成 App Store Provisioning Profile。
2. Xcode：Edit Scheme → Run → 在 `OTHER_SWIFT_FLAGS` 加 `-DPRODUCTION`，或建独立 Release-PRODUCTION scheme。
3. Signing 选付费 Team + 上述 Profile，Bundle ID 必须为 `com.gotseeker.app`。
4. 真机跑 / TestFlight 外部测试。
3. App 连 `https://api.gotseeker.com`，注册收 163 邮件验证码，发布任务走 COS 上传，中英文切换全跑通。
