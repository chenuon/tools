#!/bin/bash

bash <(wget -qO- https://raw.githubusercontent.com/guowanghushifu/Seedbox-Components/refs/heads/main/BBR/BBRx/BBRy.sh)
sleep 3
bash <(wget -qO- "https://net1999.net/misc/vnstat.sh")
sleep 3
systemctl start vnstat
sleep 3
reboot
