---
title: mypoke.trade first-deploy ops notes
type: ops-lesson
status: active
as_of: 2026-08-10
tags:
  - release
  - cloudflare
  - npm
  - next-standalone
related_spec: knowledge/03-semi-auto-release.md
related:
  - adr/ADR-001-next-standalone-runtime-uploads.md
  - knowledge/07-troubleshooting.md
---

# mypoke.trade first-deploy ops notes

## Summary
First public deploy of `mypoke.trade` on 野草云3 succeeded (orange cloud + Full strict). Post-go-live fixes: agent needed `TCGDEX_BASE_URL`; Next standalone needed API rewrite for runtime uploads.

## Evidence
- Guided DNS → NPM Details (`mypoke-web:3000`) → Certificates hang → smoke
- Valuate returned `MCP_FAILED` until agent compose received `TCGDEX_BASE_URL`
- Upload files on disk with HTTP 404 until rewrite → `/api/uploads/...`

## Lesson / guidance
- Compose-review every service that calls TCGdex/Qwen for required env (not only `web`)
- Prefer DoH / `dig +tcp` when local UDP DNS lies; phone cellular is a good smoke path
- Next standalone + runtime `public/` writes: plan API/object/DB serving up front (ADR-001)

## Links
- `Release-jobs/mypoke.trade/task-details.md`
- `specs/adr/ADR-001-next-standalone-runtime-uploads.md`
