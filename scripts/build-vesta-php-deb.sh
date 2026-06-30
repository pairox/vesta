#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'USAGE'
Usage: build-vesta-php-deb.sh --output DIR [options]

Build the bundled vesta-php Debian package.

Options:
  --output DIR           Directory where the .deb file will be written
  --version VERSION      Override the package version
  --php-version VER      PHP source version to build (default: 5.6.40)
  --source-url URL       Source tarball URL
  -h, --help             Show this help
USAGE
}

output_dir=""
version_override="${VESTA_PHP_DEB_VERSION:-}"
php_version="${VESTA_PHP_VERSION:-5.6.40}"
source_url=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output) output_dir="$2"; shift 2 ;;
        --version) version_override="$2"; shift 2 ;;
        --php-version) php_version="$2"; shift 2 ;;
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
control_file="$repo_root/src/deb/php/control"
package="$(awk -F': ' '$1 == "Package" { print $2; exit }' "$control_file")"
version="${version_override:-$(awk -F': ' '$1 == "Version" { print $2; exit }' "$control_file")}"
architecture="$(awk -F': ' '$1 == "Architecture" { print $2; exit }' "$control_file")"
source_url="${source_url:-https://www.php.net/distributions/php-${php_version}.tar.gz}"

if [[ -z "$package" || -z "$version" || -z "$architecture" ]]; then
    echo "Cannot read Package, Version, or Architecture from $control_file" >&2
    exit 1
fi

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

source_dir="$work_dir/source"
pkg_root="$work_dir/${package}_${version}_${architecture}"
install -d "$source_dir" "$pkg_root/DEBIAN" "$output_dir"

curl -fsSL "$source_url" -o "$work_dir/php.tar.gz"
tar -xzf "$work_dir/php.tar.gz" -C "$source_dir" --strip-components=1

make_jobs="${MAKE_JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)}"
(
    cd "$source_dir"
    ./configure \
        --prefix=/usr/local/vesta/php \
        --with-zlib \
        --enable-zip \
        --enable-fpm \
        --with-fpm-user=admin \
        --with-fpm-group=admin \
        --with-mysql=mysqlnd \
        --with-mysqli=mysqlnd \
        --with-curl \
        --enable-mbstring
    make -j "$make_jobs" ZEND_EXTRA_LIBS='-lresolv'
    make install INSTALL_ROOT="$pkg_root" INSTALLDIRS=vendor
)

awk -v version="$version" '
    /^Version:/ { print "Version: " version; next }
    { print }
' "$control_file" > "$pkg_root/DEBIAN/control"
install -D -m 0755 "$repo_root/src/deb/php/postinst" "$pkg_root/DEBIAN/postinst"
install -D -m 0755 "$repo_root/src/rpm/conf/php.ini" "$pkg_root/usr/local/vesta/php/lib/php.ini"
install -D -m 0755 "$repo_root/src/rpm/conf/php-fpm.conf" "$pkg_root/usr/local/vesta/php/etc/php-fpm.conf"
install -D -m 0755 "$pkg_root/usr/local/vesta/php/sbin/php-fpm" "$pkg_root/usr/local/vesta/php/sbin/vesta-php"

rm -rf \
    "$pkg_root/.channels" \
    "$pkg_root/.depdb" \
    "$pkg_root/.depdblock" \
    "$pkg_root/.filemap" \
    "$pkg_root/.lock"

find "$pkg_root" -name '.DS_Store' -delete
dpkg-deb --root-owner-group --build "$pkg_root" "$output_dir/${package}_${version}_${architecture}.deb"
