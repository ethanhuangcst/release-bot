# 野草云3 — 运维方案与资源清单

> **节点**：野草云3 · `38.55.192.140`  
> **角色**：应用/边缘节点（标准平台层 + 多应用共存）  
> **采集**：SSH 实机只读快照 · **as_of: 2026-08-12**（kb 上线后）  
> **原则**：本文件不写密码 / Token；凭证仅存本机密钥库。  
> **姊妹节点蓝图**：[`../svr_hk_vps_4/hk_vps_4_settings.md`](../svr_hk_vps_4/hk_vps_4_settings.md)（目标与本文平台层同构）。

---

## 0. 标准运维方案（本节点真相；其他节点应对齐）

本节点是 **Release Bot 半自动发布** 的参考实现：应用不在边缘机 `docker build`，只 pull CI 制品；对外经 Cloudflare → NPM → 容器；主库在**外部** DB 机。

### 0.1 平台层（所有应用共用）

| 组件 | 作用 | 本机事实 |
| --- | --- | --- |
| Docker Engine | 跑容器 | Ubuntu 上安装 |
| 外部网络 `portainer_network` | 同节点容器互通；NPM 用容器名反代 | **共享，禁止删建** |
| Portainer CE | 按 Stack 部署/更新 compose | `https://portainer.agent-mate.ai` · Stack `root` |
| Nginx Proxy Manager | TLS + 反代 +（可选）Custom Locations | `https://nginx.agent-mate.ai` |
| Cloudflare | DNS（及橙云/SSL 模式） | 各应用独立域名/子域 |

平台层 Compose：`/root/service-compose.yaml`（Portainer + NPM，`networks.default.name: portainer_network`）。

### 0.2 应用如何部署（固定套路）

1. **仓库**：应用自己的 GitHub repo；CI（如 GHCR workflow）构建并推送镜像 `ghcr.io/<owner>/<repo>/<service>:<IMAGE_TAG>`。  
2. **Compose**：生产 compose **只用 `image:`**（无本地 `build:`）；`networks.default` → `external: true` / `name: portainer_network`。  
3. **Portainer**：独立 Stack（名 = `<STACK_NAME>`，勿泛名）；环境变量含 `IMAGE_TAG`、本应用 `DATABASE_URL` 等（密码不进 Git）。  
4. **数据库**：主库在**外部** MySQL/Postgres；先连通再按需迁移；库名/实例按应用隔离。可选本机向量库（Qdrant）或本机 RAG Postgres，仅内网。  
5. **域名**：Cloudflare 仅改本应用记录 → 本节点 IP；NPM 为本域名建 Proxy Host（上游用**容器名** + **容器内端口**）。多路径服务（如 MCP）用 Custom Locations。  
6. **隔离**：只改本 Stack / 本 NPM Host / 本 DNS；发布后抽查 ≥1 个既有应用；回滚默认只动本应用。  
7. **更新镜像**：改 Stack 的 `IMAGE_TAG`（须为 GHCR **已存在** tag，勿用分支名当 tag）→ Update + Re-pull；若 recreate 了 agent 类上游，NPM 对该 Host **再 Save 一次**，并验 `/healthz`。

手册入口：仓库根目录 `knowledge/`（尤其 `03-semi-auto-release.md`、`09-isolation-safety.md`）。

### 0.3 本节点已部署 / 规划应用

| Stack | 状态 | 域名 | 主库 |
| --- | --- | --- | --- |
| `hcp-engagement-agent` | 运行中 | `hcp.agent-mate.ai` | 外部 MySQL `…/hca` |
| `mypoke-trade` | 运行中 | `mypoke.trade` | 外部 Postgres `…/mypoke_trade_prod` |
| `kb-agent` | 运行中 | `kb.agent-mate.ai` | 外部 Postgres `…/kb_agent` |
| `media-mkt-agent` | 未部署（端口/域名已规划） | `media.mkt-agent.ai` | 外部 Postgres `…/media_marketing`（schema `mia`） |

