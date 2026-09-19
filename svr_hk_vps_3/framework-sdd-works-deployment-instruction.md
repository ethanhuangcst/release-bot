# Step-by-step — framework.sdd.works → 野草云3

Guided release for stack **`framework-sdd-works`**. Follow in order. Do **not** skip GHCR before Portainer pull.

**Capability (Sprint 7, MVP-7):** Admin portal (Keys, Settings, Framework cache tree, accounts) plus **Streamable HTTP MCP** at `/mcp`. End users connect via `https://framework.sdd.works/mcp` (Bearer auth). Package install/update over HTTP returns tarball URLs (ADR-054); stdio binaries ship via **GitHub Releases only** — not on this node.

**Unlike `places-agent`:** **two** containers in one stack — Next portal (`framework-sdd-web`) and sibling MCP HTTP (`framework-sdd-mcp`). NPM uses **one** Proxy Host for the domain plus a **Custom Location** for `/mcp` (kb-agent pattern). **Do not** route the whole hostname to the MCP container.

**Canonical specs:** [`specs/tech-spec.md`](../tech-spec.md) · [`specs/mcp/mcp-design.md`](../mcp/mcp-design.md)  
**App repo:** `ethanhuangcst/workspace.framework.sdd.works`

---

## Consoles (do not paste passwords into chat)

| Console | URL |
| --- | --- |
| GitHub Actions | https://github.com/ethanhuangcst/workspace.framework.sdd.works/actions |
| GHCR packages | https://github.com/ethanhuangcst/workspace.framework.sdd.works/pkgs/container/workspace.framework.sdd.works%2Fweb |
| GitHub Releases (stdio binary) | https://github.com/ethanhuangcst/workspace.framework.sdd.works/releases |
| Portainer | https://portainer.agent-mate.ai/ |
| NPM | https://nginx.agent-mate.ai/ |
| Cloudflare | zone **`sdd.works`** → DNS |
| App (after go-live) | https://framework.sdd.works |

---

## Fixed facts

| Item | Value |
| --- | --- |
| Target node | **野草云3** · public IP **`38.55.192.140`** |
| Stack name | **`framework-sdd-works`** (exact) |
| Web container | **`framework-sdd-web`** |
| MCP container | **`framework-sdd-mcp`** |
| Public domain | **`framework.sdd.works`** (exact spelling — SNI breaks on typos) |
| Image (proposed) | `ghcr.io/ethanhuangcst/workspace.framework.sdd.works/web:<IMAGE_TAG>` |
| Web process | **`next start -p 3000`** (Next.js 16 App Router) |
| MCP process | **`node` / `tsx` `src/mcp/http-server.ts`** — Streamable HTTP on **`3041`**, path **`/mcp`** |
| Web container listen | **`3000`** |
| MCP container listen | **`3041`** (internal; NPM Custom Location forwards `/mcp` here) |
| Host bind (debug only) | **`3008→3000`** (web), **`3204→3041`** (mcp). NPM Forward uses **container** ports, **not** `3008` / `3204`. |
| Database | **PostgreSQL** Aliyun **`framework_sdd`** on `101.132.156.250:5432`. Dedicated db — **not** `places_agent`, `kb_agent`, `mypoke_trade_prod`, etc. |
| Package cache volume | **`framework_sdd_packages`** → mount at **`/data/sdd-packages`** on **both** services (`SDD_PACKAGE_CACHE_DIR`) |
| Network | existing **`portainer_network`** (**never delete/recreate**) |
| Stdio MCP | **Not deployed** on 野草云3 — GitHub Releases / local dev only (ADR-051, ADR-053) |
| Qwen (`QWEN_*`) | **N/A on this node** — HTTP MCP does not run path-discovery LLM (ADR-054) |
| Env name template | app repo `.env.prod.example` (names only) |
| Spot-check after deploy | `https://places.agent-mate.ai/v1/health` · `https://kb.agent-mate.ai/healthz` · `https://mypoke.trade/` |

### MCP client URLs (after go-live)

| Client | URL | Auth |
| --- | --- | --- |
| Cursor (Streamable HTTP) | `https://framework.sdd.works/mcp` | `Authorization: Bearer <MCP_AUTH_TOKEN>` |
| Instructions / setup prompt | `https://framework.sdd.works/agent-setup` | none (public markdown) |
| Package API (stdio clients) | `https://framework.sdd.works/api/sdd/versions` · `/api/sdd/package` | none (public read) |

**Do not** expose MCP on port `3204` to Cloudflare. Public MCP is **only** via NPM → Custom Location `/mcp`.

---

## Architecture (runtime)

