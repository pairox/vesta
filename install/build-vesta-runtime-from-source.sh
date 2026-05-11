#!/bin/bash
set -euo pipefail

nginx_version="${NGINX_VERSION:-1.24.0}"
php_version="${PHP_VERSION:-5.6.40}"
script_dir="$(cd "$(dirname "$0")" && pwd)"
project_root="$(cd "$script_dir/.." && pwd)"
out_dir="${1:-dist/deb}"
build_root="${BUILD_ROOT:-dist/source-build}"
jobs="${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)}"

case "$out_dir" in
    /*) ;;
    *) out_dir="$project_root/$out_dir" ;;
esac

case "$build_root" in
    /*) ;;
    *) build_root="$project_root/$build_root" ;;
esac

require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Error: $1 is required" >&2
        exit 1
    fi
}

fetch() {
    local url="$1"
    local dst="$2"
    if [ -f "$dst" ]; then
        return
    fi
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$url" -o "$dst"
    else
        wget -q "$url" -O "$dst"
    fi
}

require_cmd make
require_cmd gcc
require_cmd tar

rm -rf "$build_root"
mkdir -p "$build_root/src" "$build_root/runtime" "$out_dir"

nginx_tar="$build_root/src/nginx-$nginx_version.tar.gz"
php_tar="$build_root/src/php-$php_version.tar.gz"

fetch "https://nginx.org/download/nginx-$nginx_version.tar.gz" "$nginx_tar"
fetch "https://www.php.net/distributions/php-$php_version.tar.gz" "$php_tar"

tar -xzf "$nginx_tar" -C "$build_root/src"
tar -xzf "$php_tar" -C "$build_root/src"

nginx_prefix="$build_root/runtime/nginx"
php_prefix="$build_root/runtime/php"
multiarch="$(gcc -print-multiarch 2>/dev/null || true)"
php_cppflags=""
php_ldflags=""
curl_prefix="/usr"
if [ -n "$multiarch" ]; then
    if [ -d "/usr/include/$multiarch" ]; then
        php_cppflags="-I/usr/include/$multiarch"
    fi
    if [ -d "/usr/lib/$multiarch" ]; then
        php_ldflags="-L/usr/lib/$multiarch"
    fi
    if [ ! -e /usr/include/curl ] && [ -d "/usr/include/$multiarch/curl" ]; then
        curl_prefix="$build_root/deps/curl"
        mkdir -p "$curl_prefix/include" "$curl_prefix/lib"
        ln -s "/usr/include/$multiarch/curl" "$curl_prefix/include/curl"
        if [ -e "/usr/lib/$multiarch/libcurl.so" ]; then
            ln -s "/usr/lib/$multiarch/libcurl.so" "$curl_prefix/lib/libcurl.so"
        fi
    fi
fi

(
    cd "$build_root/src/nginx-$nginx_version"
    ./configure \
        --prefix=/usr/local/vesta/nginx \
        --with-http_ssl_module \
        --with-cc-opt="-Wno-error"
    make -j "$jobs"
    make install DESTDIR="$build_root/runtime/nginx-root"
)

mkdir -p "$nginx_prefix"
cp -a "$build_root/runtime/nginx-root/usr/local/vesta/nginx/." "$nginx_prefix/"
install -m 0644 "$project_root/src/rpm/conf/nginx.conf" "$nginx_prefix/conf/nginx.conf"
if [ -x "$nginx_prefix/sbin/nginx" ]; then
    cp -a "$nginx_prefix/sbin/nginx" "$nginx_prefix/sbin/vesta-nginx"
fi

(
    cd "$build_root/src/php-$php_version"
    CPPFLAGS="$php_cppflags" LDFLAGS="$php_ldflags" ./configure \
        --prefix=/usr/local/vesta/php \
        --with-config-file-path=/usr/local/vesta/php/lib \
        --with-zlib \
        --enable-zip \
        --enable-fpm \
        --with-fpm-user=admin \
        --with-fpm-group=admin \
        --with-mysql=mysqlnd \
        --with-mysqli=mysqlnd \
        --with-pdo-mysql=mysqlnd \
        --with-curl="$curl_prefix" \
        --enable-mbstring \
        --disable-debug
    make -j "$jobs" ZEND_EXTRA_LIBS='-lresolv'
    make install INSTALL_ROOT="$build_root/runtime/php-root"
)

mkdir -p "$php_prefix"
cp -a "$build_root/runtime/php-root/usr/local/vesta/php/." "$php_prefix/"
install -m 0644 "$project_root/src/rpm/conf/php.ini" "$php_prefix/lib/php.ini"
install -m 0644 "$project_root/src/rpm/conf/php-fpm.conf" "$php_prefix/etc/php-fpm.conf"
if [ -x "$php_prefix/sbin/php-fpm" ]; then
    cp -a "$php_prefix/sbin/php-fpm" "$php_prefix/sbin/vesta-php"
fi

VESTA_NGINX_DIR="$nginx_prefix" \
VESTA_PHP_DIR="$php_prefix" \
"$project_root/install/build-deb-packages.sh" "$out_dir"

cat <<EOF
Built runtime packages in $out_dir

Used versions:
  nginx $nginx_version
  php   $php_version

If PHP compilation fails on Debian 10, install build dependencies first:
  apt-get install -y build-essential gcc make curl ca-certificates \\
    libpcre3-dev zlib1g-dev libssl-dev libcurl4-openssl-dev
EOF
