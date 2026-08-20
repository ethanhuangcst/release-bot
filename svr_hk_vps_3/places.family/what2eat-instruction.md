# Step-by-step — what2eat.food → 野草云3

Guided release for stack **`what2eat`** (second wave). **Canonical plan:** `2.what2eat/2eat-specs/6.deployment-plan.md` (this file is a pointer + inventory facts).

**Gate:** places-agent is **live**. Remaining: prod Docker/CI in `ethanhuangcst/what2eat.food`, Aliyun DB **`what2eat`**, caller key, host **`3004`**.

| Item | Value |
| --- | --- |
| Stack / container | `what2eat` / `what2eat-web` |
| Domain | `https://what2eat.food` |
| Host debug | **`3004→3000`** — do **not** take **`3007`** |
| NPM | `http://what2eat-web:3000` |
| Agent URL | `PLACES_AGENT_BASE_URL=http://places-agent:3000` |
| Caller key | `PLACES_AGENT_CALLER_KEY` (never `PLACES_AGENT_API_KEY` / `NEXT_PUBLIC_*`) |
| DB | Aliyun `101.132.156.250:5432/what2eat` (ADR-023) |
| Forbidden | `OPENAI_*`, map vendor keys, SQLite volume |

Follow family step order in `workspace-specs/6.deployment-plan.md` §12.2 and isolation in `knowledge/09-isolation-safety.md`.
