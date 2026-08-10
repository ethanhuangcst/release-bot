# 环境

## 多节点

可有多台应用/边缘节点，**各有独立 IP**。部署前必须选定 `<NODE_NAME>`。

| 占位符 | 说明 |
| --- | --- |
| `<NODE_NAME>` | 节点标识（自定义） |
| `<NODE_IP>` | 该节点公网 IP |

每台节点的 `<DATABASE_URL>` **可能不同**，禁止未核对就复制上一环境的连接串。

## 主库（通常独立于 compose）

| 项 | 占位符 |
| --- | --- |
| 引擎 | 由应用约定（如 MySQL 8.x / Postgres） |
| 主机 | `<DB_HOST>` |
| 端口 | `<DB_PORT>` |
| 用户 | `<DB_USER>` |
| 库名 | `<DB_NAME>` |
| 密码 | 仅本机/服务器 `.env`，不入库 |

数据库服务**默认不**在应用 compose 内启动（若某应用例外，在当次会话说明）。

## 运维控制台

| 工具 | 占位符 |
| --- | --- |
| Portainer | `<PORTAINER_URL>` |
| Nginx Proxy Manager | `<NPM_URL>` |
| Cloudflare | 控制台账号见本地密钥库 |

## 代码与镜像

| 项 | 占位符 |
| --- | --- |
| 仓库 | `<GITHUB_OWNER>/<GITHUB_REPO>` |
| Registry | 常见为 GHCR：`ghcr.io` |
| CI 工作流 | `<CI_WORKFLOW_PATH>` |

## Docker 网络

Compose 须加入 Portainer 已存在的外部网络：`<PORTAINER_NETWORK>`（名称以实机为准；未设置则同节点容器常无法互通）。

## SSH（可选）

| 项 | 占位符 |
| --- | --- |
| 主机 | `<NODE_IP>` |
| 用户 | 常见 `root` 或专用运维用户（见本地密钥库） |
