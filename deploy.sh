#!/bin/bash

KEY="/home/ducanh/Downloads/nhu_y.txt"
USER="root"
CMD="cd /opt && ./install-rustdesk-v2.sh"

while read -r IP; do
  echo "👉 Đang chạy trên $IP"
  ssh -o StrictHostKeyChecking=no -i "$KEY" "$USER@$IP" "$CMD" &
done < list-ip.txt

wait
echo "✅ Hoàn tất cài đặt trên tất cả máy!"

