# Step-by-step — where2play.place → 野草云3

Guided release for stack **`where2play`** (third wave). **Canonical plan:** `3.where2play/2play-specs/6.deployment-plan.md`.

**Gate:** places-agent is **live** (`search_places`, `plan_itinerary`). Remaining: entire app runtime + Docker/CI in `ethanhuangcst/where2play.places`, host **`3005`**, caller key.

| Item | Value |
| --- | --- |
| Stack / container | `where2play` / `where2play-web` |
| Domain | `https://where2play.place` (not `.places`) |
| Host debug | **`3005→3000`** — do **not** take **`3004`** or **`3007`** |
| NPM | `http://where2play-web:3000` |
| Agent URL | `PLACES_AGENT_BASE_URL=http://places-agent:3000` |
| Caller key | `PLACES_AGENT_CALLER_KEY` |
| DB | TBD — never `places_agent` or `what2eat` |
| Forbidden | map vendor keys |

Follow `workspace-specs/6.deployment-plan.md` §12.3.
