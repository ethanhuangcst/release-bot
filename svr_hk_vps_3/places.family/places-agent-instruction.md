# Step-by-step — places.agent-mate.ai → 野草云3

Guided release for stack **`places-agent`** (first wave of the places family). Follow in order. Do **not** skip GHCR before Portainer pull.

**Capability (2026-08-21, MVP-7):** Agent stack is **live** on 野草云3. Core tools on **HTTP + MCP**; **`POST /v1/chat`** and Tripadvisor enrich remain **HTTP-only** ([ADR-020](../../../workspace-specs/adr/ADR-020-http-only-chat-and-enrich.md)). Timed / LLM itinerary: `plan_itinerary` (`ITINERARY_MODE=llm` default) plus split tools **`discover_places`** / **`arrange_day`** on **both** HTTP (`/v1/...`) and MCP. Live vendors must not return `fixture_` ([ADR-021](../../../workspace-specs/adr/ADR-021-live-vendor-no-fixture.md)).

**Unlike `kb-agent`:** one Node process serves **operator admin UI**, **admin BFF** (`/api/admin/*`), **HTTP tools** (`/v1/*`), and **MCP** (`/mcp`, `/sse`, `/messages`) on the **same container**. NPM uses **one** Proxy Host → `places-agent:3000`. **Do not** add kb-style Custom Locations to a second upstream.

**Canonical family plan:** `workspace-specs/6.deployment-plan.md`  
**App repo:** `1.places-agent/` (gitignored child remote `ethanhuangcst/places.agent-mate.ai`)

---

## Consoles (do not paste passwords into chat)

| Console | URL |
| --- | --- |
| GitHub Actions | https://github.com/ethanhuangcst/places.agent-mate.ai/actions |
| GHCR packages | https://github.com/ethanhuangcst/places.agent-mate.ai/pkgs/container/places.agent-mate.ai%2Fagent |
| Portainer | https://portainer.agent-mate.ai/ |
| NPM | https://nginx.agent-mate.ai/ |
| Cloudflare | zone `agent-mate.ai` → DNS |
| App (after go-live) | https://places.agent-mate.ai |

---

## Fixed facts

| Item | Value |
| --- | --- |
| Target node | **野草云3** · public IP **`38.55.192.140`** |
| Stack name | **`places-agent`** (exact) |
| Container name | **`places-agent`** |
| Public domain | **`places.agent-mate.ai`** (exact spelling — SNI breaks on typos) |
| Image (proposed) | `ghcr.io/ethanhuangcst/places.agent-mate.ai/agent:<IMAGE_TAG>` |
| Process entry | **`node server.ts`** (ADR-016) — not `next start`, not a second MCP sidecar |
| Container listen | **`3000`** |
| Host bind (debug only) | **`3007→3000` occupied** (2026-08-20). NPM Forward is container **`3000`**, never `3007`. |
| NPM Forward | **`places-agent` : `3000`** (container port, **not** `3007`) |
| Database | **PostgreSQL** Aliyun **`places_agent`** on `101.132.156.250:5432` ([ADR-025](../../../workspace-specs/adr/ADR-025-places-agent-postgres-prisma.md)). Dedicated db — **not** `what2eat`. **No** SQLite volume. |
| Network | existing **`portainer_network`** (**never delete/recreate**) |
| Caller-visible agent id | **`places-agent`** (MCP `serverInfo.name`, HTTP `agent` field) |
| Env name template | app repo `.env.production.example` (names only) |
| Local env copy (gitignored) | `release-jobs/places.family/.env` on operator machine |
| Spot-check after deploy | `https://kb.agent-mate.ai` · `https://mypoke.trade` · `https://hcp.agent-mate.ai` |

### MCP client URLs (after go-live)

| Client | URL | Auth |
| --- | --- | --- |
| Cursor (Streamable HTTP) | `https://places.agent-mate.ai/mcp` | `Authorization: Bearer <caller_api_key>` |
| ChatBox (Remote HTTP/SSE) | `https://places.agent-mate.ai/sse` | `Authorization=Bearer <caller_api_key>` |
| Health | `https://places.agent-mate.ai/v1/health` | none |

ChatBox must **not** use `/mcp`. Cursor must **not** use `/sse` for Streamable HTTP.

---

## Pre-flight — app-repo blockers

**Stop before Portainer** if any row is still missing in the app repo.

