#!/bin/bash
set -euo pipefail

version="${VESTA_DEB_VERSION:-1.0.0-10}"
out_dir="${1:-dist/deb}"
work_dir="${BUILD_DIR:-dist/build-deb}"
script_dir="$(cd "$(dirname "$0")" && pwd)"
project_root="$(cd "$script_dir/.." && pwd)"

require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Error: $1 is required" >&2
        exit 1
    fi
}

copy_debian_control() {
    local package="$1"
    local control_dir="$2"
    mkdir -p "$control_dir"
    cp "$project_root/src/deb/$package/"* "$control_dir/" 2>/dev/null || true
    if [ -f "$control_dir/control" ]; then
        sed -i "s/^Version:.*/Version: $version/" "$control_dir/control"
    fi
    find "$control_dir" -type f \( -name postinst -o -name postrm -o -name prerm \) \
        -exec chmod 755 {} \;
}

build_package() {
    local build_name="$1"
    local deb_name="${2:-$build_name}"
    local root="$work_dir/$build_name"
    dpkg-deb --build "$root" "$out_dir/${deb_name}_${version}_amd64.deb"
}

require_cmd dpkg-deb
require_cmd rsync
require_cmd gcc

rm -rf "$work_dir"
mkdir -p "$work_dir" "$out_dir"

# vesta core package
vesta_root="$work_dir/vesta"
mkdir -p "$vesta_root/DEBIAN" "$vesta_root/usr/local/vesta"
copy_debian_control vesta "$vesta_root/DEBIAN"
rsync -a --delete \
    --exclude '.git' \
    --exclude 'dist' \
    --exclude 'src/react/node_modules' \
    "$project_root/bin" \
    "$project_root/func" \
    "$project_root/install" \
    "$project_root/upd" \
    "$project_root/web" \
    "$vesta_root/usr/local/vesta/"

gcc "$project_root/src/v-check-user-password.c" \
    -o "$vesta_root/usr/local/vesta/bin/v-check-user-password" -lcrypt
chmod 755 "$vesta_root/usr/local/vesta/bin/"*
build_package vesta

copy_tree_package() {
    local build_name="$1"
    local deb_name="$2"
    local source_dir="$3"
    local target_dir="$4"
    local root="$work_dir/$build_name"

    if [ -z "$source_dir" ] || [ ! -d "$source_dir" ]; then
        case "$deb_name" in
            vesta-ioncube|vesta-softaculous)
                echo "Build empty $deb_name stub: source directory does not exist" >&2
                mkdir -p "$root/DEBIAN" "$root/$target_dir"
                copy_debian_control "$build_name" "$root/DEBIAN"
                build_package "$build_name" "$deb_name"
                return
                ;;
            *)
                echo "Skip $deb_name: source directory is not set or does not exist" >&2
                return
                ;;
        esac
    fi

    mkdir -p "$root/DEBIAN" "$root/$target_dir"
    copy_debian_control "$build_name" "$root/DEBIAN"
    rsync -a "$source_dir"/ "$root/$target_dir"/
    if [ "$deb_name" = "vesta-nginx" ]; then
        install -D -m 755 "$project_root/src/deb/nginx/vesta" "$root/etc/init.d/vesta"
    fi
    build_package "$build_name" "$deb_name"
}

copy_tree_package nginx vesta-nginx "${VESTA_NGINX_DIR:-/usr/local/vesta/nginx}" usr/local/vesta/nginx
copy_tree_package php vesta-php "${VESTA_PHP_DIR:-/usr/local/vesta/php}" usr/local/vesta/php
copy_tree_package ioncube vesta-ioncube "${VESTA_IONCUBE_DIR:-/usr/local/vesta/ioncube}" usr/local/vesta/ioncube
copy_tree_package softaculous vesta-softaculous "${VESTA_SOFTACULOUS_DIR:-/usr/local/vesta/softaculous}" usr/local/vesta/softaculous

echo "Packages are in $out_dir"
