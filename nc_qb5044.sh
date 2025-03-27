#!/bin/bash

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <user> <password> <port> <qb_up_port>"
    exit 1
fi

USER=$1
PASSWORD=$2
PORT=${3:-9527}
UP_PORT=${4:-23333}

# RAM=$(free -m | awk '/^Mem:/{print $2}')
# CACHE_SIZE=$((RAM / 4))

# 计算缓存大小，适应不同语言的输出
RAM=$(free -m | awk 'NR==2 {print $2}')  # 直接取第二行第二列的数值
CACHE_SIZE=$((RAM / 4))
log "设置缓存大小为: ${CACHE_SIZE}MB (总内存: ${RAM}MB)"

#sudo apt install curl unzip -y
bash <(wget -qO- https://raw.githubusercontent.com/jerry048/Dedicated-Seedbox/main/Install.sh) -u $USER -p $PASSWORD -c $CACHE_SIZE -q 4.6.7 -l v1.2.20
systemctl stop qbittorrent-nox@$USER
#systemctl disable qbittorrent-nox@$USER
sudo cp /usr/bin/qbittorrent-nox /usr/bin/qbittorrent-nox1
wget -O /usr/bin/qbittorrent-nox https://github.com/chenuon/jscode/releases/download/v5.0.4/qbittorrent-nox
chmod +x /usr/bin/qbittorrent-nox
sed -i "s/^WebUI\\\\Port=[0-9]*/WebUI\\\\Port=$PORT/" /home/$USER/.config/qBittorrent/qBittorrent.conf
sed -i "s/^Session\\\\Port=[0-9]*/Session\\\\Port=$UP_PORT/" /home/$USER/.config/qBittorrent/qBittorrent.conf
if grep -q "^General\\\\Locale=" /home/$USER/.config/qBittorrent/qBittorrent.conf; then
    sed -i "s/^General\\\\Locale=.*/General\\\\Locale=zh_CN/" /home/$USER/.config/qBittorrent/qBittorrent.conf
else
    sed -i "/\[Preferences\]/a General\\\\Locale=zh_CN" /home/$USER/.config/qBittorrent/qBittorrent.conf
fi
if grep -q "^Downloads\\\\PreAllocation=" /home/$USER/.config/qBittorrent/qBittorrent.conf; then
    sed -i "s/^Downloads\\\\PreAllocation=.*/Downloads\\\\PreAllocation=false/" /home/$USER/.config/qBittorrent/qBittorrent.conf
else
    sed -i "/\[Preferences\]/a Downloads\\\\PreAllocation=false" /home/$USER/.config/qBittorrent/qBittorrent.conf
fi
if grep -q "^WebUI\\\\CSRFProtection=" /home/$USER/.config/qBittorrent/qBittorrent.conf; then
    sed -i "s/^WebUI\\\\CSRFProtection=.*/WebUI\\\\CSRFProtection=false/" /home/$USER/.config/qBittorrent/qBittorrent.conf
else
    sed -i "/\[Preferences\]/a WebUI\\\\CSRFProtection=false" /home/$USER/.config/qBittorrent/qBittorrent.conf
fi
sed -i "s/disable_tso_/# disable_tso_/" /root/.boot-script.sh
systemctl enable qbittorrent-nox@chenyong
systemctl start qbittorrent-nox@chenyong
sudo apt update -y
sudo apt upgrade -y
sleep 3
reboot
