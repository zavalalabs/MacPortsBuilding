#!/usr/bin/env bash
set -euo pipefail
export PATH=/opt/local/bin:/opt/local/sbin:$PATH
LIST_FILE="${1:-macports.txt}"

mapfile -t PORTS < <(grep -vE '^\s*(#|$)' "${LIST_FILE}")

mkdir -p artifacts/pkgs

for p in "${PORTS[@]}"; do
  echo "=== Building mpkg for: $p ==="
  # mpkg includes dependencies; results land in current dir
  # If pkg fails for a given port, continue to the next
  if sudo port -N -k mpkg "$p"; then
    # grab *.mpkg / *.pkg
    find . -maxdepth 1 -type d -name "*.mpkg" -exec mv {} artifacts/pkgs/ \;
    find . -maxdepth 1 -type f -name "*.pkg"  -exec mv {} artifacts/pkgs/ \;
  else
    echo "FAILED mpkg: $p"
  fi
done
