# Release Job: kb.agent-mate.ai

Updated: 2026-08-12  
Status: **hardened after ClickFix** — public on **`v0.1.3`** (CSP nonce live; Next 15.5.7; `/healthz` ok)  
Guide: `Release-jobs/kb.agent-mate.ai/step-by-step.md`  
Incident KB: `specs/knowledge/ops/kb-agent-clickfix-incident-2026-08-12.md` · checklist · prevent note · ADR-004  
IMAGE_TAG: **`v0.1.3`** (prior: `v0.1.2` clean rebuild ← `v0.1.1` / `09a9d68`)  
Host ports: **`3006` / `3202` / `3203` / `6336`** (qdrant loopback bind still follow-up)

## Source

| Field | Value |
| --- | --- |
| Git | https://github.com/ethanhuangcst/kb.agent-mate.ai.git |
| Branch | `release-1` @ `bd34b6c` (handoff commit 2026-08-11) |
| Specs (this job) | `Release-jobs/kb.agent-mate.ai/deployment-plan.md` + `docker.compose.prod.yml` |
| App-repo plan | `specs/deployment-plan.md` on `release-1` |
| Target node | 野草云3 · `38.55.192.140` |
| Stack / slug | `kb-agent` / `kb` |
| Domain | `kb.agent-mate.ai` |
| Images | `ghcr.io/ethanhuangcst/kb.agent-mate.ai/{web,agent,rag}:<tag>` |
| External DB | Aliyun `101.132.156.250:5432` / **`kb_agent`** |
| Host ports | `3006` / `3202` / `3203` / `127.0.0.1:6336` |

## Docs reviewed

- [x] `Release-jobs/kb.agent-mate.ai/deployment-plan.md`
- [x] `Release-jobs/kb.agent-mate.ai/docker.compose.prod.yml` (mirrors repo `docker-compose.prod.yml`)
- [x] Local filled env template (job `.env` — **secrets stay local, never commit**)
- [x] `knowledge/03-semi-auto-release.md` + `09-isolation-safety.md`
- [x] `specs/hk_vps_3_resources.md` (as_of 2026-08-10)
- [x] GitHub `release-1` tree + `.github/workflows/ghcr.yml` + Actions runs (public API, 2026-08-12)

## Readiness gate (2026-08-12)

| Gate | Status | Notes |
| --- | --- | --- |
| App Dockerfiles + prod compose (image-only, `portainer_network`) | Pass | Present on `release-1` |
| Env names / prod values prepared | Pass (local) | Job `.env` filled; repo has `.env.example` (local), **no** committed `.env.prod.example` |
| DB created + Alembic (ops claim) | Pass (claimed) | Plan: through `005_import_batch` from workstation; **re-verify from 野草云3** still open |
| Port plan vs inventory | Pass (paper) | Avoids hcp 3001/3200/6333, mypoke 3002/3201/6335, reserved media **3003** |
| Isolation checklist live on node | Open | §10 not yet executed (`docker ps` / `ss`) |
| DNS `kb.agent-mate.ai` | **Fail** | `NXDOMAIN` via 1.1.1.1 / 8.8.8.8 (2026-08-12) |
| GHCR images for this ref | **Fail** | No `ghcr` workflow run on the repo; packages return 401 without auth |
| GHCR workflow triggers `release-1` | **Fail** | `on.push.branches` = `main`, `3-mvp03` only (+ `v*` tags + `workflow_dispatch`) |
| Portainer registry PAT (`read:packages`) | Unknown | Required if packages are private |
| NPM host + Custom Locations | Not started | `/mcp` `/sse` `/messages/` `/api/v1/kb/` |
| Aliyun PG whitelist for `38.55.192.140` | Open | Plan requires re-check from node |

### Verdict

**Cannot start Step 5 (Portainer deploy) yet.**  
**Can start Steps 0 / 0b** (isolation live check) and **must fix CI image push** before pull.

Recommended order before first stack create:

1. Trigger GHCR build for `release-1` (`workflow_dispatch` **or** add branch to workflow / merge to `main` / tag `v*`)
2. Confirm three images exist (`web` / `agent` / `rag`) and note usable tag (sha preferred over floating `latest` if not default branch)
3. Confirm Portainer can pull GHCR (PAT if private)
4. Live isolation on 野草云3 (§10)
5. DB connect from node + confirm `alembic_version`
6. Then Portainer → DNS → NPM → smoke

## Existing apps (spot-check later)

- `https://hcp.agent-mate.ai`
- `https://mypoke.trade`

## Q&A / progress log

