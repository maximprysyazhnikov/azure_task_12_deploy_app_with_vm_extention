#!/usr/bin/env bash
set -euxo pipefail

echo "[install-app] Start install script"

# 1. Оновлюємо пакети
sudo apt-get update -y

# 2. Ставимо базові утиліти та Python + venv
#    ВАЖЛИВО: БЕЗ python3-venv і python3-pip з apt
sudo apt-get install -y \
  git \
  nginx \
  python3 \
  python3.10-venv

# 3. Встановлюємо pip, якщо його немає
if ! command -v pip3 >/dev/null 2>&1; then
  echo "[install-app] Installing pip via get-pip.py"
  curl -sS https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py
  sudo python3 /tmp/get-pip.py
fi

# 4. Клонуємо твій форк репозиторію в /opt/todo-app
APP_DIR="/opt/todo-app"

sudo rm -rf "${APP_DIR}"
sudo git clone "https://github.com/maximprysyazhnikov/azure_task_12_deploy_app_with_vm_extention.git" "${APP_DIR}"

cd "${APP_DIR}/app"

# 5. Створюємо та активуємо віртуальне середовище
python3 -m venv venv
# shellcheck disable=SC1091
source venv/bin/activate

# 6. Встановлюємо залежності застосунку
pip3 install --upgrade pip
pip3 install -r requirements.txt

# 7. Створюємо systemd-сервіс для запуску апки на 0.0.0.0:8080
#    ⚠️ Якщо у тебе інша точка входу, підправимо пізніше.
SERVICE_FILE="/etc/systemd/system/todo-app.service"

sudo bash -c "cat > ${SERVICE_FILE}" << 'EOF'
[Unit]
Description=Todo Web App
After=network.target

[Service]
User=www-data
WorkingDirectory=/opt/todo-app/app
Environment=\"PATH=/opt/todo-app/app/venv/bin\"
ExecStart=/opt/todo-app/app/venv/bin/python app.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# 8. Перезапускаємо systemd і вмикаємо сервіс
sudo systemctl daemon-reload
sudo systemctl enable todo-app.service
sudo systemctl restart todo-app.service

# 9. Налаштовуємо nginx як простий reverse-proxy на 8080
NGINX_CONF="/etc/nginx/sites-available/todo-app.conf"

sudo bash -c "cat > ${NGINX_CONF}" << 'EOF'
server {
    listen 8080 default_server;
    listen [::]:8080 default_server;

    server_name _;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

# Вимикаємо дефолтний сайт і вмикаємо наш
sudo rm -f /etc/nginx/sites-enabled/default || true
sudo ln -sf "${NGINX_CONF}" /etc/nginx/sites-enabled/todo-app.conf
sudo systemctl restart nginx

echo "[install-app] Finished successfully"
