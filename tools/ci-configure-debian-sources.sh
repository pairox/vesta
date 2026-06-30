#!/bin/bash
set -euo pipefail

release="${1:-}"

case "$release" in
  9)
    cat >/etc/apt/sources.list <<'SOURCES'
deb http://archive.debian.org/debian stretch main contrib non-free
deb http://archive.debian.org/debian-security stretch/updates main contrib non-free
SOURCES
    ;;
  10)
    cat >/etc/apt/sources.list <<'SOURCES'
deb http://archive.debian.org/debian buster main contrib non-free
deb http://archive.debian.org/debian-security buster/updates main contrib non-free
deb http://archive.debian.org/debian buster-updates main contrib non-free
SOURCES
    ;;
  *)
    exit 0
    ;;
esac

cat >/etc/apt/apt.conf.d/99archive-valid-until <<'APTCONF'
Acquire::Check-Valid-Until "false";
APTCONF
