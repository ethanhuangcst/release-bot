# 半自动发布主流程

通用手册。占位符见 `variables.md`。历史业务笔记可作参考，但不绑定某一仓库。

## 两大阶段

| 阶段 | 内容 | 说明 |
| --- | --- | --- |
| A. CI/CD 映像 | Compose + CI → **容器仓库（如 GHCR）** | **不在本机 / 边缘机 build** 应用镜像 |
| B. 对外发布 | DB → Portainer → Cloudflare → Nginx | 容器起来之前不要指望公网通 |

对外发布推荐顺序：

1. Portainer 拉取镜像并部署容器  
2. Cloudflare 自定义域名 / DNS（可提前准备）  
3. Nginx Proxy Manager 反代  
4. 冒烟  

---

## Step 0 — 发布前检查

1. 确认 `<GITHUB_OWNER>/<GITHUB_REPO>`、分支或 tag → `<IMAGE_TAG>`  
2. 确认目标 `<NODE_NAME>` / `<NODE_IP>`  
3. 确认该节点 `.env` 中 `<DATABASE_URL>` 指向**本应用**应连的库（核对 `<DB_NAME>`）  
4. 确认当次服务清单：`<SERVICE_n>`、`<GHCR_IMAGE_n>`、`<HOST_PORT_n>`、`<STACK_NAME>`、`<APP_SLUG>`  
5. **防误伤：** 列出同节点 `<EXISTING_APPS>`（已有 Stack / 域名 / 主机端口）；完成本文件外的 `09-isolation-safety.md` 冲突检查  
6. 能登录 Portainer、NPM、Cloudflare（密码不进聊天）  
7. 记下**本应用**当前镜像 tag（回滚用）；不要动其他 Stack 的 tag  

**完成标准：** 用户给出仓库、tag、节点、服务/端口/镜像对照，并确认与既有应用无 Stack/端口/域名/库名冲突。

---

## Step 0b — 隔离门禁（新部署或新端口/域名时必做）

详见 `09-isolation-safety.md`。未通过则**停止**，不要进入 Portainer 部署。

- [ ] `<STACK_NAME>` / 容器名 / Volume 带 `<APP_SLUG>` 或不与既有冲突  
- [ ] `<HOST_PORT_n>` 空闲  
- [ ] 不会删除或重建 `<PORTAINER_NETWORK>`  
- [ ] `<DATABASE_URL>` 与迁移范围仅限本应用  
- [ ] 已约定发布后抽查 ≥1 个既有应用  

**完成标准：** 用户回复「隔离检查通过」。

---

## Step 1 — 仓库侧：Docker Compose（一次性或有变更时）

要求：

- **不**对应用服务使用本地 `build:`；只 `image:` 拉取 CI 制品  
- 数据库默认不在该 compose 内启动（除非当次应用明确如此）  
- 可选向量等依赖按应用约定  
- 服务名 / `container_name` / volume **带 `<APP_SLUG>` 前缀**（或确保节点内唯一）  
- network **必须**使用**已存在**的 Portainer 外部网（`external: true`，禁止为发版去删网重建）：

```yaml
networks:
  default:
    external: true
    name: <PORTAINER_NETWORK>
```

服务表示例（数值均为占位）：

| 服务 | 镜像 | 端口 |
| --- | --- | --- |
| `<SERVICE_1>` | `<GHCR_IMAGE_1>:${IMAGE_TAG:-latest}` | `<HOST_PORT_1>` |
| `<SERVICE_2>` | `<GHCR_IMAGE_2>:${IMAGE_TAG:-latest}` | `<HOST_PORT_2>` |
| `<VECTOR_SERVICE>` | `<VECTOR_IMAGE>` | 按应用（常仅内网） |

**完成标准：** compose 已提交；外部网络名正确；命名不会撞既有应用。

---

## Step 2 — 仓库侧：CI 构建推送（有代码变更时）

- Workflow：`<CI_WORKFLOW_PATH>`  
- 制品：`<GHCR_IMAGE_1>`、`<GHCR_IMAGE_2>`、…  
- 在 CI 界面确认本次 `<IMAGE_TAG>`（或 sha）构建成功  

