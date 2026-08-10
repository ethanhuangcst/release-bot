# Knowledge — 部署智能体内嵌知识库

非 RAG。Agent 按任务打开下列文件，不要一次加载全部。  
**全手册使用占位符**（见 [variables.md](./variables.md)），不绑定某一业务仓库。

## 索引

| 顺序 | 文件 | 用途 |
| --- | --- | --- |
| — | [variables.md](./variables.md) | 占位符表 |
| 0 | [00-overview.md](./00-overview.md) | 目标、边界、工作方式 |
| 1 | [01-environment.md](./01-environment.md) | 多节点、库、控制台 |
| 2 | [02-stack.md](./02-stack.md) | 服务与依赖顺序（模板） |
| 3 | [03-semi-auto-release.md](./03-semi-auto-release.md) | **主流程** |
| 4 | [04-portainer.md](./04-portainer.md) | Portainer + 外部网络 |
| 5 | [05-nginx-proxy-manager.md](./05-nginx-proxy-manager.md) | 反代 |
| 6 | [08-cloudflare.md](./08-cloudflare.md) | 域名 / DNS |
| 7 | [06-rollback.md](./06-rollback.md) | 回滚 |
| 8 | [07-troubleshooting.md](./07-troubleshooting.md) | 故障 |
| 9 | [09-isolation-safety.md](./09-isolation-safety.md) | **防误伤：多应用隔离** |
| — | [secrets.example.md](./secrets.example.md) | 密钥名清单 |

## Agent 使用规则

1. 开始发布：读 `variables.md` + `00` + `01` + `02`，并向用户收集占位符实值与 `<EXISTING_APPS>`  
2. 新部署或变更端口/域名/Stack：先读 `09` 并完成隔离门禁，再进入 `03` 部署步  
3. 逐步执行：严格按 `03`；每步等用户确认  
4. 细节：Portainer→`04`，NPM→`05`，Cloudflare→`08`  
5. 失败→`07`；撤销→`06`（只回滚本应用）  
6. Step 8 必须包含既有应用抽查  
7. 禁止把真实密码写入仓库或要求用户贴进聊天  
8. 禁止把当次应用专名写回通用手册；写入 `specs/sessions/`（若有）即可  
