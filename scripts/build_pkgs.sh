#!/usr/bin/env bash
set -euo pipefail
export PATH=/opt/local/bin:/opt/local/sbin:$PATH

LIST_FILE="${1:-macports.txt}"
mapfile -t PORTS < <(grep -vE '^\s*(#|$)' "${LIST_FILE}")
mkdir -p artifacts/pkgs

for p in "${PORTS[@]}"; do
  echo "=== Building mpkg for: $p ==="
  if sudo port -N -k mpkg "$p"; then
    find . -maxdepth 1 -type d -name "*.mpkg" -exec mv {} artifacts/pkgs/ \;
    find . -maxdepth 1 -type f -name "*.pkg"  -exec mv {} artifacts/pkgs/ \;
  else
    echo "FAILED mpkg: $p"
  fi
done
