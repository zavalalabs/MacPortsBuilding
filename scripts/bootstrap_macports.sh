#!/usr/bin/env bash
set -euo pipefail

# Expect macOS version like 12/13/14 and arch like arm64/x86_64
MACOS_MAJOR="$(sw_vers -productVersion | awk -F. '{print $1}')"
ARCH="$(uname -m)"

echo "macOS major: $MACOS_MAJOR arch: $ARCH"

# Install Xcode CLT (needed by MacPorts even for archive creation)
if ! xcode-select -p >/dev/null 2>&1; then
  sudo xcode-select --install || true
  # On CI this can already be present; no-op is fine.
fi

# Install MacPorts via pkg (adjust URL if needed per macOS version/arch)
# You can pin to a specific MacPorts release to keep builds reproducible.
PKG_URL=""
case "${MACOS_MAJOR}-${ARCH}" in
  12-x86_64) PKG_URL="https://github.com/macports/macports-base/releases/download/v2.8.1/MacPorts-2.8.1-12-Monterey.pkg" ;;
  13-x86_64) PKG_URL="https://github.com/macports/macports-base/releases/download/v2.8.1/MacPorts-2.8.1-13-Ventura.pkg" ;;
  13-arm64)  PKG_URL="https://github.com/macports/macports-base/releases/download/v2.8.1/MacPorts-2.8.1-13-Ventura-arm64.pkg" ;;
  14-x86_64) PKG_URL="https://github.com/macports/macports-base/releases/download/v2.8.1/MacPorts-2.8.1-14-Sonoma.pkg" ;;
  14-arm64)  PKG_URL="https://github.com/macports/macports-base/releases/download/v2.8.1/MacPorts-2.8.1-14-Sonoma-arm64.pkg" ;;
  *) echo "Define PKG_URL mapping for ${MACOS_MAJOR}-${ARCH}" ; exit 1 ;;
esac

echo "Downloading MacPorts pkg: $PKG_URL"
curl -fsSL "$PKG_URL" -o /tmp/macports.pkg
sudo installer -pkg /tmp/macports.pkg -target /

# Update ports tree
export PATH=/opt/local/bin:/opt/local/sbin:$PATH
sudo port -N selfupdate
