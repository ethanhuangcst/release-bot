# Release Job: media-marketing-agent

Updated: 2026-08-10  
Status: **usable** — HTTPS + 扫码可用；待 Portainer 与新镜像 `ccf64d4` 对齐

## Confirmed

| Field | Value | Source |
| --- | --- | --- |
| Repository | https://github.com/ethanhuangcst/media-marketing-agent.git | user |
| Git ref | `main` @ `ccf64d4` | push |
| APP_DOMAIN | `media.mkt-agent.ai` | user |
| NODE | 野草云3 / `38.55.192.140` | user |
| STACK | `media-mkt-agent` | user |
| Health | bilibili/zhihu `session_ok=true`（扫码后） | node |

## Pending

- [x] HTTPS + health
- [x] Accounts 扫码（user：完成；健康检查见 session_ok）
- [ ] Portainer env：`CRAWLER_HEADLESS=false`（与现网一致）
- [ ] CI `ccf64d4` Success 后：强制拉新镜像（含 HOME/`PLAYWRIGHT_BROWSERS_PATH`/Xvfb），去掉手工 entrypoint
- [ ] 可选：SSE Custom locations；Cloudflare 橙云 Full/strict

## Notes

- 曾错域名 `media.mkt-agents.ai`
- Chromium 曾装在 root cache；HOME 属主 root 导致 crashpad
- 现网容器曾用自定义 entrypoint 热修 — Update stack 前须先拉新镜像
