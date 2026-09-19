# mypoke.trade — NPM 反代与证书指南（按当前界面）

更新：2026-08-10  
适用：较新版 Nginx Proxy Manager（Proxy Host → SSL 页**可能没有** Email / Agree to ToS）

---

## 0. 前置检查

| 项 | 期望 |
| --- | --- |
| 容器 | `mypoke-web` 在跑；宿主机 `http://127.0.0.1:3002` 有响应（如 307） |
| 网络 | NPM 与 `mypoke-web` 同在 `portainer_network` |
| DNS | Cloudflare：`A @` → `38.55.192.140`；`CNAME www` → `mypoke.trade` |
| 隔离 | **不要**编辑 `hcp.agent-mate.ai` 或其他应用的 Proxy Host |
| 端口 80 | 公网 80 需到达本机 NPM（Let’s Encrypt HTTP 验证需要） |

NPM 入口：https://nginx.agent-mate.ai/

---

## 1. 新建 Proxy Host（反代）

1. 登录 NPM → **Hosts → Proxy Hosts**  
2. **Add Proxy Host**（新建，勿改 hcp 那条）  
3. **Details** 填写：

| 字段 | 值 |
| --- | --- |
| Domain Names | `mypoke.trade`（可同时加 `www.mypoke.trade`） |
| Scheme | `http` |
| Forward Hostname / IP | `mypoke-web` |
| Forward Port | **`3000`**（容器内端口；不是宿主机 3002） |
| Cache Assets | 关即可 |
| Block Common Exploits | 建议开 |
| Websockets Support | 建议开 |
| Access List | Publicly Accessible |

**端口对照（避免填错）：**

| Forward Hostname | Forward Port | 说明 |
| --- | --- | --- |
| `mypoke-web` | **3000** | 推荐 |
| `127.0.0.1` | **3002** | 仅当走宿主机映射时 |

4. 先 **Save**（可先不配 SSL，确认 HTTP 能通再申请证书）。

---

## 2. 证书（按当前顶栏「Certificates」界面）

当前 NPM 顶栏是 **Certificates**（不是旧版左侧「SSL Certificates」）。  
**Add Certificate** 下拉为：

| 选项 | 何时用 |
| --- | --- |
| **Let's Encrypt via HTTP** | 默认；DNS 灰云且公网 80 可达时 |
| **Let's Encrypt via DNS** | HTTP-01 失败、或必须橙云时 |
| **Custom Certificate** | 自备 PEM |

### 当前状态（2026-08-10）

Certificates 列表已有一条有效证：

- Domain：`mypoke.trade`、`www.mypoke.trade`
- Provider：Let's Encrypt
- Expires：2026-11-08 左右  

**不必再点 Add Certificate。** 下一步只是把这条证挂到 Proxy Host。

### 挂到 Proxy Host（本步必做）

1. **Hosts → Proxy Hosts** → 编辑 `mypoke.trade`  
2. 打开 **SSL** 页  
3. SSL Certificate：**下拉选** `mypoke.trade` / `www.mypoke.trade` 那条（不要再 Request / 不要再 Add）  
4. **Force SSL** = 开；**HTTP/2 Support** = 开；HSTS 可先关  
5. **Save**

### 若列表里还没有证（补申请）

1. 顶栏 **Certificates** → **Add Certificate** → **Let's Encrypt via HTTP**  
2. Domain：`mypoke.trade`、`www.mypoke.trade` → Save  
3. 再按上面「挂到 Proxy Host」操作

---

## 3. 与 Cloudflare 对齐

| 阶段 | Cloudflare 建议 |
| --- | --- |
| 首次申请证书 | DNS 可先 **灰云（DNS only）**，减少干扰 |
| 证书成功后 | 可改 **橙云**；SSL/TLS 模式用 **Full** 或 **Full (strict)** |
| 避免 | **Flexible**（浏览器 HTTPS、源站 HTTP，易混乱） |

---

## 4. 验收

1. 隐私窗口：`https://mypoke.trade`（及 `https://www.mypoke.trade`）  
2. 抽查：`https://hcp.agent-mate.ai` 仍正常  
3. NPM 里该 Host 的 SSL 下拉应显示具体证书名，而不是空白失败状态  

---

## 5. 常见失败

| 现象 | 处理 |
| --- | --- |
| 502 | 上游是否为 `mypoke-web:3000`；容器是否 Up；是否同网络 |
| 证书 Internal Error | DNS 未生效；80 未通；橙云+Flexible；改灰云后用 Certificates → Let's Encrypt via HTTP 重试 |
| 证书邮箱无效 | 到 NPM 用户设置改成真实邮箱，或用 Certificates 建证时填写 Email |
| 填了 Forward Port 3002 + Hostname `mypoke-web` | 错误；应改为 **3000** |
| 证书已在列表但站点仍不安全 | 未挂到 Proxy Host SSL；去 Host → SSL 下拉选该证并 Force SSL |

---

## 6. 完成后回复

回复：`NPM 已完成`，或贴证书/502 报错原文。
