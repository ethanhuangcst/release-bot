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
  - cve-2025-66478
  - csp
  - npm
  - portainer
related_spec: knowledge/03-semi-auto-release.md
related:
  - adr/ADR-004-html-inject-check-before-public-dns.md
  - knowledge/ops/prevent-clickfix-html-inject.md
  - knowledge/ops/ir-public-webapp-compromise-checklist.md
  - knowledge/ops/kb-agent-image-tag-portainer-update.md
  - knowledge/ops/yecao-vps1-stopped-wordpress-mysql.md
  - Release-jobs/kb.agent-mate.ai/task-details.md
  - knowledge/09-isolation-safety.md
---

# kb-agent ClickFix / Fake CAPTCHA incident (2026-08-12)

## Summary（可复述结论）

| 项 | 内容 |
| --- | --- |
| 现象 | `kb.agent-mate.ai` 首页出现假 reCAPTCHA / “Complete Verification Steps”，诱导 Terminal 粘贴执行 |
| 服务端事实 | **kb-web** 返回的 HTML `<head>` 被植入 `data:text/javascript;base64` 加载器（链上 `eth_call` → `eval`） |
| 客户端后果 | 操作者执行剪贴板命令后 Mac 无法启动 → 重装 |
| 非入口 | NPM Advanced 为空；同节点 `hcp` / `mypoke` / `media` 当时未见同注入 |
| 时间线关键 | **凌晨部署后多次冒烟正常** → 之后才出现注入 ⇒ 偏 **运行期被改**，非首发镜像天生带毒 |
| 高价值根因线索 | 生产曾用 **Next.js 15.5.2**，存在 [CVE-2025-66478](https://nextjs.org/blog/CVE-2025-66478)（RSC **RCE**）；已升至 **15.5.7** |
| 恢复 | 止血 → 部分轮换密钥 → `v0.1.2` 干净重建 → `v0.1.3` CSP + Next 补丁；公网已验 CSP `nonce-` + `/healthz` ok |

## Timeline

| When | Event |
| --- | --- |
| 2026-08-12 凌晨 | 生产部署（`v0.1.1` / 后至 `09a9d68`）；多次测试**无**注入 |
| 同日稍后 | 假 CAPTCHA；操作者执行 ClickFix 命令；本机损毁 |
| IR 止血 | Portainer **Stop** `kb-agent` → NPM **Disable** → Cloudflare **删** `kb` DNS |
| IR 取证 | 外网 `curl` 抓到 base64 加载器；NPM 配置正常；容器停后运行态证据丢失 |
| IR 重建 | Tag **`v0.1.2`** @ `09a9d68` → GHCR → Re-pull；SSH `curl :3006` 验毒 0 → 开 NPM → 恢复 DNS |
| 加固 | App 仓：nonce CSP + **Next 15.5.7**；Tag **`v0.1.3`**；公网 CSP 生效；`/healthz` 502 时 NPM **再 Save**（ADR-003）后恢复 |
| 同日旁支 | 野草云1 `38.55.199.241`（WP + hcp MySQL）面板显示 Stopped；Start 后 MySQL 未起导致 WP DB 错误；启库后恢复。见 `yecao-vps1-stopped-wordpress-mysql.md` |

## Evidence（服务端）

- 注入形态（`<head>`）：

  `script src="data:text/javascript;base64,..."`

- 解码特征：BSC testnet RPC `eth_call` + `eval(atob(...))`（区块链 C2）。
- 头：`Server: openresty`，`X-Powered-By: Next.js`，`X-Served-By: kb.agent-mate.ai`。
- 主机 `3006` 公网常不可达；访客走 NPM `:443`。

## Evidence（社工）

- 假 “I'm not a robot” → 要求打开 Terminal → ⌘V → Enter。
- 正规 CAPTCHA **从不**要求出浏览器执行系统命令。
- 恶意域名/完整 one-liner：**不要**复现拉取；仅作 IOC 家族（ClickFix）。

## Attribution

| Claim | Confidence |
| --- | --- |
| 注入在 kb-web HTML，非纯本地扩展幻觉 | High |
| NPM Advanced 非注入点 | High |
| 首发/冒烟时镜像干净，属部署后写入 | High（操作者时间线） |
| Next 15.5.2 CVE-2025-66478 为合理初始入口 | Medium（时间线吻合；无主机内存证） |
| 同节点其它站同招 | Low（当时 HTML 抽查干净） |

## Containment playbook（已验证有效）

1. Portainer：**Stop** 受害 Stack（先不急着 Delete）。  
2. NPM：**Disable** 对应 Proxy Host（保留配置）。  
3. Cloudflare：**删除/改无效** 该应用 DNS。  
4. 轮换：GitHub 密码+PAT、Portainer/NPM/Cloudflare、主机密码；（DB/应用密钥 IR 中部分跳过 → 仍待办）。  
5. 重建：新 tag → GHCR 绿 → Re-pull → **loopback/`--resolve` 验 HTML** → 开 NPM → 恢复 DNS → 再验（ADR-004）。  
6. Portainer Console 常连不上：用 **SSH** `curl http://127.0.0.1:<HOST_PORT>/`。

## Hardening shipped（kb app）

| Tag | 内容 |
| --- | --- |
| `v0.1.2` | 事故后干净重建（同 commit `09a9d68`） |
| `v0.1.3` | nonce CSP（`strict-dynamic`，生产 `connect-src 'self'`）+ Next **15.5.7**；ADR 在 app 仓 `ADR-020` |

验证命令：

```bash
curl -sS -D - -o /dev/null "https://kb.agent-mate.ai/" | grep -i content-security-policy
curl -sS "https://kb.agent-mate.ai/" | grep -c 'data:text/javascript;base64'   # expect 0
curl -sS "https://kb.agent-mate.ai/healthz"   # expect {"status":"ok"}
```

`/healthz` 502 而首页 200：NPM 对该 Host **Save** 一次（ADR-003）。

## Gaps / follow-ups

- [ ] 轮换阿里云 Postgres + 应用 API Key / Resend / JWT 等  
- [ ] `kb-qdrant` 绑定 `127.0.0.1`；野草云1 **3306 勿对公网**  
- [ ] 野草云3 主机审计（auth / Docker events）  
- [ ] HTML IOC **定时探针**（尚未自动化）  
- [ ] 容器 `read_only` 等 P1 加固  

## Detection strings（安全）

```text
data:text/javascript;base64
eth_call
I'm not a robot
Complete these Verification Steps
```

## Durable lessons

1. **冒烟通过 ≠ 永远干净** — 部署后仍可能被运行期写入；要监测 + CSP + 及时打框架 CVE。  
2. **ClickFix 第二环是人** — 任何要 Terminal/Run 粘贴的“验证”视为攻击。  
3. **IR 顺序** Stop → Disable proxy → Drop DNS；再重建与验毒。  
4. **Next/React RSC CVE** 必须跟进；15.5.2 不可继续跑生产。  
5. **密钥与口令不进 Git**；`svr_hk_vps_*/secret.md` 已纳入 `.gitignore`。  
6. 通用手册保持占位符；当次细节写 `Release-jobs/` + `specs/knowledge/ops/`。

## Links

- Job: `Release-jobs/kb.agent-mate.ai/task-details.md`  
- Node: `svr_hk_vps_3/hk_vps_3_setting.md`  
- App: https://github.com/ethanhuangcst/kb.agent-mate.ai （`v0.1.3` / ADR-020）  
- ADR-004（本仓）：验毒后再恢复 DNS  
- 防再发总表：`prevent-clickfix-html-inject.md`  
- IR 清单：`ir-public-webapp-compromise-checklist.md`  
