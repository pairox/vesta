#!/bin/bash
set -u
DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1
fail=0
say(){ printf '%s\n' "$*"; }
check(){ if "$@" >/dev/null 2>&1; then say "OK: $*"; else say "WARN: $*"; fail=1; fi; }
[ "$(id -u)" -eq 0 ] || say "WARN: run as root for complete checks"
say "Preflight for Debian/Vesta upgrade (dry-run=$DRY_RUN)"
[ -r /etc/debian_version ] && say "Debian: $(cat /etc/debian_version)"
if [ -r /etc/os-release ]; then
    # shellcheck source=/dev/null
    . /etc/os-release
    say "Codename: ${VERSION_CODENAME:-unknown}"
fi
check command -v apt-get
check command -v dpkg
check test -d /usr/local/vesta
check test -d /home
check test -d /etc
check df -h /
check apt-get -s upgrade
say "No destructive action was performed. Resolve WARN items before upgrade."
exit "$fail"
