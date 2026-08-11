# 野草云3 — 资源清单

> **节点**：野草云3 · `38.55.192.140`  
> **用途**：应用/边缘节点（Docker + Portainer + Nginx Proxy Manager）  
> **采集**：SSH 实机只读快照 · **as_of: 2026-08-10**  
> **原则**：本文件不写密码 / Token；凭证仅存本机密钥库。

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

### NPM Proxy Hosts（实机 DB）

| ID | Domains | Forward | Port | SSL forced | Enabled | 备注 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `hcp.agent-mate.ai` | `38.55.192.140` | 3001 | 0 | 1 | 与 #2 重复；建议只保留容器名上游那条 |
| 2 | `hcp.agent-mate.ai` | `hcp-engagement-agent-web-1` | 3001 | 0 | 1 | 推荐保留 |
| 3 | `portainer.agent-mate.ai` | `portainer` | 9443 | 0 | 1 | |
| 4 | `nginx.agent-mate.ai` | `root_nginx-proxy-manager_1` | 81 | 0 | 1 | |
| 5 | `mypoke.trade`, `www.mypoke.trade` | `mypoke-web` | 3000 | 1 | 1 | LE 证书 id=1，到期约 2026-11-08 |
| — | `kb.agent-mate.ai` | `kb-web` | 3000 | 1 | 1 | 2026-08-12 上线；Custom Locations → `kb-agent:8000`（`/mcp` `/sse` `/messages/` `/api/v1/kb/` `/healthz`） |

Redirection / Dead / Stream hosts：空。

---

## 3. 应用占用总览

| Stack / 项目 | 状态 | 公网域名 | 主机端口 | 本机数据 | 外部库 |
| --- | --- | --- | --- | --- | --- |
| `hcp-engagement-agent` | 运行中（~2 weeks） | `hcp.agent-mate.ai` | 3001 / 3200 / `127.0.0.1:6333` | `/data/compose/12/data` | MySQL `38.55.199.241:3306/hca` |
| `mypoke-trade` | 运行中 | `mypoke.trade` (+ www) | 3002 / 6335 / 3201 | volumes + `/opt/mypoke-trade` | Postgres `101.132.156.250:5432/mypoke_trade_prod` |
| `media-mkt-agent` | **未部署**（端口/域名已规划） | `media.mkt-agent.ai`（DNS 已指本机） | **预留 `3003`** | 计划 `/opt/social-media-mkt/data` | Postgres `101.132.156.250:5432/media_marketing`（schema `mia`，库已建） |
| `kb-agent` | **运行中**（2026-08-12） | `kb.agent-mate.ai` | **`3006` / `3202` / `3203` / `127.0.0.1:6336`** | volumes `kb_qdrant_data` / `kb_blob_data` | Postgres `101.132.156.250:5432/kb_agent` |

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
| Bind mounts | `/data/compose/12/data` → `/data`（web、mcp）；`…/data/qdrant` → `/qdrant/storage` |
| 网络 | `portainer_network` |
| 主库（外部） | MySQL `38.55.199.241:3306` / DB **`hca`** |
| 内网 URL | `MCP_URL=http://hcp-twin-mcp:3200`；`QDRANT_URL=http://qdrant:6333` |
| 快照内存 | web ~99 MiB · mcp ~58 MiB · qdrant ~23 MiB |

---

### 4.2 `mypoke-trade`

| 服务 | 容器 | 镜像 | 映射 | 角色 |
| --- | --- | --- | --- | --- |
| web | `mypoke-web` | `ghcr.io/ethanhuangcst/mypoke.trade/web:latest` | `3002→3000` | Next（NPM 上游用容器端口 **3000**） |
| agent | `mypoke-agent` | `…/agent:latest` | `6335→6335` | Agent（勿公网暴露） |
| rag | `mypoke-rag` | `…/rag:latest` | `3201→3201` | RAG（勿公网暴露） |
| postgres-rag | `mypoke-postgres-rag` | `…/postgres-rag:latest` | **无主机端口**（仅网内 `5432`） | pgvector |

| 资源 | 占用 |
| --- | --- |
| 工作目录 / env | `/opt/mypoke-trade/`（含 `docker-compose.prod.yml`、`.env`） |
| Volumes | `mypoke-trade_mypoke_web_uploads`（~0.5M）→ `/app/public/uploads`；`mypoke-trade_mypoke_rag_pg_data`（~47M） |
| 网络 | `portainer_network` |
| 主库（外部） | Postgres `101.132.156.250:5432` / **`mypoke_trade_prod`** |
| 本机 RAG 库 | `mypoke_rag` @ `mypoke-postgres-rag:5432` |
| 快照内存 | web ~245 MiB · agent ~138 MiB · rag ~101 MiB · postgres-rag ~40 MiB |

---

### 4.3 `media-mkt-agent`（规划中，节点上尚无容器）

| 项 | 规划值 |
| --- | --- |
| Stack / slug | `media-mkt-agent` |
| 域名 | `media.mkt-agent.ai`（A → `38.55.192.140` 已确认） |
| 主机端口 | **`3003→3000`**（尚未监听） |
| 数据卷 | `/opt/social-media-mkt/data`（`MCP_DATA_DIR`） |
| 主库（外部） | Postgres `101.132.156.250:5432` / **`media_marketing`** + schema **`mia`**（已创建；勿碰 `media_crawler_mcp`） |
| 形态 | 单进程 Next + 内嵌 MCP；需 Chromium + xvfb |

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
| **3006** | `*` | **kb-agent web** | `3006→3000`（容器 `kb-web`） |
| 3200 | `*` | hcp mcp | |
| 3201 | `*` | mypoke rag | 建议不对公网开放 |
| **3202** | `*` | **kb-agent agent** | `3202→8000`（容器 `kb-agent`） |
| **3203** | `*` | **kb-agent rag** | `3203→8001`（容器 `kb-rag`） |
| 6333 | `127.0.0.1` | hcp qdrant | 本机回环 |
| 6335 | `*` | mypoke agent | 建议不对公网开放 |
| **6336** | `127.0.0.1` | **kb-agent qdrant** | `127.0.0.1:6336→6333`（容器 `kb-qdrant`） |
| 25273 | `127.0.0.1` | containerd | 系统 |

