---
title: kb-agent ClickFix / Fake CAPTCHA incident
type: ops-lesson
status: active
as_of: 2026-08-12
tags:
  - security
  - incident
  - kb-agent
  - clickfix
  - npm
  - portainer
related_spec: knowledge/03-semi-auto-release.md
related:
  - adr/ADR-004-html-inject-check-before-public-dns.md
  - knowledge/ops/prevent-clickfix-html-inject.md
  - knowledge/ops/kb-agent-image-tag-portainer-update.md
  - Release-jobs/kb.agent-mate.ai/task-details.md
  - knowledge/09-isolation-safety.md
---

# kb-agent ClickFix / Fake CAPTCHA incident (2026-08-12)

## Summary

Same-day after a clean first production deploy of `kb.agent-mate.ai` on 野草云3, the live **kb-web** HTML was later injected with a Fake CAPTCHA / ClickFix loader. Visitors saw a forged “I'm not a robot” UI that pushed a malicious shell one-liner onto the clipboard; executing it in Terminal compromised an operator Mac. Sibling apps on the same node did not show the same HTML injection at check time. Containment → credential rotation (partial) → rebuild as tag **`v0.1.2`** → HTML verify → restore NPM/DNS.

## Timeline (operator-reported + verified)

| When | Event |
| --- | --- |
| 2026-08-12 early AM | Last deploy; multiple smoke tests **normal** (no injection) |
| Later same day | Homepage showed Fake CAPTCHA; operator ran clipboard Terminal command; Mac failed to boot → wipe/reinstall |
| IR | Portainer **Stop** `kb-agent` → NPM **Disable** host → Cloudflare **Delete** `kb` A record |
| IR | Spot-check: `hcp` / `mypoke` / `media` — no same injector in HTML |
| IR | NPM Details/Locations matched plan; **Advanced custom Nginx empty** |
| IR | Stack containers already gone after stop; local unused images `v0.1.1` + `09a9d68` removed |
| IR | Tag `v0.1.2` on commit `09a9d68`; GHCR Actions success; stack redeployed |
| IR | Verify via SSH `curl http://127.0.0.1:3006/` — injector count **0**; then NPM enable + `--resolve` check; then DNS restore + public check **0** |

## Evidence (server)

- Public HTML (`/`, `/guide`, `/login`) contained in `<head>`:

  `script src="data:text/javascript;base64,..."`

- Decoded loader: BSC testnet `eth_call` to a contract address, then `eval(atob(...))` (blockchain C2 pattern).
- Response headers indicated origin **Next.js / kb-web** behind NPM (`Server: openresty`, `X-Powered-By: Next.js`, `X-Served-By: kb.agent-mate.ai`).
- Host port `3006` not reachable from arbitrary public clients (timeout); traffic was via NPM :443.

## Evidence (client / social engineering)

- UI: fake reCAPTCHA → “Complete these Verification Steps” (open Terminal → ⌘V → Enter).
- Clipboard / instructed command pattern: `curl … | bash` to a third-party host (IOC family: ClickFix / Fake CAPTCHA). Do not re-fetch or execute.

## Attribution (confidence)

| Claim | Confidence |
| --- | --- |
| Injection was in **kb-web HTML responses**, not a browser-only hallucination | High |
| NPM Advanced custom config was **not** the injector | High (UI empty at IR) |
| Deploy/CI image was clean at go-live (tests normal after last deploy) | High (operator timeline) |
| Compromise was **post-deploy runtime** write to kb-web (or host-scoped change affecting only that app’s responses) | Medium–High |
| Initial access vector (app RCE vs panel/SSH/PAT vs host malware) | **Unknown** — runtime evidence lost when containers removed |
| Sibling apps compromised the same way at IR time | Low (HTML checks clean) |

## Containment that worked

1. Stop Portainer stack `kb-agent` (do not need Delete for first cut).
2. Disable NPM Proxy Host `kb.agent-mate.ai` (keep config for forensics).
3. Remove Cloudflare DNS `kb` so casual traffic stops even if NPM is re-enabled by mistake.
4. Rotate GitHub password + revoke PATs; Portainer / NPM / Cloudflare passwords; 野草云 host password.
5. Rebuild from audited commit with **new** semver tag (`v0.1.2`), re-pull via Portainer, verify HTML **before** public DNS.

## Gaps / follow-ups

- [ ] Rotate Aliyun Postgres credentials and app secrets (API keys, Resend, JWT, etc.) — skipped during IR.
- [ ] Bind `kb-qdrant` published port to `127.0.0.1` only (IR screenshot showed `6336:6333` without loopback bind).
- [ ] Host-level audit on 野草云3 (auth logs, unexpected processes, Portainer users, Docker events) — still recommended while root cause unknown.
- [ ] Daily short HTML check for `data:text/javascript;base64` on `kb` (and spot-check siblings) for a cooling-off period.

## Detection strings (safe)

Search page source / `curl` body for:

- `data:text/javascript;base64`
- `eth_call` + unexpected script next to Next.js head assets
- Visible Fake CAPTCHA / “Complete these Verification Steps” / Terminal + ⌘V instructions on a first-party app that never used reCAPTCHA

## Lesson / guidance

1. After any public WebApp go-live: save a **View Source** / `curl` snippet; re-check after later Stack updates.
2. Never run Terminal commands from a website “verification” flow; real reCAPTCHA never requires macOS Terminal.
3. IR order: **Stop app → Disable proxy → Drop DNS** before deep forensics; Portainer Console may be unusable — prefer SSH `curl` to `127.0.0.1:<HOST_PORT>`.
4. Post-incident rebuild: new git tag → wait GHCR green → deploy with Re-pull → verify HTML on loopback → enable NPM → restore DNS → verify again on public URL.
5. Keep `knowledge/` free of secrets; record IOCs and steps here / in `Release-jobs/…` only.

## Links

- Stack / job: `Release-jobs/kb.agent-mate.ai/`
- Node: `svr_hk_vps_3/hk_vps_3_setting.md`
- Rebuild tag: `v0.1.2` @ `09a9d68`
- Related ADR: `specs/adr/ADR-004-html-inject-check-before-public-dns.md`
