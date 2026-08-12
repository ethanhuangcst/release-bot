# 新项目部署说明 — 经 release-bot 发布到野草云4（域名 `{appname}.qiuge.me`）

**读者：** 将要写入 **新应用仓库**、并计划用 **release-bot** 发布到 **野草云4** 的作者。  
**应用仓库必须产出：** `deployment-plan.md`（路径可为 `specs/deployment-plan.md` 或仓库根目录 `deployment-plan.md`）。  
**使用者：** 开启发布任务时，运维将该文件作为 release-bot 的主输入（密钥放在 Git 外）。

本文描述边缘节点 **野草云4** 的目标架构与步骤。平台层与野草云3 **同构**（Docker + `portainer_network` + Portainer + NPM + GHCR），但：

| 项 | 野草云4 定稿 |
| --- | --- |
| 节点 IP | `68.64.176.124` |
| 运维入口 | Portainer `https://portainer4.agent-mate.ai` · NPM `https://nginx4.agent-mate.ai` |
| **应用公网域名约定** | **`{appname}.qiuge.me`**（例：`jobhunt.qiuge.me`） |
| Cloudflare zone（应用） | **`qiuge.me`**（与运维用的 `agent-mate.ai` 分离） |

对齐基准：[野草云4 资源清单](./hk_vps_4_settings.md) · [野草云3 同主题说明（中文）](../svr_hk_vps_3/new_deployment_instruction.md)。

---

## 0. 域名约定（先读）

### 0.1 公式

```text
<APP_DOMAIN> = {appname}.qiuge.me
```

| 占位 | 含义 | 示例（求职应用） |
| --- | --- | --- |
| `{appname}` / `<APP_SLUG>` 对外段 | 短横线小写、DNS 友好 | `jobhunt` |
| `<APP_DOMAIN>` | 完整公网主机名 | `jobhunt.qiuge.me` |
| `<APP_URL>` | 含协议 | `https://jobhunt.qiuge.me` |
| Cloudflare zone | 只动 **`qiuge.me`** | 不要改 `agent-mate.ai` 上其他记录 |
| DNS Name 栏 | 只填 `{appname}` | 填 `jobhunt`，**不要**填 `jobhunt.qiuge.me`（否则变成 `jobhunt.qiuge.me.qiuge.me`） |

### 0.2 命名建议（一次定好，全链路复用）

| 用途 | 建议规则 | 示例 |
| --- | --- | --- |
| DNS / 公网 | `{appname}.qiuge.me` | `jobhunt.qiuge.me` |
| `APP_SLUG` | 与 `{appname}` 相同或极接近 | `jobhunt` |
| `STACK_NAME` | 可与 slug 相同，或加产品后缀 | `jobhunt` / `jobhunt-web` |
| `container_name` | `<APP_SLUG>-<role>` | `jobhunt-web`、`jobhunt-agent` |
| 卷名 | `<APP_SLUG>_…` | `jobhunt_data` |
| DB 名 | 独立库，勿复用他应用 | `jobhunt_prod` |

**禁止：** 把应用挂到 `*.agent-mate.ai`（该 zone 留给野草云3/4 运维入口与既有 agent-mate 产品），除非运维书面批准例外。

### 0.3 流量路径

```text
[浏览器]
    → Cloudflare DNS（zone: qiuge.me，子域 {appname}）
        → 野草云4 Nginx Proxy Manager（:80 / :443）
            → portainer_network 上的容器（如 jobhunt-web:3000）
                → 外部 DB / LLM / 第三方
```

运维控制台走 `agent-mate.ai` 的 `portainer4` / `nginx4`；**业务流量**走 `qiuge.me`。两者不要混在同一条 Proxy Host 里。

---

## 1. release-bot 是什么（以及不是什么）

| 是 | 不是 |
| --- | --- |
| **对话式引导**：一步一步带运维完成发布 | 无人值守、自行 SSH 改节点的完整 CI/CD |
| 依据 `release-bot/knowledge/` + 你的 `deployment-plan.md` | 存放生产密码的地方 |
| 期望 GitHub Actions 构建 **GHCR 镜像**；Portainer **只 pull** | 在 VPS 或笔记本上为生产 build 应用镜像 |

