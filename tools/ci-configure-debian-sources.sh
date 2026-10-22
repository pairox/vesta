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
  11)
    cat >/etc/apt/sources.list <<'SOURCES'
deb http://archive.debian.org/debian bullseye main contrib non-free
deb http://archive.debian.org/debian-security bullseye-security main contrib non-free
deb http://archive.debian.org/debian bullseye-updates main contrib non-free
SOURCES
    ;;
  *)
    exit 0
    ;;
esac

# Archived CI images must not retain the default deb822 live-mirror sources.
rm -f /etc/apt/sources.list.d/debian.sources

cat >/etc/apt/apt.conf.d/99archive-valid-until <<'APTCONF'
Acquire::Check-Valid-Until "false";
APTCONF
