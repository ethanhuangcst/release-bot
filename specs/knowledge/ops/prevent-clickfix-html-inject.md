---
title: Prevent ClickFix / HTML inject on self-hosted WebApps
type: ops-lesson
status: active
as_of: 2026-08-12
tags:
  - security
  - clickfix
  - csp
  - hardening
  - kb-agent
  - monitoring
related_spec: knowledge/09-isolation-safety.md
related:
  - knowledge/ops/kb-agent-clickfix-incident-2026-08-12.md
  - adr/ADR-004-html-inject-check-before-public-dns.md
  - knowledge/03-semi-auto-release.md
---

# Prevent ClickFix / HTML inject on self-hosted WebApps

## Summary

After the 2026-08-12 `kb.agent-mate.ai` incident (post-deploy HTML injector → Fake CAPTCHA / ClickFix → operator Terminal paste), defenses must break **both** chains: (1) malicious script delivery in first-party HTML, (2) human execution of clipboard OS commands. Prefer browser CSP + runtime immutability + continuous HTML IOC probes; treat operator education as necessary but not sufficient for public visitors.

Research snapshot date: **2026-08-12** (public vendor/analyst write-ups 2025–2026 + this platform’s incident evidence).

## Threat model (this platform)

| Stage | What happened / can happen |
| --- | --- |
| A. Server | Attacker alters **kb-web** (or equivalent) responses after a clean deploy |
| B. Browser | Injected loader (`data:text/javascript;base64` → chain RPC → `eval`) shows Fake CAPTCHA |
| C. Human | Victim pastes clipboard command into Terminal / Run / PowerShell |

NPM Advanced was **not** the injector in the recorded incident; sibling apps were clean at IR check time. Root **initial access** on the node/app remains unknown → assume host + app + panel credentials stay in scope.

## Controls (priority)

### P0 — Do first

1. **Nonce Content-Security-Policy on Next.js web**
   - `script-src` with per-request `'nonce-…'` + `'strict-dynamic'`; do **not** rely on `'unsafe-inline'` for scripts.
   - Goal: browsers refuse un-nonced inline / `data:` script tags like the incident loader.
   - Implement in app middleware/headers; ensure NPM does not strip CSP.
   - Refs: [Next.js CSP](https://nextjs.org/docs/14/app/building-your-application/configuring/content-security-policy)

2. **HTML IOC monitor**
   - Periodic `curl` of `/` (and key routes) for:
     - `data:text/javascript;base64`
     - Fake CAPTCHA copy (“I'm not a robot”, “Complete these Verification Steps”, Terminal + ⌘V / Win+R instructions on apps that never use reCAPTCHA)
   - On hit: alert + Disable NPM host and/or remove DNS (same order as incident IR / ADR-004).
   - Should be a **recurring monitor**, not a one-off check.

3. **Finish secret rotation**
   - DB, app API keys, Resend, JWT/session secrets, any PAT still shared with panels — anything skipped during IR.

4. **Shrink exposure**
   - Bind vector DB (e.g. qdrant) to `127.0.0.1` only.
   - Portainer / NPM: strong unique passwords, few admins; prefer Cloudflare Access or IP allowlist on management hostnames.
   - Security groups: no unnecessary public host ports.

5. **Human rule (operators + docs)**
   - No legitimate site / CAPTCHA requires opening Terminal/Run and pasting a command.
   - Public explainers: [Microsoft on ClickFix](https://www.microsoft.com/en-us/security/blog/2025/08/21/think-before-you-clickfix-analyzing-the-clickfix-social-engineering-technique/), [Huntress](https://www.huntress.com/blog/dont-sweat-clickfix-techniques).

### P1 — Hardening

1. **Immutable-ish containers** in compose/Portainer stacks:
   - `read_only: true` + `tmpfs` for required writable paths
   - `security_opt: [no-new-privileges:true]`, drop caps, non-root where feasible
   - Raises cost of persisting malware in the container filesystem after RCE.

2. **Image discipline**
   - Deploy by **immutable tag or digest**; avoid floating `latest` for prod.
   - After credential incidents: new tag + Re-pull (as with `v0.1.2`).

3. **Management plane**
   - SSH: keys only, disable password auth where possible; minimal open 22.
   - Audit Portainer users and registry PATs (`read:packages` only when possible).

4. **Edge (optional)**
   - Cloudflare proxy + WAF/bot features as defense-in-depth; not a substitute for CSP or host hygiene.

### P2 — Root cause & platform

1. Application security review (authz on admin/API, uploads, deps, debug endpoints).
2. Host audit (auth logs, Docker events, unexpected processes) while initial access is unknown.
3. Extend release handbook: after go-live and after every Stack Update, save/compare HTML baseline (ADR-004).

## What not to rely on alone

- User willpower (“I won’t paste”) — fails for other visitors.
- AV that only watches downloaded files — ClickFix often uses user-launched shell + `curl|bash`.
- Redeploy without rotating secrets or verifying HTML.
- Assuming NPM/Cloudflare misconfig was the only vector.

## Suggested rollout order

1. CSP on kb-web (new release tag)  
2. HTML IOC probe + alert  
3. Secrets + port/bind + admin access lockdown  
4. `read_only` / capability hardening in compose  
5. App + host root-cause audit  

## Detection strings (safe)

```text
data:text/javascript;base64
eth_call
I'm not a robot
Complete these Verification Steps
```

Pair with ADR-004 verify gates before restoring public DNS after any suspected compromise.

## Related local docs

- Incident: `specs/knowledge/ops/kb-agent-clickfix-incident-2026-08-12.md`
- Process ADR: `specs/adr/ADR-004-html-inject-check-before-public-dns.md`
- Job notes: `Release-jobs/kb.agent-mate.ai/task-details.md`
