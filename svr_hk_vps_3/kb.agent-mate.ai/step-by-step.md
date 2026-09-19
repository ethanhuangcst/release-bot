# Step-by-step — kb.agent-mate.ai → 野草云3

Guided release for stack **`kb-agent`**. Follow in order. Do **not** skip GHCR before Portainer pull.

**Repos (do not paste passwords into chat)**

| Console | URL |
| --- | --- |
| GitHub Actions | https://github.com/ethanhuangcst/kb.agent-mate.ai/actions |
| GHCR workflow | https://github.com/ethanhuangcst/kb.agent-mate.ai/actions/workflows/ghcr.yml |
| Portainer | https://portainer.agent-mate.ai/ |
| NPM | https://nginx.agent-mate.ai/ |
| Cloudflare | zone `agent-mate.ai` → DNS |
| App (after go-live) | https://kb.agent-mate.ai |

**Fixed facts**

| Item | Value |
| --- | --- |
| Git ref | `release-1` |
| Node | 野草云3 · `38.55.192.140` |
| Stack | `kb-agent` |
| Domain | `kb.agent-mate.ai` |
| Images | `ghcr.io/ethanhuangcst/kb.agent-mate.ai/{web,agent,rag}` |
| Host ports | `3006` / `3202` / `3203` / `127.0.0.1:6336` |
| DB | Aliyun `101.132.156.250:5432` / **`kb_agent`** |
| Network | existing `portainer_network` (**never delete/recreate**) |
| Env source | `Release-jobs/kb.agent-mate.ai/.env` (local only) |
| Compose | repo `docker-compose.prod.yml` (= job `docker.compose.prod.yml`) |
| Spot-check later | `https://hcp.agent-mate.ai` · `https://mypoke.trade` |

---

## Step A — Build & push GHCR images (blocker)

`ghcr.yml` does **not** auto-run on `release-1` (only `main`, `3-mvp03`, `v*`, or manual dispatch).

1. Open https://github.com/ethanhuangcst/kb.agent-mate.ai/actions/workflows/ghcr.yml  
2. **Run workflow** → Branch: **`release-1`** → Run  
3. Wait until all three matrix jobs (`web` / `agent` / `rag`) are green  
4. Packages → confirm tags exist for:
   - `…/kb.agent-mate.ai/web`
   - `…/kb.agent-mate.ai/agent`
   - `…/kb.agent-mate.ai/rag`  
5. Record **IMAGE_TAG**:
   - Prefer the **git sha** tag from the run (reliable)
   - `latest` is only auto-tagged on the **default** branch — for `release-1` dispatch, sha is safer unless you confirmed `latest` was pushed

**Done when:** three images exist; you have a concrete tag string for Portainer.

---

## Step B — Portainer can pull GHCR

1. Portainer → **Registries**  
2. If pull later returns 401: add `ghcr.io` with a PAT that has **`read:packages`** (and SSO authorize if org requires it)  
3. Do not put the PAT in chat or git

**Done when:** registry entry exists (or you already pull other `ethanhuangcst/*` images successfully).

---

## Step C — Isolation gate (live on 野草云3)

On the node (SSH), run:

```bash
docker ps --format 'table {{.Names}}\t{{.Ports}}\t{{.Image}}'
docker volume ls | grep -E 'kb_|portainer|mypoke|hcp' || true
ss -lntup | grep -E ':3006|:3202|:3203|:6336' || true
```

Confirm **all** empty / free for kb:

- [ ] No stack named `kb-agent`
- [ ] No containers `kb-web` / `kb-agent` / `kb-rag` / `kb-qdrant`
- [ ] No volumes `kb_qdrant_data` / `kb_blob_data` (or OK to reuse empty)
- [ ] Ports **3006 / 3202 / 3203 / 127.0.0.1:6336** free
- [ ] Will **not** touch `portainer_network`, hcp, mypoke, media reserved **3003**

**Done when:** you reply「隔离检查通过」.

---

## Step D — DB from the node

1. Aliyun Postgres whitelist / security group: allow **`38.55.192.140`**  
2. From 野草云3 (password only in local env / shell history hygiene):

```bash
# shape only — use your real DATABASE_URL from local .env
psql "$DATABASE_URL" -c 'select 1'
psql "$DATABASE_URL" -c 'select version_num from alembic_version'
```

Expect DB `kb_agent` and migrations already at **`005_import_batch`** (or newer). If empty / behind:

```bash
# from a checkout of the app repo, not on Portainer build
cd packages/kb_schema && DATABASE_URL='postgresql+psycopg://…' alembic upgrade head
```

**Never** migrate `mypoke_trade_prod` / `media_marketing` / other DBs.

**Done when:** `select 1` OK; alembic version OK.