---

## 1. 主机概览

| 项 | 值 |
| --- | --- |
| 公网 IP | `38.55.192.140` |
| Hostname | `r24f1lznj8prs2b` |
| OS / Kernel | Ubuntu · Linux `6.8.0-136-generic` x86_64 |
| CPU | 4 vCPU |
| Memory | 7.8 GiB（快照：used ~1.6 GiB，available ~6.2 GiB） |
| Swap | 无 |
| Disk `/` | 87G · used ~14G (16%) · avail ~73G |
| Docker 外部网 | `portainer_network`（**共享，禁止删建**） |

---

## 2. 共享运维栈（Stack: `root`）

| 服务 | 容器 | 镜像 | 主机端口 | 域名 / 入口 | 持久化 |
| --- | --- | --- | --- | --- | --- |
| Portainer CE | `portainer` | `portainer/portainer-ce:lts` | `9443`（UI）、`8000`（Edge） | `https://portainer.agent-mate.ai` → `portainer:9443` | volume `portainer_data`（~3M）+ docker.sock |
| Nginx Proxy Manager | `root_nginx-proxy-manager_1` | `jc21/nginx-proxy-manager:latest` | `80`、`443`、`81`（Admin） | `https://nginx.agent-mate.ai` → 容器 `:81` | bind `/root/data`、`/root/letsencrypt` |

Compose 来源：`/root/service-compose.yaml`（`networks.default.name: portainer_network`）。

### NPM Proxy Hosts（实机）

| ID | Domains | Forward | Port | SSL forced | Enabled | 备注 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `hcp.agent-mate.ai` | `38.55.192.140` | 3001 | 0 | 1 | 与 #2 重复；建议只保留容器名上游 |
| 2 | `hcp.agent-mate.ai` | `hcp-engagement-agent-web-1` | 3001 | 0 | 1 | 推荐保留 |
| 3 | `portainer.agent-mate.ai` | `portainer` | 9443 | 0 | 1 | |
| 4 | `nginx.agent-mate.ai` | `root_nginx-proxy-manager_1` | 81 | 0 | 1 | |
| 5 | `mypoke.trade`, `www.mypoke.trade` | `mypoke-web` | 3000 | 1 | 1 | LE 证书；到期约 2026-11-08 |
| — | `kb.agent-mate.ai` | `kb-web` | 3000 | 1 | 1 | Custom Locations → `kb-agent:8000`（`/mcp` `/sse` `/messages/` `/api/v1/kb/` `/healthz`） |

Redirection / Dead / Stream hosts：空。

---

## 3. 应用占用总览

| Stack / 项目 | 状态 | 公网域名 | 主机端口 | 本机数据 | 外部库 |
| --- | --- | --- | --- | --- | --- |
| `hcp-engagement-agent` | 运行中 | `hcp.agent-mate.ai` | 3001 / 3200 / `127.0.0.1:6333` | `/data/compose/12/data` | MySQL `38.55.199.241:3306/hca` |
| `mypoke-trade` | 运行中 | `mypoke.trade` (+ www) | 3002 / 6335 / 3201 | volumes + `/opt/mypoke-trade` | Postgres `101.132.156.250:5432/mypoke_trade_prod` |
| `media-mkt-agent` | **未部署**（已规划） | `media.mkt-agent.ai`（DNS 已指本机） | **预留 `3003`** | 计划 `/opt/social-media-mkt/data` | Postgres `101.132.156.250:5432/media_marketing`（schema `mia`） |
| `kb-agent` | **运行中**（2026-08-12） | `kb.agent-mate.ai` | **`3006` / `3202` / `3203` / `127.0.0.1:6336`** | volumes `kb_qdrant_data` / `kb_blob_data` | Postgres `101.132.156.250:5432/kb_agent` |
| `what2eat` | **未部署**（已规划） | `what2eat.food` | **预留 `3004→3000`** | — | Postgres `101.132.156.250:5432/**what2eat**`（专用库） |
| `where2play` | **未部署**（已规划） | `where2play.place` | **预留 `3005→3000`** | TBD | TBD |
| `places-agent` | **运行中**（2026-08-20） | `places.agent-mate.ai` | **`3007→3000`** | 无应用卷 | Postgres `101.132.156.250:5432/**places_agent**`（专用库） |

