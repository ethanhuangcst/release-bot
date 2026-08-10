---
name: release-guide
description: >
  Guide semi-automatic WebApp deployment to self-hosted VPS using the local
  ./knowledge handbook (non-RAG, placeholders). Use when the user asks to deploy,
  release, publish, update Portainer/NPM, or walk through the release checklist.
---

# Release Guide

## When to use

User wants to deploy/release/update an app on their VPS, or asks what to do next in a release.

## Knowledge source

Read files under `knowledge/` (project root). Index: `knowledge/README.md`.  
Placeholders: `knowledge/variables.md`.

Do **not** invent host/repo facts — collect them from the user.  
Do **not** hardcode a previous app’s repo/image/service names into replies or back into `knowledge/`.  
Do **not** store or request secrets into the repo.

## Procedure

1. Load `knowledge/variables.md`, `00-overview.md`, `01-environment.md`, `02-stack.md`
2. Collect placeholders: repo, `IMAGE_TAG`, node, services/ports/images, `STACK_NAME`, `APP_SLUG`, DB migrate need
3. Collect `<EXISTING_APPS>` on the target node; for new deploy or port/domain/stack changes, complete `knowledge/09-isolation-safety.md` gate **before** Portainer deploy
4. Follow `knowledge/03-semi-auto-release.md` **one step at a time**
5. Open detail files only when needed: `04`, `05`, `08`, `09`
6. Enforce: no local app image build; registry pull only; never delete/recreate shared external network; DB connect before migrate; touch only this app’s Stack/NPM Host/DNS
7. On failure → `07-troubleshooting.md`; on abort → `06-rollback.md` (**this app only**)
8. Step 8 must include smoke test of **this app** plus spot-check of ≥1 existing app
9. After success, remind user to update session notes — keep `knowledge/` generic with placeholders

## Conversational protocol (every turn)

Reply in **four short blocks** — one step only:

1. **当前步** — Step N — title
2. **做什么** — copy-pastable command and/or Portainer/NPM/Cloudflare UI path（填入用户已提供的实值）
3. **完成标准** — how to know it worked
4. **请回复** — `完成` / `失败`(+脱敏日志) / `跳过（原因）` / `改节点或 tag`

## Style

- Short steps; never dump the full checklist at once
- UI paths for Portainer / NPM / Cloudflare when GUI is the tool
- Wait for user confirmation before the next step
- Never ask the user to paste production passwords into chat
