#!/bin/bash
set -e

USERNAME="workstation"
USERPASS="etonit@q7"
RUSTDESK_PASS="etonit_rustdesk@q7"

echo "=== 🚀 BẮT ĐẦU CÀI ĐẶT RUSTDESK VỚI MÔI TRƯỜNG GIAO DIỆN XFCE ==="

echo "[1/9] ➤ Cập nhật hệ thống và cài gói cơ bản..."
apt update && apt upgrade -y
apt install -y sudo wget curl unzip xfce4 xfce4-goodies xrdp

echo "[2/9] ➤ Tạo user mới: $USERNAME ..."
id -u "$USERNAME" &>/dev/null || adduser --disabled-password --gecos "" "$USERNAME"
echo "$USERNAME:$USERPASS" | chpasswd
usermod -aG sudo "$USERNAME"

echo "[3/9] ➤ Cấu hình XFCE cho user..."
echo "xfce4-session" > /home/$USERNAME/.xsession
chown $USERNAME:$USERNAME /home/$USERNAME/.xsession
systemctl enable xrdp

echo "[4/9] ➤ Vô hiệu hóa Wayland nếu có (GDM - Ubuntu GNOME)..."
if [ -f /etc/gdm3/custom.conf ]; then
    echo "  ➤ Tắt Wayland trong GDM..."
    sed -i 's/^#WaylandEnable=false/WaylandEnable=false/' /etc/gdm3/custom.conf
    sed -i '/^\[daemon\]/a DefaultSession=gnome-xorg.desktop' /etc/gdm3/custom.conf
fi

echo "[5/9] ➤ Tải và cài RustDesk..."
ARCH=$(dpkg --print-architecture)
VERSION="1.3.9"  # thay phiên bản mới hơn nếu cần
wget "https://github.com/rustdesk/rustdesk/releases/download/${VERSION}/rustdesk-${VERSION}-ubuntu-${ARCH}.deb" -O /tmp/rustdesk.deb
dpkg -i /tmp/rustdesk.deb || apt install -f -y
rm /tmp/rustdesk.deb

echo "[6/9] ➤ Cấu hình truy cập không giám sát..."
mkdir -p /etc/rustdesk
cat <<EOF > /etc/rustdesk/RustDesk.toml
[unattended]
enabled = true
password = "$RUSTDESK_PASS"
EOF

echo "[7/9] ➤ Cho phép user chạy RustDesk ở chế độ GUI..."
mkdir -p /home/$USERNAME/.config/autostart
cat <<EOF > /home/$USERNAME/.config/autostart/rustdesk.desktop
[Desktop Entry]
Type=Application
Exec=rustdesk
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=RustDesk
EOF
chown -R $USERNAME:$USERNAME /home/$USERNAME/.config

echo "[8/9] ➤ Thiết lập tự động đăng nhập nếu cần..."
mkdir -p /etc/lightdm
cat <<EOF > /etc/lightdm/lightdm.conf
[Seat:*]
autologin-user=$USERNAME
autologin-user-timeout=0
user-session=xfce
EOF

echo "[9/9] ✅ Hoàn tất cài đặt RustDesk với mật khẩu vĩnh viễn!"
sleep 5
ID_OUTPUT=$(sudo -u "$USERNAME" DISPLAY=:0 rustdesk --get-id 2>/dev/null || echo "⚠️ Chưa lấy được ID, khởi động lại máy rồi thử lại.")

echo "====================================="
echo "User đăng nhập: $USERNAME"
echo "Mật khẩu hệ thống: $USERPASS"
echo "Mật khẩu RustDesk: $RUSTDESK_PASS"
echo "RustDesk ID: $ID_OUTPUT"
echo "====================================="

read -p "Bạn có muốn reboot ngay không? (y/n): " yn
if [[ "$yn" =~ ^[Yy]$ ]]; then
    reboot
else
    echo "👉 Bạn có thể reboot sau bằng: sudo reboot"
fi
