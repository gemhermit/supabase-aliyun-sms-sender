# Supabase 配置指南

本文档详细说明如何在 Supabase 中配置阿里云短信发送服务。

## 1. 获取阿里云短信服务配置

### 1.1 获取 AccessKey

1. 访问 [阿里云 RAM 控制台](https://ram.console.aliyun.com/users)
2. 创建用户或使用现有用户
3. 创建 AccessKey，记录 `AccessKey ID` 和 `AccessKey Secret`
4. 为用户添加权限策略：`AliyunDysmsFullAccess`

### 1.2 配置短信服务

1. 访问 [阿里云短信服务控制台](https://dysms.console.aliyun.com/)
2. 添加短信签名（需要审核，通常需要 1-2 个工作日）
3. 添加短信模板（需要审核，通常需要 1-2 个工作日）

**短信模板示例**：
```
验证码${code}，您正在进行手机号验证，请在5分钟内完成操作。
```

**变量名**：`code`

## 2. 部署短信发送服务

### 2.1 独立部署服务

```bash
# 克隆项目
git clone <your-repo>
cd supabase-aliyun-sms-sender

# 配置环境变量
cp .env.example .env
# 编辑 .env 文件，填入阿里云配置

# 启动服务
./start.sh docker
```

### 2.2 获取服务地址

部署成功后，你的服务地址为：
- **本地开发**: `http://localhost:8000/functions/v1/supabase-aliyun-sms-sender`
- **生产环境**: `https://your-domain.com/functions/v1/supabase-aliyun-sms-sender`

## 3. 生成 Hook 密钥

```bash
# 生成安全的随机密钥
openssl rand -hex 32

# 输出示例：
# a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456

# 最终的 Hook 密钥格式：
# v1,whsec_a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456
```

## 4. Supabase Dashboard 配置

### 4.1 通过 Dashboard 配置

1. 登录 [Supabase Dashboard](https://app.supabase.com/)
2. 选择你的项目
3. 进入 **Project Settings** → **Auth** → **Hooks**
4. 在 **Send SMS Hook** 部分：
   - **Hook URI**: `https://your-domain.com/functions/v1/supabase-aliyun-sms-sender`
   - **Hook Secrets**: `v1,whsec_a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456`
5. 启用 Hook（如果没有自动启用）

### 4.2 通过环境变量配置

如果你使用自托管的 Supabase，可以在 `compose.yaml` 中配置：

```yaml
services:
  auth:
    environment:
      # 启用短信发送钩子
      GOTRUE_HOOK_SEND_SMS_ENABLED: "true"
      # 你的短信服务地址
      GOTRUE_HOOK_SEND_SMS_URI: "https://your-domain.com/functions/v1/supabase-aliyun-sms-sender"
      # Hook 密钥
      GOTRUE_HOOK_SEND_SMS_SECRETS: "v1,whsec_a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456"

  functions:
    environment:
      # 阿里云配置（与你的短信服务 .env 文件中的配置相同）
      ALIYUN_ACCESS_KEY_ID: "your_access_key_id"
      ALIYUN_ACCESS_KEY_SECRET: "your_access_key_secret"
      ALIYUN_SMS_SIGN_NAME: "your_sms_sign_name"
      ALIYUN_SMS_TEMPLATE_CODE: "your_template_code"
      SEND_SMS_HOOK_SECRET: "v1,whsec_a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456"
```

## 5. 测试配置

### 5.1 健康检查

```bash
curl https://your-domain.com/functions/v1/supabase-aliyun-sms-sender/health
```

预期响应：
```json
{
  "status": "ok",
  "timestamp": "2024-01-01T00:00:00Z"
}
```

### 5.2 前端测试

使用 JavaScript SDK 测试：

```javascript
const { data, error } = await supabase.auth.signInWithOtp({
  phone: '+8613012341234'
});

if (error) {
  console.error('发送失败:', error);
} else {
  console.log('发送成功:', data);
}
```

## 6. 故障排除

### 6.1 常见错误

**1. "Internal error"**
- 检查服务地址是否正确
- 查看服务日志确认错误原因
- 验证 Hook 密钥是否匹配

**2. 签名验证失败**
- 确保 Supabase 和服务中的密钥完全一致
- 检查密钥格式是否以 `v1,whsec_` 开头

**3. 阿里云短信发送失败**
- 检查 AccessKey 权限和余额
- 确认短信签名和模板已通过审核
- 验证手机号格式（国内手机号需要加 +86）

### 6.2 日志查看

```bash
# 查看短信服务日志
docker-compose logs -f aliyun-sms-sender

# 查看 Supabase Auth 日志（自托管）
docker logs -f supabase-auth
```

### 6.3 调试模式

启用调试模式获取更详细的日志：

```bash
export DEBUG=true
deno run --allow-net --allow-env index.ts
```

## 7. 安全建议

1. **密钥管理**：
   - 定期轮换 AccessKey
   - 使用强随机密钥作为 Hook 密钥
   - 不要在代码中硬编码密钥

2. **网络安全**：
   - 使用 HTTPS 传输
   - 配置防火墙规则限制访问
   - 考虑使用 CDN 和 WAF

3. **监控告警**：
   - 设置服务健康检查
   - 监控短信发送成功率和错误率
   - 配置告警机制

## 8. 配置检查清单

- [ ] 阿里云 AccessKey 已创建并配置权限
- [ ] 短信签名和模板已通过审核
- [ ] 短信发送服务已部署并正常运行
- [ ] Hook 密钥已生成并配置到服务中
- [ ] Supabase Hook URI 和 Secrets 已正确配置
- [ ] 服务地址可以从 Supabase 正常访问
- [ ] 前端可以正常发送短信验证码
- [ ] 监控和日志已配置