| Artifact | Status (check repo) | Required for |
| --- | --- | --- |
| `server.ts` | Must exist | Production entry; MCP + Next in one process |
| `Dockerfile` | Must exist | GHCR build; `CMD node server.ts`; migrate + seed on boot |
| `docker-compose.prod.yml` | Must exist | Portainer stack; image-only; external `portainer_network` |
| `.github/workflows/ghcr.yml` | Must exist | CI → GHCR |
| `.env.production.example` | Names-only template | Portainer env checklist |

`server.ts` exists. Land **Dockerfile**, **compose**, **ghcr workflow**, and **`.env.production.example`** in the app repo before Step A. Production env: `PLACES_VENDOR_MODE=live`. **Do not** set `GOOGLE_DIRECT_FORCE_FAIL`, `QUANZIL_MODE`, or `DEV_ADMIN_PASSWORD`. Database: Aliyun `places_agent` (ADR-025), not SQLite.

---

## Step A — Build & push GHCR image (blocker)

1. Confirm `.github/workflows/ghcr.yml` exists and builds image `ghcr.io/ethanhuangcst/places.agent-mate.ai/agent`.
2. Push to the default branch or run workflow dispatch on the agreed ref (`main` or release tag `v*`).
3. Wait until the workflow is green.
4. Open GitHub **Packages** and confirm the tag exists.
5. Record **`IMAGE_TAG`**:
   - Prefer the **git sha** tag from the run (reliable for rollbacks)
   - `latest` only if you confirmed it was pushed for this ref (release-bot ADR-002: **never** use git branch name `main` as `IMAGE_TAG`)

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
docker volume ls | grep -E 'places_agent|kb_|mypoke|hcp' || true
ss -lntup | grep -E ':3007|:3006|:3004|:3005' || true
```

Confirm for **places-agent**:

- [ ] No stack named `places-agent` (unless this is an intentional update)
- [ ] No container named `places-agent` (unless updating)
- [ ] Volume `places_agent_data` is **not** required (Postgres off-node). Do not create it unless leftover.
- [ ] **Proposed host port `3007`** free (if taken, pick another unused port and record it)
- [ ] Will **not** take reserved ports: `3001`–`3003`, `3006`, `3200`–`3203`, `6333`, `6335`, `6336`
- [ ] Will **not** delete/recreate `portainer_network`
- [ ] Will **not** edit other stacks (`hcp-engagement-agent`, `mypoke-trade`, `kb-agent`, `root`)
- [ ] Domain `places.agent-mate.ai` not used by another NPM host

Inventory reference: `svr_hk_vps_3/hk_vps_3_setting.md` (refresh if stale).

**Done when:** operator replies **「隔离检查通过」**.

---

## Step D — Database (Aliyun Postgres `places_agent`)

places-agent **does not** use SQLite on 野草云3. Postgres is **off-node** (same host as what2eat, **different database**).

1. Confirm Aliyun database **`places_agent`** exists (empty is OK). Do **not** use `what2eat` / `kb_agent` / `mypoke_trade_prod`.
2. Set `DATABASE_URL=postgresql://…@101.132.156.250:5432/places_agent` in Portainer (secret).
3. Compose has **no** `places_agent_data` volume.
4. Image entrypoint runs **`prisma migrate deploy`** then **seed** on boot.
5. **Never** run migrations against `kb_agent`, `mypoke_trade_prod`, `media_marketing`, `hca`, or `what2eat`.

First-boot admin (seed):

- Username **`admin`**, email **`me@ethanhuang.com`**
- Set **`BOOTSTRAP_ADMIN_PASSWORD`** once in Portainer for first boot, then **unset** after password is set
- If bootstrap password is empty, admin must use **`/set-password`** before login works
- **Do not** set `DEV_ADMIN_PASSWORD` in production
- Public register stays **off**

**Done when:** `DATABASE_URL` points at dedicated `places_agent`; bootstrap strategy agreed.

---

## Step E — Portainer Create/Update stack `places-agent`

1. https://portainer.agent-mate.ai/ → Endpoint = **野草云3**
2. **Stacks → Add stack** (or Update existing)
3. Name: **`places-agent`** (exact)
4. Build method: **Web editor**
5. Paste full **`docker-compose.prod.yml`** from the app repo (skeleton: **Appendix A**)
6. **Environment variables:** copy from local `release-jobs/places.family/.env` (derived from app `.env.production.example`). Minimum set:

