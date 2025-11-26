# 阿里云短信发送服务 - 独立部署指南

本文档介绍如何独立部署阿里云短信发送服务，适用于需要不依赖 Supabase 而直接使用短信发送功能的场景。

## 部署方案

### 方案一：Docker Compose 部署（推荐）

#### 1. 环境准备

确保系统已安装：
- Docker 20.10+
- Docker Compose 2.0+

#### 2. 配置环境变量

复制环境变量模板：
```bash
cp .env.example .env
```

编辑 `.env` 文件，填入你的配置：
```bash
# 阿里云短信服务配置
ALIYUN_ACCESS_KEY_ID=your_access_key_id
ALIYUN_ACCESS_KEY_SECRET=your_access_key_secret
ALIYUN_SMS_SIGN_NAME=your_sms_sign_name
ALIYUN_SMS_TEMPLATE_CODE=your_template_code

# Webhook 签名密钥（用于验证请求）
SEND_SMS_HOOK_SECRET=v1,whsec_your_secret_key_here
```

#### 3. 启动服务

基础部署：
```bash
docker-compose up -d
```

带 Nginx 反向代理的部署：
```bash
docker-compose --profile with-nginx up -d
```

#### 4. 验证部署

```bash
# 检查服务状态
docker-compose ps

# 查看日志
docker-compose logs -f aliyun-sms-sender

# 健康检查
curl http://localhost:8000/health
```

### 方案二：手动 Docker 部署

#### 1. 构建镜像

```bash
docker build -t aliyun-sms-sender .
```

#### 2. 运行容器

```bash
docker run -d \
  --name aliyun-sms-sender \
  -p 8000:8000 \
  -e ALIYUN_ACCESS_KEY_ID=your_access_key_id \
  -e ALIYUN_ACCESS_KEY_SECRET=your_access_key_secret \
  -e ALIYUN_SMS_SIGN_NAME=your_sms_sign_name \
  -e ALIYUN_SMS_TEMPLATE_CODE=your_template_code \
  -e SEND_SMS_HOOK_SECRET=v1,whsec_your_secret_key \
  --restart unless-stopped \
  aliyun-sms-sender
```

### 方案三：直接部署（需要安装 Deno）

#### 1. 安装 Deno

```bash
# Linux/macOS
curl -fsSL https://deno.land/install.sh | sh

# Windows (PowerShell)
irm https://deno.land/install.ps1 | iex
```

#### 2. 设置环境变量

```bash
export ALIYUN_ACCESS_KEY_ID="your_access_key_id"
export ALIYUN_ACCESS_KEY_SECRET="your_access_key_secret"
export ALIYUN_SMS_SIGN_NAME="your_sms_sign_name"
export ALIYUN_SMS_TEMPLATE_CODE="your_template_code"
export SEND_SMS_HOOK_SECRET="v1,whsec_your_secret_key"
```

#### 3. 启动服务

```bash
deno run --allow-net --allow-env index.ts
```

## API 接口

服务启动后，提供以下接口：

### 发送短信验证码

```http
POST /send-sms
Content-Type: application/json
X-Webhook-Signature: sha256=<signature>

{
  "phone": "13012341234",
  "code": "123456"
}
```

#### 响应示例

成功：
```json
{
  "msg": "SMS sent successfully",
  "result": {
    "Message": "OK",
    "RequestId": "request-id",
    "BizId": "biz-id",
    "Code": "OK"
  }
}
```

失败：
```json
{
  "error": {
    "http_code": 400,
    "message": "Missing phone or otp code"
  }
}
```

### 健康检查

```http
GET /health
```

响应：
```json
{
  "status": "ok",
  "timestamp": "2024-01-01T00:00:00Z"
}
```

## 签名验证

为了确保安全性，所有请求都需要包含签名头：

