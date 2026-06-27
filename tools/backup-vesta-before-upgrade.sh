#!/bin/bash
set -euo pipefail
DRY_RUN=0
DEST="/root/vesta-upgrade-backup-$(date +%Y%m%d-%H%M%S)"
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --dest) shift; DEST="$1" ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done
run(){ if [ "$DRY_RUN" -eq 1 ]; then echo "DRY-RUN: $*"; else "$@"; fi; }
[ "$(id -u)" -eq 0 ] || { echo "Run as root to read all Vesta data" >&2; exit 1; }
echo "Backup destination: $DEST"
run mkdir -p "$DEST"
for path in /usr/local/vesta /home /etc/nginx /etc/apache2 /etc/exim4 /etc/dovecot /etc/bind /etc/mysql /var/mail /var/lib/mysql /var/lib/vesta; do
  [ -e "$path" ] && run tar -C / -czf "$DEST/$(echo "$path" | tr / _ | sed 's/^_//').tar.gz" "${path#/}"
done
if command -v mysqldump >/dev/null 2>&1; then
  run sh -c "mysqldump --all-databases --single-transaction --routines --events > '$DEST/all-databases.sql'"
else
  echo "WARN: mysqldump not found; database logical backup skipped"
fi
echo "Backup script finished. Verify archives before continuing."