| Name | Required | Notes |
| --- | --- | --- |
| `IMAGE_TAG` | yes | Sha from Step A — not branch `main` |
| `NODE_ENV` | yes | `production` |
| `APP_NAME` | yes | `places-agent` |
| `PORT` | yes | `3000` |
| `HOSTNAME` | yes | `0.0.0.0` |
| `SESSION_SECRET` | yes | Strong random; rotate only with planned session wipe |
| `DATABASE_URL` | yes | `postgresql://…@101.132.156.250:5432/places_agent` (dedicated; never `what2eat`) |
| `PUBLIC_BASE_URL` / `APP_URL` | yes | `https://places.agent-mate.ai` |
| `PLACES_VENDOR_MODE` | yes | `live` in production |
| `ITINERARY_MODE` | yes (pin) | **`llm`** (image/compose default). Set `legacy` only for emergency rollback of itinerary planner. |
| `GOOGLE_DIRECT_FORCE_FAIL` | **must not set** | Dev-only Worker fallback switch. `NODE_ENV=production` rejects it at startup. |
| `OPENAI_*` | yes | Quanzil on agent (`https://quanzil.com/v1`, not `api.openai.com`) — required for `POST /v1/chat`, LLM itinerary, `arrange_day` |
| `PROMPT_ID` / `GLOSSARY_ID` / `CATALOG_PACK` | yes | Pin on rollback with `IMAGE_TAG` |
| Map vendor keys | as needed | `AMAP_*`, `GOOGLE_MAPS_*`, `GMAPS_MCP_*`, `TRIPADVISOR_*`, `OPEN_METEO_*` |
| `QUANZIL_MODE` | **must not set** | Fixture LLM is local/E2E only |
| `RESEND_*` | yes for mail | Admin invite / password reset |
| `BOOTSTRAP_ADMIN_PASSWORD` | one-time | Unset after first admin password set |

7. Confirm network block:

```yaml
networks:
  default:
    external: true
    name: portainer_network
```

8. **Deploy the stack** (Recreate + **Pull** if updating image)
9. Container **`places-agent`** → **running**
10. Glance other stacks — they should **not** mass-restart
11. Internal checks (from node):

```bash
curl -sS http://127.0.0.1:3007/v1/health
curl -sS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:3007/
```

Expect health JSON with `"agent":"places-agent"` and `"ok":true`.

**Done when:** container healthy; health endpoint OK on debug port.

---

## Step F — Cloudflare DNS

Zone: **`agent-mate.ai`** — add **only** the `places` record; do not edit `kb`, `hcp`, `portainer`, `nginx`, `mypoke`.

| Type | Name | Content | Proxy |
| --- | --- | --- | --- |
| A | `places` | `38.55.192.140` | **DNS only (grey)** until Let's Encrypt succeeds |

Verify:

```bash
dig +short places.agent-mate.ai
```

**Done when:** `places.agent-mate.ai` → `38.55.192.140`.

---

## Step G — Nginx Proxy Manager

1. https://nginx.agent-mate.ai/ → **Hosts → Proxy Hosts → Add Proxy Host** (new host; do not edit kb/mypoke/hcp)

### Details tab

| Field | Value |
| --- | --- |
| Domain Names | `places.agent-mate.ai` |
| Scheme | `http` |
| Forward Hostname | **`places-agent`** |
| Forward Port | **`3000`** (container port, **not** host `3007`) |
| Block Common Exploits | On |
| Websockets Support | **On** |

### Custom Locations

**None.** Do **not** route `/mcp`, `/sse`, or `/v1` to a second container. The whole hostname goes to `places-agent:3000`.

(kb-agent needs Custom Locations because `kb-web` and `kb-agent` are separate containers — that pattern is **wrong** here.)

### Advanced (required for MCP / SSE)

On the Proxy Host **Advanced** tab (or equivalent), ensure streaming works:

```nginx
proxy_buffering off;
proxy_read_timeout 300s;
proxy_send_timeout 300s;
client_max_body_size 100m;
```

### SSL

1. Keep Cloudflare **grey** until LE succeeds
2. SSL → Request new certificate for **`places.agent-mate.ai`** → Force SSL
3. After green cert, optional: Cloudflare orange + SSL mode **Full** / **Full (strict)**

### After stack Recreate

**Save** this Proxy Host again even if fields unchanged (release-bot ADR-003). Homepage `200` ≠ MCP healthy.

