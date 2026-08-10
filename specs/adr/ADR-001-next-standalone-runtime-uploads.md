# ADR-001: Next standalone — serve runtime uploads via API rewrite

## Status
Accepted

## Context
Production web images use Next.js `output: "standalone"`. Custom card photos were written under `public/uploads/` at runtime and referenced as `/uploads/...`. Files existed on disk, but HTTP returned 404; AI flows that consumed the upload body still worked, so the UI looked “uploaded” with a blank preview.

## Decision
For Next standalone on this stack: do **not** rely on the standalone server to expose files written to `public/` after boot. Persist bytes (volume or object/DB store) and expose them through an authenticated route (or CDN), optionally rewriting `/uploads/...` → that route. Keep a named Docker volume if the store is still filesystem-backed.

## Rationale
Alternatives considered: bind-mount only (still 404 without a server path), NPM static sidecar (extra moving parts), edge rebuild of `public` (impractical). API rewrite preserves existing URL shapes in the DB while matching standalone behavior.

## Consequences
- Web compose may include an uploads volume until storage moves to DB/object store.
- Image `<img>` requests need session cookies (same-origin) if the route is authed.
- Future apps on this VPS pattern should bake the lesson into compose review checklists.

## Date
2026-08-10
