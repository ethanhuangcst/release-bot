# Nginx Proxy Manager

## 入口

- URL：`<NPM_URL>`
- 账号：本地密钥库

## 何时配置

在 **目标容器已运行**，且 Cloudflare DNS 已指向（或即将指向）本节点之后配置反代。

## 反代（Proxy Host → Details）

1. **Hosts → Proxy Hosts → Add Proxy Host**（新建；勿编辑其他应用的 Host）  
2. Domain Names = `<APP_DOMAIN>`（可选同时加 `www.<APP_DOMAIN>`）  
3. Scheme = `http`  
4. Forward Hostname = 入口容器名（须与 NPM 同属 `<PORTAINER_NETWORK>`）  
5. Forward Port = **容器内监听端口**（不是宿主机映射端口）  
6. 建议打开：Block Common Exploits、Websockets Support  
7. 先 Save，再配 SSL  

### 端口易错点

| Forward Hostname | Forward Port |
| --- | --- |
| 容器名（推荐） | 容器内 PORT |
| `127.0.0.1` | 宿主机映射端口 |

## 证书（按 NPM 版本选路径）

### 路径 A — Proxy Host → SSL（新版常见）

部分版本在此页选 **Request a new Certificate** 后，**不再显示 Email / Agree to ToS**（邮箱取自管理员账号，ToS 后台自动同意）。

1. SSL Certificate = Request a new Certificate  
2. Force SSL = 开；HTTP/2 = 开  
3. Use DNS Challenge = 关（默认 HTTP-01）  
4. 直接 Save  

### 路径 B — 顶栏 Certificates（较新 UI）

1. 顶栏 **Certificates** → **Add Certificate** → **Let's Encrypt via HTTP**（或 via DNS / Custom）  
2. Domain 保存成功后，回到 **Hosts → Proxy Hosts** → 编辑该 Host → **SSL**  
3. **下拉选择已有证书**（不要再 Add / Request）  
4. Force SSL = 开 → Save  

旧版文案可能是「SSL Certificates → Add SSL Certificate → Let's Encrypt」，语义相同。

## 与 Cloudflare

- 首次申请证书：DNS 可先灰云  
- 证书成功后：可橙云；SSL 模式 **Full** 或 **Full (strict)**  
- 避免 **Flexible**  
- 公网 **80** 须到达 NPM（HTTP-01）  

## 502 优先查

- 上游容器未起来或 Forward Port 填成宿主机端口  
- Forward Hostname 不在 `<PORTAINER_NETWORK>`  
- Cloudflare 仍指向错误节点  

## 隔离

只新建/编辑本应用 Domain 对应的 Host；发布后抽查至少一个既有域名仍可用。
