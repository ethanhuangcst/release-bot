# 占位符约定

发布前由用户/会话填入**当次应用**的真实值。文档与 Skill 只写占位符，不写某一业务仓库的专有名称。

| 占位符 | 含义 |
| --- | --- |
| `<GITHUB_OWNER>` | GitHub org/user |
| `<GITHUB_REPO>` | 仓库名 |
| `<IMAGE_TAG>` | 镜像 tag（分支名、sha 或 semver） |
| `<GHCR_IMAGE_n>` | 第 n 个应用镜像，如 `ghcr.io/<GITHUB_OWNER>/<GITHUB_REPO>/<service>` |
| `<SERVICE_n>` | Compose 服务名 |
| `<HOST_PORT_n>` / `<CONTAINER_PORT_n>` | 端口 |
| `<VECTOR_SERVICE>` | 可选向量库服务名（若有） |
| `<VECTOR_IMAGE>` | 向量库镜像（若有） |
| `<DATABASE_URL>` | 完整连接串（密码不入库、不进聊天） |
| `<DB_HOST>` `<DB_PORT>` `<DB_USER>` `<DB_NAME>` | 库连接分量 |
| `<DB_MIGRATE_CMD>` | 建表/迁移命令（由应用仓库定义） |
| `<DB_MIGRATE_PATH>` | 迁移文件目录（由应用仓库定义） |
| `<NODE_NAME>` | 目标节点名（自行命名，如区域或用途） |
| `<NODE_IP>` | 该节点公网 IP |
| `<APP_DOMAIN>` | 应用域名 |
| `<PORTAINER_URL>` | Portainer 入口 |
| `<NPM_URL>` | Nginx Proxy Manager 入口 |
| `<PORTAINER_NETWORK>` | Portainer 外部网络名（常见为 `portainer_network`，以实机为准） |
| `<CI_WORKFLOW_PATH>` | 如 `.github/workflows/docker-build.yml` |
| `<STACK_NAME>` | Portainer Stack 名（须全局唯一，勿用泛名） |
| `<APP_SLUG>` | 应用短标识，用于容器/卷/服务名前缀，避免多应用撞名 |
| `<EXISTING_APPS>` | 同节点已部署应用清单（Stack / 域名 / 主机端口），防误伤用 |

平台级常量（若各应用共用同一套运维入口）可写在本机密钥文件或会话开始时确认一次，仍避免写进通用手册正文的「唯一真相」。

隔离与防误伤规则见 `09-isolation-safety.md`。
