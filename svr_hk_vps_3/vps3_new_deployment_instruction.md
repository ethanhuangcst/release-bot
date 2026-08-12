# 新项目部署说明 — 经 release-bot 发布到野草云3

**读者：** 将要写入 **新应用仓库**、并计划用 **release-bot** 发布的作者。  
**应用仓库必须产出：** `deployment-plan.md`（路径可为 `specs/deployment-plan.md` 或仓库根目录 `deployment-plan.md`）。  
**使用者：** 开启发布任务时，运维将该文件作为 release-bot 的主输入（密钥放在 Git 外）。

本文描述默认边缘节点 **野草云3** 的**目标架构与步骤**。请按本文撰写 `deployment-plan.md`，使只熟悉 release-bot 手册的智能体/运维能填占位符并跑半自动清单，而**不必另发明第二套部署方式**。

---

## 1. release-bot 是什么（以及不是什么）

| 是 | 不是 |
| --- | --- |
| **对话式引导**：一步一步带运维完成发布 | 无人值守、自行 SSH 改节点的完整 CI/CD |
| 依据本机手册 `release-bot/knowledge/` + 你的 `deployment-plan.md` | 存放生产密码的地方 |
| 期望 GitHub Actions 构建 **GHCR 镜像**；Portainer **只 pull** | 在 VPS 或运维笔记本上为生产环境 build 应用镜像 |

密钥只放本机密钥库 / Portainer 环境变量 / 节点 `.env`。切勿把密码、PAT、API Key 写入 `deployment-plan.md` 或 release-bot 仓库。

---

## 2. 目标运行时架构（野草云3）

```text
[浏览器]
    → Cloudflare DNS（可按需再开橙云）
        → 野草云3 上的 Nginx Proxy Manager（:80 / :443）
            → 共享网络 `portainer_network` 上的 Docker 容器
                → 出站访问外部 DB / LLM / 第三方
```

| 层级 | 野草云3 上的做法 |
| --- | --- |
| 节点 | **野草云3** · 公网 IP **`38.55.192.140`**（若过期，以 `svr_hk_vps_3/hk_vps_3_setting.md` 为准） |
| 容器 | Docker；用 **Portainer** `https://portainer.agent-mate.ai/` 管理 |
| 共享网络 | **`portainer_network`** — 已存在；**禁止删除或重建** |
| TLS / HTTP 入口 | **Nginx Proxy Manager** `https://nginx.agent-mate.ai/` |
| 镜像 | **`ghcr.io/<owner>/<repo>/<service>:<tag>`**，来自 GitHub Actions |
| 主库 | 通常在应用 compose **之外**（阿里云 / 其他 VPS 的 Postgres 或 MySQL） |
| 可选边车 | Agent、RAG、pgvector、Qdrant — 仅产品需要时才加；仍挂同一外部网络 |

### 多应用共存（硬规则）

节点上已有其他 Stack（历史上如：`hcp-engagement-agent`、`mypoke-trade`、`media-mkt-agent`、`kb-agent`）。你的计划必须：

- 使用唯一的 **Stack 名**、**容器名**、**卷名**、**主机端口**、**域名**，并尽量使用独立 **数据库名**
- **只**改本应用的 NPM Proxy Host 与本应用的 DNS 记录
- 上线后必须 **抽查 ≥1 个既有应用**

隔离规则正文见 release-bot `knowledge/09-isolation-safety.md`。

### 端口映射约定

| 位置 | 用哪个端口 |
| --- | --- |
| Compose `ports:` | `"<HOST_PORT>:<CONTAINER_PORT>"` — 主机端口须在野草云3 上空闲 |
| NPM Forward Port | **容器监听端口**（例如 Next 常见 `3000`），**不是**主机映射端口 |
| Forward Hostname | 优先 **Docker DNS 名** = `portainer_network` 上的 `container_name`（例如 `myapp-web`） |

主机端口以当前资源清单为准（`svr_hk_vps_3/hk_vps_3_setting.md`）或询问运维；勿复用已被占用的 `3001` / `3002` / `3003` / …。

---

## 3. 发布计划必须对齐的发布流程

release-bot 按 `knowledge/03-semi-auto-release.md` 执行。你的 `deployment-plan.md` 应让每一步**无需猜测即可作答**：

