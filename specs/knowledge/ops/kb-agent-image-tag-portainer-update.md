---
title: kb-agent release — IMAGE_TAG, Portainer 500, MCP 502, ChatBox
type: ops-lesson
status: active
as_of: 2026-08-12
tags:
  - release
  - portainer
  - ghcr
  - kb-agent
  - npm
  - chatbox
  - mcp
related_spec: knowledge/03-semi-auto-release.md
related:
  - adr/ADR-002-image-tag-is-ghcr-tag-not-branch.md
  - adr/ADR-003-npm-refresh-after-kb-agent-recreate.md
  - knowledge/ops/mypoke-first-deploy.md
  - Release-jobs/kb.agent-mate.ai/deployment-plan.md
---

# kb-agent release — IMAGE_TAG, Portainer 500, MCP 502, ChatBox

## Summary
Two failure modes hit the same release window (2026-08-12): (1) Portainer Stack Update **500** because `IMAGE_TAG=main` is not a GHCR tag; (2) after a successful pull to sha `09a9d68`, **homepage OK but MCP/ChatBox 502** until NPM Proxy Host was Saved again. ChatBox then showed Test OK / tools listed but chat tool calls hung until the **ChatBox app was restarted**.

## Evidence

### A. Portainer Update 500 (wrong tag)
- UI toast: Request failed with status code 500.
- `portainer` Logs: `failed to resolve reference "…/web|agent|rag:main": not found`.
- Packages had real tags: `09a9d68`, `latest`, `v0.1.1`, etc. — not branch name `main`.
- Stack-owned Recreate cannot change Image; must change Stack `IMAGE_TAG` then Update.

### B. Web 200 / agent paths 502 (stale NPM upstream)
- `/` `/guide` → 200 (`kb-web`).
- `/healthz` `/mcp` `/sse` `/api/v1/kb/` → 502 openresty.
- `kb-agent` running on `portainer_network`; Uvicorn up on `:8000`.
- Hitting `/healthz` produced **no** new lines on agent Logs → traffic not reaching new container.
- Fix: NPM → Proxy Host `kb.agent-mate.ai` → **Save** (no edits) → `/healthz` returned `{"status":"ok"}`; `/mcp` `/sse` returned 401 without key (routed correctly).

### C. ChatBox client stuck after recovery
- Config correct: Remote http/sse, `https://kb.agent-mate.ai/sse`, single `Authorization=Bearer …`.
- Test success; ten tools visible.
- Chat “Preparing `kb_list_knowledge`” hung; Cursor MCP list worked.
- Fix: **Quit and restart ChatBox** → tool calls worked.

### D. Operator pitfalls
- Looking at **`kb-web`** Logs (Next.js) when diagnosing agent paths.
- Portainer Console stuck on Connecting with `bash` / `sh` (skip Console; use NPM Save + public `/healthz`).

## Lesson / guidance

1. **IMAGE_TAG** = tag that exists on GHCR for **every** image the stack pulls (ADR-002). Never assume git branch name.
2. After stack Update/recreate of `kb-agent`: **Save** NPM host `kb.agent-mate.ai`, then require `/healthz` → `{"status":"ok"}` (ADR-003).
3. Split smoke: homepage ≠ MCP. Probe `/healthz` `/mcp` `/sse` separately.
4. UI-only copy changes: prefer updating **web** only (or keep agent/rag on last good tag) to reduce agent churn.
5. After agent outage recovery: restart ChatBox (and reconnect Cursor MCP) if Test works but chat tool calls hang.
6. Diagnose Portainer 500 via container **`portainer` → Logs**, not browser CSP/translation noise.
7. ChatBox must use **`/sse`** (not `/mcp`); Header must not double-`Bearer` (prior incident 2026-08-12).

## Links
- `specs/adr/ADR-002-image-tag-is-ghcr-tag-not-branch.md`
- `specs/adr/ADR-003-npm-refresh-after-kb-agent-recreate.md`
- `Release-jobs/kb.agent-mate.ai/step-by-step.md`
- `Release-jobs/kb.agent-mate.ai/deployment-plan.md` §7.1
- App: https://kb.agent-mate.ai/
