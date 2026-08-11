# ADR-002: IMAGE_TAG must be a published GHCR tag, not a git branch name

## Status
Accepted

## Context
During the 2026-08-12 production update of stack `kb-agent` (homepage copy change), Portainer Stack Update returned HTTP 500. Operators had set `IMAGE_TAG=main` because the commit was on branch `main`. Portainer logs showed:

`failed to resolve reference "ghcr.io/…/web|agent|rag:main": not found`

The images that existed were tags such as `09a9d68`, `latest`, `v0.1.1` — published by CI to GHCR — not the branch name.

## Decision
For Portainer / compose `IMAGE_TAG` (and equivalent env):

1. Use only a tag that **already appears** on GHCR Packages for **every** service image the stack pulls (e.g. `web` / `agent` / `rag`).
2. Prefer, in order: the run’s **git sha** short/long tag, an explicit **semver** tag (`v*`), or **`latest`** when CI documents that it updates `latest` on the default branch.
3. **Do not** assume git branch names (`main`, `release-1`, …) are valid container tags unless Packages lists that exact string.

## Rationale
Alternatives considered:

- Always use branch name as tag — fails unless the workflow explicitly pushes that tag; caused this outage path.
- Always use `latest` only — works for some default-branch builds but is ambiguous for rollback and non-default branches.
- Sha / Packages-confirmed tag — matches what CI actually published; pull succeeds; Portainer Update no longer 500s from “not found”.

## Consequences
- Release checklists must include “open Packages → copy real tag” before Portainer Update.
- Portainer 500 on stack update should first be checked against pull errors in the `portainer` container Logs (often image tag missing), not assumed to be Portainer corruption.
- Stack-managed containers cannot change Image via Recreate alone; tag changes require a successful Stack env/compose update after a real tag exists.

## Date
2026-08-12