**Done when:** `https://places.agent-mate.ai/` is not Default Site / not 502.

---

## Step H — Smoke (admin webapp **and** agent)

Run in order. Both surfaces must pass.

### H1 — Agent / HTTP tools (no admin session)

- [ ] `GET https://places.agent-mate.ai/v1/health` → `{ "agent": "places-agent", "ok": true, "data": { "tools": [...] } }`
- [ ] Health `tools` includes at least: `search_restaurants`, `search_places`, `plan_itinerary`, `discover_places`, `arrange_day`, `get_place_details`, `geocode`, `navigate`, `chat`
- [ ] `GET https://places.agent-mate.ai/health` → same shape (alias)
- [ ] Public `/` HTML does **not** contain `data:text/javascript;base64` (ClickFix IOC check)
- [ ] Admin **Instructions** guide lists `discover_places` / `arrange_day` and `POST /v1/discover_places` / `POST /v1/arrange_day`

### H2 — Operator admin webapp

- [ ] `https://places.agent-mate.ai/` → public home loads (agent id `places-agent` visible per spec)
- [ ] `https://places.agent-mate.ai/login` → admin sign-in form
- [ ] Sign in as **`admin`** (or complete **`/set-password`** if seed had empty hash)
- [ ] Landing → **Caller API keys** (default post-login destination)
- [ ] `https://places.agent-mate.ai/admin/users` loads (session cookie works)
- [ ] `https://places.agent-mate.ai/instructions` loads (integration guide)
- [ ] Public **register** remains disabled
- [ ] Locale switch **EN → HK** (or CN) smoke on admin chrome

### H3 — Caller API key → tool call

- [ ] Admin → **Keys** → issue key → copy `pa_…` **once** (do not commit)
- [ ] HTTP smoke:

```bash
export CALLER_KEY='pa_…'
curl -sS -H "Authorization: Bearer $CALLER_KEY" \
  -H "Content-Type: application/json" \
  -d '{"query":"restaurant","location":"Hong Kong","providers":["GOOGLE_MAPS"],"locale":"EN"}' \
  https://places.agent-mate.ai/v1/search_restaurants | head -c 400
```

Expect `"agent":"places-agent"`, `"ok":true`, and structured `data` or explicit `skipped[]` — not silent empty success with invented POIs. Fail if `native_id` starts with `fixture_`.

### H3b — Place search, timed itinerary, chat (same key)

```bash
curl -sS -H "Authorization: Bearer $CALLER_KEY" \
  -H "Content-Type: application/json" \
  -d '{"query":"museum","near":{"lat":22.2819,"lng":114.158},"providers":["GOOGLE_MAPS"],"locale":"EN"}' \
  https://places.agent-mate.ai/v1/search_places | head -c 400

curl -sS -H "Authorization: Bearer $CALLER_KEY" \
  -H "Content-Type: application/json" \
  -d '{"detail":"timed","origin":{"name":"Central","lat":22.2819,"lng":114.158},"bounds":{"start":"2026-08-25","end":"2026-08-27"},"providers":["GOOGLE_MAPS"],"locale":"EN"}' \
  https://places.agent-mate.ai/v1/plan_itinerary | head -c 400

curl -sS -H "Authorization: Bearer $CALLER_KEY" \
  -H "Content-Type: application/json" \
  -d '{"messages":[{"role":"user","content":"ramen near Tsim Sha Tsui"}],"locale":"EN"}' \
  https://places.agent-mate.ai/v1/chat | head -c 400
```

- [ ] `search_places` — ok + cards or explicit skip; no `fixture_`
- [ ] `plan_itinerary` timed — `days` present (not a `timed_no_places` empty plan when vendors are live)
- [ ] `/v1/chat` — HTTP 200; **not** registered as an MCP tool

### H3c — discover_places + arrange_day (HTTP; MVP-7)

```bash
curl -sS -H "Authorization: Bearer $CALLER_KEY" \
  -H "Content-Type: application/json" \
  -d '{"city":"Hong Kong","bounds":{"start":"2026-08-25","end":"2026-08-25"},"locale":"EN"}' \
  https://places.agent-mate.ai/v1/discover_places | head -c 600

# Then POST /v1/arrange_day with candidates from discover (dayIndex: 1). Requires ITINERARY_MODE=llm + OPENAI_*.
```

