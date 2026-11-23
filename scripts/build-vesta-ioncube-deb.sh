#!/usr/bin/env bash
set -euo pipefail

if [[ $# != 2 || $1 != --output || -z $2 ]]; then
    echo "Usage: $0 --output DIR" >&2
    exit 2
fi
output_dir="$2"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
loader="$repo_root/vendor/ioncube/ioncube_loader_lin_8.2.so"
control="$repo_root/src/deb/ioncube-php82/control"
package="$(sed -n 's/^Package: //p' "$control")"
version="$(sed -n 's/^Version: //p' "$control")"

printf '%s  %s\n' '2da620c94158eb8d89c3cacbeb79ad671a783a58d61ee28fce29567ea8c8d31d' "$loader" | sha256sum --check

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT
install -d "$output_dir"
install -D -m 0644 "$control" "$work_dir/DEBIAN/control"
install -D -m 0644 "$loader" "$work_dir/usr/local/vesta/ioncube/ioncube_loader_lin_8.2.so"
install -D -m 0644 "$repo_root/vendor/ioncube/LICENSE.txt" "$work_dir/usr/share/doc/$package/copyright"
dpkg-deb --root-owner-group --build "$work_dir" "$output_dir/${package}_${version}_amd64.deb"