---

## 4. 按应用明细

### 4.1 `hcp-engagement-agent`

| 服务 | 容器 | 镜像 | 映射 | 角色 |
| --- | --- | --- | --- | --- |
| web | `hcp-engagement-agent-web-1` | `ghcr.io/ethanhuangcst/hcp-engagement-agent/web:latest` | `3001→3001` | Next/BFF |
| hcp-twin-mcp | `hcp-engagement-agent-hcp-twin-mcp-1` | `…/hcp-twin-mcp:latest` | `3200→3200` | MCP |
| qdrant | `hcp-engagement-agent-qdrant-1` | `qdrant/qdrant:v1.14.1` | `127.0.0.1:6333→6333` | 向量库（仅本机） |

| 资源 | 占用 |
| --- | --- |
| Compose 工作目录 | `/data/compose/12/`（Portainer stack id 12） |
| Bind mounts | `/data/compose/12/data` → `/data`；`…/data/qdrant` → `/qdrant/storage` |
| 网络 | `portainer_network` |
| 主库（外部） | MySQL `38.55.199.241:3306` / DB **`hca`** |
| 内网 URL | `MCP_URL=http://hcp-twin-mcp:3200`；`QDRANT_URL=http://qdrant:6333` |

**部署方式**：Portainer Stack；镜像来自 GHCR；NPM 反代 web；库在独立 MySQL 机。

---

### 4.2 `mypoke-trade`

| 服务 | 容器 | 镜像 | 映射 | 角色 |
| --- | --- | --- | --- | --- |
| web | `mypoke-web` | `ghcr.io/ethanhuangcst/mypoke.trade/web:latest` | `3002→3000` | Next（NPM 上游容器端口 **3000**） |
| agent | `mypoke-agent` | `…/agent:latest` | `6335→6335` | Agent（勿公网暴露） |
| rag | `mypoke-rag` | `…/rag:latest` | `3201→3201` | RAG（勿公网暴露） |
| postgres-rag | `mypoke-postgres-rag` | `…/postgres-rag:latest` | **无主机端口**（仅网内 `5432`） | pgvector |

| 资源 | 占用 |
| --- | --- |
| 工作目录 / env | `/opt/mypoke-trade/`（`docker-compose.prod.yml`、`.env`） |
| Volumes | `mypoke-trade_mypoke_web_uploads`；`mypoke-trade_mypoke_rag_pg_data` |
| 网络 | `portainer_network` |
| 主库（外部） | Postgres `101.132.156.250:5432` / **`mypoke_trade_prod`** |
| 本机 RAG 库 | `mypoke_rag` @ `mypoke-postgres-rag:5432` |

**部署方式**：Portainer Stack + 本机 compose/env 目录；业务库阿里云 Postgres；RAG 用本机 postgres-rag。

---

### 4.3 `media-mkt-agent`（规划中，节点上尚无容器）

| 项 | 规划值 |
| --- | --- |
| Stack / slug | `media-mkt-agent` |
| 域名 | `media.mkt-agent.ai`（A → `38.55.192.140` 已确认） |
| 主机端口 | **`3003→3000`**（尚未监听） |
| 数据卷 | `/opt/social-media-mkt/data`（`MCP_DATA_DIR`） |
| 主库（外部） | Postgres `101.132.156.250:5432` / **`media_marketing`** + schema **`mia`**（已建；勿碰 `media_crawler_mcp`） |
| 形态 | 单进程 Next + 内嵌 MCP；需 Chromium + xvfb |

---

