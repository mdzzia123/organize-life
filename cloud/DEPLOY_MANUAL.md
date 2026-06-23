# 整理人生 - 云函数手动部署指南

若 CLI 登录不方便，可在腾讯云控制台手动部署。

## 环境信息

| 项目 | 值 |
|------|-----|
| 环境 ID | `madi-213-8gs6wu0se568f2d1-1302661085` |
| 地域 | 上海 (ap-shanghai) |
| API 地址 | `https://madi-213-8gs6wu0se568f2d1-1302661085.ap-shanghai.app.tcloudbase.com/organize_life` |

## 步骤 1：创建数据库集合

CloudBase 控制台 → 文档型数据库 → 新建集合：

- `ol_users`
- `ol_accounts`（v1.2 邮箱账号）
- `ol_categories`
- `ol_items`
- `ol_email_codes`（v1.5 邮箱验证码）
- `ol_orders`（v1.5 会员订单）

## 步骤 2：上传云函数

> **package.json 请与 xuexin_alipay 保持一致，不要改成只有 wx-server-sdk 的精简版！**

```json
{
  "name": "deal_my_life",
  "version": "1.2.0",
  "main": "index.js",
  "dependencies": {
    "@cloudbase/functions-framework": "1.12.0",
    "wx-server-sdk": "latest"
  }
}
```

HTTP 云函数还必须包含 **`scf_bootstrap`**（无扩展名），内容与 `cloud/organize_life/scf_bootstrap` 相同。

| 运行环境 | scf_bootstrap |
|----------|---------------|
| **Node.js 20**（推荐） | 用 `scf_bootstrap` |
| Node.js 18 | 改用 `scf_bootstrap.node18` 并重命名为 `scf_bootstrap`，或加 `polyfill.js` |

`index.js` 里的 `require('@cloudbase/node-sdk')` **无需**单独安装，会随 `wx-server-sdk` 自动带上。

1. 云函数 → `deal_my_life`
2. 运行环境 **Node.js 20**（避免 `File is not defined`）
3. 在线 `npm install` 或上传含 node_modules 的 zip
4. 入口：`index.main`

## 步骤 3：开启 HTTP 访问

HTTP 访问服务 → 新建：

- 关联函数：`organize_life`
- 路径：`/organize_life`

## 步骤 4：测试

```powershell
curl -X POST "https://madi-213-8gs6wu0se568f2d1-1302661085.ap-shanghai.app.tcloudbase.com/organize_life" -H "Content-Type: application/json" -d "{\"action\":\"ping\"}"
```

期望返回：`{"code":0,"msg":"pong","version":"1.5.1",...}`

## 开发联调（商户号 / AppId 未就绪）

会员 mock 测试可设：

| 变量 | 值 |
|------|-----|
| `OL_PAY_DEBUG` | `1` |

**邮箱注册默认无需验证码、无需 SendCloud**，直接邮箱+密码（≥6 位）即可注册。

若将来需要邮箱验证码（可选）：配置 SendCloud 并设 `OL_REQUIRE_EMAIL_CODE=1`，见 [SendCloud 配置](SENDCLOUD_SETUP.md)。

## v1.5 环境变量（云函数）

| 变量 | 说明 |
|------|------|
| `OL_API_BASE_URL` | 云函数 HTTP 根地址（自动生成支付回调 URL） |
| `SENDCLOUD_API_USER` / `SENDCLOUD_API_KEY` / `SENDCLOUD_FROM` | SendCloud 发验证码 |
| `OL_EMAIL_WEBHOOK_URL` | 或自定义邮件 Webhook |
| `OL_REQUIRE_EMAIL_CODE=1` | 可选：开启注册邮箱验证码（需 SendCloud） |
| `OL_PAY_DEBUG=1` | 调试：跳过真实支付，客户端 mock 确认 |
| `WECHAT_APP_ID` / `WECHAT_MCH_ID` / `WECHAT_API_KEY` | 微信 App 支付 |
| `ALIPAY_APP_ID` / `ALIPAY_PRIVATE_KEY` / `ALIPAY_PUBLIC_KEY` | 支付宝 App 支付 + 回调验签 |
| `WECHAT_NOTIFY_URL` / `ALIPAY_NOTIFY_URL` | 可选，覆盖自动回调 URL |

支付回调（已实现）：`?notify=wechat` / `?notify=alipay`，无需单独部署 notify 函数。

部署时需同时上传 **`index.js`** 与 **`ol_membership.js`**（同目录）。

## v1.2 新增能力

- **App 直传云存储**：`prepareUpload` → 客户端 POST 到 COS → `saveItem` 只写元数据
- **邮箱注册/登录**：`registerEmail` / `loginEmail` / `getAccountProfile`
- **设备关联**：登录后 `deviceId` 自动关联到 `accountId`，换机登录同一邮箱可读取全部数据
- **存储路径**：`deal_life/user_{accountId或deviceId}/items/...`（控制台「云存储」下可见）

### 测试邮箱注册

```powershell
$body = @{ action='registerEmail'; email='test@example.com'; password='123456'; deviceId='test-device-1' } | ConvertTo-Json
Invoke-RestMethod -Uri "https://madi-213-8gs6wu0se568f2d1-1302661085.ap-shanghai.app.tcloudbase.com/deal_my_life" -Method POST -ContentType "application/json" -Body $body
```

> 当前线上 HTTP 路径为 `/deal_my_life`（与 Flutter `cloud_config.dart` 一致）。

## CLI 部署（推荐）

```powershell
tcb login
powershell -File D:\organize-life\deploy-cloud.ps1
```
