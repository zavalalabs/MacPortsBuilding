#!/usr/bin/env bash
# Builds a single, self-contained, double-clickable macOS installer covering
# the entire built /opt/local tree (MacPorts base + every successfully
# installed port). Deliberately does NOT use `port pkg`/`port mpkg`: those
# targets re-fetch each port's distfiles to rebuild a fresh destroot, which
# on this pipeline fails for ~95% of ports with distfile permission errors
# (leftover .TMP files from the earlier `port install` pass). Packaging the
# already-installed, already-activated prefix directly sidesteps that
# entirely and is what actually produces an installable artifact.
set -euo pipefail
export PATH=/opt/local/bin:/opt/local/sbin:$PATH

VERSION="${INSTALLER_VERSION:-$(date +%Y.%m.%d).${GITHUB_RUN_NUMBER:-0}}"
IDENTIFIER="org.zavalalabs.macportsbuilding.allports"
PKG_NAME="MacPortsBuilding-AllPorts-arm64-${VERSION}.pkg"

WORK_DIR="$(pwd)/pkg_stage"
ROOT_DIR="${WORK_DIR}/root"
STAGE_OPT_LOCAL="${ROOT_DIR}/opt/local"
OUTPUT_DIR="$(pwd)/installer"
COMPONENT_PKG="${WORK_DIR}/component.pkg"
DISTRIBUTION_XML="${WORK_DIR}/distribution.xml"

echo "=== Staging /opt/local for packaging ==="
rm -rf "${WORK_DIR}"
mkdir -p "${STAGE_OPT_LOCAL}" "${OUTPUT_DIR}"

# Exclude MacPorts' own scratch space: build work dirs, downloaded sources,
# pre-activation port images, and logs. None of it is needed to run the
# software or to keep using `port` afterward — only bloats the installer.
sudo rsync -a \
  --exclude 'var/macports/build/' \
  --exclude 'var/macports/distfiles/' \
  --exclude 'var/macports/sources/' \
  --exclude 'var/macports/software/' \
  --exclude 'var/macports/logs/' \
  /opt/local/ "${STAGE_OPT_LOCAL}/"

sudo chown -R root:admin "${ROOT_DIR}/opt"

echo "=== Building component package ==="
pkgbuild \
  --root "${ROOT_DIR}" \
  --identifier "${IDENTIFIER}" \
  --version "${VERSION}" \
  --install-location "/" \
  "${COMPONENT_PKG}"

echo "=== Synthesizing distribution ==="
productbuild --synthesize --package "${COMPONENT_PKG}" "${DISTRIBUTION_XML}"

echo "=== Building final installer ==="
productbuild \
  --distribution "${DISTRIBUTION_XML}" \
  --package-path "${WORK_DIR}" \
  "${OUTPUT_DIR}/${PKG_NAME}"

echo "=== Installer built: ${OUTPUT_DIR}/${PKG_NAME} ==="
ls -lh "${OUTPUT_DIR}/${PKG_NAME}"
