#!/bin/bash
set -euo pipefail

codename="${CODENAME:-buster}"
release="${DEBIAN_RELEASE:-10}"
component="${COMPONENT:-vesta}"
arch="${ARCH:-amd64}"
deb_dir="${1:-dist/deb}"
out_dir="${2:-docs}"
repo_root="$out_dir/apt/$codename"
files_root="$out_dir/files"
packages_dir="$repo_root/dists/$codename/$component/binary-$arch"
pool_dir="$repo_root/pool"
script_dir="$(cd "$(dirname "$0")" && pwd)"
project_root="$(cd "$script_dir/.." && pwd)"

require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Error: $1 is required" >&2
        exit 1
    fi
}

require_cmd dpkg-scanpackages
require_cmd apt-ftparchive
require_cmd gzip
require_cmd tar

if [ ! -d "$deb_dir" ]; then
    echo "Error: Debian package directory not found: $deb_dir" >&2
    echo "Usage: $0 /path/to/debs [docs]" >&2
    exit 1
fi

if ! find "$deb_dir" -maxdepth 1 -name '*.deb' -type f | grep -q .; then
    echo "Error: no .deb packages found in $deb_dir" >&2
    exit 1
fi

mkdir -p "$packages_dir" "$pool_dir" "$files_root/debian/$release"
find "$pool_dir" -maxdepth 1 -name '*.deb' -type f -delete
cp "$deb_dir"/*.deb "$pool_dir/"

(
    cd "$repo_root"
    dpkg-scanpackages --arch "$arch" pool /dev/null > "dists/$codename/$component/binary-$arch/Packages"
    gzip -9c "dists/$codename/$component/binary-$arch/Packages" > \
        "dists/$codename/$component/binary-$arch/Packages.gz"
    apt-ftparchive \
        -o APT::FTPArchive::Release::Origin="Pairox Vesta" \
        -o APT::FTPArchive::Release::Label="Pairox Vesta" \
        -o APT::FTPArchive::Release::Suite="$codename" \
        -o APT::FTPArchive::Release::Codename="$codename" \
        -o APT::FTPArchive::Release::Architectures="$arch" \
        -o APT::FTPArchive::Release::Components="$component" \
        release "dists/$codename" > "dists/$codename/Release"
)

if [ -n "${SIGNING_KEY_ID:-}" ]; then
    require_cmd gpg
    gpg --batch --yes --armor --detach-sign \
        --local-user "$SIGNING_KEY_ID" \
        -o "$repo_root/dists/$codename/Release.gpg" \
        "$repo_root/dists/$codename/Release"
    gpg --batch --yes --armor --export "$SIGNING_KEY_ID" > "$files_root/deb_signing.key"
else
    if [ -f "$project_root/install/debian/$release/deb_signing.key" ]; then
        cp "$project_root/install/debian/$release/deb_signing.key" "$files_root/deb_signing.key"
    fi
    cat >&2 <<EOF
Warning: repository metadata was not signed.
Set SIGNING_KEY_ID to a GPG key id and rerun this script before using apt.
EOF
fi

tar -C "$project_root/install/debian/$release" -czf \
    "$files_root/debian/$release/templates.tar.gz" templates

vesta_deb=$(find "$pool_dir" -maxdepth 1 -name 'vesta_*.deb' -type f | sort | tail -n1)
if [ -n "$vesta_deb" ]; then
    version=$(dpkg-deb -f "$vesta_deb" Version)
    echo "vesta-${version%-*}-${version#*-}" > "$files_root/latest.txt"
fi

mkdir -p "$files_root/3rdparty"
touch "$files_root/3rdparty/.gitkeep"

cat <<EOF
APT repository created in $out_dir

Use these installer variables after GitHub Pages is enabled:
  VESTA_RHOST=https://pairox.github.io/vesta/apt
  VESTA_CHOST=https://pairox.github.io/vesta/files

APT source used by Vesta:
  deb https://pairox.github.io/vesta/apt/$codename/ $codename $component
EOF
