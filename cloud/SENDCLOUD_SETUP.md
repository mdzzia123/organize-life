# SendCloud 邮件验证码配置指南

> **商户号/AppId 未就绪时**：云函数环境变量设 `OL_DEBUG_EMAIL=1`，验证码会出现在 API 响应的 `debugCode` 字段，App 注册流程可完整联调。

## 一、注册 SendCloud

1. 打开 [SendCloud](https://www.sendcloud.net/) 注册账号
2. 控制台 → **发信域名** → 添加域名（如 `mail.yourdomain.com`）
3. 按提示在 DNS 添加 SPF、DKIM 记录，等待验证通过
4. 控制台 → **API 用户** → 创建「触发类」API User，记下：
   - `apiUser`
   - `apiKey`

## 二、云函数环境变量

腾讯云 CloudBase → 云函数 `deal_my_life` → 配置 → 环境变量：

| 变量 | 示例 | 说明 |
|------|------|------|
| `SENDCLOUD_API_USER` | `organize_life_trigger` | API 用户名 |
| `SENDCLOUD_API_KEY` | `xxxxxxxx` | API 密钥 |
| `SENDCLOUD_FROM` | `noreply@mail.yourdomain.com` | 发件人（须为已验证域名） |
| `OL_DEBUG_EMAIL` | `0` | 生产环境设为 `0`；开发联调可设 `1` |

可选替代方案（不用 SendCloud）：

| 变量 | 说明 |
|------|------|
| `OL_EMAIL_WEBHOOK_URL` | 自定义 HTTP 接口，POST JSON：`{ to, subject, html, code }` |

## 三、部署后自检

```powershell
$uri = "https://madi-213-8gs6wu0se568f2d1-1302661085.ap-shanghai.app.tcloudbase.com/deal_my_life"
# 查看邮件/支付配置状态
Invoke-RestMethod -Uri $uri -Method POST -ContentType "application/json" -Body '{"action":"getServiceConfig"}'

# 发送验证码（调试模式下响应含 debugCode）
$body = @{ action='sendEmailCode'; email='your@email.com'; deviceId='test-1' } | ConvertTo-Json
Invoke-RestMethod -Uri $uri -Method POST -ContentType "application/json" -Body $body
```

期望 `getServiceConfig` 返回：

```json
{
  "code": 0,
  "data": {
    "email": {
      "configured": true,
      "sendcloud": true,
      "debug": false,
      "canSend": true
    }
  }
}
```

## 四、上线前检查清单

- [ ] 发信域名 DNS 已验证
- [ ] `SENDCLOUD_FROM` 使用已验证域名邮箱
- [ ] `OL_DEBUG_EMAIL=0`（关闭调试，不再返回 debugCode）
- [ ] 用真实邮箱测试注册全流程
- [ ] SendCloud 控制台查看发信记录与退信率

## 五、常见问题

**Q：提示「邮件服务未配置」**  
A：未配置 SendCloud/Webhook 且 `OL_DEBUG_EMAIL` 不是 `1`。开发阶段先设 `OL_DEBUG_EMAIL=1`。

**Q：SendCloud 返回失败**  
A：检查 `from` 域名是否验证、`apiUser` 是否为触发类、收件箱是否进垃圾箱。

**Q：验证码收不到**  
A：查看云函数日志；SendCloud 控制台 → 投递记录；确认未超频（60 秒内同邮箱只能发一次）。
