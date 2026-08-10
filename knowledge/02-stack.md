# 服务栈（通用模板）

当次应用的服务名、端口、镜像在会话开始时向用户确认，填入占位符（见 `variables.md`）。

## 组成（典型）

```text
[浏览器]
    → Cloudflare (DNS / 可选代理)
        → Nginx Proxy Manager (TLS / 反代)
            → <SERVICE_1> (:<HOST_PORT_1>)
            → <SERVICE_2> (:<HOST_PORT_2>)   # 可选；是否公网暴露按安全策略
            → <VECTOR_SERVICE> (可选，常仅内网)
                → 独立数据库 (<DB_HOST>:<DB_PORT>/<DB_NAME>)
```

需要访问业务库的服务应共用同一 `<DATABASE_URL>`（以应用设计为准）。  
若使用向量库，向量数据通常**不**写入主库。

## 镜像（容器仓库）

| 服务 | 镜像 |
| --- | --- |
| `<SERVICE_1>` | `<GHCR_IMAGE_1>:${IMAGE_TAG:-latest}` |
| `<SERVICE_2>` | `<GHCR_IMAGE_2>:${IMAGE_TAG:-latest}` |
| `<VECTOR_SERVICE>` | `<VECTOR_IMAGE>`（若有；可为官方镜像） |

应用镜像由 CI 构建并推送；边缘 / Portainer **只 pull**，不在节点上 build 应用镜像。

多应用共存时：服务名 / 容器名 / 卷名使用 `<APP_SLUG>` 前缀；独立 `<STACK_NAME>` 与 `<DB_NAME>`。详见 `09-isolation-safety.md`。

## 依赖顺序（模板）

1. 数据库可达 +（按需）迁移完成  
2. 可选依赖（如向量库）  
3. 后端 / Agent / Worker 类服务  
4. Web / BFF 入口服务  
5. Cloudflare DNS  
6. Nginx Proxy Manager  

## 迁移

| 项 | 占位符 |
| --- | --- |
| 命令 | `<DB_MIGRATE_CMD>`（及应用提供的其他迁库命令） |
| 脚本路径 | `<DB_MIGRATE_PATH>` |

具体命令以**当次应用仓库**为准，不在本手册写死某一 monorepo 包名。