### 4.4 `kb-agent`

| 服务 | 容器 | 镜像 | 映射 | 角色 |
| --- | --- | --- | --- | --- |
| web | `kb-web` | `ghcr.io/ethanhuangcst/kb.agent-mate.ai/web:<tag>` | `3006→3000` | Admin / Guide UI |
| agent | `kb-agent` | `…/agent:<tag>` | `3202→8000` | MCP + KB REST |
| rag | `kb-rag` | `…/rag:<tag>` | `3203→8001` | RAG / index |
| qdrant | `kb-qdrant` | `qdrant/qdrant:v1.13.2` | `127.0.0.1:6336→6333` | 向量（仅本机） |

| 资源 | 占用 |
| --- | --- |
| Compose | 仓库 `docker-compose.prod.yml`（job 镜像：`Release-jobs/kb.agent-mate.ai/docker.compose.prod.yml`） |
| Volumes | `kb_qdrant_data`；`kb_blob_data` |
| 网络 | `portainer_network` |
| 主库（外部） | Postgres `101.132.156.250:5432` / **`kb_agent`** |
| NPM | 主 Host → `kb-web:3000`；Custom Locations → `kb-agent:8000` |
| 运维注意 | Stack recreate 后 NPM Host 再 Save；验 `GET /healthz` → `{"status":"ok"}`；ChatBox 用 `/sse`（非 `/mcp`） |

**部署方式**：Portainer Stack `kb-agent`；`IMAGE_TAG` 取自 GHCR Packages 真实 tag；外部 Postgres + 本机 Qdrant/blob。

---

## 5. 主机端口分配表

| 端口 | 绑定 | 占用方 | 说明 |
| --- | --- | --- | --- |
| 22 | `*` | sshd | SSH |
| 80 / 443 | `*` | NPM | HTTP/HTTPS 入口 |
| 81 | `*` | NPM Admin | 建议仅经域名访问 |
| 8000 / 9443 | `*` | Portainer | Edge / UI |
| 3001 | `*` | hcp web | |
| 3002 | `*` | mypoke web | |
| **3003** | — | **预留 media-mkt-agent** | 当前空闲 |
| **3006** | `*` | **kb-agent web** | `3006→3000` |
| 3200 | `*` | hcp mcp | |
| 3201 | `*` | mypoke rag | 建议不对公网开放 |
| **3202** | `*` | **kb-agent agent** | `3202→8000` |
| **3203** | `*` | **kb-agent rag** | `3203→8001` |
| 6333 | `127.0.0.1` | hcp qdrant | 本机回环 |
| 6335 | `*` | mypoke agent | 建议不对公网开放 |
| **6336** | `127.0.0.1` | **kb-agent qdrant** | `127.0.0.1:6336→6333` |
| **3004** | — | **预留 places what2eat** | 规划 `3004→3000`；NPM → `what2eat-web:3000` |
| **3005** | — | **预留 places where2play** | 规划 `3005→3000` |
| **3007** | `*` | **places-agent** debug | `3007→3000`；NPM → `places-agent:3000` |
| **5435** | — | **what2eat 本地 dev Postgres** | 仅开发者机器 `docker-compose.dev.yml`；野草云3 不监听 |
| 25273 | `127.0.0.1` | containerd | 系统 |

新应用请避开上表已占用/预留端口。

---

## 6. Docker 卷与本机路径

### Named volumes

| Volume | 约大小 | 归属 |
| --- | --- | --- |
| `portainer_data` | ~3M | Portainer |
| `mypoke-trade_mypoke_rag_pg_data` | ~47M | mypoke RAG Postgres |
| `mypoke-trade_mypoke_web_uploads` | ~0.5M | mypoke 上传图 |
| `kb-agent_kb_qdrant_data`（或 `kb_qdrant_data`） | — | kb Qdrant |
| `kb-agent_kb_blob_data`（或 `kb_blob_data`） | — | kb blob |

### Bind / 目录