密钥只放本机密钥库 / Portainer env / 节点 `.env`。切勿写入 `deployment-plan.md` 或 release-bot git。

---

## 2. 目标运行时架构（野草云4）

| 层级 | 野草云4 事实 |
| --- | --- |
| 节点 | **野草云4** · `68.64.176.124` · Hostname `qiuge` · Debian 13 |
| 容器编排 | **Portainer** `https://portainer4.agent-mate.ai/` |
| 共享网络 | **`portainer_network`** — 已存在；**禁止删除或重建** |
| TLS / HTTP | **NPM** `https://nginx4.agent-mate.ai/` · 主机 `80`/`443`/`81` |
| 镜像 | `ghcr.io/<owner>/<repo>/<service>:<IMAGE_TAG>`（Portainer 已登记 `ghcr.io`） |
| 主库 | 默认在 compose **外**；新建独立 `<DB_NAME>`，禁止复用野草云3 他应用库 |
| 安全组 | 公网通常只放行 **22/80/443**；`:81`/`:9443` 请走域名或 SSH 隧道 |

### 多应用共存（硬规则）

野草云4 当前应用栈为空，但后续会多应用共存。你的计划必须：

- 唯一 **Stack / 容器名 / 卷 / 主机端口 / `{appname}.qiuge.me` / DB 名**
- **只**改本应用在 `qiuge.me` 的 DNS，以及本应用在 NPM 的一条 Proxy Host
- **不要**改 `portainer4` / `nginx4` / 其他应用 Host
- 上线后抽查：**若节点上已有其他应用**，抽查 ≥1 个；若仍为空，在计划中写「首发，无既有应用可抽查」

细则：`knowledge/09-isolation-safety.md`。

### 端口映射约定

| 位置 | 用哪个端口 |
| --- | --- |
| Compose `ports:` | `"<HOST_PORT>:<CONTAINER_PORT>"` — 主机端口须在野草云4 空闲 |
| NPM Forward Port | **容器监听端口**（如 `3000`），**不是**主机映射端口 |
| Forward Hostname | **`container_name`**（如 `jobhunt-web`），不要写公网 IP |

野草云4 惯例预留（与清单一致，按实机再核）：

| 用途 | 建议段 | 状态（as_of 平台落地） |
| --- | --- | --- |
| 应用 Web | `3001+` | 空闲，按应用递增分配 |
| Agent / MCP / RAG | `3200+` | 空闲 |
| Qdrant 等 | `127.0.0.1:6333+` | 空闲；优先只绑回环 |

对照：[hk_vps_4_settings.md](./hk_vps_4_settings.md) §5。**不要**假设与野草云3 同号端口空闲或冲突——两机独立。

---

## 3. 发布流程（计划必须可逐步作答）

对齐 `knowledge/03-semi-auto-release.md`。下列表把 **qiuge.me** 定死进第 6–7 步：

| 步骤 | 运维动作 | 计划中必须写清 |
| --- | --- | --- |
| 0 | 预检 | 仓库、git ref、服务、镜像、主机端口、`{appname}`、完整 `<APP_DOMAIN>`、DB |
| 0b | 隔离门禁 | `STACK_NAME` / `APP_SLUG` / 端口 / `*.qiuge.me`；与野草云4 清单冲突说明 |
| 1 | Compose | 生产 compose 路径；仅 `image:`；`external: portainer_network` |
| 2 | CI → GHCR | 工作流；镜像名；**真实存在的** `IMAGE_TAG`（勿把分支名当 tag，见 ADR-002） |
| 3 | Env | 变量**名**；`APP_URL=https://{appname}.qiuge.me` |
| 4 | DB | 连通方式；迁移命令或「无需迁移」；独立 `<DB_NAME>` |
| 5 | Portainer | 打开 **portainer4**；仅部署本 `STACK_NAME`；确认网络已存在 |
| 6 | Cloudflare | **Zone = `qiuge.me`**；Type A；Name = `{appname}`；Content = `68.64.176.124`；先**灰云** |
| 7 | NPM | 打开 **nginx4**；新建 Host：Domain = `{appname}.qiuge.me`；上游 `http://<container>:<容器端口>`；LE + Force SSL |
| 8 | 冒烟 | `https://{appname}.qiuge.me/` + 关键路径；既有应用抽查（若有） |

