#!/bin/bash

# 检查是否为 root 用户
if [ "$EUID" -ne 0 ]; then
    echo "请使用 root 用户运行此脚本"
    exit 1
fi

# 检查参数
if [ "$#" -lt 2 ]; then
    echo "用法: $0 <user> <password> <port> <qb_up_port>"
    exit 1
fi

# 定义标记文件路径
SETUP_MARK="/root/.nc_setup_completed"
QBT_MARK="/root/.nc_qbt_completed"
BBR_MARK="/root/.nc_bbr_completed"
SETUP_LOG="/root/nc_setup.log"  # 添加日志文件

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$SETUP_LOG"
}

# 获取参数
USER=$1
PASSWORD=$2
PORT=${3:-9527}
UP_PORT=${4:-23333}

# 检查是否已完成全部安装
if [ -f "$SETUP_MARK" ]; then
    log "系统已完成全部配置，如需重新配置请删除 $SETUP_MARK 文件"
    exit 0
fi

# 安装基础工具
# apt install curl unzip wget -y

# 第一阶段：安装和配置 qBittorrent
if [ ! -f "$QBT_MARK" ]; then
    log "开始第一阶段：安装 qBittorrent..."
    
    # 计算缓存大小
    RAM=$(free -m | awk '/^Mem:/{print $2}')
    CACHE_SIZE=$((RAM / 4))
    log "设置缓存大小为: ${CACHE_SIZE}MB"

    # 安装 qBittorrent
    log "开始安装 qBittorrent..."
    bash <(wget -qO- https://raw.githubusercontent.com/jerry048/Dedicated-Seedbox/main/Install.sh) -u $USER -p $PASSWORD -c $CACHE_SIZE -q 4.6.7 -l v1.2.20
    
    # 停止服务
    log "停止 qBittorrent 服务..."
    systemctl stop qbittorrent-nox@$USER
    
    # 替换二进制文件
    log "替换 qBittorrent 二进制文件..."
    sudo cp /usr/bin/qbittorrent-nox /usr/bin/qbittorrent-nox1
    wget -O /usr/bin/qbittorrent-nox https://github.com/chenuon/jscode/releases/download/v5.0.4/qbittorrent-nox
    chmod +x /usr/bin/qbittorrent-nox
    
    # 修改配置
    log "修改 qBittorrent 配置..."
    sed -i "s/WebUI\\\\Port=[0-9]*/WebUI\\\\Port=$PORT/" /home/$USER/.config/qBittorrent/qBittorrent.conf
    sed -i "s/Session\\\\Port=[0-9]*/Session\\\\Port=$UP_PORT/" /home/$USER/.config/qBittorrent/qBittorrent.conf
    sed -i "/\\[Preferences\\]/a General\\\\Locale=zh" /home/$USER/.config/qBittorrent/qBittorrent.conf
    sed -i "/\\[Preferences\\]/a Downloads\\\\PreAllocation=false" /home/$USER/.config/qBittorrent/qBittorrent.conf
    sed -i "/\\[Preferences\\]/a WebUI\\\\CSRFProtection=false" /home/$USER/.config/qBittorrent/qBittorrent.conf
    sed -i "s/disable_tso_/# disable_tso_/" /root/.boot-script.sh
    
    # 启动服务
    log "启动 qBittorrent 服务..."
    systemctl enable qbittorrent-nox@$USER
    systemctl start qbittorrent-nox@$USER
    
    # 标记 qBittorrent 安装完成
    touch "$QBT_MARK"
    log "qBittorrent 安装配置完成"
    
    # 更新系统
    log "更新系统..."
    apt update -y
    apt upgrade -y
    
    # 设置重启后继续第二阶段
    log "准备第二阶段配置..."
    cat > /root/continue_setup.sh << 'EOF'
#!/bin/bash
SETUP_LOG="/root/nc_setup.log"
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$SETUP_LOG"
}

if [ ! -f "/root/.nc_bbr_completed" ]; then
    log "开始第二阶段配置..."
    sleep 20  # 等待系统完全启动
    
    # 安装 BBR
    log "安装 BBR..."
    bash <(wget -qO- https://raw.githubusercontent.com/guowanghushifu/Seedbox-Components/refs/heads/main/BBR/BBRx/BBRy.sh)
    if [ $? -eq 0 ]; then
        log "BBR 安装成功"
    else
        log "BBR 安装失败"
    fi
    
    # 安装 vnstat
    log "安装 vnstat..."
    bash <(wget -qO- "https://net1999.net/misc/vnstat.sh")
    if [ $? -eq 0 ]; then
        log "vnstat 安装成功"
    else
        log "vnstat 安装失败"
    fi
    
    # 启动 vnstat
    log "启动 vnstat 服务..."
    systemctl enable vnstat
    systemctl start vnstat
    
    # 标记完成
    touch /root/.nc_bbr_completed
    touch /root/.nc_setup_completed
    log "第二阶段配置完成"
    
    # 清理
    rm /root/continue_setup.sh
    rm /etc/cron.d/continue_setup
    
    # 最终重启
    log "准备最终重启..."
    reboot
fi
EOF
    
    chmod +x /root/continue_setup.sh
    
    # 添加一次性的 cron 任务
    echo "@reboot root /root/continue_setup.sh" > /etc/cron.d/continue_setup
    chmod 644 /etc/cron.d/continue_setup
    
    log "准备第一次重启..."
    sleep 3
    reboot
    
elif [ ! -f "$BBR_MARK" ]; then
    log "继续执行第二阶段安装..."
    # 脚本会通过 continue_setup.sh 自动执行
    exit 0
fi
