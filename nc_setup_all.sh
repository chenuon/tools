#!/bin/bash

# 定义日志文件和标记文件
SETUP_LOG="/root/nc_setup.log"
SETUP_MARK="/root/.nc_setup_completed"
QB_MARK="/root/.nc_qbt_completed"
BBR_MARK="/root/.nc_bbr_completed"
REBOOT_MARK="/root/.nc_reboot_needed"
BBR_REBOOT_MARK="/root/.nc_bbr_reboot_needed"

# 清空日志文件
> "$SETUP_LOG"

# 日志函数，支持日志级别
log() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    case $level in
        "INFO")  echo -e "[$timestamp] \033[32m[INFO]\033[0m $message" | tee -a "$SETUP_LOG" ;;
        "WARN")  echo -e "[$timestamp] \033[33m[WARN]\033[0m $message" | tee -a "$SETUP_LOG" ;;
        "ERROR") echo -e "[$timestamp] \033[31m[ERROR]\033[0m $message" | tee -a "$SETUP_LOG" ;;
        *)       echo -e "[$timestamp] [UNKNOWN] $message" | tee -a "$SETUP_LOG" ;;
    esac
}

# 记录命令输出
log_cmd() {
    local cmd="$1"
    local desc="$2"
    {
        echo "----------------------------------------"
        echo "$desc ($(date '+%Y-%m-%d %H:%M:%S'))"
        echo "----------------------------------------"
        eval "$cmd" 2>&1
        echo "----------------------------------------"
    } >> "$SETUP_LOG"
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
    touch "$QB_MARK"
    
    # 创建重启标记
    touch "$REBOOT_MARK"
    
    # 创建启动脚本
    cat > /etc/init.d/nc-setup-phase2 << 'EOFMARKER'
#!/bin/bash
### BEGIN INIT INFO
# Provides:          nc-setup-phase2
# Required-Start:    $network $local_fs $remote_fs
# Required-Stop:     $network $local_fs $remote_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: NC Setup Phase 2
# Description:       Execute phase 2 of NC setup after reboot
### END INIT INFO

case "$1" in
  start)
    if [ -f /root/.nc_reboot_needed ]; then
        /bin/bash /root/nc_setup_all.sh
    fi
    ;;
  stop)
    ;;
  restart)
    ;;
  *)
    echo "Usage: $0 {start|stop|restart}"
    exit 1
    ;;
esac
exit 0
EOFMARKER

    # 设置正确的权限并启用服务
    chmod 755 /etc/init.d/nc-setup-phase2
    update-rc.d nc-setup-phase2 defaults
    
    # 复制当前脚本到固定位置（如果不在 /root 目录）
    if [ "$(pwd)" != "/root" ]; then
        cp "$0" /root/nc_setup_all.sh
        chmod +x /root/nc_setup_all.sh
    fi
    
    log "INFO" "第一阶段完成，系统将在 3 秒后重启..."
    sleep 3
    reboot
    
elif [ -f "$REBOOT_MARK" ]; then
    log "INFO" "检测到重启标记，开始执行第二阶段安装..."
    rm "$REBOOT_MARK"  # 删除第一阶段重启标记
    
    if [ ! -f "$BBR_REBOOT_MARK" ]; then
        # BBR 安装前的准备
        log "INFO" "开始安装 BBR..."
        touch "$BBR_REBOOT_MARK"
        
        {
            echo "----------------------------------------"
            echo "BBR 安装日志 ($(date '+%Y-%m-%d %H:%M:%S'))"
            echo "----------------------------------------"
            bash <(wget -qO- https://raw.githubusercontent.com/chenuon/tools/refs/heads/main/nc_bbr.sh) 2>&1
            echo "----------------------------------------"
        } >> "$SETUP_LOG"
        
        # BBR 脚本会自动重启，不需要我们手动重启
        exit 0
        
    elif [ -f "$BBR_REBOOT_MARK" ]; then
        # BBR 安装后的检查
        log "INFO" "BBR 安装后检查..."
        rm "$BBR_REBOOT_MARK"
        
        # 验证 BBR 安装
        if sysctl net.ipv4.tcp_congestion_control | grep -q bbr; then
            log "INFO" "BBR 安装成功并已启用"
            sysctl net.ipv4.tcp_congestion_control >> "$SETUP_LOG"
        else
            log "ERROR" "BBR 可能未正确安装"
            sysctl net.ipv4.tcp_congestion_control >> "$SETUP_LOG"
        fi
        
        # 安装完成后的状态检查
        log_cmd "systemctl status qbittorrent-nox@$USER" "qBittorrent 服务状态"
        log_cmd "sysctl net.ipv4.tcp_congestion_control" "BBR 状态"
        log_cmd "netstat -tuln" "端口监听状态"
        
        # 标记完成
        touch "$BBR_MARK"
        touch "$SETUP_MARK"
        log "INFO" "全部安装完成"
    fi
fi 
