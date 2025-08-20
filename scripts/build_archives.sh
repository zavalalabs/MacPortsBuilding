#!/usr/bin/env bash
set -euo pipefail
export PATH=/opt/local/bin:/opt/local/sbin:$PATH

LIST_FILE="${1:-macports.txt}"
mapfile -t PORTS < <(grep -vE '^\s*(#|$)' "${LIST_FILE}")

mkdir -p artifacts/archives
FAILED=()

# Build binary archives (.tbz2) without prompting
for p in "${PORTS[@]}"; do
  echo "=== Archiving: $p ==="
  if ! sudo port -N -k archive $p; then
    echo "FAILED: $p"
    FAILED+=("$p")
  fi
done

# Collect archives from MacPorts software dir
SOFTDIR="/opt/local/var/macports/software"
rsync -a --prune-empty-dirs --include='*/' --include='*.tbz2' --exclude='*' "$SOFTDIR/" artifacts/archives/

# Manifest
OS_VERSION="$(sw_vers -productVersion)"
ARCH="$(uname -m)"
{
  echo "os: ${OS_VERSION}"
  echo "arch: ${ARCH}"
  echo "ports_count: ${#PORTS[@]}"
  echo "failed_count: ${#FAILED[@]}"
  printf 'failed: %s\n' "${FAILED[*]:-}"
} > artifacts/archives/manifest.txt

printf '%s\n' "${PORTS[@]}" > artifacts/archives/install-list.txt
