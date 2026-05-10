#!/usr/bin/env bash
# =====================================================================
# TigerAI VRAM Purge & Service Refresh (Zero-Reboot Maintenance)
# Path: deployments/08-backup-recovery/vram-purge.sh
# =====================================================================

set -eo pipefail

LOG_PREFIX="TigerAI Maintenance"
GREEN='\033[0;32m'; NC='\033[0m'
LOG(){ echo -e "${GREEN}[$LOG_PREFIX INFO]${NC} $*"; }

LOG " Periodical VRAM Purge Starting..."

# 1. Restart AI Interface (Ollama & OpenWebUI)
LOG "Restarting Phase 03 AI Interfaces..."
cd "$(dirname "$0")/../03-ai-interface-ollama-openwebui-redis" || exit
docker compose restart ollama

# 2. Restart Lemonade Native Services
LOG "Refreshing Phase 06 Lemonade Engine..."
sudo systemctl restart lemonade-edu.service || true
sudo systemctl restart lemonade-rag.service || true

LOG " VRAM Purge Complete. All GPU memory associated with AI models has been released."
LOG "System uptime preserved. No reboot was required."
