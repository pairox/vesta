#!/bin/bash
set -euo pipefail
DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1
run(){ if [ "$DRY_RUN" -eq 1 ]; then echo "DRY-RUN: $*"; else "$@"; fi; }
[ "$(id -u)" -eq 0 ] || { echo "Run as root for repair actions" >&2; exit 1; }
echo "Post-upgrade repair (dry-run=$DRY_RUN)"
run apt-get update
run apt-get -y install ca-certificates curl openssl sudo cron iptables iptables-persistent || true
for svc in vesta nginx apache2 exim4 dovecot bind9 cron fail2ban mariadb mysql; do
  if systemctl list-unit-files "$svc.service" >/dev/null 2>&1; then
    run systemctl enable "$svc" || true
    run systemctl restart "$svc" || true
  fi
done
[ -x /usr/local/vesta/bin/v-update-sys-ip ] && run /usr/local/vesta/bin/v-update-sys-ip
[ -x /usr/local/vesta/bin/v-update-firewall ] && run /usr/local/vesta/bin/v-update-firewall
echo "Repair finished; inspect failed services with: systemctl --failed"
