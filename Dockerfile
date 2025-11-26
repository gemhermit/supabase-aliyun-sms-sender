# 使用官方 Deno 运行时
FROM denoland/deno:2.1.3

# 设置工作目录
WORKDIR /app

# 复制项目文件
COPY . .

# 暴露端口
EXPOSE 8000

# 设置环境变量（用户可以通过 -e 参数覆盖）
ENV ALIYUN_ACCESS_KEY_ID=""
ENV ALIYUN_ACCESS_KEY_SECRET=""
ENV ALIYUN_SMS_SIGN_NAME=""
ENV ALIYUN_SMS_TEMPLATE_CODE=""
ENV SEND_SMS_HOOK_SECRET=""

# 启动命令
CMD ["run", "--allow-net", "--allow-env", "index.ts"]