#!/usr/bin/env bash
# =====================================================================
# TigerAI Automated Backup (P1 Tier)
# Path: deployments/08-backup-recovery/backup-tigerai.sh
# =====================================================================

set -eo pipefail

# --- 0) Configuration ---
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

BACKUP_ROOT=${BACKUP_ROOT:-"/opt/tigerai/backups"}
RETENTION_DAYS=${RETENTION_DAYS:-7}
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="${BACKUP_ROOT}/${DATE}"

LOG_PREFIX="TigerAI Backup"
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'
LOG(){ echo -e "${GREEN}[$LOG_PREFIX INFO]${NC} $*"; }
ERROR(){ echo -e "${RED}[$LOG_PREFIX ERROR]${NC} $*"; exit 1; }

# Create backup directory
mkdir -p "$BACKUP_PATH"

# --- 1) PostgreSQL Backup ---
backup_db() {
    LOG " [1/4] Dumping PostgreSQL Database..."
    if docker ps | grep -q "$PG_CONTAINER"; then
        docker exec "$PG_CONTAINER" pg_dump -U "$PG_USER" "$PG_DB" | gzip > "${BACKUP_PATH}/database.sql.gz"
        LOG " Database dump completed."
    else
        LOG " PostgreSQL container not running, skipping DB backup."
    fi
}

# --- 2) Node-RED (Native) Backup ---
backup_nodered() {
    LOG " [2/4] Backing up Node-RED Configurations..."
    if [ -d "$NODERED_DATA" ]; then
        sudo tar -czf "${BACKUP_PATH}/nodered_config.tar.gz" -C "$NODERED_DATA" . --exclude="node_modules"
        LOG " Node-RED backup completed (excluded node_modules)."
    else
        LOG " Node-RED data directory not found."
    fi
}

# --- 3) Critical Data Directories ---
backup_data_dirs() {
    LOG " [3/4] Backing up Application Data Directories..."
    for dir in $DATA_DIRS; do
        if [ -d "$dir" ]; then
            name=$(basename "$dir")
            LOG "Packaging $dir..."
            sudo tar -czf "${BACKUP_PATH}/data_${name}.tar.gz" -C "$dir" .
        else
            LOG " Directory $dir not found, skipping."
        fi
    done
    LOG " Data directory backup completed."
}

# --- 4) Retention Policy ---
cleanup_old_backups() {
    LOG " [4/4] Applying Retention Policy (Keeping last $RETENTION_DAYS days)..."
    find "$BACKUP_ROOT" -maxdepth 1 -type d -mtime +"$RETENTION_DAYS" -exec rm -rf {} +
    LOG " Cleanup finished."
}

# --- Main Logic ---
[ "$(id -u)" -ne 0 ] && ERROR "Please run with sudo."

LOG " Starting Full System Backup to ${BACKUP_PATH}..."
backup_db
backup_nodered
backup_data_dirs
cleanup_old_backups

LOG " Backup Process Finished Successfully."
LOG "Backup Location: ${BACKUP_PATH}"
