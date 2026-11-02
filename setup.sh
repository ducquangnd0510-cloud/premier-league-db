#!/bin/bash
# Chạy bằng: sudo bash setup.sh   (đặt file cùng chỗ với thư mục ngoai-hang-anh trong /home/ubuntu)
set -e
export DEBIAN_FRONTEND=noninteractive
PASS='Webpass123'
DBN=QuanLyNgoaiHangAnh
SRC=/home/ubuntu/ngoai-hang-anh
DST=/var/www/html/ngoai-hang-anh

if [ ! -f "$SRC/api.php" ]; then echo "Khong thay $SRC/api.php - hay scp thu muc ngoai-hang-anh len truoc"; exit 1; fi

# 1. Go nginx
systemctl stop nginx 2>/dev/null || true
apt purge -y 'nginx*' || true
apt autoremove -y
rm -rf /etc/nginx

# 2. Cai Apache + PHP + MySQL
apt update
apt install -y apache2 libapache2-mod-php php-mysql mysql-server
systemctl enable --now apache2 mysql

# 3. Chep web
rm -rf "$DST"
cp -r "$SRC" "$DST"

# 4. CSDL (schema.sql tu tao DB) + du lieu mau + user rieng (chi co quyen doc)
mysql -e "DROP DATABASE IF EXISTS $DBN; DROP USER IF EXISTS 'webuser'@'localhost';"
mysql < "$DST/schema.sql"
mysql --default-character-set=utf8mb4 < "$DST/sample_data_v2.sql"
mysql --default-character-set=utf8mb4 < "$DST/triggers.sql"
mysql --default-character-set=utf8mb4 < "$DST/ai_model.sql"
mysql -e "CREATE USER 'webuser'@'localhost' IDENTIFIED BY '$PASS'; GRANT SELECT ON $DBN.* TO 'webuser'@'localhost'; FLUSH PRIVILEGES;"

# 5. Doi tai khoan trong api.php, xoa file .sql khoi thu muc web
sed -i "s/'user' => 'root', 'pass' => ''/'user' => 'webuser', 'pass' => '$PASS'/" "$DST/api.php"
rm -f "$DST"/*.sql "$DST"/*.bak "$DST"/*.pl
chown -R www-data:www-data "$DST"

# 6. Khoi dong lai
ufw allow 80/tcp 2>/dev/null || true
systemctl restart apache2

echo
echo "XONG. Mo trang: http://$(hostname -I | awk '{print $1}')/ngoai-hang-anh/"