| 步骤 | 运维动作 | 计划中必须写清 |
| --- | --- | --- |
| 0 | 预检 | 仓库、默认分支/tag、服务、镜像、端口、域名、是否需要 DB |
| 0b | 隔离门禁 | 拟用 `STACK_NAME` / `APP_SLUG` / 端口 / 域名；冲突说明 |
| 1 | 应用仓库中的 Compose | 生产 compose 路径；应用服务仅 `image:`（无本地 `build:`）；`external` 网络 |
| 2 | CI → GHCR | 工作流路径；镜像名；tag（`latest` + sha 等） |
| 3 | 节点 / Portainer 环境变量 | 变量**名**（不要写密钥值）；哪些必填 |
| 4 | DB 连通 + 迁移 | 如何验库；迁移命令/路径或「无需迁移」 |
| 5 | Portainer 部署 | Stack 名；compose 片段或文件；卷挂载 |
| 6 | Cloudflare / DNS | Zone；记录类型；目标 IP；灰云/橙云建议 |
| 7 | NPM | 域名拼写；上游 host:port；SSL；SSE/WebSocket 附加配置 |
| 8 | 冒烟 | 要访问的 URL/路径；既有应用抽查清单 |

**顺序提醒：** DB 可达 → pull/部署容器 → DNS → NPM → 冒烟。容器未健康前不要指望公网 HTTPS。

---

## 4. 应用仓库必须已具备的内容

发布任务开始前，**应用**仓库应已有：

1. **`deployment-plan.md`**（本文要求的交付物）  
2. **生产 Dockerfile**（如 `docker/Dockerfile.*`）  
3. **`docker-compose.prod.yml`**（或等价文件），且满足：
   - 应用服务只用 `image: ghcr.io/...`  
   - `networks.default.external: true` + `name: portainer_network`  
   - 稳定的 `container_name` / 以 app slug 为前缀的卷名  
4. **GitHub Actions** 工作流：在约定分支/tag 上构建并推送到 GHCR  
5. **`.env.prod.example`**（或等价）：列出全部必填变量 — **不含真实密钥**  
6. 如需要：迁移说明/命令、Playwright/xvfb 说明、SSE 反代说明、首次登录手册  

release-bot **不会**另造一套架构。若本地文档写「裸机 PM2」，而平台标准是 Portainer+GHCR，则 **`deployment-plan.md` 必须以 Portainer 路径为生产路径**（或明确写出已批准的例外）。

---

## 5. `deployment-plan.md` — 必填章节

按下列大纲撰写。环境相关处保留占位符；已知处填具体值。

```markdown
# 部署计划 — <PRODUCT_NAME>

## 0. Meta
- 应用仓库：`<GITHUB_OWNER>/<GITHUB_REPO>`
- 首次部署默认 git ref：`main`（或 tag 策略）
- 目标节点：野草云3（`38.55.192.140`），除非运维另指定
- Stack 名：`<STACK_NAME>`
- App slug：`<APP_SLUG>`
- 公网域名：`<APP_DOMAIN>`（仔细拼写；拼错会导致 SNI 失败）

## 1. 架构（运行时）
- 图或列表：浏览器 → NPM → 哪些容器 → DB / API
- 进程模型：单进程 vs 多服务
- 何为进程内、何为独立容器
- 必须持久化的内容（路径 → 卷名）

## 2. 服务表
| Service | container_name | Image | 容器端口 | 主机端口 | 是否公网 | 职责 |
| --- | --- | --- | --- | --- | --- | --- |
| web | `<APP_SLUG>-web` | `ghcr.io/.../web` | 3000 | `<HOST_PORT>` | 是（经 NPM） | ... |

## 3. 镜像与 CI
- Dockerfile 路径
- 工作流路径：`.github/workflows/...`
- Registry：`ghcr.io`
- Tags：`latest` 和/或 git sha
- 构建说明（Node 版本、monorepo、Playwright、镜像源）

## 4. Compose 契约
- 生产 compose 文件路径
- 确认：无应用 `build:`；外部网 `portainer_network`
- 卷与 bind mount
- 如需：`shm_size` / 特殊 Docker 参数（如 Chromium）

## 5. 环境变量
| Name | Required | Notes |
| --- | --- | --- |
| `DATABASE_URL` | yes | 仅库名 `<DB_NAME>`；密码不写本文件 |
| `APP_URL` | yes | `https://<APP_DOMAIN>` |

## 6. 数据库
- 引擎 / 主机角色（外部阿里云 Postgres 等）
- `<DB_NAME>` / schema
- 迁移：命令，或「应用启动时建表」/「人工一次性」
- 隔离：绝不迁移其他应用的库

## 7. DNS 与 TLS
- Zone 与记录（`A` / `CNAME`）
- NPM 上 Let's Encrypt 成功前优先灰云
- NPM：Forward `http://<container_name>:<CONTAINER_PORT>`
- Force SSL；证书域名必须与 `<APP_DOMAIN>` **完全一致**

