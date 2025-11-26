// 测试客户端 - 用于测试独立部署的 SMS API
const crypto = require('crypto');

class SMSTestClient {
  constructor(baseUrl, secret) {
    this.baseUrl = baseUrl;
    this.secret = secret;
  }

  generateSignature(payload) {
    const secretKey = this.secret.replace('v1,whsec_', '');
    const timestamp = Date.now().toString();
    const signaturePayload = `${timestamp}.${payload}`;

    const signature = crypto
      .createHmac('sha256', secretKey)
      .update(signaturePayload)
      .digest('hex');

    return `t=${timestamp},v1=${signature}`;
  }

  async sendSMS(phone, code) {
    const payload = JSON.stringify({ phone, code });
    const signature = this.generateSignature(payload);

    console.log('发送短信请求...');
    console.log('URL:', `${this.baseUrl}/send-sms`);
    console.log('Payload:', payload);
    console.log('Signature:', signature);

    try {
      const response = await fetch(`${this.baseUrl}/send-sms`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Webhook-Signature': signature
        },
        body: payload
      });

      const result = await response.json();
      console.log('响应状态:', response.status);
      console.log('响应内容:', JSON.stringify(result, null, 2));

      return { status: response.status, data: result };
    } catch (error) {
      console.error('请求失败:', error);
      throw error;
    }
  }

  async healthCheck() {
    console.log('健康检查...');
    try {
      const response = await fetch(`${this.baseUrl}/health`);
      const result = await response.json();
      console.log('健康检查结果:', JSON.stringify(result, null, 2));
      return { status: response.status, data: result };
    } catch (error) {
      console.error('健康检查失败:', error);
      throw error;
    }
  }
}

// 使用示例
async function main() {
  // 配置参数
  const baseUrl = process.env.SMS_BASE_URL || 'http://localhost:8000';
  const secret = process.env.SMS_SECRET || 'v1,whsec_your_secret_key_here';
  const phone = process.env.TEST_PHONE || '13012341234';
  const code = process.env.TEST_CODE || '123456';

  const client = new SMSTestClient(baseUrl, secret);

  try {
    // 健康检查
    await client.healthCheck();

    // 发送短信
    await client.sendSMS(phone, code);
  } catch (error) {
    console.error('测试失败:', error);
    process.exit(1);
  }
}

// 如果直接运行此文件
if (require.main === module) {
  main().catch(console.error);
}

module.exports = { SMSTestClient };