新应用请避开上表已占用/预留端口；media 用 **3003**；kb 已占用 **3006 / 3202 / 3203 / 6336**。

---

## 6. Docker 卷与本机路径

### Named volumes

| Volume | 约大小 | 归属 |
| --- | --- | --- |
| `portainer_data` | ~3M | Portainer |
| `mypoke-trade_mypoke_rag_pg_data` | ~47M | mypoke RAG Postgres |
| `mypoke-trade_mypoke_web_uploads` | ~0.5M | mypoke 上传图 |
| `kb-agent_kb_qdrant_data`（或 Portainer 命名的 `kb_qdrant_data`） | — | kb Qdrant |
| `kb-agent_kb_blob_data`（或 `kb_blob_data`） | — | kb blob 原文 |

### Bind / 目录

| 路径 | 用途 |
| --- | --- |
| `/root/data` · `/root/letsencrypt` | NPM 配置与证书 |
| `/root/service-compose.yaml` | Portainer + NPM compose |
| `/data/compose/12/data` | HCP 栈数据（含 qdrant storage） |
| `/opt/mypoke-trade` | mypoke compose + `.env` |
| `/opt/social-media-mkt/data` | media（计划，尚未创建） |

---

## 7. 外部数据库（不在本节点，但被本节点应用占用）

| 引擎 | 主机 | 库 / schema | 使用方 | 备注 |
| --- | --- | --- | --- | --- |
| MySQL | `38.55.199.241:3306` | `hca` | hcp-engagement-agent | 独立 DB 机 |
| Postgres | `101.132.156.250:5432` | `mypoke_trade_prod` | mypoke-trade | 阿里云实例 |
| Postgres | `101.132.156.250:5432` | `media_marketing` / `mia` | media-mkt-agent | 已建库；应用未上线 |
| Postgres | `101.132.156.250:5432` | `media_crawler_mcp` | （开发/其它） | **勿给生产 media 复用** |
| Postgres | `101.132.156.250:5432` | **`kb_agent`** | kb-agent | Alembic `005_import_batch`（2026-08-12 核实） |

本节点内另有：`mypoke_rag`（容器 `mypoke-postgres-rag`，无主机端口）。

---

## 8. 镜像体积（在用）

| 镜像 | Size（docker images） |
| --- | --- |
| mypoke `web` / `agent` / `rag` / `postgres-rag` | ~412MB / 2.2GB / 2.2GB / 621MB |
| hcp `web` / `hcp-twin-mcp` | ~428MB / 1.19GB |
| `qdrant/qdrant:v1.14.1` | ~281MB |
| `jc21/nginx-proxy-manager` | ~1.79GB |
| `portainer/portainer-ce:lts` | ~187MB |

---

## 9. 网络成员（`portainer_network`）

| 容器 | 约 IPv4 |
| --- | --- |
| `root_nginx-proxy-manager_1` | 172.18.0.2 |
| `portainer` | 172.18.0.3 |
| `hcp-engagement-agent-qdrant-1` | 172.18.0.4 |
| `hcp-engagement-agent-hcp-twin-mcp-1` | 172.18.0.5 |
| `hcp-engagement-agent-web-1` | 172.18.0.6 |
| `mypoke-postgres-rag` | 172.18.0.7 |
| `mypoke-rag` | 172.18.0.8 |
| `mypoke-agent` | 172.18.0.9 |
| `mypoke-web` | 172.18.0.10 |
| `kb-agent` / `kb-web` / `kb-rag` / `kb-qdrant` | 2026-08-12 加入（IP 以节点为准） |

---

## 10. 运维注意

1. **只改目标 Stack / 对应 NPM Host / 对应 DNS**；禁止 `docker network rm` 或重建 `portainer_network`。  
2. NPM 上 `hcp.agent-mate.ai` 存在 **两条** Proxy Host（#1 指 IP、#2 指容器名）——清理时只动 HCP，勿碰 mypoke / Portainer / NPM 自身。  
3. `media.mkt-agent.ai` DNS 已指本机，但 **3003 与 Stack 尚未部署**。  
4. `kb.agent-mate.ai` 已上线（Stack `kb-agent`，镜像 tag **`v0.1.1`**，端口 **3006/3202/3203/6336**）。  
5. Agent / RAG / Qdrant 主机端口默认不应对公网开 Cloudflare 记录。  
6. 刷新本清单（脱敏）：在节点上执行 `docker ps`、`ss -lntup`、`docker volume ls`、`docker network inspect portainer_network`，并只读查询 NPM `/root/data/database.sqlite` 的 `proxy_host`。

---

## 11. 来源

- 实机：`38.55.192.140`（2026-08-10 SSH 只读；kb 段 2026-08-12 发布会话更新）  
- 会话/任务：`Release-jobs/mypoke.trade/task-details.md`、`Release-jobs/media-marketing-agent/task-details.md`、`Release-jobs/kb.agent-mate.ai/task-details.md`  
- Compose 参考：`Release-jobs/mypoke.trade/deploy/docker-compose.prod.yml`、`Release-jobs/kb.agent-mate.ai/docker.compose.prod.yml`
