# 密钥清单（示例 — 无真实值）

在**本机或目标节点**保存（密码管理器或未入库文件）。  
**不要**提交 Git，**不要**写入其他 `knowledge/` 文件。

```bash
# 应用节点 SSH
VPS_APP_SSH_HOST=<NODE_IP>
VPS_APP_SSH_USER=
VPS_APP_SSH_PASSWORD=   # 推荐改用 SSH key

# Portainer
PORTAINER_URL=<PORTAINER_URL>
PORTAINER_USER=
PORTAINER_PASSWORD=

# Nginx Proxy Manager
NPM_URL=<NPM_URL>
NPM_USER=
NPM_PASSWORD=

# Cloudflare
CLOUDFLARE_ACCOUNT=
CLOUDFLARE_API_TOKEN=

# 数据库（写入各服务 .env；密码 URL 编码）
DATABASE_URL=<DATABASE_URL>
# 形状示例：mysql://<DB_USER>:YOUR_PASSWORD@<DB_HOST>:<DB_PORT>/<DB_NAME>

# 换机迁移时（若应用支持）
SOURCE_DATABASE_URL=

# 容器仓库登录（Portainer / docker login）
REGISTRY_USER=
REGISTRY_TOKEN=

IMAGE_TAG=<IMAGE_TAG>
```
