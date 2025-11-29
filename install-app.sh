#!/usr/bin/env bash
set -euo pipefail

# === Налаштування ===
REPO_URL="https://github.com/maximprysyazhnikov/azure_task_12_deploy_app_with_vm_extention.git"
APP_ROOT="/opt/todo-app"
APP_DIR="$APP_ROOT/app"
SERVICE_NAME="todo-app"

echo "[install-app] Start install script"

# 1. Оновлюємо пакети і ставимо залежності
sudo apt-get update -y
sudo apt-get install -y python3 python3-venv python3-pip git

# 2. Готуємо директорію для застосунку
sudo mkdir -p "$APP_ROOT"
sudo chown "$USER":"$USER" "$APP_ROOT"

# 3. Клонуємо/оновлюємо репозиторій
if [ -d "$APP_ROOT/.git" ]; then
  echo "[install-app] Repo already exists, pulling latest changes..."
  cd "$APP_ROOT"
  git pull origin main || true
else
  echo "[install-app] Cloning repo..."
  git clone "$REPO_URL" "$APP_ROOT"
fi

# 4. Інсталюємо Python-залежності
cd "$APP_DIR"

python3 -m venv venv
source venv/bin/activate

pip install --upgrade pip
if [ -f "requirements.txt" ]; then
  pip install -r requirements.txt
fi

# 5. Створюємо systemd сервіс, щоб апка стартувала автоматично
#    Припускаємо, що точка входу - app.py, який слухає порт 8080
sudo tee /etc/systemd/system/${SERVICE_NAME}.service > /dev/null << EOF
[Unit]
Description=Todo web app
After=network.target

[Service]
User=$USER
WorkingDirectory=$APP_DIR
Environment="PATH=$APP_DIR/venv/bin"
ExecStart=$APP_DIR/venv/bin/python app.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# 6. Вмикаємо сервіс
sudo systemctl daemon-reload
sudo systemctl enable ${SERVICE_NAME}
sudo systemctl restart ${SERVICE_NAME}

echo "[install-app] Finished successfully"
