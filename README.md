# Supabase Aliyun SMS Sender

适配Supabase的[`send_sms_hook`](https://supabase.com/docs/guides/auth/auth-hooks/send-sms-hook)的[阿里云短信](https://api.aliyun.com/document/Dysmsapi/2017-05-25/SendSms)发送云函数，运行在`edge-functions`容器中。

📺Bilibili视频: [Supabase调用阿里云短信API，给大陆+86用户发送验证码](https://www.bilibili.com/video/BV1NDptzaEmc)

📋 **详细配置指南**: 查看 [Supabase 配置指南](./SUPABASE_CONFIG.md) 获取完整的配置步骤和故障排除方法

## 特点

- 🔧 **双重部署模式**: 支持 Supabase 集成部署和独立部署
- 🌏 **国内友好**: 解决Supabase官方未支持国内的短信服务商问题
- 🔒 **安全可靠**: 非入侵方案，函数内会验证webhook签名，防止接口被滥用
- 📦 **易于部署**: 提供Docker、Docker Compose和原生Deno多种部署方式
- 📊 **完整监控**: 内置健康检查和结构化日志输出

## 部署方式

### 方式一：Supabase 集成部署（原始方式）

参考原项目配置，将本服务作为 Supabase Edge Function 部署。

### 方式二：独立部署（推荐）

支持多种独立部署方式，提供独立的 HTTP API：

#### 快速启动

**Linux/macOS:**
```bash
# 复制环境变量配置
cp .env.example .env

# 编辑配置文件，填入你的阿里云配置
vim .env

# 启动服务
chmod +x start.sh
./start.sh docker
```

**Windows:**
```cmd
# 复制环境变量配置
copy .env.example .env

# 编辑配置文件，填入你的阿里云配置
notepad .env

# 启动服务
start.bat docker
```

#### Docker Compose 部署（推荐）
```bash
# 配置环境变量
cp .env.example .env
# 编辑 .env 文件填入配置

# 启动服务
docker-compose up -d

# 查看日志
docker-compose logs -f

# 停止服务
docker-compose down
```

#### 手动 Docker 部署
```bash
# 构建镜像
docker build -t aliyun-sms-sender .

# 运行容器
docker run -d \
  --name aliyun-sms-sender \
  -p 8000:8000 \
  -e ALIYUN_ACCESS_KEY_ID="your_access_key_id" \
  -e ALIYUN_ACCESS_KEY_SECRET="your_access_key_secret" \
  -e ALIYUN_SMS_SIGN_NAME="your_sms_sign_name" \
  -e ALIYUN_SMS_TEMPLATE_CODE="your_template_code" \
  -e SEND_SMS_HOOK_SECRET="v1,whsec_your_secret_key" \
  --restart unless-stopped \
  aliyun-sms-sender
```

#### 原生 Deno 部署
```bash
# 安装 Deno
curl -fsSL https://deno.land/install.sh | sh

# 设置环境变量
export ALIYUN_ACCESS_KEY_ID="your_access_key_id"
export ALIYUN_ACCESS_KEY_SECRET="your_access_key_secret"
export ALIYUN_SMS_SIGN_NAME="your_sms_sign_name"
export ALIYUN_SMS_TEMPLATE_CODE="your_template_code"
export SEND_SMS_HOOK_SECRET="v1,whsec_your_secret_key"

# 启动服务
deno run --allow-net --allow-env index.ts
```

## API 接口

独立部署后，服务提供以下 API 接口：

### 发送短信验证码
```http
POST /send-sms
Content-Type: application/json

{
  "phone": "13012341234",
  "code": "123456"
}
```

### 健康检查
```http
GET /health
```

### Supabase Hook 兼容接口
默认路径仍然兼容 Supabase Auth Hook 格式。

## 客户端集成示例

### JavaScript
```javascript
class SMSService {
  constructor(baseUrl, secret) {
    this.baseUrl = baseUrl;
    this.secret = secret;
  }

  async sendSMS(phone, code) {
    const response = await fetch(`${this.baseUrl}/send-sms`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Webhook-Signature': this.generateSignature({ phone, code })
      },
      body: JSON.stringify({ phone, code })
    });

    return response.json();
  }

  generateSignature(payload) {
    // 实现签名逻辑
    const crypto = require('crypto');
    const timestamp = Date.now().toString();
    const secretKey = this.secret.replace('v1,whsec_', '');
    const signaturePayload = `${timestamp}.${JSON.stringify(payload)}`;
    const signature = crypto.createHmac('sha256', secretKey).update(signaturePayload).digest('hex');
    return `t=${timestamp},v1=${signature}`;
  }
}

// 使用示例
const smsService = new SMSService('http://localhost:8000', 'v1,whsec_your_secret_key');
await smsService.sendSMS('13012341234', '123456');
```

### Python
```python
import requests
import hmac
import hashlib
import json

class SMSService:
    def __init__(self, base_url, secret):
        self.base_url = base_url
        self.secret = secret

    def send_sms(self, phone, code):
        payload = {"phone": phone, "code": code}
        response = requests.post(
            f"{self.base_url}/send-sms",
            headers={
                'Content-Type': 'application/json',
                'X-Webhook-Signature': self._generate_signature(payload)
            },
            json=payload
        )
        return response.json()

    def _generate_signature(self, payload):
        import time
        secret_key = self.secret.replace('v1,whsec_', '')
        timestamp = str(int(time.time()))
        signature_payload = f"{timestamp}.{json.dumps(payload)}"
        signature = hmac.new(secret_key.encode(), signature_payload.encode(), hashlib.sha256).hexdigest()
        return f"t={timestamp},v1={signature}"

# 使用示例
sms_service = SMSService('http://localhost:8000', 'v1,whsec_your_secret_key')
result = sms_service.send_sms('13012341234', '123456')
print(result)
```

## 原有功能 - Supabase 集成

对于需要在 Supabase 中集成的用户，原有的部署方式仍然完全兼容：

```mermaid
sequenceDiagram
    participant frontend
    box Container
        participant auth
        participant edge-functions
    end
    box Deno
        participant main
        participant aliyun-sms-sender
    end
    box AlibabaCloud
    participant AliyunSMS
    end

    frontend->>auth: 请求发送短信验证码
    auth->>edge-functions: 触发 send_sms_hook
    edge-functions->>main: 事件转发
    main->>aliyun-sms-sender: 路由到云函数
    aliyun-sms-sender->>AliyunSMS: 调用短信发送API
    note over AliyunSMS: 向运营商提起短信请求
    AliyunSMS-->>aliyun-sms-sender: 返回结果
    aliyun-sms-sender-->>main: 返回结果
    main-->>edge-functions: 返回结果
    edge-functions-->>auth: 返回结果
    auth-->>frontend: 返回验证码发送状态
```

### Supabase 集成部署

将本仓库放在`volumes/functions/`目录下，和`main`文件夹平级，修改`compose.yaml`配置：

1. 复制文件到正确位置

2. 修改`compose.yaml` 配置：

``` diff
services:
    # ...
    auth:
        # ...
++      extra_hosts:
++          - "host.docker.internal:host-gateway"
        environment:
            #...
++          GOTRUE_HOOK_SEND_SMS_ENABLED: "true"
++          GOTRUE_HOOK_SEND_SMS_URI: "http://host.docker.internal:8000/functions/v1/supabase-aliyun-sms-sender"
++          GOTRUE_HOOK_SEND_SMS_SECRETS: "v1,whsec_REPLACE_WITH_YOUR_SECRET"
            #...
        #...
    #...
    functions:
        #...
        environment:
            #...
++          ALIYUN_ACCESS_KEY_ID: "REPLACE_WITH_YOUR_ACCESS_KEY_ID"
++          ALIYUN_ACCESS_KEY_SECRET: "REPLACE_WITH_YOUR_ACCESS_KEY_SECRET"
++          ALIYUN_SMS_SIGN_NAME: "REPLACE_WITH_YOUR_SIGN_NAME"
++          ALIYUN_SMS_TEMPLATE_CODE: "REPLACE_WITH_YOUR_TEMPLATE_CODE"
++          SEND_SMS_HOOK_SECRET: "v1,whsec_REPLACE_WITH_YOUR_SECRET"
        #...
    #...
```

3. 重新创建`docker compose`（需要环境变量生效）

## Supabase Hook 配置详解

### 发送确认短信的 HTTPS 服务地址

这是你的独立部署服务的完整地址，Supabase 会向此地址发送 webhook 请求。

**格式**: `https://your-domain.com/functions/v1/supabase-aliyun-sms-sender`

**本地开发环境**:
```
http://localhost:8000/functions/v1/supabase-aliyun-sms-sender
```

**生产环境示例**:
```
https://sms.yourdomain.com/functions/v1/supabase-aliyun-sms-sender
```

### Hook 密钥配置

用于验证 Supabase 发送请求的签名密钥，确保请求的安全性。

**格式要求**:
- 必须以 `v1,whsec_` 开头
- 后跟随机字符串（建议至少 32 字符）

**生成安全密钥**:
```bash
# 使用 openssl 生成随机密钥
openssl rand -hex 32
# 输出示例: a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456
# 最终密钥: v1,whsec_a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456
```

### Supabase Dashboard 配置

1. 进入 Supabase Dashboard
2. 选择你的项目 → **Project Settings** → **Auth** → **Hooks**
3. 在 **Send SMS Hook** 部分配置：
   - **Hook URI**: `https://your-domain.com/functions/v1/supabase-aliyun-sms-sender`
   - **Hook Secrets**: `v1,whsec_your_random_secret_string_here`
4. 确保 Hook 已启用

### 环境变量配置方式

也可以通过在 `compose.yaml` 中设置环境变量：

```yaml
services:
    auth:
        environment:
            # 启用短信发送钩子
            GOTRUE_HOOK_SEND_SMS_ENABLED: "true"
            # 你的独立部署服务地址
            GOTRUE_HOOK_SEND_SMS_URI: "https://your-domain.com/functions/v1/supabase-aliyun-sms-sender"
            # Hook 密钥，必须以 v1,whsec_ 开头
            GOTRUE_HOOK_SEND_SMS_SECRETS: "v1,whsec_your_random_secret_string_here"
```

### Webhook 数据格式

Supabase 会向你的服务发送如下格式的 POST 请求：

```json
{
  "user": {
    "id": "6481a5c1-3d37-4a56-9f6a-bee08c554965",
    "aud": "authenticated",
    "role": "authenticated",
    "phone": "+8613012341234",
    "phone_confirmed_at": "2024-05-13T11:52:48.157306Z",
    "confirmation_sent_at": "2024-05-14T12:31:52.824573Z",
    "confirmed_at": "2024-05-13T11:52:48.157306Z",
    "app_metadata": {
      "provider": "phone",
      "providers": ["phone"]
    },
    "user_metadata": {},
    "created_at": "2024-05-13T11:45:33.7738Z",
    "updated_at": "2024-05-14T12:31:52.82475Z"
  },
  "sms": {
    "otp": "561166"
  }
}
```

### 服务器端处理要求

你的服务需要：

1. **验证签名**: 使用 `SEND_SMS_HOOK_SECRET` 验证请求来源
2. **提取数据**: 从 `user.phone` 获取手机号，从 `sms.otp` 获取验证码
3. **发送短信**: 调用阿里云短信 API
4. **返回响应**: HTTP 状态码 200（响应体可以为空即表示成功）

**响应要求**:
- ✅ **成功**: HTTP 200 状态码，响应体可以为空
- ❌ **失败**: 其他 HTTP 状态码（前端会显示 "Internal error"）

### 环境变量说明

| 变量名 | 必需 | 说明 |
|--------|------|------|
| `ALIYUN_ACCESS_KEY_ID` | ✅ | 阿里云 AccessKey ID |
| `ALIYUN_ACCESS_KEY_SECRET` | ✅ | 阿里云 AccessKey Secret |
| `ALIYUN_SMS_SIGN_NAME` | ✅ | 已审核的短信签名 |
| `ALIYUN_SMS_TEMPLATE_CODE` | ✅ | 已审核的短信模板代码 |
| `SEND_SMS_HOOK_SECRET` | ✅ | Webhook 签名密钥，必须与 Supabase 中配置的完全一致 |

## 使用

- 前端调用(REST)：
``` bash
curl -X POST http://your-domain.com/auth/v1/otp 
     -H "Content-Type: application/json" 
     -H "Authorization: Bearer replace-with-your-secret"
     -d '{"phone": "13012341234"}'
```
- SDK调用：
``` js
const { data, error } = await supabase.auth.signInWithOtp({
  phone: '+13012341234',
})
```

## 测试服务

### 使用测试客户端

```bash
# 设置环境变量
export SMS_BASE_URL="http://localhost:8000"
export SMS_SECRET="v1,whsec_your_secret_key_here"
export TEST_PHONE="13012341234"
export TEST_CODE="123456"

# 运行测试
npm test
# 或者
node test-client.js
```

### 手动测试

```bash
# 健康检查
curl http://localhost:8000/health

# 发送短信
curl -X POST http://localhost:8000/send-sms \
     -H "Content-Type: application/json" \
     -d '{"phone": "13012341234", "code": "123456"}'
```

## 监控和日志

### 查看日志

```bash
# Docker 部署
docker-compose logs -f aliyun-sms-sender

# 手动 Docker 部署
docker logs -f aliyun-sms-sender

# 直接部署
# 日志会直接输出到控制台
```

### 日志格式

服务输出结构化的 JSON 日志：
```json
{
  "timestamp": "2024-01-01T00:00:00Z",
  "level": "info",
  "message": "SMS sent via independent API",
  "phone": "130****1234",
  "success": true,
  "requestId": "request-id"
}
```

### 健康检查

```bash
curl http://localhost:8000/health
# 响应
{
  "status": "ok",
  "timestamp": "2024-01-01T00:00:00Z"
}
```

## 故障排除

### Supabase 集成调试

- `gotrue`封装了错误的具体消息内容，即便云函数返回了具体错误信息，前端也无法获取到，只能得到类似 `Internal error` 500 的错误。
- 每次修改`index.ts`代码后，需要通过命令 `docker compose restart supabase-functions` 重启edge-functions服务，才能生效。
- 查看`gotrue`日志：`docker logs -f supabase-auth`
- 查看`edge-functions`日志：`docker logs -f supabase-edge-functions`

### 独立部署调试

- 确保环境变量设置正确
- 检查阿里云短信服务配置和余额
- 验证网络连接和端口占用

## 部署建议

### 生产环境建议

1. **使用 HTTPS**: 配置 Nginx 反向代理和 SSL 证书
2. **安全配置**: 使用强密钥，定期轮换 AccessKey
3. **监控告警**: 设置服务健康检查和错误监控
4. **负载均衡**: 在高并发场景下使用负载均衡器

### 性能优化

- 使用 CDN 加速静态资源
- 配置连接池和请求超时
- 实施速率限制防止滥用

## 参考

- https://supabase.com/docs/guides/auth/auth-hooks/send-sms-hook
- https://github.com/orgs/supabase/discussions/33699
- https://api.aliyun.com/document/Dysmsapi/2017-05-25/SendSms

## 许可证

MIT License
