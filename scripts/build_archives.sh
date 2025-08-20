#!/usr/bin/env bash
set -euo pipefail
export PATH=/opt/local/bin:/opt/local/sbin:$PATH

LIST_FILE="${1:-macports.txt}"

# Ensure noninteractive, always build archives
# macports.conf defaults to build archives on install; we explicitly run archive.
# Variants in macports.txt will be honored.
mapfile -t PORTS < <(grep -vE '^\s*(#|$)' "${LIST_FILE}")

# Pre-fetch & build archives without failing the whole job if one port fails
mkdir -p artifacts/archives
FAILED=()

for p in "${PORTS[@]}"; do
  echo "=== Archiving: $p ==="
  if ! sudo port -N -k archive $p; then
    echo "FAILED: $p"
    FAILED+=("$p")
  fi
done

# Copy produced archives out of the MacPorts software dir
# Structure: /opt/local/var/macports/software/<port>/*.tbz2
SOFTWARE_DIR="/opt/local/var/macports/software"
rsync -a --prune-empty-dirs --include='*/' --include='*.tbz2' --exclude='*' "$SOFTWARE_DIR/" artifacts/archives/

# Write a manifest describing OS/arch and list
OS_VERSION="$(sw_vers -productVersion)"
ARCH="$(uname -m)"
{
  echo "os: ${OS_VERSION}"
  echo "arch: ${ARCH}"
  echo "ports_count: ${#PORTS[@]}"
  echo "failed_count: ${#FAILED[@]}"
  printf 'failed: %s\n' "${FAILED[*]:-}"
} > artifacts/archives/manifest.txt

# Useful for clients: a simple install list
printf '%s\n' "${PORTS[@]}" > artifacts/archives/install-list.txt
