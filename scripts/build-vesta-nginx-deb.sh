#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'USAGE'
Usage: build-vesta-nginx-deb.sh --output DIR [options]

Build the bundled vesta-nginx Debian package.

Options:
  --output DIR           Directory where the .deb file will be written
  --version VERSION      Override the package version
  --nginx-version VER    Nginx source version to build (default: 1.24.0)
  --source-url URL       Source tarball URL
  -h, --help             Show this help
USAGE
}

output_dir=""
version_override="${VESTA_NGINX_DEB_VERSION:-}"
nginx_version="${VESTA_NGINX_VERSION:-1.24.0}"
source_url=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output) output_dir="$2"; shift 2 ;;
        --version) version_override="$2"; shift 2 ;;
        --nginx-version) nginx_version="$2"; shift 2 ;;
        --source-url) source_url="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
done

if [[ -z "$output_dir" ]]; then
    usage >&2
    exit 2
fi

for command in curl dpkg-deb make tar; do
    if ! command -v "$command" >/dev/null 2>&1; then
        echo "$command is required." >&2
        exit 1
    fi
done

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
control_file="$repo_root/src/deb/nginx/control"
package="$(awk -F': ' '$1 == "Package" { print $2; exit }' "$control_file")"
version="${version_override:-$(awk -F': ' '$1 == "Version" { print $2; exit }' "$control_file")}"
architecture="$(awk -F': ' '$1 == "Architecture" { print $2; exit }' "$control_file")"
source_url="${source_url:-https://nginx.org/download/nginx-${nginx_version}.tar.gz}"

if [[ -z "$package" || -z "$version" || -z "$architecture" ]]; then
    echo "Cannot read Package, Version, or Architecture from $control_file" >&2
    exit 1
fi

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

source_dir="$work_dir/source"
pkg_root="$work_dir/${package}_${version}_${architecture}"
install -d "$source_dir" "$pkg_root/DEBIAN" "$output_dir"

curl -fsSL "$source_url" -o "$work_dir/nginx.tar.gz"
tar -xzf "$work_dir/nginx.tar.gz" -C "$source_dir" --strip-components=1

make_jobs="${MAKE_JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)}"
(
    cd "$source_dir"
    ./configure --prefix=/usr/local/vesta/nginx --with-http_ssl_module
    make -j "$make_jobs"
    make install DESTDIR="$pkg_root"
)

awk -v version="$version" '
    /^Version:/ { print "Version: " version; next }
    { print }
' "$control_file" > "$pkg_root/DEBIAN/control"
cp "$repo_root/src/deb/nginx/conffiles" "$pkg_root/DEBIAN/conffiles"
install -D -m 0755 "$repo_root/src/deb/nginx/postinst" "$pkg_root/DEBIAN/postinst"
install -D -m 0755 "$repo_root/src/deb/nginx/postrm" "$pkg_root/DEBIAN/postrm"
install -D -m 0755 "$repo_root/src/deb/nginx/vesta" "$pkg_root/etc/init.d/vesta"
install -D -m 0755 "$repo_root/src/rpm/conf/nginx.conf" "$pkg_root/usr/local/vesta/nginx/conf/nginx.conf"
install -D -m 0755 "$pkg_root/usr/local/vesta/nginx/sbin/nginx" "$pkg_root/usr/local/vesta/nginx/sbin/vesta-nginx"

find "$pkg_root" -name '.DS_Store' -delete
dpkg_deb_options=()
if dpkg-deb --help 2>&1 | grep -q -- '--root-owner-group'; then
    dpkg_deb_options+=(--root-owner-group)
fi
dpkg-deb "${dpkg_deb_options[@]}" --build "$pkg_root" "$output_dir/${package}_${version}_${architecture}.deb"
