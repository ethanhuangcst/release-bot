# ADR-003: Refresh NPM Proxy Host after kb-agent stack recreate

## Status
Accepted

## Context
On 2026-08-12, stack `kb-agent` was updated to a new `IMAGE_TAG` (UI copy change on `kb-web`). After containers recreated, `https://kb.agent-mate.ai/` returned 200 but `/healthz`, `/mcp`, `/sse`, and `/api/v1/kb/*` returned NPM **502**. `kb-agent` was `running` on `portainer_network` with healthy Uvicorn logs, yet public agent paths failed until the Nginx Proxy Manager host for `kb.agent-mate.ai` was **Saved** again (no field changes). ChatBox could Test MCP and list tools only after upstream recovery; a stuck “Preparing tool” state cleared only after restarting the ChatBox app.

## Decision
1. After any Portainer update/recreate that replaces `kb-agent` (or the whole `kb-agent` stack), **re-open and Save** the NPM Proxy Host `kb.agent-mate.ai` (Custom Locations unchanged is fine) before declaring MCP/ChatBox healthy.
2. Smoke gate: `GET https://kb.agent-mate.ai/healthz` → `{"status":"ok"}` (not 502), then client Test.
3. For **UI-only** web changes, prefer updating **only** the `web` image (or pin `agent`/`rag` to the last known-good tag) instead of bumping a shared `IMAGE_TAG` for all services when avoidable.

## Rationale
Alternatives considered:

- Restart `kb-agent` only — did not restore public routes while NPM still pointed at a stale upstream.
- Assume Docker DNS always refreshes for NPM Custom Locations — failed in practice after stack recreate.
- Always restart NPM container — works but briefly affects all hosts on the node; host Save is narrower.
- Rely on ChatBox reconnect without app restart — Test/tools could look fine while chat tool calls stayed stuck on a stale SSE session.

## Consequences
- Release checklists for `kb-agent` must include NPM Save + `/healthz` after stack Update.
- Operators should not treat “homepage 200” as MCP healthy.
- ChatBox/Cursor clients may need reconnect or full app restart after a prolonged agent outage.

## Date
2026-08-12