```text
[Browser / MCP client]
    → Cloudflare DNS (framework.sdd.works)
        → NPM :443
            → / (portal, BFF, package API)     → framework-sdd-web:3000
            → /mcp (Custom Location)           → framework-sdd-mcp:3041
                    │
                    ├── Aliyun Postgres (framework_sdd)
                    ├── GitHub API (GITHUB_TOKEN — sync job)
                    └── shared volume /data/sdd-packages (SYNK cache)
```

Both containers share:

- **`DATABASE_URL`** (Prisma — admins, keys, settings)
- **`SDD_PACKAGE_CACHE_DIR=/data/sdd-packages`** (manifest + unpacked tarball — Framework page + HTTP install)
- **`GITHUB_TOKEN`** (server-side repo sync only)

Only **`framework-sdd-web`** runs **`prisma migrate deploy`** + **`prisma db seed`** on boot. MCP container starts HTTP only (no double-seed).

Scheduled sync (30 min) starts via Next **`instrumentation.ts`** when `GITHUB_TOKEN` is set on the web container.

---

## Pre-flight — app-repo blockers

**Stop before Portainer** if any row is still missing in the app repo.

| Artifact | Status (check repo) | Required for |
| --- | --- | --- |
| `Dockerfile` | **Present** | GHCR build; multi-stage Next standalone + Prisma generate |
| `docker-compose.prod.yml` | **Present** | Portainer stack; image-only; two services; external `portainer_network` |
| `.github/workflows/ghcr.yml` | **Present** | CI → GHCR (`latest` + git sha tags) |
| `.env.prod.example` | **Present** | Portainer env checklist (names only) |
| `docker-entrypoint-web.sh` | **Present** | `migrate deploy` + `db seed` then `node server.js` (standalone) on web only |
| This instruction | Present | Operator guide |

**Dockerfile requirements (when landing):**

- Node 22 LTS
- `npm ci` → `prisma generate` → `next build`
- Listen **`0.0.0.0`** — set `HOSTNAME=0.0.0.0`, `PORT=3000` for web
- MCP service command: `node` (or `tsx`) `src/mcp/http-server.ts` with `MCP_HTTP_HOST=0.0.0.0`

**Do not** commit real secrets. Production values live in Portainer only.

---

## Production artifacts & operator prerequisites

Complete this section **before** Step A. Nothing here goes in git — store secrets in your password manager and Portainer stack env only.

### 1. App repo artifacts

| Artifact | Status | Blocks |
| --- | --- | --- |
| `Dockerfile` | **Present** | — |
| `docker-compose.prod.yml` | **Present** | — |
| `.github/workflows/ghcr.yml` | **Present** | — |
| `.env.prod.example` | **Present** | — |
| `docker-entrypoint-web.sh` | **Present** | — |

Step A (GHCR) unblocked after push to `main`. Portainer (Step E) still awaits operator secrets + `IMAGE_TAG`.

### 1b. Operator values ledger (single source of truth)

**Never commit secret values.** Status only — store values in Portainer / password manager.

| Resource / secret | Status | Notes |
| --- | --- | --- |
| Aliyun host `101.132.156.250:5432` | **Confirmed** | Shared Postgres host (sibling apps) |
| Database `framework_sdd` | **Created** | Empty DB provisioned 2026-09-18 |
| Postgres superuser / DSN | **Operator-held** | Use `postgresql://USER:PASSWORD@101.132.156.250:5432/framework_sdd` in Portainer only |
| `SESSION_SECRET` | **Pending** | Generate before Step E |
| `KEYS_ENCRYPTION_KEY` | **Pending** | 64 hex chars; immutable after first Keys write |
| `ADMIN_SEED_PASSWORD` | **Pending** | Required for seed (SEED-01) |
| `GITHUB_TOKEN` | **Pending** | `contents:read` on framework package source repo |
| `MCP_AUTH_TOKEN` | **Pending** | Bearer for public `/mcp` |
| `RESEND_API_KEY` / `MAIL_FROM` | **Pending** | P1 — mail flows |
| `GITHUB_WEBHOOK_SECRET` / `CRON_SECRET` | **Pending** | P2 — optional at go-live |
| GHCR read PAT (Portainer registry) | **Pending** | `read:packages` if private pull fails |
| `IMAGE_TAG` | **Pending** | Set after Step A GHCR build completes |

### 2. Infrastructure to provision (not env vars)

| Resource | Planned value | Operator action |
| --- | --- | --- |
| **Aliyun Postgres database** | `framework_sdd` on `101.132.156.250:5432` | **Created** — set `DATABASE_URL` in Portainer (operator-held credentials) |
| **DNS** | `framework.sdd.works` → `38.55.192.140` | Cloudflare A record in zone `sdd.works` (grey cloud until LE) |
| **Host ports** | `3008→3000`, `3204→3041` | Confirm free on 野草云3 (see [`hk_vps_3_setting.md`](./hk_vps_3_setting.md)) |
| **Docker volume** | `framework_sdd_packages` | Created by compose; SYNK cache at `/data/sdd-packages` |
| **Portainer stack** | `framework-sdd-works` | Two services on `portainer_network` |
| **NPM Proxy Host** | `framework.sdd.works` | Main → `framework-sdd-web:3000`; Custom Location `/mcp` → `framework-sdd-mcp:3041` |
| **TLS certificate** | Let's Encrypt via NPM | Domain must match DNS exactly |
| **GHCR image** | `ghcr.io/ethanhuangcst/workspace.framework.sdd.works/web:<tag>` | Built by CI after repo artifacts land |

