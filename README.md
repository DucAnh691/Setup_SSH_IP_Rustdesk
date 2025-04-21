# Setup_SSH_IP_Rustdesk

## Hướng dẫn triển khai:
Chuẩn bị ip_list.txt:

Tạo file ip_list.txt chứa IP của tất cả 50 máy Ubuntu.

## Chuẩn bị key SSH:

Đảm bảo bạn đã có SSH public key cài trên các máy trạm và private key trên máy điều khiển.

## Sao chép các file lên máy điều khiển:

Đặt install-rustdesk.sh, deploy.sh, và ip_list.txt vào cùng một thư mục trên máy điều khiển.

## Chạy deploy.sh:

Đảm bảo file deploy.sh có quyền thực thi:

chmod +x deploy.sh
./deploy.sh

## Script này sẽ tự động sao chép file install-rustdesk.sh và id_rustdesk lên các máy trạm qua SSH, sau đó chạy script cài đặt RustDesk.