**完成标准：** 仓库中能看到对应 tag；Portainer 将直接拉取，本地不 build。

---

## Step 3 — 节点 `.env`：写明数据库连接

- 密码**仅**本机 / 服务器 `.env`，禁止进 Git  
- 特殊字符须按 URL 编码规则处理  
- 多服务共用库时，使用同一 `<DATABASE_URL>`（以应用为准）  

示例形状（无真实主机/库名/密码）：

```bash
DATABASE_URL=<DATABASE_URL>
# 形状示例：mysql://<DB_USER>:YOUR_PASSWORD@<DB_HOST>:<DB_PORT>/<DB_NAME>
```

**完成标准：** 用户确认目标节点已写入正确连接（勿把真实密码贴到聊天）。

---

## Step 4 — 先通数据库，再迁移

顺序强制：

1. 确认能连上数据库  
2. 再执行 `<DB_MIGRATE_CMD>`（及应用文档中的其他迁库命令）  

若开发环境已长期使用同一库且结构已齐，日常发布可跳过迁移，但仍建议先做连通检查。

**完成标准：** 连通成功；若需迁移则命令成功。

---

## Step 5 — Portainer 部署到目标环境

1. 打开 `<PORTAINER_URL>` → 选中 `<NODE_NAME>` 对应 Endpoint  
2. **二次确认**打开的是 `<STACK_NAME>`（不是邻近的其他 Stack）  
3. 首次：Create stack；日常：Update **该** stack；`IMAGE_TAG` 与 Step 2 一致  
4. 确认网络为已有 `<PORTAINER_NETWORK>`（不要删网）  
5. 检查本应用各 `<SERVICE_n>` 状态与日志  
6. 扫一眼其他 Stack：不应批量变成 Restarting  

详见 `04-portainer.md`、`09-isolation-safety.md`。

**完成标准：** 本应用约定服务 running；其他既有 Stack 无异常波动。

---

## Step 6 — Cloudflare 自定义域名

1. 进入**本应用** `<APP_DOMAIN>` 所在 zone  
2. **只**改该域名（或该子域）记录，指向本次 `<NODE_IP>`  
3. 不要改 `<EXISTING_APPS>` 中其他域名的解析  
4. 代理/SSL 模式与 NPM 策略一致  

详见 `08-cloudflare.md`。

**完成标准：** 仅本域名 DNS 符合预期。

---

## Step 7 — Nginx Proxy Manager 反代

1. 打开 `<NPM_URL>` → 按域名确认是 `<APP_DOMAIN>`  
2. 新建或编辑**该** Proxy Host → 上游本应用 `<SERVICE_入口>:<HOST_PORT>`  
3. 不要改其他应用的 Host  
4. SSL / Force SSL 按现网  

详见 `05-nginx-proxy-manager.md`。

**完成标准：** 本域名 HTTPS 可打开，无 502；其他域名 Host 未改动。

---

## Step 8 — 应用冒烟 + 共存验收

- 本应用入口核心路径一条  
- 按需测本应用其他服务最小调用  
- **必做：** 抽查 `<EXISTING_APPS>` 中 ≥1 个既有应用仍可用  
- 记录：`<NODE_NAME>`、`<STACK_NAME>`、`<IMAGE_TAG>`、是否迁移、是否改 DNS/NPM  
- 当次实值写入 session；通用手册保持占位符  

**完成标准：** 用户确认本应用对外可用，且既有应用抽查通过。

---

## 首次建仓 Action Items（对照）

- [ ] 生成 Docker Compose（`external` 网络 + `<APP_SLUG>` 命名隔离）  
- [ ] 与 `<EXISTING_APPS>` 做端口/Stack/域名冲突检查  
- [ ] CI 加入镜像 Build 并推仓库  
- [ ] 各服务 `.env` 写明本应用 `<DATABASE_URL>`  
- [ ] 先 DB 连通，再迁移（按需，范围仅本库）  
- [ ] Portainer 仅部署 `<STACK_NAME>`  
- [ ] Cloudflare 仅改 `<APP_DOMAIN>`  
- [ ] Nginx 仅配本应用 Host  
- [ ] 冒烟 + 既有应用抽查  
