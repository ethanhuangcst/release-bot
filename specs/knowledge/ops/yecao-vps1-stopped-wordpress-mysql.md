---
title: 野草云1 stopped — WordPress DB error / MySQL
type: ops-lesson
status: active
as_of: 2026-08-12
tags:
  - ops
  - mysql
  - wordpress
  - yecao
related:
  - knowledge/ops/kb-agent-clickfix-incident-2026-08-12.md
  - svr_hk_vps_3/hk_vps_3_setting.md
---

# 野草云1 stopped — WordPress DB error / MySQL

## Summary

Host **`38.55.199.241`**（野草云1 / woodensword）在控制台为 **Stopped** 时，外网对 22/80/443 均为 timeout。面板 **Start** 后 LiteSpeed 恢复，但 WordPress 报 **Error establishing a database connection**，直至本机 **MySQL/MariaDB 服务被启动**。

同 IP 在库存档中亦为 **`hcp-engagement-agent` 外部 MySQL**（`…:3306/hca`）。主机停机时 hcp 页面仍可能 200（未写库路径），但库相关功能有风险。

## What worked

1. Panel: confirm Running (not only “clicked Start”).  
2. VNC (SSH may be firewalled): `systemctl start mysql` or `mariadb`.  
3. Refresh WordPress.

## Follow-ups

- [ ] Find why the instance was Stopped (billing, manual, provider).  
- [ ] **Do not expose MySQL `3306` to the whole Internet** — allowlist only consumers (e.g. 野草云3).  
- [ ] Keep host secrets in gitignored local files only (`**/secret.md`).
