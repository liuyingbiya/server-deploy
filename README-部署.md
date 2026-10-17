# 部署指南 · 给两个项目配真实域名

> 目标：简历上能写
> `在线演示：https://ai.你的域名.top` 和 `https://order.你的域名.top`
>
> 面试官点开就能用，比只看 GitHub 仓库说服力强得多。

---

## 一、先做决定：服务器放哪里

| 方案 | 备案 | 上线时间 | 国内访问 | 年成本（参考） |
|---|---|---|---|---|
| **A. 阿里云 中国香港**（推荐） | **不需要** | 当天 | 稍慢（100–200ms） | 轻量 2核2G 约 ¥24–30/月 |
| B. 阿里云 大陆（如杭州） | **必须备案** | 备案 7–20 个工作日 | 快 | 轻量 2核2G 约 ¥99/年（新用户） |

**为什么推荐 A**：你现在要投简历（10 月底截止），备案等 2–3 周会错过窗口。香港节点免备案、当天可用，演示场景下 100ms 延迟完全够。

如果时间不紧、且想要国内速度，选 B，但**先提交备案再写代码都不迟**——域名实名后就能提交，不用等服务器。

---

## 二、买服务器（阿里云轻量应用服务器）

1. 打开 https://www.aliyun.com → 搜索「轻量应用服务器」
2. 配置选择：

| 项 | 选什么 | 说明 |
|---|---|---|
| 地域 | **中国香港**（或大陆） | 香港免备案 |
| 镜像 | **Ubuntu 22.04** | 本指南按这个写 |
| 规格 | **2 核 2G** 起（3M 带宽） | 两个 Java + 一个 MySQL，2G 是下限，我们脚本会加 2G swap |
| 时长 | 建议年付 | 月付贵一些 |

3. 买完后在控制台找到 **公网 IP**，记下来
4. **防火墙里放行 80 和 443**（轻量有独立的「防火墙」页签，默认只开了 22）

> ⚠️ 忘了放行 80/443 是最常见的「部署完了打不开」原因。

---

## 三、买域名（阿里云万网）

### 推荐域名

| 用途 | 推荐 | 价格 |
|---|---|---|
| 主域 | **`liuyingbiya.top`** | 首年约 ¥10 |
| 子域 1 | `ai.liuyingbiya.top` → 考研复习助手 | 免费（子域不需要额外买） |
| 子域 2 | `order.liuyingbiya.top` → 点餐系统 | 免费 |

**为什么用子域名而不是买两个域名**：一个 ¥10 解决两个项目；HTTPS 证书 Caddy 会自动为每个子域各签一张，也不用额外配置。

备选：`liuyingbiya.xyz`（更便宜）、`liuyingbiya.online`。

### 步骤

1. 阿里云 → 「域名注册」→ 搜索 `liuyingbiya.top` → 加入清单 → 买
2. **做实名认证**（个人身份证，一般几小时到 1 天，不认证域名会被暂停解析）
3. 进「云解析 DNS」→ 找到这个域名 → **添加记录**，两条：

| 记录类型 | 主机记录 | 记录值 | TTL |
|---|---|---|---|
| A | `ai` | 你的服务器公网 IP | 600 |
| A | `order` | 你的服务器公网 IP | 600 |

验证解析是否生效（在你**自己电脑**上）：

```powershell
nslookup ai.liuyingbiya.top
nslookup order.liuyingbiya.top
```

返回的应该是你服务器的 IP，不是 `找不到`。

> ⚠️ 解析没生效就启动，Caddy 申请证书会失败（Let's Encrypt 要访问你的域名验证归属）。

---

## 四、上传代码

服务器上需要三个目录：

```
/opt/apps/
  ├─ ai-app/       考研复习助手（git clone）
  ├─ order-app/    点餐系统（git clone）
  └─ deploy/       本部署包（scp 上传）
```

### 1. 在服务器上克隆两个仓库

```bash
ssh root@你的服务器IP

apt-get update && apt-get install -y git
mkdir -p /opt/apps && cd /opt/apps

git clone https://github.com/liuyingbiya/kaoyan-review-assistant ai-app
git clone https://github.com/liuyingbiya/ordering-system order-app
```

### 2. 上传 deploy 目录（在**你的 Windows 电脑**上执行）

```powershell
cd D:\个人项目与简历制作
scp -r deploy root@你的服务器IP:/opt/apps/
```