- [ ] `discover_places` — `ok:true` with `candidates.places` / `candidates.restaurants` (≤8 each when live)
- [ ] `arrange_day` — `ok:true` with a single-day plan / blocks (or explicit 502 `errors.arrange_day_failed` if LLM misconfigured — do not ship with broken Quanzil)
- [ ] Both routes require Bearer; missing key → 401

### H4 — MCP (same caller key)

- [ ] **Cursor:** `.cursor/mcp.json` → `url` `https://places.agent-mate.ai/mcp`, Bearer header → **initialize** returns `serverInfo.name` **`places-agent`**; **tools/list** includes core tools **plus** `discover_places` and `arrange_day` (`search_restaurants`, `search_places`, `get_place_details`, `geocode`, `navigate`, `plan_itinerary`, `discover_places`, `arrange_day`)
- [ ] **ChatBox:** Type **Remote (HTTP/SSE)**; URL **`https://places.agent-mate.ai/sse`**; header `Authorization=Bearer …`; enable MCP on a **new chat** → Test OK (**not** `/mcp`)
- [ ] **`POST /v1/chat`** is **HTTP-only** (ADR-020) — do not expect it as an MCP tool

### H5 — Coexistence

- [ ] Spot-check ≥1 existing app: `https://kb.agent-mate.ai/healthz` or `https://mypoke.trade/` still OK
- [ ] Change default admin password if bootstrap was used; do not leave a known bootstrap password in Portainer env

### H6 — Vendor honesty (after H3; [ADR-021](../../../workspace-specs/adr/ADR-021-live-vendor-no-fixture.md))

ChatBox is **not** this gate ([ADR-019](../../../workspace-specs/adr/ADR-019-http-first-user-test-automation.md)). Use HTTP + the caller key from H3. Fail if any `native_id` starts with `fixture_`.

- [ ] **AMAP:** same body as `make verify-amap-live` — `query=烧烤`, `address=上海地铁十号线紫藤路站`, `providers=["AMAP"]`. Expect `provider=AMAP`, `crs=GCJ-02`, no `fixture_`.
- [ ] **Google:** HK pin search, `providers=["GOOGLE_MAPS"]`, named query (e.g. `restaurants in Central Hong Kong` near `22.2819,114.158`). Expect `GOOGLE_MAPS`, no `fixture_`. Do not use `query=restaurant` alone (Places text search can return unrelated US POIs).
- [ ] **Tripadvisor:** same Google search with `enrich.tripadvisor: true`. At least one numeric `tripadvisor.rating`; no `tripadvisor.com/ichiran`.
- [ ] **Weather:** `plan_itinerary` with a HK pin and near-term bounds. Day weather is numeric `weather_code` 0–99, `provider=OPEN_METEO`, and not the fixture signature (`weather_code: 80` with temps 24/18).

**Done when:** H1–H6 pass (H6 weather row only when that vendor is live-honest); operator confirms admin + agent usable.

---

## Updates (subsequent releases)

1. Merge code → CI builds new GHCR tag
2. Set Portainer `IMAGE_TAG` to new **published** sha (not branch name)
3. **Update stack** with **Recreate + Pull**
4. NPM → **Save** Proxy Host `places.agent-mate.ai` (even if unchanged)
5. Re-run **H1**, **H3b**, **H3c**, and **H4** (health + tools + discover/arrange + MCP); spot-check admin login if session secret unchanged
6. Confirm Portainer `ITINERARY_MODE` is `llm` (or intentional `legacy` rollback)
7. If Prisma schema changed: **backup Aliyun `places_agent` first**

---

## Abort / rollback (this app only)

- Portainer: stop/remove **only** stack `places-agent`, or roll `IMAGE_TAG` back to last known-good sha
- NPM: delete/disable **only** `places.agent-mate.ai` host
- DNS: remove/disable **only** `places` A record
- Postgres `places_agent` is **not** reverted by image rollback — restore a DB backup if a bad migration shipped
- **Never** `docker network rm portainer_network`

---

## Appendix A — Proposed `docker-compose.prod.yml`

Land this file in the **app repo** root before Step E. Confirm host port on node.