---

## Step E — Portainer Create stack `kb-agent`

1. https://portainer.agent-mate.ai/ → Endpoint = **this node** (野草云3)  
2. **Stacks → Add stack**  
3. Name: **`kb-agent`** (exact)  
4. Build method: **Web editor**  
5. Paste full contents of `docker-compose.prod.yml` from repo (or job `docker.compose.prod.yml`)  
6. **Environment variables**: paste names/values from local `Release-jobs/kb.agent-mate.ai/.env`  
   - Must include at least: `IMAGE_TAG`, `DATABASE_URL`, `SESSION_SECRET`, `API_KEY_PEPPER`, `API_KEY_ENCRYPTION_SECRET`, `RESEND_*`, `QWEN_*`, `RAG_SERVICE_TOKEN`, `PUBLIC_BASE_URL`, `USE_FAKE_EMBEDDER=false`, `USE_FAKE_KM=false`  
   - Set `IMAGE_TAG` to the sha from Step A  
7. Confirm network block is:

```yaml
networks:
  default:
    external: true
    name: portainer_network
```

8. **Deploy the stack**  
9. Check containers: `kb-web`, `kb-agent`, `kb-rag`, `kb-qdrant` → running  
10. Glance other stacks — should **not** mass-restart  
11. Quick internal health (from node):

```bash
curl -sS http://127.0.0.1:3202/healthz
curl -sS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:3006/
```

**Do not** edit stacks `hcp-engagement-agent`, `mypoke-trade`, or `root`.

**Done when:** four containers healthy; healthz OK.

---

## Step F — Cloudflare DNS

Zone: **`agent-mate.ai`** (only add `kb`; do not edit hcp / portainer / nginx / mypoke).

| Type | Name | Content | Proxy |
| --- | --- | --- | --- |
| A | `kb` | `38.55.192.140` | **DNS only (grey)** first |

**Done when:** `dig +short kb.agent-mate.ai` → `38.55.192.140`.

---

## Step G — Nginx Proxy Manager

1. https://nginx.agent-mate.ai/ → **Hosts → Proxy Hosts → Add Proxy Host** (new; do not edit hcp/mypoke)  

### Details

| Field | Value |
| --- | --- |
| Domain Names | `kb.agent-mate.ai` |
| Scheme | `http` |
| Forward Hostname | `kb-web` |
| Forward Port | **`3000`** (container port, not 3006) |
| Block Common Exploits | On |
| Websockets Support | On |

### Custom Locations (required)

| Location | Scheme | Forward Hostname | Forward Port |
| --- | --- | --- | --- |
| `/api/v1/kb/` | http | `kb-agent` | `8000` |
| `/mcp` | http | `kb-agent` | `8000` |
| `/sse` | http | `kb-agent` | `8000` |
| `/messages/` | http | `kb-agent` | `8000` |
| `/healthz` | http | `kb-agent` | `8000` |

### Advanced (SSE / long requests)

For locations that hit the agent (or host-level advanced if UI allows), ensure buffering off and long timeouts, e.g.:

```nginx
proxy_buffering off;
proxy_read_timeout 300s;
proxy_send_timeout 300s;
client_max_body_size 100m;
```

### SSL

1. Prefer grey-cloud DNS until LE succeeds  
2. SSL → Request new certificate for `kb.agent-mate.ai` → Force SSL  
3. After green cert, optional: Cloudflare orange + SSL mode **Full** / **Full (strict)**

**Done when:** `https://kb.agent-mate.ai/` is not Default Site / not 502.

---

## Step H — Smoke

- [ ] `https://kb.agent-mate.ai/` or `/admin` loads  
- [ ] First login `admin` / `admin` → forced password change  
- [ ] Issue an API key in Admin  
- [ ] `https://kb.agent-mate.ai/healthz` OK  
- [ ] Cursor MCP: URL `https://kb.agent-mate.ai/mcp` + Bearer key → list tools  
- [ ] ChatBox: Remote SSE URL `https://kb.agent-mate.ai/sse` + `Authorization=Bearer …` (not `/mcp`)  
- [ ] Spot-check `https://hcp.agent-mate.ai` or `https://mypoke.trade`  
- [ ] Change default admin password; do not leave `admin`/`admin`

---

## After success

- Update `Release-jobs/kb.agent-mate.ai/task-details.md` status  
- Update `specs/hk_vps_3_resources.md` with kb ports/volumes/containers  

## Abort / rollback (this app only)

- Portainer: stop/remove **only** stack `kb-agent`, or roll `IMAGE_TAG` back  
- NPM: delete/disable **only** `kb.agent-mate.ai` host  
- DNS: remove/disable **only** `kb` record  
- **Never** `docker network rm portainer_network`
