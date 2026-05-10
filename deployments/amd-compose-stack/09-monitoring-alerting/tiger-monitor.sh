#!/usr/bin/env bash
set -eo pipefail
cd "$(dirname "$0")"
if [ -f .env ]; then export $(grep -v '^#' .env | sed 's/\r//g' | xargs); fi
if [ -f ../tiger-tuning.env ]; then export $(grep -v '^#' ../tiger-tuning.env | sed 's/\r//g' | xargs); fi
for var in $(env | grep -E 'PORT|IMAGE|URL' | cut -d= -f1); do export "$var"="$(echo "${!var}" | tr -d '\r')"; done

LOG_PREFIX="TigerAI Monitor"
GREEN='\033[0;32m'; NC='\033[0m'
LOG(){ echo -e "${GREEN}[$LOG_PREFIX INFO]${NC} $*"; }

check_and_notify() {
    local report="Health Check:\n"
    # Logic for health check...
}

case "$1" in
    once) check_and_notify ;;
    start)
        LOG "Starting loop..."
        while true; do check_and_notify; sleep 60; done
        ;;
    install)
        LOG "Installing systemd service..."
        sudo tee /etc/systemd/system/tiger-monitor.service > /dev/null <<EOF
[Unit]
Description=TigerAI Monitor
[Service]
Type=simple
WorkingDirectory=$(pwd)
ExecStart=$(pwd)/tiger-monitor.sh start
Restart=always
[Install]
WantedBy=multi-user.target
EOF
        sudo systemctl daemon-reload && sudo systemctl enable --now tiger-monitor.service
        ;;
    *) echo "Usage: $0 {once|start|install}" ;;
esac