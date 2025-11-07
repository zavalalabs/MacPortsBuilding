[![Build MacPorts Binaries (arm64)](https://github.com/zavalalabs/MacPortsBuilding/actions/workflows/build-macports-arm64.yml/badge.svg)](https://github.com/zavalalabs/MacPortsBuilding/actions/workflows/build-macports-arm64.yml)

# MacPorts Building

Automated MacPorts package building system for ARM64 macOS with intelligent failure handling and retry logic.

## Features

- **Automated Port Building**: Builds MacPorts packages from a curated list
- **Intelligent Failure Handling**: Automatically skips problematic ports and continues building
- **Build Attempt Tracking**: Limits builds to 3 attempts per 24 hours to prevent resource waste
- **Automatic Issue Creation**: Creates GitHub issues when builds fail repeatedly
- **Wildcard Support**: Skip entire port families (e.g., `texlive-*`)
- **Persistent Tracking**: Maintains state across workflow runs

## How It Works

### Build Process

1. **Pre-Build Check**: Verifies that build attempts haven't exceeded the limit (3 in 24 hours)
2. **Port Building**: Iterates through `macports.txt`, installing each port
3. **Skip Problematic Ports**: Automatically skips ports listed in `problematic_ports.txt`
4. **Capture Failures**: New failures are automatically added to `problematic_ports.txt`
5. **Record Results**: Build success/failure is recorded in `build_attempts.json`
6. **Issue Creation**: After 3 consecutive failures, a GitHub issue is automatically created

### Retry Logic

The system implements a progressive retry strategy:

1. **First Attempt**: Builds all ports except those in `problematic_ports.txt`
2. **Second Attempt**: If failures occur, they're added to `problematic_ports.txt` and skipped on next run
3. **Third Attempt**: Final attempt with updated problematic ports list
4. **After 3 Failures**: System pauses and creates a GitHub issue requiring manual intervention

### Files

- **`macports.txt`**: List of ports to build (one per line)
- **`problematic_ports.txt`**: Ports with known issues that should be skipped
  - Supports exact matches: `postgresql17`
  - Supports wildcards: `texlive-*`
- **`build_attempts.json`**: Tracks build attempts and timestamps (persisted in repo)
- **`.gitignore`**: Excludes temporary build artifacts from git

### Scripts

#### `scripts/build_archives.sh`
Main build script that:
- Loads problematic ports from file
- Skips problematic ports during build
- Captures new failures
- Updates `problematic_ports.txt` automatically
- Provides detailed build summary

#### `scripts/track_build_attempts.sh`
Build attempt tracking utility:
```bash
# Check if build is allowed
./scripts/track_build_attempts.sh can-build

# Record a successful build
./scripts/track_build_attempts.sh record-success

# Record a failed build
./scripts/track_build_attempts.sh record-failure

# Check if issue should be created
./scripts/track_build_attempts.sh should-create-issue

# View tracking status
./scripts/track_build_attempts.sh status
```

#### `scripts/create_build_issue.sh`
Issue creation utility:
```bash
# Create GitHub issue (requires gh CLI)
./scripts/create_build_issue.sh create

# Save issue body to file
./scripts/create_build_issue.sh save issue_body.md
```

## Workflow Integration

The GitHub Actions workflow (`.github/workflows/build-macports-arm64.yml`) automatically:

1. Checks build attempt limits before starting
2. Bootstraps MacPorts environment
3. Runs the build process
4. Records build results
5. Creates issues if needed
6. Commits updated `problematic_ports.txt` back to repository
7. Uploads build artifacts

## Managing Problematic Ports

### Adding Ports Manually

Edit `problematic_ports.txt` and add ports one per line:

```
# Exact match
postgresql17

# Wildcard match (all texlive ports)
texlive-*

# Multiple specific ports
py27-gdata
openldap
```

### Automatic Addition

When a port fails to build, it's automatically added to `problematic_ports.txt` by the build script.

### Removing Ports

Once a port's issues are resolved:
1. Remove it from `problematic_ports.txt`
2. Commit the change
3. Re-run the workflow

## Resetting Build Attempts

If you need to reset the build attempt counter:

1. Edit `build_attempts.json` to reset attempts:
   ```json
   {"attempts": [], "last_success": null}
   ```
2. Commit the change
3. Re-run the workflow

## Troubleshooting

### Build Stopped After 3 Attempts

This is expected behavior. Check the automatically created GitHub issue for details:
1. Review failed ports
2. Investigate permission issues
3. Update `problematic_ports.txt` if needed
4. Reset `build_attempts.json` if issues are resolved
5. Close the issue and re-run the workflow

### Port Installation Fails

If a specific port consistently fails:
1. Add it to `problematic_ports.txt`
2. Investigate the root cause separately
3. Once fixed, remove from `problematic_ports.txt`

### Wildcard Not Working

Ensure the pattern in `problematic_ports.txt` uses proper syntax:
- Correct: `texlive-*` (matches all ports starting with texlive-)
- Incorrect: `*texlive*` (not supported)

## Development

### Running Locally

```bash
# Make scripts executable
chmod +x scripts/*.sh

# Test build attempt tracking
./scripts/track_build_attempts.sh status

# Test problematic port detection
./scripts/build_archives.sh
```

### Testing Changes

Before committing changes to scripts, test them locally or in a test workflow run to avoid breaking the production build pipeline.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

See repository license for details.