### 3. Operator credentials (outside Portainer stack env)

These are **not** pasted into this file. Prepare them in your secret store before deploy.

| Credential | Used for | How to obtain | Notes |
| --- | --- | --- | --- |
| **Aliyun Postgres DSN** | `DATABASE_URL` | Aliyun console → user + password for `framework_sdd` | Shape: `postgresql://USER:PASSWORD@101.132.156.250:5432/framework_sdd` — **never** reuse `places_agent` / `kb_agent` credentials |
| **GHCR read PAT** | Portainer → Registries → `ghcr.io` | GitHub → Settings → Developer settings → PAT with **`read:packages`** | SSO authorize if org packages are private |
| **GitHub API token** | `GITHUB_TOKEN` | Fine-grained or classic PAT with **`contents:read`** on the **framework package source repo** (Settings URL target) | Server-side sync only; never in browser |
| **GitHub webhook secret** | `GITHUB_WEBHOOK_SECRET` | Generate random string; register in GitHub repo → Webhooks → `https://framework.sdd.works/api/github/webhook` | Optional until webhook configured |
| **Cron bearer secret** | `CRON_SECRET` | Generate random string; use as `Authorization: Bearer …` on `POST /api/sync/cron` | Optional backup sync trigger |
| **Session signing secret** | `SESSION_SECRET` | `openssl rand -base64 32` (or equivalent) | Rotating invalidates all admin sessions |
| **Keys encryption key** | `KEYS_ENCRYPTION_KEY` | `openssl rand -hex 32` (64 hex chars) | **Immutable after first Keys write** — changing it breaks existing encrypted rows (ADR-048) |
| **MCP HTTP bearer** | `MCP_AUTH_TOKEN` | `openssl rand -base64 32` | Required on public `/mcp`; share with MCP clients only |
| **Resend API key** | `RESEND_API_KEY` | Resend dashboard | Required for password reset / invite mail |
| **Admin bootstrap password** | `ADMIN_SEED_PASSWORD` | Operator-chosen strong password | Seed fails if blank; change via portal after first login |

### 4. Portainer environment variables

Set in stack **`framework-sdd-works`** (both containers unless noted). Values **never** in git.

#### P0 — Blockers (minimum go-live)

| Name | Service | Required value / shape | If missing |
| --- | --- | --- | --- |
| `IMAGE_TAG` | both | GHCR tag (git **sha** preferred) | Pull fails or wrong image |
| `NODE_ENV` | both | `production` | Wrong cookie/security behavior |
| `DATABASE_URL` | both | Aliyun `framework_sdd` DSN | App / MCP cannot start |
| `PUBLIC_BASE_URL` | both | `https://framework.sdd.works` | Wrong links in mail / MCP responses |
| `SESSION_SECRET` | web | Random secret | Admin login broken |
| `ADMIN_SEED_EMAIL` | web | e.g. `me@ethanhuang.com` | Seed uses default email |
| `ADMIN_SEED_USERNAME` | web | `admin` | Seed uses default username |
| `ADMIN_SEED_PASSWORD` | web | Non-empty password | **Seed throws; container exits** |
| `KEYS_ENCRYPTION_KEY` | both | 64-char hex | Keys CRUD fails |
| `GITHUB_TOKEN` | both | GitHub PAT `contents:read` | Sync / Framework tree / package API empty |
| `MCP_AUTH_TOKEN` | mcp | Random bearer | **Do not expose `/mcp` publicly without this** |
| `MCP_HTTP_HOST` | mcp | `0.0.0.0` | MCP not reachable from NPM |
| `MCP_HTTP_PORT` | mcp | `3041` | NPM Custom Location mismatch |
| `MCP_HTTP_PATH` | mcp | `/mcp` | Client URL mismatch |
| `SDD_PACKAGE_CACHE_DIR` | both | `/data/sdd-packages` | Install / Framework page cache broken |
| `SDD_SERVER_URL` | mcp | `https://framework.sdd.works` | HTTP install returns wrong package URLs |
| `PORT` | web | `3000` | Next listen mismatch |
| `HOSTNAME` | web | `0.0.0.0` | Container not reachable from NPM |
| `APP_NAME` | both | `framework.sdd.works` | Branding / logs |

#### P1 — Full admin portal (mail flows)

