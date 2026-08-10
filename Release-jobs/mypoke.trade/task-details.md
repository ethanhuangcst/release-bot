# Release Job: mypoke.trade

Updated: 2026-08-10  
Status: **guided config (one question at a time)** — starting with DNS

## Q&A log (public domain)

_(appended as we go)_

## Target node

`38.55.192.140`（野草云3）

## Cloudflare DNS — recommended records for `mypoke.trade`

> Zone NS already: `felipe.ns.cloudflare.com` / `gail.ns.cloudflare.com`  
> Do **not** change records for `hcp.agent-mate.ai` or other zones.

### Required (site)

| Type | Name | Content | Proxy | TTL | Purpose |
| --- | --- | --- | --- | --- | --- |
| `A` | `@` | `38.55.192.140` | Proxied (orange) **or** DNS only (grey) for first SSL bring-up | Auto | Apex `mypoke.trade` → app node |
| `CNAME` | `www` | `mypoke.trade` | Same as apex (usually Proxied) | Auto | `www.mypoke.trade` → apex |

### Optional (only if you need them)

| Type | Name | Content | Proxy | Purpose |
| --- | --- | --- | --- | --- |
| `CNAME` | `www` | `mypoke.trade` | Proxied | Already listed above — keep one www record only |
| `AAAA` | `@` | _(omit unless you have a public IPv6)_ | — | Not required for this VPS |
| `A` / `CNAME` | `api` / `agent` / `rag` | — | — | **Do not** publicly expose Agent `:6335` or RAG `:3201` unless you explicitly want that |

### Email (Resend later — not required for first HTTP smoke)

When you enable Resend for `mypoke.trade`, add whatever Resend shows in their DNS setup (typical pattern):

| Type | Name | Content | Proxy |
| --- | --- | --- | --- |
| `TXT` | `@` or Resend-given host | SPF / verification as Resend instructs | DNS only |
| `CNAME` or `TXT` | Resend DKIM host | Resend value | DNS only |
| `TXT` | `_dmarc` | e.g. `v=DMARC1; p=none;` (your policy) | DNS only |

Do not invent SPF/DKIM values — copy from Resend dashboard.

### Explicitly out of scope for this app zone

| Do not add/edit | Why |
| --- | --- |
| Anything under `agent-mate.ai` / `hcp.agent-mate.ai` | Other app — isolation |
| Changing NS away from Cloudflare | Breaks the zone |

### Suggested first-time proxy mode

1. Create `A @` + `CNAME www` with **DNS only (grey cloud)**  
2. Configure NPM + Let’s Encrypt / certificate  
3. Then switch both records to **Proxied (orange)** and set Cloudflare SSL mode to **Full** or **Full (strict)** to match NPM

## Pending

- [x] Cloudflare `A @` → `38.55.192.140`（灰云）— user 2026-08-10
- [x] Cloudflare `CNAME www` → `mypoke.trade`（灰云）— user 2026-08-10
- [x] NPM Proxy Host Details（`mypoke-web:3000`）— user 2026-08-10
- [x] Let's Encrypt 证书已在 Certificates 列表（mypoke + www）— screenshot 2026-08-10
- [x] Proxy Host SSL 页挂上该证书 + Force SSL — user 2026-08-10
- [x] Browser smoke — phone cellular OK for mypoke; hcp OK earlier; local Wi‑Fi DNS was the blocker

## Status

**First public deploy complete**（橙云 + Full strict；QWEN/Resend；RAG 33 chunks；估价/上传图修复已上线）。用户确认：发布成功（2026-08-10）。

## Pending (optional follow-ups)

- [x] Cloudflare `@` + `www` → Proxied（橙云）— confirmed CF anycast + `server: cloudflare` 2026-08-10
- [x] Cloudflare SSL/TLS mode → Full (strict) — user 2026-08-10
- [x] 本机 Wi‑Fi DNS — 桌面已能开（user 2026-08-10）
- [x] QWEN / Resend 注入 `/opt/mypoke-trade/.env` + recreate — 2026-08-10（prod DB 未改）
- [x] Bugfix 2026-08-10: AI 估价 `MCP_FAILED` — agent 缺 `TCGDEX_BASE_URL`；已修 compose 并 recreate；节点复测 valuate HTTP 200
- [x] Bugfix 2026-08-10: 上传图不显示 — standalone 对 runtime `public/uploads` 404；已加 rewrite→API 流式读取 + uploads volume；web 已在节点重建
- [x] 上述修复已推 `mypoke.trade` `main` @ `4ad19bb`（含 agent TCGDEX_BASE_URL）

## Q&A log (public domain)

### Q1 — Apex A record
- **Q:** Cloudflare `A @` → `38.55.192.140` 是否已加好？
- **A:** 已加好，灰云

### Q2 — www CNAME
- **Q:** Cloudflare `CNAME www` → `mypoke.trade` 是否已加好？
- **A:** 已加好

### Q3 — NPM Proxy Host Details
- **Q:** Details（`mypoke-web:3000`）是否已保存？
- **A:** Details 已保存

### Q4 — 挂证书到 Proxy Host（调整后）
- **UI：** 顶栏 Certificates；Add = Let's Encrypt via HTTP / DNS / Custom
- **状态：** 证书已存在，无需再申请
- **Q:** Proxy Host → SSL 是否已选中该证并 Force SSL 保存？
- **A:** 证书已挂上

### Q5 — Browser smoke
- **A:** Wi‑Fi 下 1/2 打不开、3 hcp 正常 → 本机 DNS；**手机蜂窝能开**（2026-08-10）

### Q5b — DNS 界面 vs 本机解析
- **User:** DNS 一直在（截图正常；CF 蓝条误报可忽略）
- **Re-check:** DoH / `dig +tcp` → A `38.55.192.140`；HTTPS 307 OK

### Q6 — 改橙云
- **Q:** 是否改橙云 + Full/strict？
- **A:** 改橙云；手机能开；后桌面也能开（修本机 DNS 后）

### Q8a — SSL mode
- **A:** Full (strict)

### Q8b–d — QWEN/Resend + RAG index
- **A:** 用户提供了本地 `.env.local`（含密钥）；已合并 QWEN/Resend 到生产 `.env`（`mypoke_trade_prod` 未改）；容器 recreate；`rag:index` → 33 chunks ok
- **Security note:** 密钥曾出现在聊天；建议事后轮换 QWEN / Resend / DB 密码；勿再贴明文

