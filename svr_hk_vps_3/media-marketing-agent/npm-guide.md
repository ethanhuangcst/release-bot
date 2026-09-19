# NPM 指南 — media.mkt-agent.ai

入口：https://nginx.agent-mate.ai/  
**只新建本域名 Host；不要改 hcp / mypoke / portainer / nginx 条目。**

---

## 1. Details（先保存）

**Hosts → Proxy Hosts → Add Proxy Host**

| 字段 | 值 |
| --- | --- |
| Domain Names | `media.mkt-agent.ai` |
| Scheme | `http` |
| Forward Hostname / IP | `media-mkt-agent-web` |
| Forward Port | **`3000`**（容器内端口，不是 3003） |
| Block Common Exploits | 开 |
| Websockets Support | 开 |
| Access List | Publicly Accessible |

点 **Save**（可先不配 SSL）。

备选上游（仅当容器名解析失败）：`127.0.0.1` + 端口 **`3003`**。

---

## 2. SSE（流式必做；无 Advanced 页时）

新版 NPM 有时不显示 **Advanced**。按优先级试：

### 2a — 找「高级 / Custom」

编辑 Proxy Host，看是否有：**高级**、**Custom Nginx Configuration**、齿轮图标里的 Extra。有则粘贴：

```nginx
proxy_buffering off;
proxy_read_timeout 300s;
proxy_send_timeout 300s;
proxy_set_header Connection "";
```

### 2b — Custom locations

1. 打开 **Custom locations**（或「自定义位置」）
2. **Add location**
3. Location：`/`  
   Scheme/Forward：与 Details 相同（`http` / `media-mkt-agent-web` / `3000`）
4. 若该 location 有 **Advanced / 自定义配置** 文本框，粘贴上面 4 行
5. Save

### 2c — 暂时跳过 SSE，先办 SSL

首页与登录可先通；流式报表/Agent 对话若卡住，再让运维在节点改 NPM 生成配置（或升级/换 UI 找 Advanced）。

---

## 3. SSL

与 mypoke 相同路径（按你当前 NPM UI）：

1. **Certificates** → 已有证则跳过；否则 **Add Certificate → Let's Encrypt via HTTP**，域名 `media.mkt-agent.ai`
2. 编辑 Proxy Host → **SSL** → 选该证书（或 Request a new）
3. **Force SSL** = 开 → Save  

DNS 仍建议先保持灰云直到证书成功。

---

## 4. 完成标准

- `https://media.mkt-agent.ai/` 能打开（或至少不是 502）
- `/api/login/health` 可访问
- hcp / mypoke 仍正常
