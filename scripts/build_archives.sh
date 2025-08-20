#!/usr/bin/env bash
set -euo pipefail
export PATH=/opt/local/bin:/opt/local/sbin:$PATH

LIST_FILE="${1:-macports.txt}"

mkdir -p artifacts/archives
FAILED=()
SUCCESS=0

# Iterate lines safely; skip blanks and comments
while IFS= read -r line || [ -n "${line:-}" ]; do
  # trim
  port="${line#"${line%%[![:space:]]*}"}"
  port="${port%"${port##*[![:space:]]}"}"
  # skip empty or comment
  [ -z "$port" ] && continue
  case "$port" in \#*) continue ;; esac

  echo "=== Archiving: $port ==="
  if sudo port -N -k archive $port; then
    SUCCESS=$((SUCCESS+1))
  else
    echo "FAILED: $port"
    FAILED+=("$port")
  fi
done < "$LIST_FILE"

# Collect produced archives (flatten into artifacts/archives)
SOFTWARE_DIR="/opt/local/var/macports/software"
find "$SOFTWARE_DIR" -type f -name '*.tbz2' -print0 | xargs -0 -I{} cp {} artifacts/archives/

# Manifest
OS_VERSION="$(sw_vers -productVersion)"
ARCH="$(uname -m)"
{
  echo "os: ${OS_VERSION}"
  echo "arch: ${ARCH}"
  echo "ports_success: ${SUCCESS}"
  echo "failed_count: ${#FAILED[@]}"
  if [ "${#FAILED[@]}" -gt 0 ]; then
    printf 'failed: %s\n' "${FAILED[@]}"
  fi
} > artifacts/archives/manifest.txt

# Save the cleaned list we actually tried
# (same filter logic as loop)
awk '!/^[[:space:]]*($|#)/' "$LIST_FILE" > artifacts/archives/install-list.txt
