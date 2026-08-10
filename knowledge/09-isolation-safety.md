# 隔离与防误伤（多应用共存）

目标：在同一 Portainer / 同一节点 / 同一 `<PORTAINER_NETWORK>` / 同一 NPM / 同一 Cloudflare 账号下部署或更新**当前应用**时，**不修改、不重启、不占用**其他已部署应用的资源。

会话开始必须建立「共存清单」：节点上已有哪些 Stack / 域名 / 主机端口 / 库名（用户提供或从 Portainer/NPM 只读查看）。

---

## 硬规则（违反即停）

1. **只改当次目标**：只编辑 `<STACK_NAME>`、只改 `<APP_DOMAIN>` 对应 Proxy Host、只改该域名的 DNS。  
2. **禁止**对共享网络执行删除/重建（如 `docker network rm`、把 `external` 网改成新建网并覆盖同名）。  
3. **禁止**在「更新 Stack」时粘贴会换掉其他服务定义的整站 compose（除非已确认文件只含本应用服务）。  
4. **禁止**未确认库名就对共享 MySQL/Postgres 跑迁移；迁移必须落在 `<DB_NAME>`（或应用约定 schema），且先备份若有风险。  
5. **禁止**复用其他应用已占用的 **主机端口**、**容器名**、**Volume 名**、**Stack 名**。  
6. **冒烟不仅测新应用**：发布后抽查至少 **1 个既有应用** 的首页/健康检查仍可用。  

---

## 命名隔离（强烈建议）

| 资源 | 建议 |
| --- | --- |
| Portainer Stack | `<STACK_NAME>` = 与应用唯一对应，勿用 `app` / `stack` / `web` 等泛名 |
| Compose `container_name` / 服务名 | 带应用前缀，如 `<APP_SLUG>-web`，避免多个栈都叫 `web` |
| Volume | 带 `<APP_SLUG>` 前缀；勿挂载其他应用的具名卷 |
| 主机端口 | 每应用一套；部署前在节点上核对未被占用 |
| 域名 | 每应用独立 `<APP_DOMAIN>`；禁止改他人域名的 Proxy Host |
| 数据库 | 优先独立 `<DB_NAME>`（或独立实例）；禁止共用库时跑会改全局的脚本 |

`<APP_SLUG>`：短唯一标识（会话确认），用于前缀。

---

## 资源冲突检查清单（部署前）

在目标 `<NODE_NAME>` 上确认与**既有应用**无冲突：

- [ ] `<STACK_NAME>` 不与已有 Stack 重名（首次部署）；或确认更新的就是该 Stack（日常发布）  
- [ ] 每个 `<HOST_PORT_n>` 未被其他容器占用  
- [ ] 容器名 / 服务名在节点范围内唯一或带前缀  
- [ ] Volume 名不覆盖他应用数据卷  
- [ ] `<APP_DOMAIN>` 的 NPM Host 是新建或明确属于本应用；不编辑其他 Host  
- [ ] Cloudflare 只改本域名记录；不改其他域名的 A/CNAME  
- [ ] `<DATABASE_URL>` 的库名/实例属于本应用；迁移范围已确认  

可选命令（用户在节点执行，输出可脱敏后粘贴）：

```bash
docker ps --format 'table {{.Names}}\t{{.Ports}}\t{{.Image}}'
docker volume ls
# 检查主机端口占用示例
ss -lntup | grep -E ':<HOST_PORT_1>|<HOST_PORT_2>' || true
```

---

## Portainer 防误操作

| 做 | 不做 |
| --- | --- |
| 先搜索并打开**唯一**的 `<STACK_NAME>` | 在错误 Endpoint/节点上部署 |
| 更新前导出/复制当前 stack 文件作备份 | 对无关 Stack 点 Update / Remove |
| 环境变量只改本 stack | 把其他应用的 `.env` 粘进本 stack |
| 使用已存在的 `external` 网络 | 删除或重建 `<PORTAINER_NETWORK>` |

日常**更新镜像**：只改本 stack 的 `image:` / `<IMAGE_TAG>`，不要顺手改其他服务。

---

## NPM / Cloudflare 防误操作

- NPM：按域名筛选；编辑前确认 Domain 等于 `<APP_DOMAIN>`  
- 新建 Proxy Host 优于「改一个很像的旧 Host」  
- Cloudflare：进入**正确域名**产品后再改 DNS；多应用共用一个 zone 时只动本应用子域  

---

## 数据库防误伤

- 连接串核对：`<DB_HOST>` + `<DB_NAME>`（或 schema）属于本应用  
- 共享实例时：迁移脚本不得 `DROP` 他库；不确定则先停下来人工确认  
- 禁止把 A 应用的 `<DATABASE_URL>` 复制到 B 应用 stack  

---

## 发布后共存验收（必做）

1. 本应用冒烟通过  
2. 从共存清单中选 **≥1** 个既有应用：浏览器或健康检查仍成功  
3. Portainer 中其他 Stack 未出现意外 Restarting / Exit  
4. 若既有应用异常：立即停止继续扩大变更，走 `06-rollback.md` **只回滚本应用**，并排查是否误改共享资源  

---

## 失败时的隔离回滚

- 默认：**只**回滚 `<STACK_NAME>` 的镜像 tag / 本应用 NPM / 本应用 DNS  
- **不要**为修本应用而去重启/重建整个 `<PORTAINER_NETWORK>` 或 Portainer 本身  
- 若已误改共享资源：先恢复共享资源，再修本应用  
