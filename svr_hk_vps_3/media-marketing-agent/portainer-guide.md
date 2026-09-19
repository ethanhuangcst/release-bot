# Portainer 部署指南 — media-mkt-agent

入口：https://portainer.agent-mate.ai/  
**Stack 名：`media-mkt-agent`**  
容器名：`media-mkt-agent-web`  
镜像：`ghcr.io/ethanhuangcst/media-marketing-agent/web:latest`（仓库名仍为 media-marketing-agent）  
节点：野草云3 · Endpoint 选对本机  

**不要**编辑/更新 `hcp-engagement-agent`、`mypoke-trade`、`root`（Portainer/NPM）栈。  
若已用旧名 `media-marketing-agent` 建过栈：先 **Stop + Remove** 该栈，再按新名新建。

---

## 0. 先确认 GitHub Actions（main 是否构建成功）

1. 打开：https://github.com/ethanhuangcst/media-marketing-agent/actions  
2. 看列表最上面一条（分支 `main`）  
3. 判定：

| UI | 含义 |
| --- | --- |
| 绿勾 Success | 可拉镜像 |
| 黄圈 In progress | 等完成再拉 |
| 红叉 Failure | 先修 CI，不要 Pull |

本次修 `xauth` 的成功 run：  
https://github.com/ethanhuangcst/media-marketing-agent/actions/runs/31372667419  
（commit `58760b3`，约 2026-08-10 17:05 UTC+8 完成）

> 只看 Portainer 里 **State = running 一瞬间不够**：旧镜像会立刻再挂。必须以 **Logs 无 `xauth`** + 长时间 **running** 为准。

---

## 1. Registry（若 Pull 401）

Portainer → **Registries** → 添加 GitHub（GHCR）：`ghcr.io` + PAT（`read:packages`）。

---

## 2. 新建 Stack（仅首次）

1. **Stacks** → **Add stack**
2. Name：**`media-mkt-agent`**
3. Build method：**Web editor**
4. 粘贴：

```yaml
name: media-mkt-agent

services:
  web:
    image: ghcr.io/ethanhuangcst/media-marketing-agent/web:${IMAGE_TAG:-latest}
    container_name: media-mkt-agent-web
    restart: unless-stopped
    ports:
      - "3003:3000"
    shm_size: "256mb"
    volumes:
      - media_mkt_agent_data:/data
    environment:
      NODE_ENV: production
      PORT: "3000"
      HOSTNAME: "0.0.0.0"
      DATABASE_URL: ${DATABASE_URL:?set DATABASE_URL}
      DASHSCOPE_API_KEY: ${DASHSCOPE_API_KEY:?set DASHSCOPE_API_KEY}
      DASHSCOPE_BASE_URL: ${DASHSCOPE_BASE_URL:-}
      DASHSCOPE_MODEL: ${DASHSCOPE_MODEL:-qwen-plus}
      CRAWLER_MODE: ${CRAWLER_MODE:-live}
      CRAWLER_HEADLESS: ${CRAWLER_HEADLESS:-false}
      MCP_DATA_DIR: /data
      APP_URL: ${APP_URL:-https://media.mkt-agent.ai}
    networks:
      - default

volumes:
  media_mkt_agent_data:

networks:
  default:
    external: true
    name: portainer_network
```

5. **Environment variables**（从 `Release-jobs/media-marketing-agent/.env`）：

| Name | 说明 |
| --- | --- |
| `IMAGE_TAG` | `latest` |
| `DATABASE_URL` | 库名 **`media_marketing`** |
| `DASHSCOPE_API_KEY` | 本地 `.env` |
| `DASHSCOPE_BASE_URL` | 本地 `.env` |
| `DASHSCOPE_MODEL` | 如 `qwen-plus` |
| `CRAWLER_MODE` | `live` |
| `CRAWLER_HEADLESS` | `false` |
| `APP_URL` | `https://media.mkt-agent.ai` |

6. 网络：`portainer_network`（external）  
7. **Deploy the stack**

---

## 3. 强制拉取新镜像（当前必做）

你这版 Portainer（Stack → **Editor**）底部通常只有：

