#!/bin/bash
set -e

# === Config ===
RUSTDESK_VERSION="1.3.9"
RUSTDESK_PASS="Etonq7_obtren"
RUSTDESK_DEB="rustdesk-${RUSTDESK_VERSION}-x86_64.deb"
DOWNLOAD_URL="https://github.com/rustdesk/rustdesk/releases/download/${RUSTDESK_VERSION}/${RUSTDESK_DEB}"
CONFIG_FILE="/root/.config/rustdesk/RustDesk.toml"
CONFIG_FILE2="/root/.config/rustdesk/RustDesk2.toml"
USERNAME=$(basename $(ls -d /home/* | head -n 1))
PASSWORD="123456"

# === Cài Desktop Env ===
echo "=== [1/7] Cài XFCE4 + GDM3 ==="
apt update && apt install -y wget curl xfce4 xfce4-goodies gdm3 xserver-xorg x11-xserver-utils dbus-x11

# === Tạo user remote ===
echo "=== [2/7] Tạo user remote ==="
if ! id "$USERNAME" &>/dev/null; then
    echo "  - Tạo user $USERNAME..."
    sudo adduser --disabled-password --gecos "" "$USERNAME" || { echo "    [LỖI] Không thể tạo user $USERNAME."; exit 1; }
    echo "$USERNAME:$PASSWORD" | sudo chpasswd || { echo "    [LỖI] Không thể đặt mật khẩu cho $USERNAME."; exit 1; }
    sudo usermod -aG sudo "$USERNAME" || { echo "    [LỖI] Không thể thêm $USERNAME vào nhóm sudo."; exit 1; }
else
    echo "  - User $USERNAME đã tồn tại."
fi

mkdir -p /etc/gdm3
cat > /etc/gdm3/custom.conf <<EOF
[daemon]
WaylandEnable=false
AutomaticLoginEnable=true
AutomaticLogin=$USERNAME
EOF

su - "$USERNAME" -c "echo 'exec startxfce4' > ~/.xinitrc"

# === Kiểm tra màn hình vật lý ===
echo "=== [3/7] Kiểm tra và cài dummy monitor nếu cần ==="
apt install -y x11-utils
if ! xrandr --listmonitors | grep -q "Monitors: 1"; then
    echo "Máy đã có màn hình vật lý. Không cài dummy."
else
    echo "Không tìm thấy màn hình. Cài dummy monitor."
    apt install -y xserver-xorg-video-dummy
    mkdir -p /etc/X11/xorg.conf.d
    cat > /etc/X11/xorg.conf.d/10-headless.conf <<EOD
Section "Device"
  Identifier "Configured Video Device"
  Driver "dummy"
  Option "DRI" "3"
EndSection

Section "Monitor"
  Identifier "Monitor0"
  HorizSync 28.0-80.0
  VertRefresh 48.0-75.0
  Modeline "1920x1080" 172.80 1920 2040 2248 2576 1080 1081 1084 1118
EndSection

Section "Screen"
  Identifier "Screen0"
  Monitor "Monitor0"
  Device "Configured Video Device"
  DefaultDepth 24
  SubSection "Display"
    Depth 24
    Modes "1920x1080"
  EndSubSection
EndSection

Section "ServerFlags"
  Option "DRI3" "True"
  Option "DRI2" "True"
EndSection
EOD
fi

# === Cài đặt RustDesk ===
echo "=== [4/7] Cài đặt RustDesk ==="
if dpkg -l | grep -q rustdesk; then
    echo "RustDesk đã cài trước đó. Gỡ bỏ trước khi cài lại."
    systemctl stop rustdesk || true
    apt purge -y rustdesk || true
    rm -f /etc/systemd/system/rustdesk.service /lib/systemd/system/rustdesk.service
    rm -rf /root/.config/rustdesk
    systemctl daemon-reload || true
fi

wget "$DOWNLOAD_URL" -O /tmp/$RUSTDESK_DEB || { echo "Không tải được RustDesk"; exit 1; }
dpkg -i /tmp/$RUSTDESK_DEB || apt install -f -y
rm -f /tmp/$RUSTDESK_DEB

systemctl enable rustdesk
systemctl restart rustdesk

# === Cấu hình RustDesk password ===
echo "=== [5/7] Cấu hình mật khẩu RustDesk ==="

# Chờ file config RustDesk xuất hiện
for ((i=1; i<=60; i++)); do
    if [ -f "$CONFIG_FILE" ] && grep -q "enc_id" "$CONFIG_FILE" && grep -q "salt" "$CONFIG_FILE"; then
        break
    fi
    sleep 1
done
if [ $i -gt 60 ]; then
    echo "RustDesk config không tạo được."
    exit 1
fi

# Đặt mật khẩu và xác thực
MAX_PASS_RETRY=3
for ((pass_retry=1; pass_retry<=MAX_PASS_RETRY; pass_retry++)); do
    rustdesk --password "$RUSTDESK_PASS"
    sleep 2
    if grep -q 'password' "$CONFIG_FILE" && grep -qv 'password = ""' "$CONFIG_FILE"; then
        echo "Đặt mật khẩu thành công."
        break
    fi
    echo "Đặt mật khẩu thất bại, thử lại lần $pass_retry..."
    sleep 2
done
if [ $pass_retry -gt $MAX_PASS_RETRY ]; then
    echo "Không thể đặt mật khẩu RustDesk."
    exit 1
fi

echo "=== [5.1] Cấu hình server riêng cho RustDesk ==="
sudo systemctl start rustdesk
# Đảm bảo [options] tồn tại để tránh lỗi khi cập nhật các key bên trong
grep -q "^\[options\]" "$CONFIG_FILE2" || echo -e "\n[options]" >> "$CONFIG_FILE2"

# Cập nhật từng dòng, hoặc thêm nếu chưa có
update_or_add() {
    local key="$1"
    local value="$2"
    if grep -q "^\s*${key}\s*=" "$CONFIG_FILE2"; then
        sed -i "s|^\s*${key}\s*=.*|${key} = '${value}'|" "$CONFIG_FILE2"
    else
        echo "${key} = '${value}'" >> "$CONFIG_FILE2"
    fi
}

update_or_add "rendezvous_server" "10.0.19.40:21116"
update_or_add "relay-server" "10.0.19.40:21117"
update_or_add "key" "ygc8zxTf3+o0UwXLeMs1egqfCZ7Vo+xXVZ2NT9qVRSg="
update_or_add "custom-rendezvous-server" "10.0.19.40:21116"

sudo systemctl restart rustdesk
sudo cat /root/.config/rustdesk/RustDesk2.toml

# === Lấy RustDesk ID ===
echo "=== [6/7] Lấy RustDesk ID ==="

MAX_ID_RETRY=3
for ((id_retry=1; id_retry<=MAX_ID_RETRY; id_retry++)); do
    RUSTDESK_ID=$(rustdesk --get-id 2>/dev/null)
    if [ -n "$RUSTDESK_ID" ]; then
        echo "RustDesk ID: $RUSTDESK_ID"
        break
    fi
    echo "Không lấy được ID, thử lại lần $id_retry..."
    sleep 2
done
if [ $id_retry -gt $MAX_ID_RETRY ]; then
    echo "Không thể lấy RustDesk ID."
    exit 1
fi

# === Hoàn tất ===
echo "=== [7/7] Hoàn tất. Hỏi reboot ==="
read -p "Bạn có muốn reboot ngay để áp dụng (y/n)? " yn
if [[ "$yn" =~ ^[Yy]$ ]]; then
    reboot
else
    echo "Bạn có thể reboot sau bằng: sudo reboot"
fi

echo "=== Cài đặt hoàn tất! ==="