**顺序：** DB 可达 → 容器 healthy → DNS（灰云）→ NPM 申证 → 冒烟。容器未好不要申公网证书。

**Stack recreate 后：** 对本应用 NPM Host **再点一次 Save**；agent 类验 `/healthz`（ADR-003）。

---

## 4. 应用仓库必须已具备

1. **`deployment-plan.md`**（按本文 §5）  
2. 生产 **Dockerfile(s)**  
3. **`docker-compose.prod.yml`**（或等价）：`image:` only + `portainer_network` + 稳定 `container_name`  
4. **GitHub Actions** → 推 GHCR  
5. **`.env.prod.example`**：变量名清单，无真实密钥  
6. 按需：迁移、SSE/WebSocket、Playwright/Xvfb、首次登录说明  

生产路径必须是：**野草云4 + Portainer + GHCR + NPM + `{appname}.qiuge.me`**。若本地文档写 PM2/裸机，以本文为准（或写明已批准例外）。

---

## 5. `deployment-plan.md` — 必填章节（含 qiuge.me 示例）

将下列大纲复制到应用仓库并替换占位符。示例列以 **jobhunt** 示意。

```markdown
# 部署计划 — <PRODUCT_NAME>

## 0. Meta
- 应用仓库：`<GITHUB_OWNER>/<GITHUB_REPO>`
- 首次部署 git ref：`main`（或 tag 策略）
- 目标节点：野草云4（`68.64.176.124`）
- 运维入口：Portainer `https://portainer4.agent-mate.ai` · NPM `https://nginx4.agent-mate.ai`
- Stack 名：`<STACK_NAME>`                 # 例：jobhunt
- App slug：`<APP_SLUG>`                   # 例：jobhunt
- 公网域名：`<APP_DOMAIN>` = `{appname}.qiuge.me`   # 例：jobhunt.qiuge.me
- Cloudflare zone：`qiuge.me`（仅本应用子域）

## 1. 架构（运行时）
- 浏览器 → Cloudflare(`qiuge.me`) → NPM(野草云4) → 容器 → 外部 DB/API
- 单进程 / 多服务；持久化路径与卷名

## 2. 服务表
| Service | container_name | Image | 容器端口 | 主机端口 | 公网 | 职责 |
| --- | --- | --- | --- | --- | --- | --- |
| web | `<APP_SLUG>-web` | `ghcr.io/.../web` | 3000 | `<HOST_PORT>` | 是 → NPM | UI |

## 3. 镜像与 CI
- Dockerfile / workflow 路径
- Registry：`ghcr.io`
- Tags：优先 **git sha** 或已发布 semver；说明 Packages 里真实存在的 tag（勿用未推送的分支名）

## 4. Compose 契约
- 文件路径
- 确认：无 `build:`；`networks.default.external.name: portainer_network`
- 卷 / `shm_size` 等

## 5. 环境变量
| Name | Required | Notes |
| --- | --- | --- |
| `DATABASE_URL` | yes | 库名 `<DB_NAME>`；密码不写本文件 |
| `APP_URL` | yes | 必须为 `https://<APP_DOMAIN>`，例 `https://jobhunt.qiuge.me` |
| `IMAGE_TAG` | Portainer | 与 GHCR 已有 tag 一致 |

## 6. 数据库
- 引擎与主机（外部实例）
- `<DB_NAME>`（独立；勿用野草云3 他应用库名）
- 迁移命令或「无需 / 启动自建」
- 隔离声明

## 7. DNS 与 TLS（qiuge.me）
- Zone：`qiuge.me`
- 记录：Type **A** · Name **`{appname}`** · Content **`68.64.176.124`**
- 代理：申请 Let's Encrypt 前用 **DNS only（灰云）**；成功后可按需橙云（Full / Full strict）
- NPM Domain Names：必须精确为 `{appname}.qiuge.me`
- Forward：`http://<container_name>:<CONTAINER_PORT>`
- Force SSL；证书 CN/SAN 与域名一致

## 8. 反代附加项
- WebSocket：按需开启
- SSE / MCP：`proxy_buffering off`、加长 read/send 超时（若适用）
- 不要把运维域名或 agent-mate 子域配进本 Host