| Name | Service | Required when | If missing |
| --- | --- | --- | --- |
| `RESEND_API_KEY` | web | Password reset or invite needed | Mail sends fail |
| `MAIL_FROM` | web | Same | Resend rejects send |
| `RESEND_HOST` | web | Optional | Defaults to `api.resend.com` |
| `RESEND_BASE_URL` | web | Optional | Resend API base override |
| `SMTP_URL` | web | Only if bypassing Resend | Unused if Resend configured |

#### P2 — Freshness automation (recommended)

| Name | Service | Required when | If missing |
| --- | --- | --- | --- |
| `GITHUB_WEBHOOK_SECRET` | web | GitHub push webhook configured | Webhook returns 401 |
| `CRON_SECRET` | web | External cron hits `/api/sync/cron` | Cron route rejected |
| `GITHUB_API_HOST` | both | Optional | Default `api.github.com` |
| `GITHUB_API_BASE_URL` | both | Optional | Default `https://api.github.com` |

#### Omit on Server 2 (prod)

| Name | Reason |
| --- | --- |
| `QWEN_*` | Stdio path-discovery LLM only (ADR-047); HTTP MCP does not call Qwen |
| `MCP_HTTP_PORT` on **web** | MCP runs in sibling container |
| `GITHUB_FIXTURE` | CI fixture only |
| `E2E_*` / `PLAYWRIGHT_*` | Test harness only |

#### Optional overrides

| Name | Service | Default if unset |
| --- | --- | --- |
| `MCP_PUBLIC_URL` | mcp | Derived from `PUBLIC_BASE_URL` + `/mcp` in prod |

### 5. Post-deploy configuration (portal UI — not environment variables)

After stack is healthy, configure in the **admin portal** (stored in Postgres, not Portainer):

| Item | Where | Required for |
| --- | --- | --- |
| **GitHub repository URL** | Settings → save reachable repo URL | SYNK sync, Framework tree, `sdd_list_versions`, HTTP install inventory |
| **API keys** (`key_name` / `key_value`) | Keys → create | `sdd_get_key` MCP tool |
| **Admin password rotation** | Login / profile | Replace known `ADMIN_SEED_PASSWORD` after bootstrap |
| **Additional admins** | Accounts → invite | Team access (needs P1 mail) |

Without Settings URL + force sync, `GET /api/sdd/versions` returns **`409 sync_pending`**.

### 6. Pre-go-live checklist (artifacts + secrets)

**Repo**

- [ ] `Dockerfile`, `docker-compose.prod.yml`, `ghcr.yml`, `.env.prod.example`, web entrypoint exist on `main`
- [ ] GHCR image built; **`IMAGE_TAG`** recorded

**Infrastructure**

- [ ] Aliyun database **`framework_sdd`** exists; DSN tested from 野草云3
- [ ] Ports **`3008`** / **`3204`** free (or substitutes documented)
- [ ] DNS **`framework.sdd.works`** → `38.55.192.140`

**Secrets in Portainer (P0)**

- [ ] `DATABASE_URL`, `SESSION_SECRET`, `KEYS_ENCRYPTION_KEY`, `ADMIN_SEED_PASSWORD`
- [ ] `GITHUB_TOKEN`, `MCP_AUTH_TOKEN`
- [ ] `PUBLIC_BASE_URL`, `SDD_SERVER_URL`, MCP listen vars

**Secrets for mail (P1 — if using reset/invite)**

- [ ] `RESEND_API_KEY`, `MAIL_FROM`

**External**

- [ ] Portainer can pull `ghcr.io` (read PAT if needed)
- [ ] NPM Proxy Host + `/mcp` Custom Location + SSL

**After smoke**

- [ ] Settings GitHub URL saved and sync succeeded
- [ ] At least one Key created (if testing `sdd_get_key`)
- [ ] Default admin password changed

---

## Step A — Build & push GHCR image (blocker)

1. Confirm `.github/workflows/ghcr.yml` exists and builds image `ghcr.io/ethanhuangcst/workspace.framework.sdd.works/web`.
2. Push to `main` or run workflow dispatch on the agreed ref (or release tag `v*`).
3. Wait until the workflow is green.
4. Open GitHub **Packages** and confirm the tag exists.
5. Record **`IMAGE_TAG`**:
   - Prefer the **git sha** tag from the run (reliable for rollbacks)
   - `latest` only if you confirmed it was pushed for this ref
   - **Never** use git branch name `main` as `IMAGE_TAG`

**Done when:** image exists on GHCR; you have a concrete tag string for Portainer.

---

## Step B — Portainer can pull GHCR

1. Portainer → **Registries**
2. If pull returns 401: add `ghcr.io` with a PAT that has **`read:packages`** (SSO authorize if required)
3. Do not put the PAT in chat or git

