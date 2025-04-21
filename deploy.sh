#!/bin/bash

USER="workstation"
SCRIPT="install-rustdesk.sh"
KEY_PRIV="id_rustdesk"  # Tên file private key SSH
KEY_PUB="id_rustdesk.pub"  # Tên file public key SSH

# Lặp qua danh sách các IP
while read IP; do
  echo "→ Deploy trên $IP"

  # 1. Copy script cài đặt RustDesk lên máy trạm
  scp -o StrictHostKeyChecking=no $SCRIPT $USER@$IP:/tmp/

  # 2. Nếu bạn muốn dùng ID mới random: xóa key cũ để RustDesk tự sinh
  ssh -o StrictHostKeyChecking=no $USER@$IP "rm -f ~/.config/rustdesk/id_ecdsa*"

  # 3. Nếu bạn muốn dùng keypair cố định:
  scp -o StrictHostKeyChecking=no $KEY_PRIV $KEY_PUB $USER@$IP:/home/$USER/.config/rustdesk/id_ecdsa{,\.pub}
  ssh -o StrictHostKeyChecking=no $USER@$IP "chown $USER:$USER /home/$USER/.config/rustdesk/id_ecdsa*; chmod 600 /home/$USER/.config/rustdesk/id_ecdsa"

  # 4. Chạy script cài đặt
  ssh -o StrictHostKeyChecking=no $USER@$IP "chmod +x /tmp/$SCRIPT && sudo /tmp/$SCRIPT"

  echo "✅ Hoàn tất trên máy $IP"
done < ip_list.txt
