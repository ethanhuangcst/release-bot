# 部署说明（从用户提供文档入库 · 2026-08-10）

> **应用**：Social-Media Marketing Agent（`apps/web` + 内嵌 MCP 后端）  
> **架构**：单进程单端口；见仓库 `specs/`  
> **日期**：2026-08-10

---

## 1. 架构：单进程，单端口

本应用**只有一个对外服务**：Next.js Web 应用。MCP 后端（`@caa/socia-media-mkt`）以 **in-process 单例** 方式内嵌在 Web 进程里，**没有独立的 MCP 端口、没有跨进程通信**。

```
浏览器 ──HTTPS──▶ Next.js (单进程, 单端口)
                   └─ 内嵌 MCP 后端 (in-process, 无端口)
                       ├─ Playwright Chromium + data/profiles/{platform}/
                       ├─ DashScope LLM (出站 HTTPS)
                       └─ PostgreSQL (出站, DATABASE_URL)
```

- BFF 路由在同一 Node 进程里直接调用 MCP tool handlers。
- `npm run dev:socia-media-mkt` 仅本地调试，**部署不需要**。
- 不需要独立 MCP server，也不需要 `MCP_URL`。

---

## 2. 前置条件

| 依赖 | 版本 | 说明 |
|------|------|------|
| Node.js | **>= 22** | `engines.node` |
| npm | **10** | `packageManager: "npm@10"` |
| Playwright Chromium | 随 `postinstall` | 抓取与扫码 |
| PostgreSQL | 现代版本 | `DATABASE_URL` |
| OS | Linux / macOS | Linux 需 Chromium 系统库 |

---

## 3. 环境变量（摘要）

- `DASHSCOPE_API_KEY` / `DASHSCOPE_BASE_URL` / `DASHSCOPE_MODEL`
- `DATABASE_URL`
- `CRAWLER_MODE=live`
- `CRAWLER_HEADLESS=false`（抖音需要；无显示器配 xvfb）
- `MCP_DATA_DIR` → **必须持久化**（例：`/opt/social-media-mkt/data`）

---

## 4–8. 构建 / 数据 / Playwright / xvfb / 进程

- `npm install` → `npm run build` → `npm run start -w @caa/web`（默认 `:3000`）
- `MCP_DATA_DIR` 挂持久卷；含 `profiles/{douyin,bilibili,xiaohongshu,zhihu}/`
- Linux：`npx playwright install-deps chromium`
- 有头：`xvfb-run -a -s "-screen 0 1280x800x24" …`
- 进程：文档推荐 **PM2** 或 **systemd**（非必须 Docker）

---

## 9. 反向代理

- NPM/Nginx → `127.0.0.1:<HOST_PORT>`
- **SSE**：`proxy_buffering off` + `proxy_read_timeout 300s`

---

## 10–13. 首登 / 清单 / FAQ / 非目标

- 首次打开 `/login` 逐平台扫码
- 单实例；不横向扩展；无多租户

完整原文以仓库 `specs` / 用户粘贴为准；本文件为 release-job 摘要副本。