```yaml
name: places-agent

services:
  agent:
    image: ghcr.io/ethanhuangcst/places.agent-mate.ai/agent:${IMAGE_TAG:-latest}
    container_name: places-agent
    restart: unless-stopped
    ports:
      - "3007:3000"
    volumes:
      - places_agent_data:/data
    environment:
      NODE_ENV: production
      APP_NAME: places-agent
      PORT: "3000"
      HOSTNAME: "0.0.0.0"
      DATABASE_URL: ${DATABASE_URL:-file:/data/places-agent.db}
      PUBLIC_BASE_URL: ${PUBLIC_BASE_URL:-https://places.agent-mate.ai}
      APP_URL: ${APP_URL:-https://places.agent-mate.ai}
      SESSION_SECRET: ${SESSION_SECRET:?set SESSION_SECRET}
      PLACES_VENDOR_MODE: ${PLACES_VENDOR_MODE:-live}
      PROMPT_ID: ${PROMPT_ID:-chat.v1}
      GLOSSARY_ID: ${GLOSSARY_ID:-}
      CATALOG_PACK: ${CATALOG_PACK:-catalogs.v1}
      OPENAI_API_KEY: ${OPENAI_API_KEY:-}
      OPENAI_HOST: ${OPENAI_HOST:-quanzil.com}
      OPENAI_BASE_URL: ${OPENAI_BASE_URL:-https://quanzil.com/v1}
      OPENAI_CHAT_MODEL: ${OPENAI_CHAT_MODEL:-}
      AMAP_API_KEY: ${AMAP_API_KEY:-}
      AMAP_HOST: ${AMAP_HOST:-restapi.amap.com}
      AMAP_BASE_URL: ${AMAP_BASE_URL:-https://restapi.amap.com}
      GOOGLE_MAPS_API_KEY: ${GOOGLE_MAPS_API_KEY:-}
      GOOGLE_MAPS_HOST: ${GOOGLE_MAPS_HOST:-maps.googleapis.com}
      GOOGLE_MAPS_BASE_URL: ${GOOGLE_MAPS_BASE_URL:-}
      GOOGLE_PLACES_BASE_URL: ${GOOGLE_PLACES_BASE_URL:-https://places.googleapis.com/v1}
      GOOGLE_MAPS_PROJECT: ${GOOGLE_MAPS_PROJECT:-}
      GMAPS_MCP_HOST: ${GMAPS_MCP_HOST:-}
      GMAPS_MCP_URL: ${GMAPS_MCP_URL:-}
      GMAPS_MCP_BEARER: ${GMAPS_MCP_BEARER:-}
      TRIPADVISOR_API_KEY: ${TRIPADVISOR_API_KEY:-}
      TRIPADVISOR_HOST: ${TRIPADVISOR_HOST:-terra.tripadvisor.com}
      TRIPADVISOR_BASE_URL: ${TRIPADVISOR_BASE_URL:-https://terra.tripadvisor.com/api}
      OPEN_METEO_HOST: ${OPEN_METEO_HOST:-api.open-meteo.com}
      OPEN_METEO_BASE_URL: ${OPEN_METEO_BASE_URL:-https://api.open-meteo.com/v1}
      OPEN_METEO_API_KEY: ${OPEN_METEO_API_KEY:-}
      RESEND_API_KEY: ${RESEND_API_KEY:-}
      RESEND_HOST: ${RESEND_HOST:-api.resend.com}
      RESEND_BASE_URL: ${RESEND_BASE_URL:-https://api.resend.com}
      RESEND_FROM_EMAIL: ${RESEND_FROM_EMAIL:-}
      BOOTSTRAP_ADMIN_PASSWORD: ${BOOTSTRAP_ADMIN_PASSWORD:-}
    networks:
      - default

volumes:
  places_agent_data:

networks:
  default:
    external: true
    name: portainer_network
```

---

## Appendix B — release-bot references

| Doc | Purpose |
| --- | --- |
| `knowledge/03-semi-auto-release.md` | Generic step order |
| `knowledge/09-isolation-safety.md` | Multi-app isolation |
| `knowledge/04-portainer.md` | Portainer operations |
| `knowledge/05-nginx-proxy-manager.md` | NPM + SSL |
| `knowledge/08-cloudflare.md` | DNS |
| `knowledge/06-rollback.md` | Rollback |
| `svr_hk_vps_3/vps3_new_deployment_instruction.md` | Authoring `deployment-plan.md` |
| `svr_hk_vps_3/hk_vps_3_setting.md` | Live port/stack inventory |
| `Release-jobs/kb.agent-mate.ai/step-by-step.md` | Contrast only — **do not** copy Custom Locations |
| `workspace-specs/6.deployment-plan.md` | Family plan (smoke §9, env §5) |