---

## 五、配置并启动

```bash
cd /opt/apps/deploy

# 1. 初始化服务器（装 Docker、加 swap、设时区）—— 只跑一次
bash init-server.sh

# 2. 填写配置
cp .env.example .env
vi .env
```

`.env` 里改四个地方：

```ini
AI_DOMAIN=ai.liuyingbiya.top
ORDER_DOMAIN=order.liuyingbiya.top
ACME_EMAIL=你的邮箱
MYSQL_ROOT_PASSWORD=换成一串随机字符
DEEPSEEK_API_KEY=sk-你的key
```

```bash
# 3. 启动（首次要编译 Maven + 拉镜像，大约 5–10 分钟）
bash deploy.sh
```

---

## 六、验证

```bash
cd /opt/apps/deploy
bash smoke-test.sh
```

会检查：容器是否都在跑、80/443 是否监听、应用内部接口、外网 HTTPS、证书到期时间。

手动再确认一次：

- https://ai.liuyingbiya.top → 应该看到「考研复习助手」科目树
- https://order.liuyingbiya.top → 应该看到「微信点餐 - 首页」
- https://ai.liuyingbiya.top/api/chat/status → 应该返回 `{"mock":false,...}`

---

## 七、常见问题

### 1. 浏览器打开 https 报「证书错误 / 不安全」

Caddy 没拿到证书。原因通常是：

```bash
docker compose logs caddy | tail -30
```

- 日志里有 `dns problem` / `no such host` → 域名没解析好，先 `nslookup` 确认
- 日志里有 `connection refused` → 80 端口没放行，去阿里云防火墙加规则
- 日志里有 `acme: error ... rate limited` → Let's Encrypt 申请太频繁，等 1 小时

### 2. 页面 502 Bad Gateway

应用起来了但 Caddy 连不上。

```bash
docker compose ps          # 看 app-ai / app-order 是不是 running
docker compose logs app-ai | tail -50
```

常见原因：MySQL 还没就绪（等 1 分钟）、或应用 OOM 被杀（`docker stats` 看内存）。

### 3. 中文变成乱码

MySQL 初始化时字符集没设对。确认容器环境有 `--character-set-server=utf8mb4`（compose 里已配）。

### 4. 改了 schema.sql 但数据库没变

**MySQL 的 `/docker-entrypoint-initdb.d` 只在数据目录为空时执行一次。**

要重新初始化：

```bash
docker compose down
docker volume rm deploy_mysql-data     # 注意：会删掉所有数据
docker compose up -d --build
```

### 5. 内存不够（应用反复重启）

```bash
free -h
docker stats --no-stream
```

2G 机器跑「MySQL + 2 个 JVM」很紧。已在 compose 里做了 `mem_limit`（各 640m）和 `-Xmx320m`，还不行就升级到 2核4G。

### 6. 只想先看效果，不想等 HTTPS

把两个域名换成 `http://服务器IP:8080`（点餐系统）和 `http://服务器IP:8081`（复习助手）——但需要在 compose 里给两个 app 加上端口映射 `ports: ["8080:8080"]`。**不推荐**，因为这样不像真实项目。

---

## 八、以后更新代码

```bash
cd /opt/apps/deploy
bash deploy.sh          # 会自动 git pull 两个仓库再重建
```

只看日志：

```bash
bash deploy.sh --logs
```

---

## 九、成本小结

| 项 | 费用 |
|---|---|
| 阿里云轻量 2核2G（香港） | 约 ¥24–30/月 |
| 域名 `.top` | 约 ¥10/年 |
| HTTPS 证书（Let's Encrypt） | 免费 |
| Docker / 代码托管 | 免费 |
| **合计** | **约 ¥300/年** |

> 如果是大陆服务器：约 ¥99/年（新用户价）+ 备案免费但需等待。

---

## 十、附：文件说明

| 文件 | 作用 |
|---|---|
| `docker-compose.yml` | 一个 MySQL（两个库）+ 两个应用 + Caddy |
| `Caddyfile` | 反代 + 自动 HTTPS |
| `.env.example` | 配置模板（复制成 `.env` 填真实值） |
| `init-server.sh` | 装 Docker、加 2G swap、设时区（只跑一次） |
| `deploy.sh` | 一键构建启动 / 看日志 / 停止 |
| `smoke-test.sh` | 上线后自检，8 项检查 |