## 8. 反代附加项
- WebSockets：开/关
- SSE：`proxy_buffering off` + 长超时（流式 UI/agent 时）
- 仅当 Advanced 不可用时才用 Custom locations

## 9. 冒烟清单
- [ ] `https://<APP_DOMAIN>/`
- [ ] 健康检查/登录路径（列出确切路径）
- [ ] 关键用户旅程（一句话）
- [ ] 抽查野草云3 上 ≥1 个既有应用

## 10. 隔离清单（首次部署前填写）
- [ ] 对照当前节点清单检查 Stack / 端口 / 域名 / DB 名冲突
- [ ] 不会重建 `portainer_network`
- [ ] 不会改其他 NPM Host

## 11. 运维注意（应用特有）
- 首次登录 / 二维码 / 种子数据
- 有头浏览器 / Xvfb / `PLAYWRIGHT_BROWSERS_PATH`（爬虫类）
- 入口/镜像修复进行中时，不要在未重新 pull 的情况下「Update stack」
```

---

## 6. Compose 骨架（复制到应用仓库后再特化）

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
      APP_URL: ${APP_URL:-https://<APP_DOMAIN>}
    networks:
      - default

volumes:
  <APP_SLUG>_data:

networks:
  default:
    external: true
    name: portainer_network
```

仅当架构章节声明为独立容器时再增加服务。同网服务之间优先用 Docker DNS 名互通。

---

## 7. 已踩过的坑（相关时写进计划 §11）

以下问题已在野草云3 发生过；若你的应用会碰到，请在 §11 写明：

| 主题 | 建议 |
| --- | --- |
| 镜像拉取 | Portainer「Update」常常**不会**重新 pull `latest`；写明 Recreate + Pull，或删除本地 tag |
| NPM 域名 | 域名字符串必须与 DNS **完全一致**（`media.mkt-agent.ai` ≠ `media.mkt-agents.ai`）。写错 → Default Site / TLS `unrecognized_name` |
| NPM 上游 | 用容器名 + **容器**端口；主机端口仅用于调试 |
| Docker 内 Playwright | 浏览器装到运行时用户可读路径（`PLAYWRIGHT_BROWSERS_PATH`）；`appuser` 的 HOME 可写；`CRAWLER_HEADLESS=false` 时有头扫码需要 Xvfb |
| Entrypoint | 优先先起 `Xvfb` 再 `exec` 应用；脆弱的 `xvfb-run -s "..."` 引号在 Docker 下曾失败 |
| 健康检查 | 只检查 Playwright JS 模块的「chromium_available」不够；要冒烟真实登录/爬取 |
| 密钥 | 曾贴进聊天或出现在 Portainer 截图中的密钥应轮换 |

---

## 8. release-bot 如何使用你的文件

运维开启新任务时：

1. 将 `deployment-plan.md` 复制或链接到 `release-bot/Release-jobs/<job>/`（或让智能体指向应用仓库路径）  
2. release-bot 收集缺失占位符与现网 `<EXISTING_APPS>` 列表  
3. 执行：隔离门禁 → 核对 CI → Portainer → DNS → NPM → 冒烟  
4. 会话笔记写入 `release-bot/Release-jobs/<job>/` / `specs/sessions/` — **不把密钥写入 git**  

你的计划应足够稳定，使 Step 0 多为「确认」而非「从零设计」。

---

## 9. 撰写 `deployment-plan.md` 的完成标准

- [ ] §5 各节齐全（不用则显式标 N/A）  
- [ ] 服务/端口/镜像/域名/stack/slug 无歧义  
- [ ] Compose + CI 路径在应用仓库中存在（或列为阻塞项）  
- [ ] 环境变量表只列名称；存在 `.env.prod.example`  
- [ ] 隔离与冒烟清单具体可执行  
- [ ] 文件中无密码、Token、私钥  
- [ ] 生产路径为野草云3 上的 Portainer + GHCR + NPM（或写明已批准例外）

---

## 10. release-bot 内相关文档

| 文档 | 何时查阅 |
| --- | --- |
| `knowledge/variables.md` | 占位符词汇表 |
| `knowledge/03-semi-auto-release.md` | 步骤顺序 |
| `knowledge/09-isolation-safety.md` | 多应用安全 |
| `knowledge/04-portainer.md` / `05-nginx-proxy-manager.md` / `08-cloudflare.md` | 各工具细节 |
| `svr_hk_vps_3/hk_vps_3_setting.md` | 野草云3 当前端口/域名/Stack（过期则刷新） |
| `.claude/skills/release-guide/SKILL.md` | Agent 对话协议 |

有疑问时，优先沿用手册占位符与本节点共享栈，不要另发明反代或 registry。
