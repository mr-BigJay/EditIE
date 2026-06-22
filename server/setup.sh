#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo bash setup.sh"
  exit 1
fi

INSTALL_DIR="/opt/editie-telemetry"
LOG_DIR="/var/log/editie"
SERVICE_USER="editie"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Installing packages"
apt-get update
apt-get install -y python3 python3-venv python3-pip

echo "==> Creating service user"
id -u "${SERVICE_USER}" &>/dev/null || useradd --system --no-create-home --shell /usr/sbin/nologin "${SERVICE_USER}"

echo "==> Deploying application"
mkdir -p "${INSTALL_DIR}"
cp "${SCRIPT_DIR}/app.py" "${SCRIPT_DIR}/requirements.txt" "${INSTALL_DIR}/"

if [[ ! -d "${INSTALL_DIR}/venv" ]]; then
  python3 -m venv "${INSTALL_DIR}/venv"
fi

"${INSTALL_DIR}/venv/bin/pip" install --upgrade pip
"${INSTALL_DIR}/venv/bin/pip" install -r "${INSTALL_DIR}/requirements.txt"

echo "==> Preparing log directory"
mkdir -p "${LOG_DIR}"
chown -R "${SERVICE_USER}:${SERVICE_USER}" "${LOG_DIR}"
chown -R "${SERVICE_USER}:${SERVICE_USER}" "${INSTALL_DIR}"

echo "==> Installing systemd service"
cp "${SCRIPT_DIR}/editie-telemetry.service" /etc/systemd/system/editie-telemetry.service
systemctl daemon-reload
systemctl enable editie-telemetry
systemctl restart editie-telemetry

if command -v ufw >/dev/null 2>&1; then
  echo "==> Opening firewall port 8080"
  ufw allow 8080/tcp || true
fi

echo
echo "Setup complete."
echo "Health check: curl http://127.0.0.1:8080/health"
echo "Install endpoint: http://$(hostname -I | awk '{print $1}'):8080/api/install"
echo "Logs: ${LOG_DIR}/installs.jsonl"
echo "View logs: tail -f ${LOG_DIR}/installs.jsonl"
