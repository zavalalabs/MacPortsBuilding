#!/bin/bash
# filepath: /Users/czavala/GitHub/MacPortsBuilding/scripts/build_archives.sh
set -e

# Ensure proper environment
export PATH=/opt/local/bin:/opt/local/sbin:$PATH
export TMPDIR=/tmp

# Build attempt tracking file
BUILD_ATTEMPTS_FILE="${BUILD_ATTEMPTS_FILE:-build_attempts.json}"

# Function to fix permissions after each port installation
fix_permissions() {
  echo "Fixing permissions for MacPorts directories..."
  sudo find /opt/local -type d -exec chmod 755 {} + 2>/dev/null || true
  sudo find /opt/local -type f -exec chmod 644 {} + 2>/dev/null || true
  sudo find /opt/local/bin -type f -exec chmod 755 {} + 2>/dev/null || true
  sudo find /opt/local/sbin -type f -exec chmod 755 {} + 2>/dev/null || true
  sudo chown -R macports:admin /opt/local 2>/dev/null || true
}

# Load problematic ports from file
load_problematic_ports() {
  local ports=()
  if [ -f "problematic_ports.txt" ]; then
    while IFS= read -r line; do
      # Skip empty lines and comments
      [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
      # Handle wildcard patterns (e.g., texlive-*)
      ports+=("$line")
    done < "problematic_ports.txt"
  fi
  printf '%s\n' "${ports[@]}"
}

# Check if current port is problematic
is_problematic() {
  local port=$1
  local pattern
  while IFS= read -r pattern; do
    [[ -z "$pattern" ]] && continue
    # Handle wildcard patterns
    if [[ "$pattern" == *"*"* ]]; then
      # Convert glob pattern to regex
      local regex="${pattern//\*/.*}"
      [[ "$port" =~ ^${regex}$ ]] && return 0
    else
      [[ "$port" == "$pattern" ]] && return 0
    fi
  done < <(load_problematic_ports)
  return 1
}

# Update problematic ports file with newly failed ports
update_problematic_ports() {
  local new_failed_ports=("$@")
  if [ ${#new_failed_ports[@]} -eq 0 ]; then
    return
  fi
  
  echo "Updating problematic_ports.txt with ${#new_failed_ports[@]} newly failed ports..."
  
  # Read existing problematic ports
  local existing_ports=()
  if [ -f "problematic_ports.txt" ]; then
    while IFS= read -r line; do
      [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
      existing_ports+=("$line")
    done < "problematic_ports.txt"
  fi
  
  # Add new failed ports if not already in the list
  for port in "${new_failed_ports[@]}"; do
    local already_exists=false
    for existing in "${existing_ports[@]}"; do
      if [[ "$port" == "$existing" ]]; then
        already_exists=true
        break
      fi
    done
    if [ "$already_exists" = false ]; then
      echo "$port" >> "problematic_ports.txt"
      echo "  Added $port to problematic_ports.txt"
    fi
  done
}

# Clean environment before building
echo "Cleaning MacPorts environment..."
sudo port clean --all all || true
sudo port uninstall inactive || true

# Fix permissions before starting
fix_permissions

# Build ports with error handling
failed_ports=()
successful_ports=()
skipped_ports=()

echo "Starting MacPorts build process..."
echo "Loading list of problematic ports to skip..."
load_problematic_ports | while IFS= read -r p; do
  echo "  - Will skip: $p"
done

while IFS= read -r port; do
  # Skip empty lines and comments
  [[ -z "$port" || "$port" =~ ^[[:space:]]*# ]] && continue
  
  # Skip problematic ports
  if is_problematic "$port"; then
    echo "⊘ SKIPPING (problematic): $port"
    skipped_ports+=("$port")
    continue
  fi
  
  echo "Building: $port"
  # Normal installation
  if sudo port install "$port"; then
    echo "✓ Successfully installed: $port"
    successful_ports+=("$port")
    # Fix permissions after each successful install
    fix_permissions
  else
    echo "✗ FAILED: $port"
    failed_ports+=("$port")
    # Try to clean up failed port
    sudo port clean "$port" || true
  fi
done < macports.txt

# Update problematic_ports.txt with newly failed ports
if [ ${#failed_ports[@]} -gt 0 ]; then
  update_problematic_ports "${failed_ports[@]}"
fi

# Report results
echo ""
echo "========================================"
echo "Build Summary:"
echo "========================================"
echo "Successful: ${#successful_ports[@]}"
echo "Failed: ${#failed_ports[@]}"
echo "Skipped (problematic): ${#skipped_ports[@]}"
echo "========================================"

# Save failed ports log
if [ ${#failed_ports[@]} -gt 0 ]; then
  echo "Failed ports:" > failed_ports.log
  printf '%s\n' "${failed_ports[@]}" >> failed_ports.log
  echo "Build completed with ${#failed_ports[@]} failed ports (see failed_ports.log)"
  
  # Exit with error if we have new failures
  exit 1
elif [ ${#skipped_ports[@]} -gt 0 ]; then
  echo "Build completed successfully, but ${#skipped_ports[@]} ports were skipped"
  # Exit successfully even with skipped ports
  exit 0
else
  echo "All ports built successfully!"
  exit 0
fi

# Final permission fix
fix_permissions
