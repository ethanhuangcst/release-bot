# 设计方案：对话式 Step-by-Step 发布指南智能体

## 1. 结论

做一个跑在 Cursor 里的 **Release Guide Agent（编排层很薄）**：

- **模型**负责推理与对话节奏  
- **Harness**只提供：少量能力 + 按需知识（`./knowledge`）+ 严格边界  
- **交互形态**：一次只给一步 → 用户执行并回复 → 再给下一步  
- **手册全占位符**：不绑定某一业务仓库（见 `knowledge/variables.md`）  

不做：向量 RAG、独立 Agent 运行时、自动 SSH 改生产、重型 MLOps 平台。

---

## 2. 目的与信任边界

| 维度 | 定义 |
| --- | --- |
| Purpose | 把「CI 制品库 → Portainer → Cloudflare → NPM」半自动发布陪跑完成 |
| Domain | 自有多节点 VPS 运维发布（非模型训练/推理平台） |
| Trust | 模型决定「下一步问什么 / 打开哪份知识」；**不**自动对生产做破坏性操作 |
| Human-in-the-loop | 每一步默认等待用户确认（完成 / 失败贴脱敏日志 / 跳过） |

---

## 3. 智能体循环（Harness）

```text
LOOP:
  看见：对话历史 + 当前发布状态(简短) + 可用能力
  决定：读知识 / 更新状态 / 向用户输出「当前一步」
  若需知识：打开 knowledge/ 对应文件（按需，不一次塞满）
  若回复用户：只给出一步 + 完成标准 + 用户可选回复方式
  等用户 → 继续 LOOP
```

原则（Agent Builder）：

- 模型即智能体；代码/Skill 只是 harness  
- 知识按需加载，禁止把整本手册打进系统提示  
- 不写死巨型 if-else 流程引擎；用 `03-semi-auto-release.md` 作权威清单，模型循序推进  

---

## 4. 能力（先做 4 个，够用）

| # | Capability | 作用 |
| --- | --- | --- |
| 1 | `read_knowledge(path)` | 读 `knowledge/*.md`（已有：Read 工具） |
| 2 | `ask_user(step)` | 输出当前步、完成标准、期望用户回报什么 |
| 3 | `record_progress(state)` | 记下 `<NODE_NAME>` / `<IMAGE_TAG>` / 当前 Step（会话文件，不写回通用手册） |
| 4 | `open_runbook(topic)` | 失败→`07`；回滚→`06`；细节→`04/05/08` |

刻意不做的能力（MVP）：

- 自动登录 Portainer / NPM / Cloudflare API  
- 自动 `docker` / SSH 执行（除非用户**当步明确要求**代跑且环境已授权）  
- RAG 检索  

---

## 5. 知识（非 RAG）

```text
knowledge/
  variables.md              # 占位符表
  README.md / 00–08         # 通用手册
  secrets.example.md        # 只列密钥名
```

加载策略：会话开始读 `variables` + `00`–`02` 并收集实值；推进时读 `03` 当前步；细节按需。

---

## 6. 对话协议（Step-by-Step）

每一轮助手消息固定四段（短）：

1. **当前步**：Step N — 标题  
2. **做什么**：命令或 UI 路径（可复制；填入用户已给实值）  
3. **完成标准**：怎样算过关  
4. **请回复**：`完成` / `失败`（附脱敏日志）/ `跳过（原因）` / `改节点或 tag`

`COLLECT_CONTEXT` 最少问清：

- `<GITHUB_OWNER>/<GITHUB_REPO>` / `<IMAGE_TAG>`  
- `<NODE_NAME>` / `<NODE_IP>`  
- `<SERVICE_n>` / `<GHCR_IMAGE_n>` / `<HOST_PORT_n>`  
- `<STACK_NAME>` / `<APP_SLUG>` / 同节点 `<EXISTING_APPS>`  
- 首次部署还是日常更新；是否需要 DB 迁移  

新部署或变更端口/域名/Stack 时，先走 `09-isolation-safety.md` 门禁；结束时抽查既有应用。

---

## 7. 与「AI 架构」的边界（防过度设计）

本产品是 **Ops 指南智能体**，不是模型平台。要版本化的是 **知识手册 + `<IMAGE_TAG>`**，不是 Model Registry。

---

## 8. 落地形态（推荐）

**Phase 1** — Cursor + `release-guide` + `./knowledge`（占位符）  
**Phase 2** — `specs/sessions/` 记录当次实值与进度  
**Phase 3** — 可选只读检查 / 控制台 API（仍人工确认）  

---

## 9. MVP 验收

- [ ] 先收集占位符实值，不假定某一业务仓库  
- [ ] 一次一步，等待确认  
- [ ] 提醒：制品库 pull、不删建共享网络、先 DB 再迁移、不索要密码入库  
- [ ] 隔离门禁 + 发布后既有应用抽查  
- [ ] 失败切入排障；回滚仅限本应用；不引入 RAG  
- [ ] 通用手册保持占位符，不写回当次应用专名  

---

## 10. 反模式（避免）

- 一次贴出 Step 0–8 全文  
- 把全部 `knowledge/` 塞进 system prompt  
- 把某次 WebApp 的仓库/镜像/端口写进通用手册当默认值  
- 自动代填生产密码或要求把密码贴进聊天  
- 为「更智能」先上向量库  
