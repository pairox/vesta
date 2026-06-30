#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'USAGE'
Usage: build-apt-repository.sh --input DIR --output DIR --codename CODENAME [options]

Build a static Debian APT repository that can be published by GitHub Pages.

Options:
  --component NAME        Repository component (default: vesta)
  --origin NAME           Release Origin field (default: VestaCP fork)
  --label NAME            Release Label field (default: VestaCP fork)
  --suite NAME            Release Suite field (default: CODENAME)
  --description TEXT      Release Description field
  --gpg-key KEYID         Sign Release as InRelease/Release.gpg with this GPG key
  --require-signature     Fail when --gpg-key is not provided
  -h, --help              Show this help
USAGE
}

input_dir=""
output_dir=""
codename=""
component="vesta"
origin="VestaCP fork"
label="VestaCP fork"
suite=""
description="VestaCP Debian packages"
gpg_key=""
require_signature=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --input) input_dir="$2"; shift 2 ;;
        --output) output_dir="$2"; shift 2 ;;
        --codename) codename="$2"; shift 2 ;;
        --component) component="$2"; shift 2 ;;
        --origin) origin="$2"; shift 2 ;;
        --label) label="$2"; shift 2 ;;
        --suite) suite="$2"; shift 2 ;;
        --description) description="$2"; shift 2 ;;
        --gpg-key) gpg_key="$2"; shift 2 ;;
        --require-signature) require_signature=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
done

if [[ -z "$input_dir" || -z "$output_dir" || -z "$codename" ]]; then
    usage >&2
    exit 2
fi

if [[ ! -d "$input_dir" ]]; then
    echo "Input directory does not exist: $input_dir" >&2
    exit 1
fi

if ! command -v dpkg-scanpackages >/dev/null 2>&1; then
    echo "dpkg-scanpackages is required (install dpkg-dev)." >&2
    exit 1
fi
if ! command -v apt-ftparchive >/dev/null 2>&1; then
    echo "apt-ftparchive is required (install apt-utils)." >&2
    exit 1
fi

mapfile -t debs < <(find "$input_dir" -type f -name '*.deb' | sort)
if [[ ${#debs[@]} -eq 0 ]]; then
    echo "No .deb packages found in $input_dir" >&2
    exit 1
fi

suite="${suite:-$codename}"
archs=()
rm -rf "$output_dir"
mkdir -p "$output_dir/pool/$component" "$output_dir/dists/$codename/$component"

for deb in "${debs[@]}"; do
    arch=$(dpkg-deb -f "$deb" Architecture)
    if [[ -z "$arch" ]]; then
        echo "Cannot read Architecture from $deb" >&2
        exit 1
    fi
    if [[ ! " ${archs[*]} " =~ [[:space:]]${arch}[[:space:]] ]]; then
        archs+=("$arch")
    fi
    mkdir -p "$output_dir/pool/$component/$arch"
    cp "$deb" "$output_dir/pool/$component/$arch/"
done

pushd "$output_dir" >/dev/null
for arch in "${archs[@]}"; do
    mkdir -p "dists/$codename/$component/binary-$arch"
    dpkg-scanpackages --arch "$arch" "pool/$component/$arch" /dev/null > "dists/$codename/$component/binary-$arch/Packages"
    gzip -9cn "dists/$codename/$component/binary-$arch/Packages" > "dists/$codename/$component/binary-$arch/Packages.gz"
done

cat > apt-ftparchive.conf <<EOF_CONF
APT::FTPArchive::Release::Origin "$origin";
APT::FTPArchive::Release::Label "$label";
APT::FTPArchive::Release::Suite "$suite";
APT::FTPArchive::Release::Codename "$codename";
APT::FTPArchive::Release::Architectures "${archs[*]}";
APT::FTPArchive::Release::Components "$component";
APT::FTPArchive::Release::Description "$description";
EOF_CONF
apt-ftparchive -c apt-ftparchive.conf release "dists/$codename" > "dists/$codename/Release"
rm apt-ftparchive.conf

if [[ -n "$gpg_key" ]]; then
    gpg_options=(--batch --yes --local-user "$gpg_key" --digest-algo SHA256)
    if [[ -f "$HOME/.gnupg/passphrase" ]]; then
        gpg_options+=(--pinentry-mode loopback --passphrase-file "$HOME/.gnupg/passphrase")
    fi
    gpg "${gpg_options[@]}" --clearsign \
        --output "dists/$codename/InRelease" "dists/$codename/Release"
    gpg "${gpg_options[@]}" --detach-sign --armor \
        --output "dists/$codename/Release.gpg" "dists/$codename/Release"
elif [[ "$require_signature" -eq 1 ]]; then
    echo "Signing is required, but --gpg-key was not provided." >&2
    exit 1
else
    echo "WARNING: repository was generated without InRelease/Release.gpg signatures." >&2
fi
popd >/dev/null

printf 'APT repository generated in %s for codename %s (%s)\n' "$output_dir" "$codename" "${archs[*]}"
