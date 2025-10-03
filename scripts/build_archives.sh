#!/bin/bash
# filepath: /Users/czavala/GitHub/MacPortsBuilding/scripts/build_archives.sh
set -e

# Ensure proper environment
export PATH=/opt/local/bin:/opt/local/sbin:$PATH
export TMPDIR=/tmp

# Function to fix permissions after each port installation
fix_permissions() {
  echo "Fixing permissions for MacPorts directories..."
  sudo find /opt/local -type d -exec chmod 755 {} + 2>/dev/null || true
  sudo find /opt/local -type f -exec chmod 644 {} + 2>/dev/null || true
  sudo find /opt/local/bin -type f -exec chmod 755 {} + 2>/dev/null || true
  sudo find /opt/local/sbin -type f -exec chmod 755 {} + 2>/dev/null || true
  sudo chown -R macports:admin /opt/local 2>/dev/null || true
}

# List of problematic ports
problematic_ports=("py27-gdata" "openldap" "postgresql17")

# Check if current port is problematic
is_problematic() {
  local port=$1
  for problematic in "${problematic_ports[@]}"; do
    [[ "$port" == "$problematic" ]] && return 0
  done
  return 1
}

# Clean environment before building
echo "Cleaning MacPorts environment..."
sudo port clean --all all || true
sudo port uninstall inactive || true

# Fix permissions before starting
fix_permissions

# Build ports with error handling
failed_ports=()
while IFS= read -r port; do
  # Skip empty lines and comments
  [[ -z "$port" || "$port" =~ ^[[:space:]]*# ]] && continue
  
  echo "Building: $port"
  if is_problematic "$port"; then
    echo "Installing problematic port with special handling: $port"
    if sudo port install "$port" && sudo chmod -R 755 /opt/local/var/macports/software/"$port"* 2>/dev/null; then
      echo "✓ Successfully installed with permission fix: $port"
    else
      echo "✗ FAILED: $port"
      failed_ports+=("$port")
    fi
  else
    # Normal installation
    if sudo port install "$port"; then
      echo "✓ Successfully installed: $port"
      # Fix permissions after each successful install
      fix_permissions
    else
      echo "✗ FAILED: $port"
      failed_ports+=("$port")
      # Try to clean up failed port
      sudo port clean "$port" || true
    fi
  fi
done < macports.txt

# Report failed ports
if [ ${#failed_ports[@]} -gt 0 ]; then
  echo "Failed ports:" > failed_ports.log
  printf '%s\n' "${failed_ports[@]}" >> failed_ports.log
  echo "Build completed with ${#failed_ports[@]} failed ports"
else
  echo "All ports built successfully!"
fi

# Final permission fix
fix_permissions
