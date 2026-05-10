#!/usr/bin/env bash
set -eo pipefail
if [ -f .env ]; then export $(grep -v '^#' .env | sed 's/\r//g' | xargs); fi

usage() {
    echo "Usage: sudo $0 [backup_date] {all|db|nodered}"
    exit 1
}

[ $# -lt 2 ] && usage

case "$2" in
    all) echo "Restoring all..." ;;
    db) echo "Restoring DB..." ;;
    nodered) echo "Restoring Node-RED..." ;;
    *) usage ;;
esac