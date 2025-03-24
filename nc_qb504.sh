#!/bin/bash

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <user> <password> <port> <qb_up_port>"
    exit 1
fi

USER=$1
PASSWORD=$2
PORT=${3:-9527}
UP_PORT=${4:-23333}
RAM=$(free -m | awk '/^Mem:/{print $2}')
CACHE_SIZE=$((RAM / 8))

sudo apt install curl unzip -y
bash <(wget -qO- https://raw.githubusercontent.com/jerry048/Dedicated-Seedbox/main/Install.sh) -u $USER -p $PASSWORD -c $CACHE_SIZE -q 4.6.7 -l v1.2.20
systemctl stop qbittorrent-nox@$USER
#systemctl disable qbittorrent-nox@$USER
sudo cp /usr/bin/qbittorrent-nox /usr/bin/qbittorrent-nox1
wget -O /usr/bin/qbittorrent-nox https://github.com/chenuon/jscode/releases/download/v5.0.4/qbittorrent-nox
chmod +x /usr/bin/qbittorrent-nox
sed -i "s/WebUI\\\\Port=[0-9]*/WebUI\\\\Port=$PORT/" /home/$USER/.config/qBittorrent/qBittorrent.conf
sed -i "s/Connection\\\\PortRangeMin=[0-9]*/Connection\\\\PortRangeMin=$UP_PORT/" /home/$USER/.config/qBittorrent/qBittorrent.conf
sed -i "/\\[Preferences\\]/a Downloads\\\\PreAllocation=false" /home/$USER/.config/qBittorrent/qBittorrent.conf
sed -i "/\\[Preferences\\]/a WebUI\\\\CSRFProtection=false" /home/$USER/.config/qBittorrent/qBittorrent.conf
systemctl enable qbittorrent-nox@chenyong
systemctl start qbittorrent-nox@chenyong
sudo apt update -y
sudo apt upgrade -y
sleep 3
reboot
