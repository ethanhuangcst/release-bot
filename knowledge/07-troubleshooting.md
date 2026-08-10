# 故障排查

| 现象 | 先查 |
| --- | --- |
| 域名 502 | 容器是否 running；NPM 上游 host/port；是否在 `<PORTAINER_NETWORK>` |
| 容器互相访问失败 | compose 是否 `external: true` + 正确的 `<PORTAINER_NETWORK>` |
| 镜像拉不下来 | Registry 权限 / PAT；`<IMAGE_TAG>` 是否存在；CI 是否成功 |
| 容器反复重启 | 日志；`<DATABASE_URL>` 是否错误或密码未 URL 编码 |
| 能连库但业务不可用 | 是否未跑迁移；先连通再执行 `<DB_MIGRATE_CMD>` |
| 页面打到错误环境 | Cloudflare DNS 是否指向错误 `<NODE_IP>` / 节点 |
| 在节点上 build 应用镜像 | 流程错误：应用镜像应由 CI 推仓库，边缘只 pull |
| 新发版后旧应用 502/宕掉 | 是否改错 Stack/NPM Host/DNS；端口是否撞车；是否重建了共享网络 → 见 `09-isolation-safety.md` |
| 更新后多个 Stack 一起重启 | 是否误部署了合并多应用的 compose；是否动了共享网络 |
| 手机能开、同 Wi‑Fi 桌面不能开 | 本机/路由器 DNS（如 `10.0.0.1`）负缓存；改 `1.1.1.1`/`8.8.8.8` 或蜂窝复测；DoH/`dig +tcp` 核对 |
| Cloudflare 有 A 记录但 dig UDP 空 | 用 DoH 或 `dig +tcp`；灰云时 CF「Visitors cannot reach」常误报 |
| AI 估价 MCP_FAILED / valuate 502 | Agent 是否注入 `TCGDEX_BASE_URL`（web 有、agent 无会踩坑）；再查 QWEN |
| 上传成功但预览空白（Next standalone） | runtime 写 `public/` 常 404 → API 读盘 + rewrite；见 `specs/adr/ADR-001-…` |
| NPM 证书页文案 | 顶栏多为 **Certificates**；Add = Let's Encrypt via HTTP/DNS/Custom；有证则挂到 Proxy Host SSL，勿重复申请 |
