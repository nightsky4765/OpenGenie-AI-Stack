#!/usr/bin/env bash
# =====================================================================
# TigerAI Maintenance Cron Installer
# Path: deployments/08-backup-recovery/setup-cron.sh
# =====================================================================

set -eo pipefail

LOG_PREFIX="TigerAI Cron"
GREEN='\033[0;32m'; NC='\033[0m'
LOG(){ echo -e "${GREEN}[$LOG_PREFIX INFO]${NC} $*"; }

# 
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PURGE_SCRIPT="$SCRIPT_DIR/vram-purge.sh"

if [ ! -f "$PURGE_SCRIPT" ]; then
    echo ":  $PURGE_SCRIPT"
    exit 1
fi

chmod +x "$PURGE_SCRIPT"

#  Cron Job ( 5:00)
CRON_JOB="0 5 * * * /bin/bash $PURGE_SCRIPT >> $SCRIPT_DIR/maintenance.log 2>&1"

# 
if crontab -l 2>/dev/null | grep -q "$PURGE_SCRIPT"; then
    LOG "Cron job skipping"
else
    LOG " 5:00 AM VRAM ..."
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
    LOG " "
fi

LOG " crontab :"
crontab -l | grep "vram-purge"
