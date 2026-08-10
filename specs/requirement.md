# Release Bot — 半自动部署指导智能体

## 目标

做一个**部署指导智能体**（不是全自动 CI/CD），帮助把 GitHub 上的 WebApp **一步一步半自动部署**到自有 VPS。

## 产品形态

- 智能体运行在 Cursor（或同类 Agent）中
- **内嵌知识库**：本地文件夹 `./knowledge`（Markdown）
- **非 RAG**：不建向量库；Agent 按步骤读取对应知识文件
- **交互方式**：给出第 N 步 → 执行并回报结果 → 再给下一步
- **文档使用占位符**（见 `knowledge/variables.md`），不绑定某一业务仓库

## WebApp 常见架构（模板）

- 入口 Web/BFF 服务 + 可选 Agent/Worker/MCP 等服务 + 可选内网向量库
- 多个服务可共用同一 `<DATABASE_URL>`（以应用设计为准）
- 主库通常在**独立主机**；不默认放进应用 compose
- 镜像：**CI → 容器仓库（如 GHCR）**；Portainer 只 pull，不在边缘 build
- 网络：compose 加入 Portainer 外部网 `<PORTAINER_NETWORK>`
- 对外：Cloudflare 域名 + Nginx Proxy Manager

## 代码与基础设施（占位）

| 项 | 说明 |
| --- | --- |
| 仓库 | `<GITHUB_OWNER>/<GITHUB_REPO>`（会话时确认） |
| 镜像 | `<GHCR_IMAGE_n>` |
| 节点 | `<NODE_NAME>` / `<NODE_IP>`（可多节点） |
| 主库 | `<DB_HOST>:<DB_PORT>/<DB_NAME>`（密码不入库） |
| 容器管理 | `<PORTAINER_URL>` |
| 反向代理 | `<NPM_URL>` |
| DNS | Cloudflare |
| 发布手册 | `knowledge/03-semi-auto-release.md` |

## 防误伤（多应用共存）

同一节点 / 同一 Portainer / 同一 NPM 上可有多个应用。智能体与手册必须：

- 发布前做隔离门禁（Stack 名、端口、域名、库名、卷名）
- 只改当次 `<STACK_NAME>` / `<APP_DOMAIN>`，不删建共享网络
- 发布后抽查既有应用；回滚默认仅限本应用  
详见 `knowledge/09-isolation-safety.md`。

## 明确不做（MVP）

- 不要求无人值守全自动部署（可有 CI 仅负责 build/push 镜像）
- 不做向量检索作为本智能体的知识库
- 智能体不替代 Portainer/NPM 点击操作，只逐步指导

## 技能缺口（由智能体补位）

操作者可能不熟悉：CI/CD、GitHub Release、VPS 管理、Linux Shell。智能体必须用**可复制命令 + Portainer/NPM 界面步骤**降低门槛。

## 密钥

- **禁止**把密码、Token 写入本仓库或 `knowledge/`
- 凭证放本机密码管理器或未入库的本地文件（见 `knowledge/secrets.example.md`）
- 若凭证曾出现在旧版需求文档中，应**轮换**后再使用
