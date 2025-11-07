#!/bin/bash
# Script to create a GitHub issue when build attempts fail repeatedly

set -e

# Configuration
ISSUE_TITLE="MacPorts Build Failed After 3 Attempts"
REPO="${GITHUB_REPOSITORY:-zavalalabs/MacPortsBuilding}"

# Function to create issue body
create_issue_body() {
  local failed_ports_log="${1:-failed_ports.log}"
  local build_summary="${2:-build_summary.md}"
  
  cat << EOF
## MacPorts Build Failure Report

The MacPorts build process has failed 3 consecutive times within a 24-hour period. The build has been paused to prevent excessive resource usage.

### Build Information
- **Repository**: $REPO
- **Workflow Run**: $GITHUB_SERVER_URL/$REPO/actions/runs/$GITHUB_RUN_ID
- **Timestamp**: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
- **Branch**: ${GITHUB_REF#refs/heads/}

### Failed Ports
EOF

  if [ -f "$failed_ports_log" ]; then
    echo ""
    echo "The following ports failed during the most recent build attempt:"
    echo ""
    echo '```'
    cat "$failed_ports_log"
    echo '```'
  else
    echo ""
    echo "No failed ports log available."
  fi
  
  cat << EOF

### Problematic Ports
The following ports are currently marked as problematic and are being skipped:
EOF

  if [ -f "problematic_ports.txt" ]; then
    echo ""
    echo '```'
    cat problematic_ports.txt
    echo '```'
  else
    echo ""
    echo "No problematic ports currently marked."
  fi
  
  cat << EOF

### Build Summary
EOF

  if [ -f "$build_summary" ]; then
    echo ""
    cat "$build_summary"
  else
    echo ""
    echo "No build summary available."
  fi
  
  cat << EOF

### Actions Required
1. Review the failed ports and investigate permission issues
2. Determine if the ports should be added to \`problematic_ports.txt\`
3. Fix any underlying issues with MacPorts configuration or sudo permissions
4. Once resolved, manually re-trigger the workflow

### Next Steps
- The build will remain paused until this issue is addressed
- Close this issue once the problems are resolved
- Re-run the workflow to resume builds
EOF
}

# Function to create GitHub issue using gh CLI
create_issue() {
  if ! command -v gh &> /dev/null; then
    echo "ERROR: GitHub CLI (gh) is not installed or not in PATH"
    echo "Issue creation failed - please create issue manually"
    return 1
  fi
  
  local issue_body=$(create_issue_body "$@")
  
  echo "Creating GitHub issue..."
  gh issue create \
    --title "$ISSUE_TITLE" \
    --body "$issue_body" \
    --label "bug,build-failure,automated" \
    --repo "$REPO"
  
  echo "GitHub issue created successfully"
}

# Function to save issue body to file (for debugging or manual creation)
save_issue_body() {
  local output_file="${1:-issue_body.md}"
  shift || true
  create_issue_body "$@" > "$output_file"
  echo "Issue body saved to: $output_file"
}

# Main execution
case "${1:-create}" in
  create)
    shift || true
    create_issue "$@"
    ;;
  save)
    shift || true
    save_issue_body "$@"
    ;;
  help|*)
    echo "Usage: $0 {create|save} [failed_ports.log] [build_summary.md]"
    echo ""
    echo "Commands:"
    echo "  create  - Create a GitHub issue (requires gh CLI and authentication)"
    echo "  save    - Save issue body to file (issue_body.md)"
    echo ""
    echo "Arguments:"
    echo "  failed_ports.log   - Path to failed ports log (default: failed_ports.log)"
    echo "  build_summary.md   - Path to build summary (default: build_summary.md)"
    exit 0
    ;;
esac
