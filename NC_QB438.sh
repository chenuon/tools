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

bash <(wget -qO- https://raw.githubusercontent.com/jerry048/Dedicated-Seedbox/main/Install.sh) -u $USER -p $PASSWORD -c $CACHE_SIZE -q 4.6.7 -l v1.2.20
systemctl stop qbittorrent-nox@$USER
systemctl disable qbittorrent-nox@$USER
sudo cp /usr/bin/qbittorrent-nox /usr/bin/qbittorrent-nox1
wget -O /usr/bin/qbittorrent-nox wget https://github.com/chenuon/jscode/releases/download/v5.0.4/qbittorrent-nox
chmod +x /usr/bin/qbittorrent-nox
sudo apt update -y
sudo apt upgrade -y
sleep 3
reboot
