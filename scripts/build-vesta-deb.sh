#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'USAGE'
Usage: build-vesta-deb.sh --output DIR

Build the vesta Debian package from this repository.

Options:
  --output DIR           Directory where the .deb file will be written
  --version VERSION      Override the package version
  -h, --help             Show this help
USAGE
}

output_dir=""
version_override="${VESTA_DEB_VERSION:-}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output) output_dir="$2"; shift 2 ;;
        --version) version_override="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
done

if [[ -z "$output_dir" ]]; then
    usage >&2
    exit 2
fi

if ! command -v dpkg-deb >/dev/null 2>&1; then
    echo "dpkg-deb is required." >&2
    exit 1
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
control_file="$repo_root/src/deb/vesta/control"
package="$(awk -F': ' '$1 == "Package" { print $2; exit }' "$control_file")"
version="${version_override:-$(awk -F': ' '$1 == "Version" { print $2; exit }' "$control_file")}"
architecture="$(awk -F': ' '$1 == "Architecture" { print $2; exit }' "$control_file")"

if [[ -z "$package" || -z "$version" || -z "$architecture" ]]; then
    echo "Cannot read Package, Version, or Architecture from $control_file" >&2
    exit 1
fi

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

pkg_root="$work_dir/${package}_${version}_${architecture}"
install -d "$pkg_root/DEBIAN" "$pkg_root/usr/local/vesta" "$pkg_root/usr/share/doc/vesta" "$output_dir"

awk -v version="$version" '
    /^Version:/ { print "Version: " version; next }
    { print }
' "$control_file" > "$pkg_root/DEBIAN/control"
cp "$repo_root/src/deb/vesta/conffiles" "$pkg_root/DEBIAN/conffiles"
install -m 0755 "$repo_root/src/deb/vesta/postinst" "$pkg_root/DEBIAN/postinst"
cp "$repo_root/src/deb/vesta/copyright" "$pkg_root/usr/share/doc/vesta/copyright"
gzip -9cn "$repo_root/src/deb/vesta/changelog" > "$pkg_root/usr/share/doc/vesta/changelog.Debian.gz"

for path in bin func install upd web LICENSE README.md SECURITY.md; do
    if [[ -e "$repo_root/$path" ]]; then
        cp -a "$repo_root/$path" "$pkg_root/usr/local/vesta/"
    fi
done

find "$pkg_root" -name '.DS_Store' -delete
dpkg_deb_options=()
if dpkg-deb --help 2>&1 | grep -q -- '--root-owner-group'; then
    dpkg_deb_options+=(--root-owner-group)
fi
dpkg-deb "${dpkg_deb_options[@]}" --build "$pkg_root" "$output_dir/${package}_${version}_${architecture}.deb"
