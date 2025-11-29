#!/usr/bin/env bash
set -euxo pipefail

echo "[install-app] Start install script"

APP_ROOT="/opt/todo-app"
APP_REPO="https://github.com/maximprysyazhnikov/azure_task_12_deploy_app_with_vm_extention.git"
APP_DIR="${APP_ROOT}/app"

# 1. Оновлюємо пакети і ставимо базові утиліти
sudo apt-get update -y
sudo apt-get install -y python3 git curl

# 2. Ставимо pip через офіційний bootstrap, БЕЗ apt-get install python3-pip
if ! command -v pip3 >/dev/null 2>&1; then
  echo "[install-app] Installing pip via get-pip.py"
  curl -sS https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py
  sudo python3 /tmp/get-pip.py
fi

# 3. Клонуємо (або перевстановлюємо) репозиторій
sudo rm -rf "${APP_ROOT}"
sudo mkdir -p "${APP_ROOT}"
sudo chown "$USER":"$USER" "${APP_ROOT}"

git clone "${APP_REPO}" "${APP_ROOT}"

cd "${APP_DIR}"

# 4. Встановлюємо залежності застосунку
if [ -f "requirements.txt" ]; then
  pip3 install --upgrade pip
  pip3 install -r requirements.txt
fi

# 5. Створюємо systemd-сервіс, який запускає app.py напряму через python3
sudo tee /etc/systemd/system/todo-app.service > /dev/null << 'EOF'
[Unit]
Description=Todo web app
After=network.target

[Service]
User=azureuser
WorkingDirectory=/opt/todo-app/app
ExecStart=/usr/bin/python3 app.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# 6. Вмикаємо сервіс
sudo systemctl daemon-reload
sudo systemctl enable todo-app.service
sudo systemctl restart todo-app.service

echo "[install-app] Finished successfully"