| When | Note |
| --- | --- |
| 2026-08-12 | Preflight review: **blocked on GHCR + DNS**; compose/ports/env prep look good on paper |
| 2026-08-12 | User chose **C**: trigger GHCR via `main` push and/or `v*` tag (not release-1 dispatch) |
| 2026-08-12 | User pushed tag **`v0.1.0`** from local `knowledge.base` (`git push origin v0.1.0` OK) |
| 2026-08-12 | GHCR run [31511227059](https://github.com/ethanhuangcst/kb.agent-mate.ai/actions/runs/31511227059) **failed**: agent/rag OK; **web** `npm run build` fail — ESLint `react-hooks/rules-of-hooks` on `useLogTransport` in `apps/kb-web/lib/resend.ts`. Local fix: rename → `prefersLogTransport` (uncommitted in knowledge.base). |
| 2026-08-12 | Second web fail after ESLint fix: `guide/page.tsx` `Step` typed only as zh-CN literals. Fixed union with `en` steps. Local `npm run build` **green**. Awaiting commit + new tag (`v0.1.1`). |
| 2026-08-12 | User: GHCR **成功** — tag **`v0.1.1`** run [31511837500](https://github.com/ethanhuangcst/kb.agent-mate.ai/actions/runs/31511837500) success (`ebafaeb`) |
| 2026-08-12 | User clarified: still **Docker / Portainer / compose** path (same as mypoke/hcp); Step B was only GHCR pull auth check |
| 2026-08-12 | User: **回到 Step B**（Portainer GHCR registry） |
| 2026-08-12 | Portainer Registries 截图：已有 **`ghcr` → `ghcr.io`（authentication-enabled）** → Step B 视为通过 |
| 2026-08-12 | User: **不会 SSH** → Step C 改为 Portainer UI 隔离检查 |
| 2026-08-12 | User: **隔离检查通过**；要求对照 `specs/hk_vps_3_resources.md` |
| 2026-08-12 | User: 主机端口改为 **`3006` / `3202` / `3203`**（web `3004→3006`）；qdrant 仍 `127.0.0.1:6336` |
| 2026-08-12 | User Step D: **不确定，细查**（D2）— 阿里云 PG 白名单 + 库 `kb_agent` |
| 2026-08-12 | User: 阿里云库一直在用，野草云3 之前连库无问题 → **白名单视为 OK**；下一步确认库名 **`kb_agent`** |
| 2026-08-12 | Agent 实测连 `101.132.156.250/kb_agent`：**OK**；同实例另有 mypoke/media 库；`alembic_version=005_import_batch`；public tables=8 → **Step D 通过** |
| 2026-08-12 | Portainer Deploy **失败**：`error from registry: denied`（GHCR 拉取鉴权） |
| 2026-08-12 | User: 已用 **classic PAT** 勾上 `read:packages` → 下一步更新 Portainer ghcr 密码并重新 Deploy |
| 2026-08-12 | User: **已改 PAT 并 Deploy**（结果待确认：四容器是否 running） |
| 2026-08-12 | Portainer 截图：`kb-web`/`kb-agent`/`kb-rag`/`kb-qdrant` 全 **running**，镜像 `…:v0.1.1` → **Step E 通过** |
| 2026-08-12 | User: **DNS 完成**（`kb` → 野草云3） |
| 2026-08-12 | User: NPM SSL **界面与指南不符** — 使用顶栏 Certificates → Let's Encrypt via HTTP（新版 UI） |
| 2026-08-12 | User: **证书+挂载完成** → 进入 Smoke |
| 2026-08-12 | User: **冒烟通过** → 首次生产发布完成 |
| 2026-08-12 | ChatBox MCP：修 `https` + 去掉双 `Bearer` 后 **完成** |
| 2026-08-12 | **Incident**: Fake CAPTCHA / ClickFix via injected `data:text/javascript;base64` in kb-web HTML (post-deploy; smokes earlier same day were clean). Contained (Stop / Disable NPM / delete `kb` DNS). Rebuild **`v0.1.2`**. Likely vector clue: Next **15.5.2** [CVE-2025-66478](https://nextjs.org/blog/CVE-2025-66478). Shipped **`v0.1.3`**: nonce CSP + Next **15.5.7**; public CSP verified; `/healthz` ok after NPM Save. KB: `specs/knowledge/ops/kb-agent-clickfix-incident-2026-08-12.md`, `prevent-clickfix-html-inject.md`, `ir-public-webapp-compromise-checklist.md`. **Open**: DB/app secrets; qdrant bind; HTML monitor; host audit. |

## Pending

- [x] Run `ghcr` workflow for `release-1` (or promote ref that triggers CI) — **`v0.1.1` success**
- [x] Record `<IMAGE_TAG>` actually pushed — **`v0.1.1`**
- [x] Live isolation §10 on 野草云3 — **用户 Portainer UI 确认通过（2026-08-12）**
- [x] DB whitelist + `select 1` / `alembic_version` from node — **agent 自查 2026-08-12：kb_agent + 005_import_batch**
- [x] Portainer stack `kb-agent` — **四容器 running @ v0.1.1（2026-08-12）**
- [x] Cloudflare `kb` A → `38.55.192.140` (grey until LE OK) — **用户确认 2026-08-12**
- [x] NPM Proxy Host + path locations — **用户确认证书+挂载完成（2026-08-12）**
- [x] Smoke §9 + spot-check ≥1 existing app — **用户确认冒烟通过（2026-08-12）**
- [x] Update `specs/hk_vps_3_resources.md` after go-live — **本回合更新**
- [ ] Optional: Cloudflare `kb` 灰云 → 橙云 + SSL Full/strict
- [x] Optional: Cursor/ChatBox 远端 MCP 实机验证 — **ChatBox SSE 已通（2026-08-12；修 https + 单 Bearer）**
