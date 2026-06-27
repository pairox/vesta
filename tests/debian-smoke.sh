#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
. "$root/install/debian-common.sh"
for rel in 9 10 11 12; do
  code=$(vesta_debian_codename "$rel")
  pkgs=$(vesta_debian_package_list "$rel")
  repos=$(vesta_debian_repo_lines "$rel")
  [ -n "$code" ] && [ -n "$pkgs" ] && [ -n "$repos" ]
  case "$rel:$code" in 9:stretch|10:buster|11:bullseye|12:bookworm) ;; *) exit 1;; esac
  VESTA_CI=1 VESTA_DEBIAN_RELEASE="$rel" bash "$root/install/vst-install-debian.sh" --interactive no --apache no --nginx no --mysql no --exim no --dovecot no --clamav no --spamassassin no --iptables no --fail2ban no --softaculous no >/tmp/vesta-dry-$rel.log
  grep -q "release=$rel" /tmp/vesta-dry-$rel.log
  grep -q "$code" /tmp/vesta-dry-$rel.log
  echo "OK debian:$rel $code"
done