## 9. 冒烟清单
- [ ] `https://{appname}.qiuge.me/`
- [ ] 健康检查 / 登录等确切路径
- [ ] 关键用户旅程（一句话）
- [ ] 抽查野草云4 上 ≥1 既有应用（若有）；并确认未误改 `portainer4`/`nginx4`

## 10. 隔离清单（首次部署前）
- [ ] Stack / 主机端口 / `{appname}.qiuge.me` / DB 名 vs [hk_vps_4_settings.md](./hk_vps_4_settings.md)
- [ ] 不重建 `portainer_network`
- [ ] 不编辑其他 NPM Host；不改 `agent-mate.ai` 无关记录
- [ ] 不触碰野草云3（`38.55.192.140`）

## 11. 运维注意（应用特有）
- 首次登录 / 种子数据
- Playwright / Xvfb 等（若有）
- Update stack 时确认会 re-pull 正确 `IMAGE_TAG`
```

### 5.1 填表速查（jobhunt 示例）

| 字段 | 示例值 |
| --- | --- |
| `{appname}` | `jobhunt` |
| `<APP_DOMAIN>` | `jobhunt.qiuge.me` |
| `<APP_URL>` | `https://jobhunt.qiuge.me` |
| DNS Name | `jobhunt` |
| DNS Content | `68.64.176.124` |
| NPM Domain | `jobhunt.qiuge.me` |
| NPM Forward | `http://jobhunt-web:3000`（容器端口以 compose 为准） |
| Portainer | `https://portainer4.agent-mate.ai` → Stack `jobhunt` |
| NPM Admin | `https://nginx4.agent-mate.ai` |

---

## 6. Compose 骨架

```yaml
name: <STACK_NAME>

services:
  web:
    image: ghcr.io/<GITHUB_OWNER>/<GITHUB_REPO>/web:${IMAGE_TAG:-latest}
    container_name: <APP_SLUG>-web
    restart: unless-stopped
    ports:
      - "<HOST_PORT>:3000"
    volumes:
      - <APP_SLUG>_data:/data
    environment:
      NODE_ENV: production
      PORT: "3000"
      HOSTNAME: "0.0.0.0"
      DATABASE_URL: ${DATABASE_URL:?set DATABASE_URL}
      APP_URL: ${APP_URL:-https://<APP_SLUG>.qiuge.me}
    networks:
      - default

volumes:
  <APP_SLUG>_data:

networks:
  default:
    external: true
    name: portainer_network
```

多服务时：服务间用 `container_name` 互访；对外只把需要暴露的服务交给 NPM。

---

## 7. DNS / NPM 操作细则（野草云4 + qiuge.me）

### 7.1 Cloudflare（zone：`qiuge.me`）

1. 确认 zone **Active**（NS 已切到 Cloudflare）。  
2. DNS → Add record：
   - Type: **A**
   - Name: **`{appname}`**（仅子域标签）
   - IPv4: **`68.64.176.124`**
   - Proxy: **DNS only（灰云）**（首次申 LE）
3. 用权威/DoH 确认解析到本机 IP 后再进 NPM 申证。  
4. 证书成功后，若需橙云：打开代理，SSL/TLS 模式 **Full** 或 **Full (strict)**；长连接应用先评估超时。

**禁止：** 在 `agent-mate.ai` 下误建同名业务子域，除非运维明确要求。

### 7.2 Nginx Proxy Manager（`nginx4`）

1. 登录 `https://nginx4.agent-mate.ai`。  
2. **Hosts → Proxy Hosts → Add**：
   - Domain Names: `{appname}.qiuge.me`（一个域名一项，拼写核对）
   - Scheme: `http`（上游为容器明文时）
   - Forward Hostname / IP: **`container_name`**
   - Forward Port: **容器端口**
   - Websockets：按应用需要  
3. SSL 页：Request new certificate → Force SSL → Agree LE。  
4. LE 邮箱须为**真实可收件地址**（勿用 `admin@example.com`；野草云4 曾因此申证失败）。  
5. 保存后访问 `https://{appname}.qiuge.me`，确认不是 Default Site。