- Environment variables（可折叠）  
- Webhooks  
- Options → Prune services  
- **Update the stack**

**没有** “Pull and redeploy / Re-pull image” 按钮——这是正常的，不要在 Editor 里找 §3。

节点上若 Logs 仍有：

```text
xvfb-run: error: xauth command not found
```

或 Stack 页 **Created = `2026-08-10 16:30:15`**（对应旧镜像 UTC 08:30），说明还在用 **旧 `latest`**。必须换镜像。

### 3a — 按你当前 UI：Containers → Recreate + Pull（推荐）

对照截图操作：

1. 打开 https://portainer.agent-mate.ai/  
2. 左栏点 **Containers**（不要停在 Stacks → Editor）  
3. 在列表找到 **`media-mkt-agent-web`**，点进容器详情（或勾选后找顶部 **Recreate**）  
4. 点 **Recreate**  
5. 弹出框里勾选：
   - **Pull latest image** / **Pull image** / **Re-pull image**（有哪个勾哪个）  
6. 确认 Recreate，等 1–3 分钟（镜像较大）

### 3b — 若 Recreate 也没有 Pull 勾选：删旧镜像再 Update

1. 左栏 **Containers** → 勾选 `media-mkt-agent-web` → **Stop**  
2. 左栏 **Images** → 搜索 `media-marketing-agent`  
3. 勾选 `ghcr.io/ethanhuangcst/media-marketing-agent/web:latest` → **Remove**  
4. 回到 **Stacks → media-mkt-agent → Editor**  
5. 滚到底点 **Update the stack**（会重新从 GHCR 拉 `latest`）

### 3c — 不要只做的事

- 只点 **Update the stack**、compose 未改 → 往往**继续用本地旧 `latest`**  
- 只看 Stack 页绿徽章 **running** 一瞬间 → 旧镜像也会短暂显示 running，随后又 Restarting  

---

## 4. 如何确认「真的」成功（对照你的 Stack 截图）

回到 **Stacks → media-mkt-agent → 页签 Stack**（不是 Editor）。

### 4.1 Created 时间必须变新

| Created（截图里） | 含义 |
| --- | --- |
| 仍是 `2026-08-10 16:30:15` | **没换成新镜像**，回到 §3a/3b |
| 变成 **约 17:05 之后**（本地时间） | 有机会已是新镜像，再查 Logs |

### 4.2 Logs（关键）

在 Stack 页容器行，点 **Logs** 图标（你截图 Quick actions 最左那个）：

| 看到 | 含义 |
| --- | --- |
| 仍有 `xauth command not found` | 仍是旧镜像 → §3 |
| `Ready` / `started server` / 监听 `3000` | 镜像 OK |
| DB / `DATABASE_URL` 报错 | env 问题，另查 |

### 4.3 状态要稳

- **running** 且连续看 **≥ 1 分钟** 不跳成 restarting  
- Published Ports 有 **`3003:3000`**（可在容器详情看）

### 4.4 隔离抽查

同节点确认仍为 running：`hcp-…-web`、`mypoke-web`

---

## 5. 临时绕过（仅应急；优先用新镜像）

若 GHCR/网络暂时拉不动，可先让站起来再修爬虫：

1. Stack → **Environment variables**  
2. 将 `CRAWLER_HEADLESS` 改为 **`true`**  
3. **Update the stack**  

有头抖音爬虫需要再改回 `false`，并确保已跑在含 `xauth` 的镜像上。

---

## 6. 本步完成标准

- [ ] Actions 上 `58760b3`（或更新的 main）为 Success  
- [ ] 已执行 **Pull and redeploy**（或等价强制拉）  
- [ ] `media-mkt-agent-web` **running** ≥ 1 分钟  
- [ ] Logs **没有** `xauth command not found`  
- [ ] hcp / mypoke 仍正常  

完成后回复：`容器已稳定 Running` / `失败`（贴 Logs 末尾脱敏几行）。

下一步是 NPM：**新建** Proxy Host `media.mkt-agent.ai`（当前节点上还没有这条；仅有证书不够）。见 `npm-guide.md`。
