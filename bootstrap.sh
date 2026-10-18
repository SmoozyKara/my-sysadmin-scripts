#!/usr/bin/env bash
set -euo pipefail

echo "=== [1/4] Установка пакетов и подготовка логов ==="
sudo apt update && sudo apt install -y docker.io docker-compose-v2 mdadm lvm2 nginx openssl
logger "Test error event for sysadmin capstone"

echo "=== [2/4] Сборка RAID 1 и LVM ==="
sudo mkdir -p /mnt/raid-lab && cd /mnt/raid-lab
for i in 1 2 3; do
    [ -f "disk${i}.img" ] || sudo dd if=/dev/zero of="disk${i}.img" bs=1M count=512
done

LOOP1=$(sudo losetup -fP --show disk1.img)
LOOP2=$(sudo losetup -fP --show disk2.img)
LOOP3=$(sudo losetup -fP --show disk3.img)

yes | sudo mdadm --create /dev/md0 --level=1 --raid-devices=2 "$LOOP1" "$LOOP2"
sudo mkfs.ext4 -F /dev/md0
sudo mkdir -p /mnt/raid && sudo mount /dev/md0 /mnt/raid

yes | sudo pvcreate -ff "$LOOP3"
sudo vgcreate vg_data "$LOOP3"
yes | sudo lvcreate -L 200M -n lv_logs vg_data
sudo mkfs.ext4 -F /dev/vg_data/lv_logs
sudo mkdir -p /mnt/logs && sudo mount /dev/vg_data/lv_logs /mnt/logs
sudo lvextend -L +100M -r /dev/vg_data/lv_logs

echo "=== [3/4] Сборка контейнера и systemd ==="
cd ~/my-sysadmin-scripts
sudo docker rm -f my-app 2>/dev/null || true
sudo docker compose up -d --build
sudo docker stop my-app

sudo tee /etc/systemd/system/my-app.service > /dev/null << 'SERVICE'
[Unit]
Description=my-app service
After=docker.service
Requires=docker.service

[Service]
ExecStart=/usr/bin/docker start -a my-app
ExecStop=/usr/bin/docker stop my-app
Restart=on-failure

[Install]
WantedBy=multi-user.target
SERVICE

sudo systemctl daemon-reload
sudo systemctl enable --now my-app
sleep 3

echo "=== [4/4] Настройка Nginx с TLS ==="
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/my-app.key \
  -out /etc/ssl/certs/my-app.crt \
  -subj "/CN=my-app.local"

sudo tee /etc/nginx/sites-available/my-app > /dev/null << 'NGINX'
server {
    listen 80;
    server_name _;
    return 301 https://$host$request_uri;
}
server {
    listen 443 ssl;
    server_name _;
    ssl_certificate /etc/ssl/certs/my-app.crt;
    ssl_certificate_key /etc/ssl/private/my-app.key;
    location / {
        proxy_pass http://127.0.0.1:8080;
    }
}
NGINX

sudo rm -f /etc/nginx/sites-enabled/default
sudo ln -sf /etc/nginx/sites-available/my-app /etc/nginx/sites-enabled/my-app
sudo nginx -t && sudo systemctl reload nginx
curl -kI https://127.0.0.1
