#!/bin/bash

# 阿里云短信发送服务快速启动脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查环境变量
check_env() {
    log_info "检查环境变量..."

    local required_vars=(
        "ALIYUN_ACCESS_KEY_ID"
        "ALIYUN_ACCESS_KEY_SECRET"
        "ALIYUN_SMS_SIGN_NAME"
        "ALIYUN_SMS_TEMPLATE_CODE"
        "SEND_SMS_HOOK_SECRET"
    )

    local missing_vars=()

    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            missing_vars+=("$var")
        fi
    done

    if [ ${#missing_vars[@]} -ne 0 ]; then
        log_error "缺少必需的环境变量:"
        for var in "${missing_vars[@]}"; do
            echo "  - $var"
        done
        echo
        log_warn "请设置这些环境变量后重试"
        echo "你可以复制 .env.example 到 .env 并填入相应值"
        exit 1
    fi

    log_info "环境变量检查通过"
}

# Docker 部署
deploy_docker() {
    log_info "开始 Docker 部署..."

    if command -v docker-compose &> /dev/null; then
        docker-compose up -d --build
    elif command -v docker &> /dev/null; then
        docker build -t aliyun-sms-sender .
        docker run -d \
            --name aliyun-sms-sender \
            -p 8000:8000 \
            -e ALIYUN_ACCESS_KEY_ID="$ALIYUN_ACCESS_KEY_ID" \
            -e ALIYUN_ACCESS_KEY_SECRET="$ALIYUN_ACCESS_KEY_SECRET" \
            -e ALIYUN_SMS_SIGN_NAME="$ALIYUN_SMS_SIGN_NAME" \
            -e ALIYUN_SMS_TEMPLATE_CODE="$ALIYUN_SMS_TEMPLATE_CODE" \
            -e SEND_SMS_HOOK_SECRET="$SEND_SMS_HOOK_SECRET" \
            --restart unless-stopped \
            aliyun-sms-sender
    else
        log_error "未找到 Docker 或 Docker Compose"
        exit 1
    fi

    log_info "Docker 部署完成"
}

# 直接部署 (Deno)
deploy_direct() {
    log_info "开始直接部署..."

    if ! command -v deno &> /dev/null; then
        log_error "未找到 Deno 运行时"
        log_warn "请安装 Deno: curl -fsSL https://deno.land/install.sh | sh"
        exit 1
    fi

    log_info "启动服务..."
    deno run --allow-net --allow-env index.ts &
    local pid=$!

    log_info "服务已启动，PID: $pid"
    echo $pid > sms_service.pid
}

# 健康检查
health_check() {
    log_info "等待服务启动..."
    sleep 5

    local max_attempts=30
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if curl -f http://localhost:8000/health &> /dev/null; then
            log_info "服务启动成功！"
            echo
            log_info "服务地址: http://localhost:8000"
            log_info "健康检查: http://localhost:8000/health"
            log_info "发送短信: POST http://localhost:8000/send-sms"
            return 0
        fi

        log_warn "等待服务启动... ($attempt/$max_attempts)"
        sleep 2
        ((attempt++))
    done

    log_error "服务启动失败或超时"
    return 1
}

# 停止服务
stop_service() {
    log_info "停止服务..."

    if [ -f sms_service.pid ]; then
        local pid=$(cat sms_service.pid)
        if kill -0 $pid 2> /dev/null; then
            kill $pid
            rm sms_service.pid
            log_info "服务已停止"
        else
            log_warn "服务进程不存在"
        fi
    fi

    # 停止 Docker 容器
    if command -v docker &> /dev/null; then
        docker stop aliyun-sms-sender 2> /dev/null || true
        docker rm aliyun-sms-sender 2> /dev/null || true
    fi

    if command -v docker-compose &> /dev/null; then
        docker-compose down 2> /dev/null || true
    fi
}

# 显示帮助
show_help() {
    echo "用法: $0 [选项]"
    echo
    echo "选项:"
    echo "  docker    使用 Docker 部署"
    echo "  direct    直接使用 Deno 部署"
    echo "  stop      停止服务"
    echo "  test      运行测试"
    echo "  help      显示此帮助信息"
    echo
    echo "环境变量:"
    echo "  ALIYUN_ACCESS_KEY_ID      阿里云 AccessKey ID"
    echo "  ALIYUN_ACCESS_KEY_SECRET  阿里云 AccessKey Secret"
    echo "  ALIYUN_SMS_SIGN_NAME      短信签名"
    echo "  ALIYUN_SMS_TEMPLATE_CODE  短信模板代码"
    echo "  SEND_SMS_HOOK_SECRET      Webhook 签名密钥"
    echo
    echo "示例:"
    echo "  $0 docker                # Docker 部署"
    echo "  $0 direct                # 直接部署"
    echo "  $0 stop                  # 停止服务"
}

# 运行测试
run_test() {
    log_info "运行测试..."

    if ! command -v node &> /dev/null; then
        log_error "未找到 Node.js，无法运行测试"
        exit 1
    fi

    node test-client.js
}

# 主逻辑
main() {
    case "${1:-help}" in
        "docker")
            check_env
            deploy_docker
            health_check
            ;;
        "direct")
            check_env
            deploy_direct
            health_check
            ;;
        "stop")
            stop_service
            ;;
        "test")
            run_test
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        *)
            log_error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
}

# 运行主函数
main "$@"