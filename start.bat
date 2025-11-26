@echo off
REM 阿里云短信发送服务快速启动脚本 (Windows)

setlocal enabledelayedexpansion

REM 颜色定义
set "RED=[91m"
set "GREEN=[92m"
set "YELLOW=[93m"
set "NC=[0m"

REM 日志函数
:log_info
echo %GREEN%[INFO]%NC% %~1
goto :eof

:log_warn
echo %YELLOW%[WARN]%NC% %~1
goto :eof

:log_error
echo %RED%[ERROR]%NC% %~1
goto :eof

REM 检查环境变量
:check_env
call :log_info "检查环境变量..."

set "missing_vars=0"

if "%ALIYUN_ACCESS_KEY_ID%"=="" (
    call :log_error "缺少环境变量: ALIYUN_ACCESS_KEY_ID"
    set /a missing_vars+=1
)
if "%ALIYUN_ACCESS_KEY_SECRET%"=="" (
    call :log_error "缺少环境变量: ALIYUN_ACCESS_KEY_SECRET"
    set /a missing_vars+=1
)
if "%ALIYUN_SMS_SIGN_NAME%"=="" (
    call :log_error "缺少环境变量: ALIYUN_SMS_SIGN_NAME"
    set /a missing_vars+=1
)
if "%ALIYUN_SMS_TEMPLATE_CODE%"=="" (
    call :log_error "缺少环境变量: ALIYUN_SMS_TEMPLATE_CODE"
    set /a missing_vars+=1
)
if "%SEND_SMS_HOOK_SECRET%"=="" (
    call :log_error "缺少环境变量: SEND_SMS_HOOK_SECRET"
    set /a missing_vars+=1
)

if %missing_vars% gtr 0 (
    echo.
    call :log_warn "请设置这些环境变量后重试"
    echo "你可以复制 .env.example 到 .env 并填入相应值"
    pause
    exit /b 1
)

call :log_info "环境变量检查通过"
goto :eof

REM Docker 部署
:deploy_docker
call :log_info "开始 Docker 部署..."

docker-compose up -d --build
if %errorlevel% neq 0 (
    call :log_error "Docker 部署失败"
    exit /b 1
)

call :log_info "Docker 部署完成"
goto :eof

REM 直接部署 (Deno)
:deploy_direct
call :log_info "开始直接部署..."

deno --version >nul 2>&1
if %errorlevel% neq 0 (
    call :log_error "未找到 Deno 运行时"
    call :log_warn "请安装 Deno: irm https://deno.land/install.ps1 | iex"
    pause
    exit /b 1
)

call :log_info "启动服务..."
start /B deno run --allow-net --allow-env index.ts
if %errorlevel% neq 0 (
    call :log_error "服务启动失败"
    exit /b 1
)

call :log_info "服务已启动"
goto :eof

REM 健康检查
:health_check
call :log_info "等待服务启动..."
timeout /t 5 /nobreak >nul

set "max_attempts=30"
set "attempt=1"

:health_check_loop
curl -f http://localhost:8000/health >nul 2>&1
if %errorlevel% equ 0 (
    call :log_info "服务启动成功！"
    echo.
    call :log_info "服务地址: http://localhost:8000"
    call :log_info "健康检查: http://localhost:8000/health"
    call :log_info "发送短信: POST http://localhost:8000/send-sms"
    goto :eof
)

call :log_warn "等待服务启动... (!attempt!/!max_attempts!)"
timeout /t 2 /nobreak >nul
set /a attempt+=1

if !attempt! leq %max_attempts% goto health_check_loop

call :log_error "服务启动失败或超时"
exit /b 1

REM 停止服务
:stop_service
call :log_info "停止服务..."

taskkill /F /IM deno.exe >nul 2>&1
docker stop aliyun-sms-sender >nul 2>&1
docker rm aliyun-sms-sender >nul 2>&1
docker-compose down >nul 2>&1

call :log_info "服务已停止"
goto :eof

REM 显示帮助
:show_help
echo 用法: %~nx0 [选项]
echo.
echo 选项:
echo   docker    使用 Docker 部署
echo   direct    直接使用 Deno 部署
echo   stop      停止服务
echo   test      运行测试
echo   help      显示此帮助信息
echo.
echo 环境变量:
echo   ALIYUN_ACCESS_KEY_ID      阿里云 AccessKey ID
echo   ALIYUN_ACCESS_KEY_SECRET  阿里云 AccessKey Secret
echo   ALIYUN_SMS_SIGN_NAME      短信签名
echo   ALIYUN_SMS_TEMPLATE_CODE  短信模板代码
echo   SEND_SMS_HOOK_SECRET      Webhook 签名密钥
echo.
echo 示例:
echo   %~nx0 docker                # Docker 部署
echo   %~nx0 direct                # 直接部署
echo   %~nx0 stop                  # 停止服务
goto :eof

REM 运行测试
:run_test
call :log_info "运行测试..."

node --version >nul 2>&1
if %errorlevel% neq 0 (
    call :log_error "未找到 Node.js，无法运行测试"
    exit /b 1
)

node test-client.js
goto :eof

REM 主逻辑
if "%1"=="docker" (
    call :check_env
    call :deploy_docker
    call :health_check
) else if "%1"=="direct" (
    call :check_env
    call :deploy_direct
    call :health_check
) else if "%1"=="stop" (
    call :stop_service
) else if "%1"=="test" (
    call :run_test
) else if "%1"=="help" (
    call :show_help
) else if "%1"=="" (
    call :show_help
) else (
    call :log_error "未知选项: %1"
    call :show_help
    exit /b 1
)

pause