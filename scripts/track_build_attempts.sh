#!/bin/bash
# Script to track build attempts and prevent excessive retries
# Limits builds to max 3 attempts in 24 hours

set -e

BUILD_ATTEMPTS_FILE="${BUILD_ATTEMPTS_FILE:-build_attempts.json}"
MAX_ATTEMPTS=3
TIME_WINDOW_HOURS=24

# Initialize attempts file if it doesn't exist
initialize_attempts_file() {
  if [ ! -f "$BUILD_ATTEMPTS_FILE" ]; then
    echo '{"attempts": [], "last_success": null}' > "$BUILD_ATTEMPTS_FILE"
  fi
}

# Get current timestamp in seconds
current_timestamp() {
  date +%s
}

# Add a new build attempt
record_attempt() {
  local status="$1"  # success or failure
  local timestamp=$(current_timestamp)
  
  initialize_attempts_file
  
  # Read current attempts
  local attempts=$(cat "$BUILD_ATTEMPTS_FILE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
data['attempts'].append({'timestamp': $timestamp, 'status': '$status'})
if '$status' == 'success':
    data['last_success'] = $timestamp
json.dump(data, sys.stdout)
")
  
  echo "$attempts" > "$BUILD_ATTEMPTS_FILE"
  echo "Recorded build attempt: $status at timestamp $timestamp"
}

# Clean old attempts (older than TIME_WINDOW_HOURS)
clean_old_attempts() {
  initialize_attempts_file
  
  local cutoff_time=$(($(current_timestamp) - TIME_WINDOW_HOURS * 3600))
  
  local cleaned=$(cat "$BUILD_ATTEMPTS_FILE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
data['attempts'] = [a for a in data['attempts'] if a['timestamp'] > $cutoff_time]
json.dump(data, sys.stdout)
")
  
  echo "$cleaned" > "$BUILD_ATTEMPTS_FILE"
  echo "Cleaned attempts older than $TIME_WINDOW_HOURS hours"
}

# Check if we can attempt another build
can_attempt_build() {
  initialize_attempts_file
  clean_old_attempts
  
  local count=$(cat "$BUILD_ATTEMPTS_FILE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(len(data['attempts']))
")
  
  echo "Current attempts in last $TIME_WINDOW_HOURS hours: $count"
  
  if [ "$count" -ge "$MAX_ATTEMPTS" ]; then
    echo "ERROR: Maximum build attempts ($MAX_ATTEMPTS) reached in the last $TIME_WINDOW_HOURS hours"
    return 1
  fi
  
  return 0
}

# Get recent failed attempts count
get_failed_attempts_count() {
  initialize_attempts_file
  # Suppress "Cleaned attempts" message but not errors
  local cleanup_output=$(clean_old_attempts 2>&1)
  if [ $? -ne 0 ]; then
    echo "Warning: Failed to clean old attempts: $cleanup_output" >&2
  fi
  
  local count=$(cat "$BUILD_ATTEMPTS_FILE" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    failed = [a for a in data['attempts'] if a['status'] == 'failure']
    print(len(failed))
except Exception as e:
    print(f'Error: {e}', file=sys.stderr)
    print(0)
")
  
  echo "$count"
}

# Check if we should create an issue (3 consecutive failures)
should_create_issue() {
  local failed_count=$(get_failed_attempts_count)
  
  if [ "$failed_count" -ge "$MAX_ATTEMPTS" ]; then
    echo "yes"
  else
    echo "no"
  fi
}

# Main command dispatcher
case "${1:-help}" in
  can-build)
    if can_attempt_build; then
      echo "Build attempt allowed"
      exit 0
    else
      echo "Build attempt NOT allowed - maximum attempts reached"
      exit 1
    fi
    ;;
  record-success)
    record_attempt "success"
    ;;
  record-failure)
    record_attempt "failure"
    ;;
  should-create-issue)
    result=$(should_create_issue)
    echo "$result"
    if [ "$result" = "yes" ]; then
      exit 0
    else
      exit 1
    fi
    ;;
  status)
    initialize_attempts_file
    clean_old_attempts
    echo "Build attempt tracking status:"
    cat "$BUILD_ATTEMPTS_FILE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(f'Total attempts in last $TIME_WINDOW_HOURS hours: {len(data[\"attempts\"])}')
failed = [a for a in data['attempts'] if a['status'] == 'failure']
print(f'Failed attempts: {len(failed)}')
success = [a for a in data['attempts'] if a['status'] == 'success']
print(f'Successful attempts: {len(success)}')
if data['last_success']:
    import datetime
    dt = datetime.datetime.fromtimestamp(data['last_success'])
    print(f'Last successful build: {dt}')
"
    ;;
  help|*)
    echo "Usage: $0 {can-build|record-success|record-failure|should-create-issue|status}"
    echo ""
    echo "Commands:"
    echo "  can-build             - Check if a build attempt is allowed (exits 0 if yes, 1 if no)"
    echo "  record-success        - Record a successful build attempt"
    echo "  record-failure        - Record a failed build attempt"
    echo "  should-create-issue   - Check if an issue should be created (3 consecutive failures)"
    echo "  status                - Show current tracking status"
    exit 0
    ;;
esac
