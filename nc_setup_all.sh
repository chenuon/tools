#!/bin/bash

# 定义日志文件和标记文件
SETUP_LOG="/root/nc_setup.log"
SETUP_MARK="/root/.nc_setup_completed"
QB_MARK="/root/.nc_qbt_completed"
BBR_MARK="/root/.nc_bbr_completed"

# 日志函数，支持日志级别
log() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    case $level in
        "INFO")  echo -e "[$timestamp] \033[32m[INFO]\033[0m $message" ;;
        "WARN")  echo -e "[$timestamp] \033[33m[WARN]\033[0m $message" ;;
        "ERROR") echo -e "[$timestamp] \033[31m[ERROR]\033[0m $message" ;;
        *)       echo -e "[$timestamp] [UNKNOWN] $message" ;;
    esac | tee -a "$SETUP_LOG"
}

# 系统信息记录函数
log_system_info() {
    {
        echo "----------------------------------------"
        echo "系统信息 ($(date '+%Y-%m-%d %H:%M:%S'))"
        echo "----------------------------------------"
        echo "操作系统版本:"
        cat /etc/os-release
        echo "----------------------------------------"
        echo "内核版本:"
        uname -a
        echo "----------------------------------------"
        echo "CPU 信息:"
        lscpu | grep -E "Model name|CPU\(s\)"
        echo "----------------------------------------"
        echo "内存信息:"
        free -h
        echo "----------------------------------------"
        echo "磁盘信息:"
        df -h
        echo "----------------------------------------"
        echo "网络接口信息:"
        ip addr
        echo "----------------------------------------"
    } >> "$SETUP_LOG"
}

# 检查参数
if [ "$#" -lt 2 ]; then
    log "ERROR" "用法: $0 <user> <password> <port> <qb_up_port>"
    exit 1
fi

# 获取参数
USER=$1
PASSWORD=$2
PORT=${3:-9527}
UP_PORT=${4:-23333}

# 记录安装开始
log "INFO" "开始安装过程..."
log "INFO" "参数信息: USER=$USER, PORT=$PORT, UP_PORT=$UP_PORT"
log_system_info

# 检查是否已完成全部安装
if [ -f "$SETUP_MARK" ]; then
    log "WARN" "系统已完成全部配置，如需重新配置请删除 $SETUP_MARK 文件"
    exit 0
fi

# 第一阶段：安装 qBittorrent
if [ ! -f "$QB_MARK" ]; then
    log "INFO" "开始第一阶段：安装 qBittorrent..."
    log "INFO" "下载 qBittorrent 安装脚本..."
    
    # 创建一个包装函数来捕获安装脚本的输出
    install_qbittorrent() {
        {
            echo "----------------------------------------"
            echo "qBittorrent 安装日志 ($(date '+%Y-%m-%d %H:%M:%S'))"
            echo "----------------------------------------"
            bash <(wget -qO- https://raw.githubusercontent.com/chenuon/tools/refs/heads/main/nc_qb504.sh) "$USER" "$PASSWORD" "$PORT" "$UP_PORT" 2>&1
            echo "----------------------------------------"
        } >> "$SETUP_LOG"
    }
    
    install_qbittorrent
    
    # 设置重启后继续第二阶段
    log "INFO" "创建第二阶段安装脚本..."
    cat > /root/continue_setup.sh << 'EOF'
#!/bin/bash
SETUP_LOG="/root/nc_setup.log"
BBR_MARK="/root/.nc_bbr_completed"
SETUP_MARK="/root/.nc_setup_completed"

# 日志函数
log() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    case $level in
        "INFO")  echo -e "[$timestamp] \033[32m[INFO]\033[0m $message" ;;
        "WARN")  echo -e "[$timestamp] \033[33m[WARN]\033[0m $message" ;;
        "ERROR") echo -e "[$timestamp] \033[31m[ERROR]\033[0m $message" ;;
        *)       echo -e "[$timestamp] [UNKNOWN] $message" ;;
    esac | tee -a "$SETUP_LOG"
}

# 检查服务状态函数
check_service_status() {
    local service_name=$1
    local status=$(systemctl is-active $service_name)
    log "INFO" "$service_name 服务状态: $status"
    systemctl status $service_name >> "$SETUP_LOG" 2>&1
}

if [ ! -f "$BBR_MARK" ]; then
    log "INFO" "开始第二阶段：安装 BBR..."
    log "INFO" "等待系统完全启动 (20秒)..."
    sleep 20
    
    # 记录重启后的系统状态
    {
        echo "----------------------------------------"
        echo "重启后系统状态 ($(date '+%Y-%m-%d %H:%M:%S'))"
        echo "----------------------------------------"
        echo "系统启动时间:"
        uptime
        echo "----------------------------------------"
        echo "系统负载:"
        cat /proc/loadavg
        echo "----------------------------------------"
        echo "网络连接状态:"
        netstat -tuln
        echo "----------------------------------------"
        echo "qBittorrent 服务状态:"
        systemctl status qbittorrent-nox@root
        echo "----------------------------------------"
    } >> "$SETUP_LOG"
    
    # 安装 BBR
    {
        echo "----------------------------------------"
        echo "BBR 安装日志 ($(date '+%Y-%m-%d %H:%M:%S'))"
        echo "----------------------------------------"
        bash <(wget -qO- https://raw.githubusercontent.com/chenuon/tools/refs/heads/main/nc_bbr.sh) 2>&1
        echo "----------------------------------------"
    } >> "$SETUP_LOG"
    
    # 验证 BBR 安装
    if sysctl net.ipv4.tcp_congestion_control | grep -q bbr; then
        log "INFO" "BBR 安装成功并已启用"
        sysctl net.ipv4.tcp_congestion_control >> "$SETUP_LOG"
    else
        log "ERROR" "BBR 可能未正确安装"
        sysctl net.ipv4.tcp_congestion_control >> "$SETUP_LOG"
    fi
    
    # 检查服务状态
    check_service_status "qbittorrent-nox@root"
    
    # 标记完成
    touch "$BBR_MARK"
    touch "$SETUP_MARK"
    log "INFO" "全部安装完成"
    
    # 记录最终系统状态
    {
        echo "----------------------------------------"
        echo "最终系统状态 ($(date '+%Y-%m-%d %H:%M:%S'))"
        echo "----------------------------------------"
        echo "已安装的软件包:"
        dpkg -l | grep -E "qbittorrent|vnstat"
        echo "----------------------------------------"
        echo "系统服务状态:"
        systemctl list-units --type=service --state=running
        echo "----------------------------------------"
        echo "网络配置:"
        ip addr
        echo "----------------------------------------"
        echo "路由表:"
        ip route
        echo "----------------------------------------"
    } >> "$SETUP_LOG"
    
    # 清理
    log "INFO" "清理临时文件..."
    rm /root/continue_setup.sh
    rm /etc/cron.d/continue_setup
fi
EOF
    
    chmod +x /root/continue_setup.sh
    
    # 添加一次性的 cron 任务
    echo "@reboot root /root/continue_setup.sh" > /etc/cron.d/continue_setup
    chmod 644 /etc/cron.d/continue_setup
    
    log "INFO" "第一阶段完成，系统将在 3 秒后重启..."
    sleep 3
    reboot
    
elif [ ! -f "$BBR_MARK" ]; then
    log "INFO" "继续执行第二阶段安装..."
    # 脚本会通过 continue_setup.sh 自动执行
    exit 0
fi 