**Done when:** registry works (or other `ethanhuangcst/*` images already pull successfully).

---

## Step C — Isolation gate (live on 野草云3)

On the node (SSH):

```bash
docker ps --format 'table {{.Names}}\t{{.Ports}}\t{{.Image}}'
docker volume ls | grep -E 'framework_sdd|places_agent|kb_|mypoke|hcp' || true
ss -lntup | grep -E ':3008|:3204|:3007|:3006|:3004|:3005' || true
```

Confirm for **framework-sdd-works**:

- [ ] No stack named `framework-sdd-works` (unless this is an intentional update)
- [ ] No containers `framework-sdd-web` / `framework-sdd-mcp` (unless updating)
- [ ] **Proposed host ports `3008` and `3204`** free (if taken, pick other unused ports and record them in Portainer compose)
- [ ] Will **not** take occupied/reserved ports: `3001`–`3007`, `3200`–`3203`, `6333`, `6335`, `6336` (see [`hk_vps_3_setting.md`](./hk_vps_3_setting.md))
- [ ] Will **not** delete/recreate `portainer_network`
- [ ] Will **not** edit other stacks (`places-agent`, `kb-agent`, `mypoke-trade`, `hcp-engagement-agent`, `root`)
- [ ] Domain **`framework.sdd.works`** not used by another NPM host
- [ ] Database name **`framework_sdd`** does not collide with an existing app's schema usage

Inventory reference: [`hk_vps_3_setting.md`](./hk_vps_3_setting.md) (refresh if stale).

**Done when:** operator replies **「隔离检查通过」**.

---

## Step D — Database (Aliyun Postgres `framework_sdd`)

framework.sdd.works uses **off-node Postgres** (same host as sibling apps, **different database**).

1. On Aliyun Postgres (`101.132.156.250:5432`), create empty database **`framework_sdd`** (if not exists).
2. **Do not** use `places_agent`, `kb_agent`, `mypoke_trade_prod`, `what2eat`, `media_marketing`, or `hca`.
3. Set `DATABASE_URL=postgresql://…@101.132.156.250:5432/framework_sdd` in Portainer (secret — not in git).
4. **Prefer migrate-on-boot:** web container entrypoint runs **`prisma migrate deploy`** then **`prisma db seed`** once.
5. **Do not** run `prisma migrate deploy` from a laptop against prod unless you explicitly accept that ops risk.

### First-boot admin (seed)

Seed reads **`ADMIN_SEED_PASSWORD`** — **required**; seed **fails** if blank (SEED-01).

| Variable | Value |
| --- | --- |
| `ADMIN_SEED_EMAIL` | `me@ethanhuang.com` (or operator override) |
| `ADMIN_SEED_USERNAME` | `admin` |
| `ADMIN_SEED_PASSWORD` | Strong password — set once in Portainer; rotate via portal after first login |

Re-running seed with a new `ADMIN_SEED_PASSWORD` updates the admin hash (upsert).

**Done when:** `DATABASE_URL` points at dedicated `framework_sdd`; bootstrap password strategy agreed.

---

## Step E — Portainer Create/Update stack `framework-sdd-works`

