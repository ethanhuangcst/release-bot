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
  - cve-2025-66478
related_spec: knowledge/09-isolation-safety.md
related:
  - knowledge/ops/kb-agent-clickfix-incident-2026-08-12.md
  - knowledge/ops/ir-public-webapp-compromise-checklist.md
  - adr/ADR-004-html-inject-check-before-public-dns.md
  - knowledge/03-semi-auto-release.md
---

# Prevent ClickFix / HTML inject on self-hosted WebApps

## Summary

Break **both** chains: (1) malicious script in first-party HTML, (2) human OS command paste (ClickFix). Prefer **framework CVE hygiene + nonce CSP + HTML IOC monitors + immutable-ish containers**; operator education alone is not enough for public visitors.

Research / incident snapshot: **2026-08-12**.

## Status on kb.agent-mate.ai（as_of 2026-08-12）

| Control | Status |
| --- | --- |
| Next.js patch CVE-2025-66478 | **Done** — `15.5.2` → **`15.5.7`** in tag **`v0.1.3`** |
| Nonce CSP (`strict-dynamic`, prod `connect-src 'self'`) | **Done** — live `Content-Security-Policy` with `nonce-` |
| Clean rebuild after inject | **Done** — `v0.1.2` then `v0.1.3` |
| HTML IOC automated monitor | **Open** |
| DB / app secret rotation | **Open**（IR 中跳过） |
| qdrant / MySQL bind lockdown | **Open** |
| Container `read_only` etc. | **Open** |

App ADR: `kb.agent-mate.ai` repo `specs/adr/ADR-020-csp-nonce-clickfix-defense.md`.

## Threat model

| Stage | Mechanism |
| --- | --- |
| A | Post-deploy write to kb-web responses (RCE / panel / host) |
| B | Browser runs loader → Fake CAPTCHA |
| C | Victim pastes clipboard into Terminal / Run |

Plausible A for this incident: **Next.js RSC RCE** on unpatched 15.5.x ([CVE-2025-66478](https://nextjs.org/blog/CVE-2025-66478)).

## Controls

### P0

1. **Keep Next/React on patched releases** — no production lag on RSC advisories.  
2. **Nonce CSP** on Next web (`middleware` + `force-dynamic`); verify header reaches clients (NPM must not strip).  
3. **HTML IOC monitor** on `/` (and key routes); on hit → IR checklist.  
4. **Finish secret rotation** (DB, API keys, Resend, JWT, PATs).  
5. **Shrink exposure** — loopback binds for DBs; lock admin UIs.  
6. **Human rule** — no site may require Terminal paste for “CAPTCHA”.

### P1

- Compose: `read_only`, `no-new-privileges`, non-root, drop caps.  
- Immutable image tags/digests; Re-pull after incidents.  
- SSH keys-only; minimal open management ports.  
- Optional Cloudflare WAF (edge only).

### P2

- App security review; host audit; release handbook baseline HTML after every Update.

## Verify after deploy

```bash
curl -sS -D - -o /dev/null "https://<APP>/" | grep -i content-security-policy
curl -sS "https://<APP>/" | grep -c 'data:text/javascript;base64'   # 0
curl -sS "https://<APP>/healthz"   # ok JSON; if 502 → NPM Save (ADR-003)
```

## Detection strings

```text
data:text/javascript;base64
eth_call
I'm not a robot
Complete these Verification Steps
```

## Related

- Incident narrative: `kb-agent-clickfix-incident-2026-08-12.md`  
- IR checklist: `ir-public-webapp-compromise-checklist.md`  
- ADR-004: HTML verify before public DNS  
