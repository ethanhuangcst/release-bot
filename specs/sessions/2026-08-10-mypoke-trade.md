# Session: MyPoke.Trade 首次部署

Date: 2026-08-10  
Status: COLLECT_CONTEXT — 部分确认，缺节点与共存清单

## 已确认（用户）

| 项 | 值 |
| --- | --- |
| 仓库 | https://github.com/ethanhuangcst/mypoke.trade.git |
| Owner/Repo | `ethanhuangcst` / `mypoke.trade` |
| IMAGE_TAG | `main`（以当次构建 sha/tag 为准） |
| 类型 | 首次部署 |
| APP_DOMAIN | `mypoke.trade` |
| 运维入口 | 沿用现有 Portainer / NPM / 外部网络 |
| 数据库 | 尚未新建库；需要迁移 |

## 建议默认（待用户确认）

| 项 | 建议值 |
| --- | --- |
| STACK_NAME | `mypoke-trade` |
| APP_SLUG | `mypoke` |
| PORTAINER_NETWORK | `portainer_network`（以实机为准） |

## 从仓库推断（2026-08-10，main）

| 项 | 推断 | 备注 |
| --- | --- | --- |
| 本地 compose | 仅 `postgres` + `postgres-rag` | **无** web/agent/rag 应用服务；无 GHCR；无 external network |
| Web 端口 | `3000` | Next.js |
| Agent 端口 | `.env.example` 为 **`3101`** | 用户口述 3001 — **不一致，需选定** |
| RAG 端口 | `.env.example` 为 **`3102`** | 用户口述 3002 — **不一致，需选定** |
| App DB | Postgres `mypoke` @ compose `5432` | 生产需独立实例或带前缀的 stack 内库 |
| RAG DB | pgvector `mypoke_rag` @ compose `5433` | 与 App DB 分离 |
| 迁移命令 | `npm run db:migrate` / `make db-migrate` | Drizzle |
| CI / GHCR | **仓库内未见** `.github/workflows` | 首次部署前需补 compose 应用服务 + build 工作流 |

## 未决（阻塞隔离门禁）

- [ ] NODE_NAME / NODE_IP  
- [ ] EXISTING_APPS（同节点 Stack / 域名 / 已占用端口）  
- [ ] 生产 DB：沿用哪台 Postgres，还是在本 stack 内起 `mypoke-postgres`（须避开他人 5432/5433）  
- [ ] 对外端口最终：`3000/3101/3102` 还是 `3000/3001/3002`  
