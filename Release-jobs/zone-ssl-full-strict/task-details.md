# zone `agent-mate.ai` SSL 迁移 Full (strict)

> 立项：2026-10-22（hcp 仓 [OPS2-01](../../../code/hcp-engagement-agent/specs/product-backlog.md) / pb-19，Sprint 2 增补 task-03，ToDo）
> 动因：DEF-011（hcp 仓）执行中实测 zone SSL 模式为 **Flexible**（CF 以 `http:80` 明文回源）；kb ClickFix 事件（`specs/adr/ADR-004-html-inject-check-before-public-dns.md`）证明该入口面曾出现被注入内容；Flexible 亦与 NPM `ssl_forced` 互踩 301 循环（2026-10-22 `hcp-mcp` 实发）。
> 协作方式：agent 尽可能自动化（NPM API / Portainer API / 验证脚本）；用户仅 Cloudflare 面板两步（切 Full、切 Full strict）。一次一步，需面板操作时给图解与贴指令。
> 原则：全程 `ssl_forced` 保持关，直到 zone 切 Full 完成；每步验证过再进下一步。

---

## 0. 现状盘点（2026-10-22 NPM API 实查）

| Host | 域名 | 源站证书 | 说明 |
| --- | --- | --- | --- |
| #5 | `mypoke.trade` (+ www) | 已有 #1（LE） | 约 2026-11-08 到期，Phase 0 核对自动续期 |
| #7 | `kb.agent-mate.ai` | 已有 #4（LE） | Custom Locations 不受影响 |
| #6 | `media.mkt-agent.ai` | 已有 #3（LE） | |
| #8 | `places.agent-mate.ai` | 已有 #5（LE） | |
| #9 | `framework.sdd.works` | 已有 #6（LE） | 规划中 |
| #11 | `hcp-mcp.agent-mate.ai` | 已有 #10（LE） | 2026-10-22 签，至 2027-01-20 |
| #2 | `hcp.agent-mate.ai` | **缺（cert:0）** | 靠 Flexible 运行 |
| #3 | `portainer.agent-mate.ai` | **缺（cert:0）** | 上游 `https://portainer:9443` 自签；NPM 不校验上游，不受影响 |
| #4 | `nginx.agent-mate.ai` | **缺（cert:0）** | 管理面；建议同批加 Access List（可选项） |

`sdd.works`（Host #10，证书 #9）属另一 zone，SSL 模式独立，**不在本任务范围**。

## 1. 前置条件

- hcp 仓 `specs/.secrets`：NPM 与 Portainer 凭据（API 自动化用）。
- Cloudflare 账号面板（用户操作）。
- 执行窗口：低峰；全程预计 45–60 分钟。

## 2. 步骤

| Phase | 内容 | 谁 |
| --- | --- | --- |
| 0 预检 | NPM API 重拉 hosts + certs 映射，确认与上表一致、无新增 Host；核对 mypoke 证书 #1 续期状态 | agent |
| 1 补证书 | 为 `hcp` / `portainer` / `nginx` 三域名各签 LE（NPM API：`POST /api/nginx/certificates` 不带 `meta`；HTTP-01，公网 80 须达 NPM）；挂到对应 Host（`certificate_id`）；**全程不开 `ssl_forced`** | agent |
| 2 源站直验 | 每个主机名 `curl --resolve <host>:443:38.55.192.140` 验有效 LE 证书 + 200/预期响应，**绕开 CF** 证明源站可独立服务 443——防切 Full 后 526 的关键步 | agent |
| 3 切 Full | CF 面板：zone `agent-mate.ai` → SSL/TLS → Overview → Flexible 改 **Full**（先非 strict）；随后 agent 逐站公网复验（验证矩阵） | **用户一步** → agent |
| 4 切 Full (strict) | 全站稳定后（同日或次日）改 **Full (strict)**；agent 复验全绿；逐 Host 重开 `ssl_forced`（含 #11）；刷新本仓清单与 knowledge | **用户一步** → agent |

## 3. 验证矩阵（Phase 3 / 4 各跑一轮）

| 站点 | 检查 | 期望 |
| --- | --- | --- |
| `hcp.agent-mate.ai` | `GET /api/health` | `ok:true` + twin live |
| `hcp-mcp.agent-mate.ai` | `GET /health`；`initialize` + `tools/list` | 200 / 八工具 |
| `kb.agent-mate.ai` | 首页 | 200 |
| `places.agent-mate.ai` | `GET /v1/health` | 200 |
| `mypoke.trade` | 首页 | 200 |
| `media.mkt-agent.ai` | 首页或 health | 200 |
| `portainer.agent-mate.ai` | 登录页 | 200 |
| `nginx.agent-mate.ai` | 登录页 | 200 |

任一站 526 / 失败：停，按回滚处理。

## 4. 回滚

- **单一开关**：CF 面板 SSL 模式切回 **Flexible**，秒级恢复全部站点。
- 单站异常：先查该站源站证书（Phase 2 已直验基线），不急着动 zone。
- 证书挂错：NPM API 把该 Host `certificate_id` 改回 0 即回原状。

## 5. 隔离红线

- 只动：zone SSL 模式（一次）、上述三张新证书及其挂载、各 Host `ssl_forced` 开关（Phase 4）。
- 不动：DNS 记录、任何 Stack、其他 NPM Host 的上游/Advanced 配置。
- NPM API 字段名注意（2026-10-22 实测）：`allow_websocket_upgrade`（非 `websockets`）；证书 POST 不带 `meta` 键。

## 6. 收尾

- 本仓 `svr_hk_vps_3/hk_vps_3_setting.md`：§10.11 Flexible 注更新为已迁 Full；各 Host 证书号刷新。
- `knowledge/05-nginx-proxy-manager.md` Flexible 陷阱节补「已迁移」结论。
- hcp 仓：OPS2-01 close（走 `sdd-dod.mdc` close confirm）。
