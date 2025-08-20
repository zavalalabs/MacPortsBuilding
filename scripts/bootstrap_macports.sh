#!/usr/bin/env bash
set -euo pipefail

# Hard-stop if we’re not on Apple silicon
[[ "$(uname -m)" == "arm64" ]] || { echo "This workflow is arm64-only."; exit 1; }

MACOS_MAJOR="$(sw_vers -productVersion | awk -F. '{print $1}')"
ARCH="arm64"
echo "Detected macOS $MACOS_MAJOR ($ARCH)"

# Xcode CLT (should already exist on GH runners, safe to noop)
if ! xcode-select -p >/dev/null 2>&1; then
  sudo xcode-select --install || true
fi

# Install MacPorts (arm64) via pkg.
# Tip: keep this mapping updated for the MacPorts version you pin.
# You can also inject MACPORTS_PKG_URL via env to override.
PKG_URL="${MACPORTS_PKG_URL:-}"

if [[ -z "${PKG_URL}" ]]; then
  case "${MACOS_MAJOR}" in
    14) PKG_URL="https://github.com/macports/macports-base/releases/download/v2.10.5/MacPorts-2.10.5-14-Sonoma.pkg" ;;
    15) PKG_URL="https://github.com/macports/macports-base/releases/download/v2.10.7/MacPorts-2.10.7-15-Sequoia.pkg" ;;
    *) echo "Add a MacPorts pkg URL mapping for macOS ${MACOS_MAJOR} (arm64)"; exit 1 ;;
  esac
fi

echo "Installing MacPorts from: $PKG_URL"
curl -fsSL "$PKG_URL" -o /tmp/macports.pkg
sudo installer -pkg /tmp/macports.pkg -target /

# Update ports tree
export PATH=/opt/local/bin:/opt/local/sbin:$PATH
sudo port -N selfupdate
