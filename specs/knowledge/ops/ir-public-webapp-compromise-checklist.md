---
title: IR checklist — public WebApp HTML compromise / ClickFix
type: ops-lesson
status: active
as_of: 2026-08-12
tags:
  - security
  - incident-response
  - checklist
related:
  - knowledge/ops/kb-agent-clickfix-incident-2026-08-12.md
  - adr/ADR-004-html-inject-check-before-public-dns.md
  - knowledge/ops/prevent-clickfix-html-inject.md
  - adr/ADR-003-npm-refresh-after-kb-agent-recreate.md
---

# IR checklist — public WebApp HTML compromise / ClickFix

Reusable after Fake CAPTCHA / injected scripts on a Portainer + NPM + Cloudflare site.

## 0. Operator safety

- [ ] Do **not** open the site and click “VERIFY” / paste Terminal commands.
- [ ] Work from a **clean** machine; rotate credentials used on any infected host.

## 1. Contain (minutes)

- [ ] Portainer: **Stop** the app Stack (prefer Stop over Delete for first cut).
- [ ] NPM: **Disable** the Proxy Host (keep config).
- [ ] Cloudflare: **Delete** or neutralize the app DNS record only.
- [ ] Spot-check sibling apps’ View Source for `data:text/javascript;base64`.

## 2. Confirm injector (safe)

```bash
curl -sS "https://<APP_DOMAIN>/" | grep -c 'data:text/javascript;base64'
# After stop/disable, expect failure/timeout — good.
```

- [ ] Note whether NPM Advanced is empty (rules out obvious proxy HTML rewrite).
- [ ] Do **not** fetch malware second-stage URLs.

## 3. Credentials (minimum)

- [ ] GitHub password + revoke PATs; refresh Portainer GHCR registry secret.
- [ ] Portainer / NPM / Cloudflare passwords (and sessions).
- [ ] Host / panel passwords.
- [ ] DB + app secrets (API keys, mail, JWT) — do not skip forever.

## 4. Rebuild (ADR-004)

- [ ] Audit recent git commits / Actions / package tags.
- [ ] Prefer **new semver tag** from audited commit; wait GHCR green.
- [ ] Patch framework CVEs before/with rebuild (e.g. Next.js RSC advisories).
- [ ] Portainer: `IMAGE_TAG=<new>` + **Re-pull**.
- [ ] Verify HTML **before** public DNS:

```bash
# on node
curl -sS http://127.0.0.1:<HOST_PORT>/ | grep -c 'data:text/javascript;base64'  # expect 0
# or with DNS still down
curl -sS --resolve <APP_DOMAIN>:443:<NODE_IP> https://<APP_DOMAIN>/ | grep -c 'data:text/javascript;base64'
```

- [ ] Enable NPM → re-check → restore DNS → re-check public URL.
- [ ] If homepage 200 but `/healthz`/`/mcp` 502: NPM Host **Save** again (ADR-003).

## 5. Posture after reopen

- [ ] Confirm security headers (e.g. `Content-Security-Policy` with `nonce-` if deployed).
- [ ] Schedule HTML IOC monitor.
- [ ] Write ops note under `specs/knowledge/ops/` + update `Release-jobs/<app>/task-details.md`.
- [ ] No secrets in git; local only under gitignored paths.
