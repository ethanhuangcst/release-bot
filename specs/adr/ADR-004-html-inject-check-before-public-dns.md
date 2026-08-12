# ADR-004: HTML inject check before public DNS (post-incident)

## Status
Accepted

## Context
On 2026-08-12, `kb.agent-mate.ai` served Fake CAPTCHA / ClickFix malware via an injected `data:text/javascript;base64` loader in kb-web HTML after an initially clean deploy. NPM Advanced config was not the injection point. Re-exposing the site only via Cloudflare DNS before proving the new containers clean would risk re-infecting visitors.

## Decision
After any security rebuild or suspected HTML compromise of a public WebApp on this platform:

1. Deploy/re-pull the stack with NPM host **disabled** and public DNS for the app **absent or pointed away**.
2. Verify response body on the node (SSH `curl` to `127.0.0.1:<HOST_PORT>/` or equivalent) for injector markers (at least `data:text/javascript;base64`).
3. Enable NPM and re-check with `curl --resolve` (still without public DNS if possible).
4. Only then restore Cloudflare DNS and re-check on the real hostname.
5. Prefer a **new** immutable image tag for the rebuild; do not assume a previously good tag’s **running** container stayed unmodified.

## Rationale
- Separates “containers healthy” from “safe to be discovered on the public Internet.”
- Loopback/`--resolve` checks work when Portainer Console cannot connect and when host ports are firewalled from the operator laptop.
- New tags make GHCR Actions and Portainer Re-pull explicit after credential revocation.

Alternatives rejected for the reopen path: enable DNS first then “watch the browser”; rely only on Portainer “running” state; reuse old local image layers without Re-pull.

## Consequences
- Slightly longer restore time (extra verify gates).
- Operators need SSH or an in-network probe path documented per node.
- Incident lessons: `specs/knowledge/ops/kb-agent-clickfix-incident-2026-08-12.md`.
- IR checklist: `specs/knowledge/ops/ir-public-webapp-compromise-checklist.md`.
- Applied successfully for reopen on `v0.1.2`; later `v0.1.3` added CSP + Next CVE patch (verify `Content-Security-Policy` on public URL after deploy).

## Date
2026-08-12
