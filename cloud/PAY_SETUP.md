# 微信 / 支付宝支付与回调配置指南

> **商户号/AppId 未就绪时**：云函数设 `OL_PAY_DEBUG=1`，App 会员页可走 mock 支付并自动开通，功能可先完整联调。  
> 拿到商户资质后，按本文填入密钥并关闭 `OL_PAY_DEBUG` 即可上线。

## 一、回调 URL（已实现，无需单独建函数）

支付异步通知走**同一个 HTTP 云函数**，通过 query 区分：

| 渠道 | 回调 URL |
|------|----------|
| 微信 | `https://<你的域名>/deal_my_life?notify=wechat` |
| 支付宝 | `https://<你的域名>/deal_my_life?notify=alipay` |

当前环境示例：

```
https://madi-213-8gs6wu0se568f2d1-1302661085.ap-shanghai.app.tcloudbase.com/deal_my_life?notify=wechat
https://madi-213-8gs6wu0se568f2d1-1302661085.ap-shanghai.app.tcloudbase.com/deal_my_life?notify=alipay
```

云函数会自动使用上述 URL（需配置 `OL_API_BASE_URL`），也可显式覆盖：

| 变量 | 说明 |
|------|------|
| `OL_API_BASE_URL` | 如 `https://.../deal_my_life`（推荐，自动生成 notify URL） |
| `WECHAT_NOTIFY_URL` | 可选，覆盖微信回调 |
| `ALIPAY_NOTIFY_URL` | 可选，覆盖支付宝回调 |

## 二、开发联调（无需商户号）

云函数环境变量：

```
OL_PAY_DEBUG=1
OL_API_BASE_URL=https://madi-213-8gs6wu0se568f2d1-1302661085.ap-shanghai.app.tcloudbase.com/deal_my_life
```

流程：App 登录 → 设置 → 会员 → 选套餐 → 微信/支付宝 → 自动 mock 开通。

自检：

```powershell
$uri = "https://madi-213-8gs6wu0se568f2d1-1302661085.ap-shanghai.app.tcloudbase.com/deal_my_life"
Invoke-RestMethod -Uri $uri -Method POST -ContentType "application/json" -Body '{"action":"getServiceConfig"}'
# pay.debug=true, pay.canPay=true
```

## 三、微信支付（App 支付）

### 3.1 准备材料

- 微信开放平台 App（与 Flutter `WECHAT_APP_ID` 一致）
- 微信商户号（MCH ID）
- 商户平台 API 密钥（32 位，v2 密钥）

### 3.2 云函数环境变量

| 变量 | 说明 |
|------|------|
| `WECHAT_APP_ID` | 开放平台 AppId |
| `WECHAT_MCH_ID` | 商户号 |
| `WECHAT_API_KEY` | 商户 API v2 密钥 |
| `OL_API_BASE_URL` | 见上文 |
| `OL_PAY_DEBUG` | 生产设为 `0` |

### 3.3 商户平台配置

微信商户平台 → 产品中心 → App 支付 → 关联 AppId  
支付授权目录 / 回调 URL 填：`.../deal_my_life?notify=wechat`

### 3.4 Flutter 编译

```powershell
flutter build apk --dart-define=WECHAT_APP_ID=wx你的AppId
```

### 3.5 回调逻辑（已实现）

- 接收 XML POST → 验签（MD5 + API Key）
- 校验 `out_trade_no`、`total_fee` 与订单一致
- 幂等更新 `ol_orders` 为 `paid`，开通会员
- 响应 XML：`<return_code>SUCCESS</return_code>`

## 四、支付宝（App 支付）

### 4.1 准备材料

- 支付宝开放平台应用 AppId
- 应用私钥（RSA2）
- 支付宝公钥（用于验签回调，**不是**应用公钥）

### 4.2 云函数环境变量

| 变量 | 说明 |
|------|------|
| `ALIPAY_APP_ID` | 开放平台 AppId |
| `ALIPAY_PRIVATE_KEY` | 应用私钥 PEM，`\n` 可用字面量或换行 |
| `ALIPAY_PUBLIC_KEY` | 支付宝公钥 PEM（验签 notify 必需） |
| `OL_API_BASE_URL` | 见上文 |
| `OL_PAY_DEBUG` | 生产设为 `0` |

私钥示例（环境变量中 `\n` 表示换行）：

```
ALIPAY_PRIVATE_KEY=-----BEGIN RSA PRIVATE KEY-----\nMIIE...\n-----END RSA PRIVATE KEY-----
ALIPAY_PUBLIC_KEY=-----BEGIN PUBLIC KEY-----\nMIIB...\n-----END PUBLIC KEY-----
```

### 4.3 开放平台配置

支付宝开放平台 → 应用 → App 支付 → 添加能力  
**异步通知地址**：`.../deal_my_life?notify=alipay`

### 4.4 回调逻辑（已实现）

- 接收 `application/x-www-form-urlencoded` POST
- RSA2 验签 → 校验 `trade_status` 为 `TRADE_SUCCESS` / `TRADE_FINISHED`
- 幂等开通会员
- 响应纯文本：`success`（失败返回 `failure`）

## 五、上线检查清单

- [ ] `OL_PAY_DEBUG=0`
- [ ] 微信/支付宝密钥与 AppId 已填入云函数
- [ ] `getServiceConfig` 显示 `pay.wechat` / `pay.alipay` 为 true
- [ ] 商户后台回调 URL 与 `wechatNotifyUrl` / `alipayNotifyUrl` 一致
- [ ] 小额真实支付测试 → 查 `ol_orders.status=paid` → App 会员状态刷新
- [ ] 云函数日志无 sign invalid / amount mismatch

## 六、订单与会员数据

| 集合/字段 | 说明 |
|-----------|------|
| `ol_orders` | `orderId`, `accountId`, `planId`, `amountFen`, `status`, `tradeNo` |
| `ol_accounts.memberPlanId` | `monthly` / `yearly` / `lifetime` |
| `ol_accounts.memberExpireAt` | 到期时间，永久会员为 `2099-12-31` |

App 支付完成后会轮询 `queryMemberOrder`；生产环境主要依赖 notify 异步到账。