| 路径 | 用途 |
| --- | --- |
| `/root/data` · `/root/letsencrypt` | NPM 配置与证书 |
| `/root/service-compose.yaml` | Portainer + NPM compose |
| `/data/compose/12/data` | HCP 栈数据 |
| `/opt/mypoke-trade` | mypoke compose + `.env` |
| `/opt/social-media-mkt/data` | media（计划） |

---

## 7. 外部数据库（不在本节点）

| 引擎 | 主机 | 库 / schema | 使用方 | 备注 |
| --- | --- | --- | --- | --- |
| MySQL | `38.55.199.241:3306` | `hca` | hcp-engagement-agent | 独立 DB 机 |
| Postgres | `101.132.156.250:5432` | `mypoke_trade_prod` | mypoke-trade | 阿里云 |
| Postgres | `101.132.156.250:5432` | `media_marketing` / `mia` | media-mkt-agent | 已建库；应用未上线 |
| Postgres | `101.132.156.250:5432` | `media_crawler_mcp` | （其它） | **勿给生产 media 复用** |
| Postgres | `101.132.156.250:5432` | **`kb_agent`** | kb-agent | Alembic 已用 |
| Postgres | `101.132.156.250:5432` | **`what2eat`** | what2eat（规划） | 专用库；勿复用 kb/mypoke/media |
| Postgres | `101.132.156.250:5432` | **`places_agent`** | places-agent | 专用库；勿复用 `what2eat` |

本节点内另有：`mypoke_rag`（容器 `mypoke-postgres-rag`，无主机端口）。

---

## 8. 镜像体积（在用，快照）

| 镜像 | Size（约） |
| --- | --- |
| mypoke `web` / `agent` / `rag` / `postgres-rag` | ~412MB / 2.2GB / 2.2GB / 621MB |
| hcp `web` / `hcp-twin-mcp` | ~428MB / 1.19GB |
| `qdrant/qdrant` | ~281MB 级 |
| `jc21/nginx-proxy-manager` | ~1.79GB |
| `portainer/portainer-ce:lts` | ~187MB |

---

## 9. 网络成员（`portainer_network`）

| 容器 | 约 IPv4（会随 recreate 变化） |
| --- | --- |
| `root_nginx-proxy-manager_1` | 172.18.0.2 |
| `portainer` | 172.18.0.3 |
| HCP / mypoke / kb 各容器 | 以 `docker network inspect portainer_network` 为准 |

IP 仅作排障参考；NPM 上游应使用**容器名**，不要写死旧 IP。

---

## 10. 运维注意

1. **只改目标 Stack / 对应 NPM Host / 对应 DNS**；禁止删建 `portainer_network`。  
2. NPM 上 `hcp.agent-mate.ai` 有两条 Host（IP vs 容器名）——清理时勿碰其他域名。  
3. `media.mkt-agent.ai` DNS 已指本机，Stack/端口 **3003** 尚未部署。  
4. `kb.agent-mate.ai`：Stack recreate 后 NPM 再 Save；验 `/healthz`。  
5. Agent / RAG / Qdrant 主机端口默认不对公网开 Cloudflare。  
6. `IMAGE_TAG` 必须是 GHCR 已发布 tag（勿用分支名 `main`）。  
7. 刷新本清单：节点上 `docker ps`、`ss -lntup`、`docker volume ls`、`docker network inspect portainer_network`，只读 NPM DB 的 `proxy_host`。

---

## 11. 来源

- 实机：`38.55.192.140`（2026-08-10 SSH；kb 段 2026-08-12）  
- 任务：`Release-jobs/mypoke.trade/`、`Release-jobs/media-marketing-agent/`、`Release-jobs/kb.agent-mate.ai/`  
- 手册：`knowledge/03-semi-auto-release.md`、`knowledge/09-isolation-safety.md`  
- ADR：`specs/adr/ADR-002-…`、`specs/adr/ADR-003-…`
