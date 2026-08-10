# Portainer

## 入口

- URL：`<PORTAINER_URL>`
- 账号：本地密钥库

## 部署要点

1. 选择**正确节点** Endpoint（对应 `<NODE_NAME>`）  
2. 搜索并打开**唯一**的 `<STACK_NAME>`（防点错相邻 Stack）  
3. Stacks → 创建或更新：compose **只含本应用服务**  
4. 环境变量 / `.env`：本应用的 `<DATABASE_URL>`、`<IMAGE_TAG>`（勿粘贴他应用 env）  
5. 确认网络为**已存在**的 external `<PORTAINER_NETWORK>`（禁止删网重建）  
6. Deploy / Update 后：看本应用 Logs，并确认其他 Stack 未集体异常  
7. **不要**在节点上 build 应用镜像；只 pull CI 制品  

隔离细则：`09-isolation-safety.md`。

## 拉取权限

私有仓库时，在 Portainer/节点配置 Registry 登录（凭证见本地密钥库）。

## 检查（SSH 可选）

```bash
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
docker network inspect <PORTAINER_NETWORK>
```