### 7.3 Portainer（`portainer4`）

1. `https://portainer4.agent-mate.ai` → 本机 Endpoint。  
2. Stacks → Create / Update **仅** `<STACK_NAME>`。  
3. Env 含真实存在的 `IMAGE_TAG`；网络勾选已有 `portainer_network`。  
4. 私有 GHCR 包：在 Registries 为 `ghcr.io` 配置 `read:packages` PAT（公开包可无认证）。

---

## 8. 已踩过的坑（写进计划 §11，若相关）

| 主题 | 建议 |
| --- | --- |
| `IMAGE_TAG` | 必须是 GHCR **已存在**的 tag（sha/semver）；分支名 `main` 往往不是镜像 tag（ADR-002） |
| Portainer Update | 常不重新 pull `latest`；用 Recreate + Pull 或换明确 sha |
| NPM 域名 | 与 DNS **逐字符一致**；错一个字母 → Default Site / `unrecognized_name` |
| NPM 上游 | 容器名 + **容器**端口；主机端口仅调试 |
| DNS Name 栏 | 只填 `{appname}`，不要填 FQDN |
| Zone 搞错 | 业务在 `qiuge.me`；运维在 `agent-mate.ai` — 改错 zone 会伤到其他产品 |
| LE 邮箱 | 禁用示例邮箱；用真实邮箱 |
| 申证时机 | 灰云且解析已指向本机后再 Request certificate |
| Stack recreate | NPM 对本 Host 再 Save；agent 验 `/healthz`（ADR-003） |
| 密钥 | 聊天/截图出现过的密码与 PAT 应轮换 |

---

## 9. release-bot 如何使用本说明与你的计划

1. 将应用仓库的 `deployment-plan.md` 放入 `release-bot/Release-jobs/<job>/`（或指向应用仓库路径）。  
2. 本文件（`svr_hk_vps_4/vps4_new_deployment_instruction.md`）作为**节点 + 域名约定**上下文；手册 `knowledge/` 提供逐步话术。  
3. 收集占位符与野草云4 现网占用（更新 [hk_vps_4_settings.md](./hk_vps_4_settings.md)）。  
4. 隔离门禁 → CI/GHCR → Portainer → Cloudflare(`qiuge.me`) → NPM → 冒烟。  
5. 会话笔记可入库；**密钥永不入库**。

---

## 10. 撰写 `deployment-plan.md` 的完成标准

- [ ] §5 各节齐全（不用则标 N/A）  
- [ ] `<APP_DOMAIN>` 符合 **`{appname}.qiuge.me`**，与 `APP_URL`、DNS、NPM 四处一致  
- [ ] 目标节点明确为野草云4（`68.64.176.124`），运维入口为 portainer4 / nginx4  
- [ ] 服务/端口/镜像/stack/slug 无歧义  
- [ ] Compose + CI 路径存在或列为阻塞  
- [ ] Env 表仅名称；有 `.env.prod.example`  
- [ ] 隔离与冒烟可执行；无密码/Token  
- [ ] 生产路径为 Portainer + GHCR + NPM + `qiuge.me`（或书面例外）

---

## 11. 相关文档指针

| 文档 | 用途 |
| --- | --- |
| [hk_vps_4_settings.md](./hk_vps_4_settings.md) | 野草云4 端口/网络/平台验收 |
| [../svr_hk_vps_3/new_deployment_instruction.md](../svr_hk_vps_3/new_deployment_instruction.md) | 野草云3 同构说明（域名多为 `*.agent-mate.ai`） |
| `knowledge/variables.md` | 占位符词汇 |
| `knowledge/03-semi-auto-release.md` | 半自动步骤 |
| `knowledge/09-isolation-safety.md` | 多应用隔离 |
| `knowledge/04-portainer.md` / `05-nginx-proxy-manager.md` / `08-cloudflare.md` | 工具细则 |
| `.claude/skills/release-guide/SKILL.md` | Agent 对话协议 |
| `specs/adr/` ADR-002 / ADR-003 | IMAGE_TAG；NPM Save + healthz |

有疑问时：优先本节点共享栈 + `{appname}.qiuge.me` 约定，不要另造反代、registry 或把业务域名塞进 `agent-mate.ai`。