```javascript
import { createHmac } from 'crypto';

function generateSignature(payload, secret) {
  const secretKey = secret.replace('v1,whsec_', '');
  const timestamp = Date.now().toString();
  const signaturePayload = `${timestamp}.${payload}`;

  return createHmac('sha256', secretKey)
    .update(signaturePayload)
    .digest('hex');
}

// 使用示例
const payload = JSON.stringify({ phone: "13012341234", code: "123456" });
const secret = "v1,whsec_your_secret_key";
const signature = generateSignature(payload, secret);

fetch('http://localhost:8000/send-sms', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'X-Webhook-Signature': `t=${Date.now()},v1=${signature}`
  },
  body: payload
});
```

## 客户端集成

### JavaScript 示例

```javascript
class AliyunSMSClient {
  constructor(baseUrl, secret) {
    this.baseUrl = baseUrl;
    this.secret = secret;
  }

  async sendSMS(phone, code) {
    const payload = { phone, code };
    const response = await fetch(`${this.baseUrl}/send-sms`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Webhook-Signature': this.generateSignature(payload)
      },
      body: JSON.stringify(payload)
    });

    return response.json();
  }

  generateSignature(payload) {
    // 实现签名逻辑
    // 参考上文的签名验证代码
  }
}

// 使用示例
const smsClient = new AliyunSMSClient('http://localhost:8000', 'v1,whsec_your_secret_key');
await smsClient.sendSMS('13012341234', '123456');
```

### Python 示例

```python
import requests
import hmac
import hashlib
import time
import json

class AliyunSMSClient:
    def __init__(self, base_url, secret):
        self.base_url = base_url
        self.secret = secret

    def send_sms(self, phone, code):
        payload = {"phone": phone, "code": code}
        payload_json = json.dumps(payload)

        headers = {
            'Content-Type': 'application/json',
            'X-Webhook-Signature': self._generate_signature(payload_json)
        }

        response = requests.post(
            f"{self.base_url}/send-sms",
            headers=headers,
            data=payload_json
        )

        return response.json()

    def _generate_signature(self, payload):
        secret_key = self.secret.replace('v1,whsec_', '')
        timestamp = str(int(time.time()))
        signature_payload = f"{timestamp}.{payload}"

        signature = hmac.new(
            secret_key.encode(),
            signature_payload.encode(),
            hashlib.sha256
        ).hexdigest()

        return f"t={timestamp},v1={signature}"

# 使用示例
client = AliyunSMSClient('http://localhost:8000', 'v1,whsec_your_secret_key')
result = client.send_sms('13012341234', '123456')
print(result)
```

## 监控和日志

### 查看日志

```bash
# Docker Compose 部署
docker-compose logs -f aliyun-sms-sender

# 手动 Docker 部署
docker logs -f aliyun-sms-sender
```

### 监控指标

服务提供基础的监控能力：
- 请求成功率
- 响应时间
- 错误率

### 日志格式

```json
{
  "timestamp": "2024-01-01T00:00:00Z",
  "level": "info|error",
  "message": "日志消息",
  "data": {
    "phone": "130****1234",
    "success": true,
    "request_id": "xxx"
  }
}
```

## 故障排除

### 常见问题

1. **签名验证失败**
   - 检查 `SEND_SMS_HOOK_SECRET` 配置是否正确
   - 确认客户端签名算法实现正确

2. **阿里云 API 调用失败**
   - 检查 AccessKey 是否有效
   - 确认短信签名和模板已通过审核
   - 检查账户余额是否充足

3. **网络连接问题**
   - 检查防火墙设置
   - 确认端口 8000 可访问

### 调试模式

可以通过设置环境变量启用调试模式：

```bash
export DEBUG=true
```

## 安全建议

1. **API 密钥安全**
   - 使用环境变量存储敏感信息
   - 定期轮换 AccessKey
   - 限制 AccessKey 权限

2. **网络安全**
   - 使用 HTTPS 传输
   - 配置防火墙规则
   - 使用反向代理

3. **访问控制**
   - 实施 IP 白名单
   - 使用 API 密钥认证
   - 限制请求频率

## 更新和维护

### 更新服务

```bash
# 拉取最新代码
git pull origin main

# 重新构建镜像
docker-compose build

# 重启服务
docker-compose up -d
```

### 备份配置

定期备份配置文件：
```bash
cp .env .env.backup
cp docker-compose.yml docker-compose.yml.backup
```