# Cloudflare

## 作用

为 `<APP_DOMAIN>` 配置 DNS（可选代理），是对外发布的一环。

## 步骤骨架

1. 登录 Cloudflare → 选择域名  
2. DNS：A/CNAME 指向本次 `<NODE_IP>`（或多节点时的入口）  
3. 代理状态与 SSL 模式按现网；需与 Nginx Proxy Manager 策略一致  
4. 解析生效后再测公网  

## 注意

- 多节点 IP 不同：换节点部署时必须改 DNS  
- **只改本应用** `<APP_DOMAIN>`（或子域）；不要改 `<EXISTING_APPS>` 里其他域名的记录  
- 不要把 API Token 写入本仓库  
- 现网 SSL 模式以实测为准：zone `agent-mate.ai` 现为 **Flexible**（2026-10-22 实测，旁证为无源站证书的 `hcp.agent-mate.ai` 可跑）；**避免 Flexible** 的目标不变，迁移是 zone 级动作，先补齐各 Host 源站证书再统一切 Full  
- 新子域先灰云（DNS only）签 LE 证书，签成后切橙云；切橙后解析器/权威 NS 有最长 300 秒 TTL 缓存，勿据旧解析误判未生效  

## 待在会话中确认

- [ ] 当次 `<APP_DOMAIN>`  
- [ ] 当次 `<NODE_IP>`  
- [ ] 现网 SSL 模式  
