#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="/var/log/install-todo-app.log"

log() {
  echo "[install-app] $1" | tee -a "$LOG_FILE"
}

log "Start install script"

export DEBIAN_FRONTEND=noninteractive

log "Updating package index..."
apt-get update -y

log "Installing required packages (git, python3, curl)..."
apt-get install -y git python3 curl

APP_DIR="/opt/azure-todo-app"
REPO_URL="https://github.com/maximprysyazhnikov/azure_task_12_deploy_app_with_vm_extention.git"

log "Preparing app directory ${APP_DIR}..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR"

log "Cloning repository ${REPO_URL}..."
git clone "$REPO_URL" "$APP_DIR"

cd "$APP_DIR/app"

# Install pip if missing
if ! command -v pip3 >/dev/null 2>&1; then
  log "pip3 not found, installing via get-pip.py..."
  curl -sS https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py
  python3 /tmp/get-pip.py
fi

log "Installing Python dependencies from requirements.txt..."
pip3 install --no-cache-dir -r requirements.txt

log "Applying Django migrations..."
python3 manage.py migrate --noinput

log "Stopping any process on port 8080 (if any)..."
if command -v fuser >/dev/null 2>&1; then
  fuser -k 8080/tcp || true
fi

log "Starting Django todo app on port 8080..."
nohup python3 manage.py runserver 0.0.0.0:8080 >> "$LOG_FILE" 2>&1 &

log "Install script finished successfully"