1. https://portainer.agent-mate.ai/ → Endpoint = **野草云3**
2. **Stacks → Add stack** (or Update existing)
3. Name: **`framework-sdd-works`** (exact)
4. Build method: **Web editor**
5. Paste full **`docker-compose.prod.yml`** from the app repo (skeleton: **Appendix A**)
6. **Environment variables** — full checklist in **[Production artifacts & operator prerequisites](#production-artifacts--operator-prerequisites)** (§4 P0/P1/P2). Copy names from `.env.prod.example` once it exists in the repo. At minimum set all **P0** rows before Deploy.

7. Confirm network block:

```yaml
networks:
  default:
    external: true
    name: portainer_network
```

8. Confirm **shared volume** `framework_sdd_packages` mounted on **both** services at `/data/sdd-packages`.
9. **Deploy the stack** (Recreate + **Pull** if updating image)
10. Containers **`framework-sdd-web`** and **`framework-sdd-mcp`** → **running**
11. Glance other stacks — they should **not** mass-restart
12. Internal checks (from node):

```bash
curl -sS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:3008/
curl -sS -o /dev/null -w '%{http_code}\n' -X POST http://127.0.0.1:3204/mcp \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer <MCP_AUTH_TOKEN>' \
  -d '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"smoke","version":"1.0"}},"id":1}'
```

Expect web `200` or `307`; MCP `200` with JSON-RPC result (401 without Bearer).

**Done when:** both containers healthy; debug ports respond.

---

## Step F — Cloudflare DNS

Zone: **`sdd.works`** — add **only** the `framework` record; do not edit apex WordPress or unrelated subdomains.

| Type | Name | Content | Proxy |
| --- | --- | --- | --- |
| A | `framework` | `38.55.192.140` | **DNS only (grey)** until Let's Encrypt succeeds |

Verify:

```bash
dig +short framework.sdd.works
```

**Done when:** `framework.sdd.works` → `38.55.192.140`.

---

## Step G — Nginx Proxy Manager

1. https://nginx.agent-mate.ai/ → **Hosts → Proxy Hosts → Add Proxy Host** (new host; do not edit kb/mypoke/places/hcp)

### Details tab

| Field | Value |
| --- | --- |
| Domain Names | `framework.sdd.works` |
| Scheme | `http` |
| Forward Hostname | **`framework-sdd-web`** |
| Forward Port | **`3000`** (container port, **not** host `3008`) |
| Block Common Exploits | On |
| Websockets Support | **On** |

### Custom Locations

Add **one** location (kb-agent pattern):

| Location | Forward Hostname | Forward Port | Notes |
| --- | --- | --- | --- |
| `/mcp` | **`framework-sdd-mcp`** | **`3041`** | Streamable HTTP MCP only |

**Do not** add `/sse` unless the app ships SSE transport later. Cursor uses **`/mcp`**.

### Advanced (main Proxy Host — portal + long requests)

```nginx
proxy_buffering off;
proxy_read_timeout 300s;
proxy_send_timeout 300s;
client_max_body_size 100m;
```

Apply the same streaming-friendly settings on the **`/mcp` Custom Location** if NPM exposes per-location Advanced.

### SSL

1. Keep Cloudflare **grey** until LE succeeds
2. SSL → Request new certificate for **`framework.sdd.works`** → Force SSL
3. After green cert, optional: Cloudflare orange + SSL mode **Full** / **Full (strict)**

### After stack Recreate

**Save** this Proxy Host again even if fields unchanged. Homepage `200` ≠ MCP healthy.

**Done when:** `https://framework.sdd.works/` is not Default Site / not 502; `/mcp` reaches MCP container (not Next 404).

---

## Step H — Smoke (portal **and** MCP)

Run in order. Both surfaces must pass.

### H1 — Public portal (no admin session)

- [ ] `GET https://framework.sdd.works/` → home with instructions link + sign-in
- [ ] `GET https://framework.sdd.works/instructions` → MCP guide (hero, agents roster, setup prompt)
- [ ] `GET https://framework.sdd.works/agent-setup` → markdown setup instructions (rewrite to `/api/agent-setup`)
- [ ] `GET https://framework.sdd.works/login` → sign-in form
- [ ] `GET https://framework.sdd.works/api/sdd/versions` → `200` with versions **or** `409` `sync_pending` (before first sync — acceptable)

### H2 — Operator admin webapp

- [ ] Sign in as seeded admin (`ADMIN_SEED_EMAIL` / password from Portainer)
- [ ] Landing → **Keys** list
- [ ] **Settings** → save reachable GitHub framework repo URL (dirty-only Save)
- [ ] **Framework** → empty or `cache_missing` until sync; click **Sync with git repository** → tree from SYNK cache (Agents / Rules / Skills expanded one level)
- [ ] **Accounts** list loads (if invite flow configured)
- [ ] Locale switch **EN → 简 → 繁** on admin chrome

### H3 — Package API + sync (after Settings URL saved)

- [ ] `POST /api/admin/sync` with `{ "force": true }` (via Framework page button) completes
- [ ] `GET https://framework.sdd.works/api/sdd/versions` → `200` with `latestCommit`, `inventory`
- [ ] `GET https://framework.sdd.works/api/sdd/package?version=latest` → `200` tarball stream; headers `X-SDD-Commit`, `X-SDD-Version`
- [ ] Framework page tree lists skills/rules/agents from cache; directories before files

### H4 — MCP (Streamable HTTP)

Use a strong **`MCP_AUTH_TOKEN`** from Portainer (not chat).

- [ ] **Cursor:** `.cursor/mcp.json` → `url` `https://framework.sdd.works/mcp`, header `Authorization: Bearer …` → **initialize** succeeds
- [ ] **tools/list** includes: `sdd_list_versions`, `sdd_get_key`, `sdd_install_framework`, `sdd_update_framework`
- [ ] **sdd_list_versions** returns `paths_version` and inventory (after sync)
- [ ] **sdd_install_framework** over HTTP returns `packageUrl` + extraction instructions — **no** server-side writes to user home (ADR-054)
- [ ] Missing / wrong Bearer → `401 unauthorized`

Optional HTTP smoke:

```bash
export MCP_TOKEN='…'
curl -sS -X POST https://framework.sdd.works/mcp \
  -H "Authorization: Bearer $MCP_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"smoke","version":"1.0"}},"id":1}'
```

### H5 — Keys + MCP get_key

- [ ] Admin → **Keys** → create key → copy value once
- [ ] MCP **`sdd_get_key`** with `key_name` returns plaintext (HTTP only — stdio binary does not register this tool per ADR-053)

### H6 — Webhook / cron (if configured)

- [ ] GitHub webhook push to repo → cache refreshes (check manifest `syncedAt`)
- [ ] `POST /api/sync/cron` with `Authorization: Bearer $CRON_SECRET` triggers scheduled sync path

Skip H6 if secrets not yet configured.

### H7 — Coexistence

- [ ] Spot-check ≥1 existing app: `https://places.agent-mate.ai/v1/health` or `https://kb.agent-mate.ai/healthz` or `https://mypoke.trade/` still OK
- [ ] Change default admin password if a known seed password was used for bootstrap

**Done when:** H1–H5 and H7 pass; operator confirms portal + MCP usable for framework install flow.

---

## Updates (subsequent releases)

1. Merge code → CI builds new GHCR tag
2. Set Portainer `IMAGE_TAG` to new **published** sha (not branch name)
3. **Update stack** with **Recreate + Pull** (both services share the same image digest)
4. NPM → **Save** Proxy Host `framework.sdd.works` (even if unchanged)
5. Re-run **H1**, **H3**, **H4** (portal, package API, MCP initialize + list_versions)
6. If Prisma schema changed: **backup Aliyun `framework_sdd` first**
7. Stdio binary users: publish new GitHub Release (`v*` tag) separately — not part of Portainer stack update

---

## Abort / rollback (this app only)

- Portainer: stop/remove **only** stack `framework-sdd-works`, or roll `IMAGE_TAG` back to last known-good sha
- NPM: delete/disable **only** `framework.sdd.works` host (including `/mcp` Custom Location)
- DNS: remove/disable **only** `framework` A record under `sdd.works`
- Postgres **`framework_sdd`** is **not** reverted by image rollback — restore a DB backup if a bad migration shipped
- Volume **`framework_sdd_packages`** retains SYNK cache — safe to keep on rollback unless corrupt
- **Never** `docker network rm portainer_network`

---

## Appendix A — Proposed `docker-compose.prod.yml`

Land this file in the **app repo** root before Step E. Confirm host ports on node.

```yaml
name: framework-sdd-works

services:
  web:
    image: ghcr.io/ethanhuangcst/workspace.framework.sdd.works/web:${IMAGE_TAG:-latest}
    container_name: framework-sdd-web
    restart: unless-stopped
    ports:
      - "3008:3000"
    volumes:
      - framework_sdd_packages:/data/sdd-packages
    environment:
      NODE_ENV: production
      APP_NAME: framework.sdd.works
      PORT: "3000"
      HOSTNAME: "0.0.0.0"
      DATABASE_URL: ${DATABASE_URL:?set DATABASE_URL}
      PUBLIC_BASE_URL: ${PUBLIC_BASE_URL:-https://framework.sdd.works}
      SESSION_SECRET: ${SESSION_SECRET:?set SESSION_SECRET}
      ADMIN_SEED_EMAIL: ${ADMIN_SEED_EMAIL:-me@ethanhuang.com}
      ADMIN_SEED_USERNAME: ${ADMIN_SEED_USERNAME:-admin}
      ADMIN_SEED_PASSWORD: ${ADMIN_SEED_PASSWORD:?set ADMIN_SEED_PASSWORD}
      KEYS_ENCRYPTION_KEY: ${KEYS_ENCRYPTION_KEY:?set KEYS_ENCRYPTION_KEY}
      GITHUB_TOKEN: ${GITHUB_TOKEN:?set GITHUB_TOKEN}
      GITHUB_API_HOST: ${GITHUB_API_HOST:-api.github.com}
      GITHUB_API_BASE_URL: ${GITHUB_API_BASE_URL:-https://api.github.com}
      GITHUB_WEBHOOK_SECRET: ${GITHUB_WEBHOOK_SECRET:-}
      CRON_SECRET: ${CRON_SECRET:-}
      RESEND_API_KEY: ${RESEND_API_KEY:-}
      RESEND_HOST: ${RESEND_HOST:-api.resend.com}
      RESEND_BASE_URL: ${RESEND_BASE_URL:-https://api.resend.com}
      RESEND_KEY_MGMT_SITE: ${RESEND_KEY_MGMT_SITE:-}
      MAIL_FROM: ${MAIL_FROM:-}
      SMTP_URL: ${SMTP_URL:-}
      SDD_PACKAGE_CACHE_DIR: /data/sdd-packages
    command: ["./docker-entrypoint-web.sh"]
    networks:
      - default

  mcp:
    image: ghcr.io/ethanhuangcst/workspace.framework.sdd.works/web:${IMAGE_TAG:-latest}
    container_name: framework-sdd-mcp
    restart: unless-stopped
    ports:
      - "3204:3041"
    volumes:
      - framework_sdd_packages:/data/sdd-packages
    environment:
      NODE_ENV: production
      APP_NAME: framework.sdd.works
      DATABASE_URL: ${DATABASE_URL:?set DATABASE_URL}
      PUBLIC_BASE_URL: ${PUBLIC_BASE_URL:-https://framework.sdd.works}
      SDD_SERVER_URL: ${SDD_SERVER_URL:-https://framework.sdd.works}
      KEYS_ENCRYPTION_KEY: ${KEYS_ENCRYPTION_KEY:?set KEYS_ENCRYPTION_KEY}
      GITHUB_TOKEN: ${GITHUB_TOKEN:?set GITHUB_TOKEN}
      GITHUB_API_HOST: ${GITHUB_API_HOST:-api.github.com}
      GITHUB_API_BASE_URL: ${GITHUB_API_BASE_URL:-https://api.github.com}
      MCP_AUTH_TOKEN: ${MCP_AUTH_TOKEN:-}
      MCP_HTTP_HOST: "0.0.0.0"
      MCP_HTTP_PORT: "3041"
      MCP_HTTP_PATH: /mcp
      SDD_PACKAGE_CACHE_DIR: /data/sdd-packages
    command: ["npx", "tsx", "src/mcp/http-server.ts"]
    networks:
      - default

volumes:
  framework_sdd_packages:

networks:
  default:
    external: true
    name: portainer_network
```

**Notes for implementers landing this file:**

- Web entrypoint: `prisma migrate deploy` → `prisma db seed` → `node server.js` (Next standalone).
- MCP command: `npx tsx src/mcp/http-server.ts` (`tsx` installed in image at build time).
- MCP must **not** run seed/migrate.
- Both services must mount the **same** named volume for SYNK cache coherence.

---

## Appendix B — Environment variable index

Canonical detail: **[Production artifacts & operator prerequisites](#production-artifacts--operator-prerequisites)** (§3–§6).

Quick index mapped to [`.env.example`](../../.env.example):

| Name | Priority | In `.env.example` |
| --- | --- | --- |
| `DATABASE_URL` | P0 | yes |
| `SESSION_SECRET` | P0 | yes |
| `ADMIN_SEED_*` | P0 | yes |
| `KEYS_ENCRYPTION_KEY` | P0 | yes |
| `GITHUB_TOKEN` | P0 | yes |
| `MCP_AUTH_TOKEN` | P0 | yes |
| `MCP_HTTP_*` | P0 | yes |
| `PUBLIC_BASE_URL` | P0 | yes |
| `SDD_PACKAGE_CACHE_DIR` | P0 | compose default |
| `SDD_SERVER_URL` | P0 | code default — set explicitly in prod |
| `IMAGE_TAG` | P0 | **no** — Portainer only |
| `NODE_ENV` / `HOSTNAME` | P0 | partial — prod compose |
| `RESEND_*` / `MAIL_FROM` | P1 | yes |
| `GITHUB_WEBHOOK_SECRET` / `CRON_SECRET` | P2 | yes |
| `QWEN_*` | omit | yes (dev stdio only) |
| `SMTP_URL` | P1 alt | yes |

---

## Appendix C — release-bot references

| Doc | Purpose |
| --- | --- |
| [`vps3_new_deployment_instruction.md`](./vps3_new_deployment_instruction.md) | Authoring `deployment-plan.md` |
| [`hk_vps_3_setting.md`](./hk_vps_3_setting.md) | Live port/stack inventory (refresh before deploy) |
| [`release-instruction-example.md`](./release-instruction-example.md) | places-agent contrast — **no** Custom Locations there; **yes** here for `/mcp` |
| release-bot `knowledge/03-semi-auto-release.md` | Generic step order |
| release-bot `knowledge/09-isolation-safety.md` | Multi-app isolation |
| release-bot `knowledge/04-portainer.md` | Portainer operations |
| release-bot `knowledge/05-nginx-proxy-manager.md` | NPM + SSL + Custom Locations |
| release-bot `knowledge/08-cloudflare.md` | DNS |
| [`specs/tech-spec.md`](../tech-spec.md) | Architecture, ports, env codes |
| [`specs/mcp/mcp-test.md`](../mcp/mcp-test.md) | MCP verification scenarios |

---

## Document status

| Item | State |
| --- | --- |
| Operator instruction | **Ready** |
| Prerequisites § (artifacts + secrets) | **Documented** — operator ledger §1b; P0 secrets still Pending |
| App-repo Dockerfile / compose / ghcr workflow / `.env.prod.example` | **Landed** — push `main` to run Step A |
| Aliyun DB `framework_sdd` | **Created** (2026-09-18) |
| GHCR image | **Pending** — await CI after push |
| Portainer deploy (Steps B–H) | **Not executed** — operator after `IMAGE_TAG` |
