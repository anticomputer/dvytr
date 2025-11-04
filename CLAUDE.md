# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**DevYeeter (dvytr)** is a bash-based CLI tool that spins up containerized development environments. The project follows a "middle ground" naming convention:
- **Project name**: DevYeeter (user-friendly, used in documentation)
- **Command name**: dvytr (terse, for CLI efficiency)

## Architecture

### Core Components

1. **dvytr** (main bash script)
   - Single executable that manages Docker containers
   - Uses `SCRIPT_DIR` to locate Dockerfile/entrypoint (where dvytr is installed)
   - Uses `WORKSPACE_PATH` for current directory (where user runs command)
   - Key variables: `IMAGE_NAME="dvytr"`, `CONTAINER_PREFIX="dvytr"`, `VERSION="1.0.0"`

2. **Dockerfile**
   - Ubuntu 22.04 base with multi-language tooling
   - Creates a `dev` user (UID 1000) with sudo access
   - Pre-installs: C/C++, Python3, Node.js v20, pnpm, Go 1.21.5, Rust, editors (vim/emacs/nano)
   - Uses gosu for secure user switching

3. **entrypoint.sh**
   - Container entrypoint that dynamically adjusts `dev` user's UID/GID
   - Detects mounted `/workspace` owner and modifies `dev` user to match
   - Ensures files created in container are owned by host user
   - Critical for Linux permission handling; transparent on macOS

### Key Design Patterns

**One Image, Many Containers**
- Docker image built once, stored in Docker's cache
- Each project directory gets its own container instance
- Container naming: `dvytr-<sanitized-dirname>-<8-char-path-hash>`
  - Hash prevents collisions (e.g., multiple `tmp` directories)
  - Deterministic: same path always generates same container name

**Configuration Hierarchy**
1. `.dvytr.conf` in project directory (sourced if exists)
   - Sets: `CONTAINER_NAME`, `PORTS[]`, `ENV_VARS[]`, `ADDITIONAL_VOLUMES[]`
2. `.env` file auto-loaded (parsed, not sourced)
   - Variables added to `ENV_VARS[]` array
   - Format: `KEY=value` (comments and empty lines ignored)

**Permission Mapping**
- Container starts as root, runs entrypoint.sh
- Entrypoint detects workspace UID/GID using `stat`
- Modifies `dev` user to match host user
- Drops to `dev` user via `gosu`
- All tools in `/home/dev` remain accessible after UID change

## Common Commands

### Testing Changes
```bash
# Build image after Dockerfile changes
./dvytr build

# Test container creation
./dvytr run
./dvytr list
./dvytr status

# Test container functionality
./dvytr shell
./dvytr exec echo "test"

# Cleanup
./dvytr stop
./dvytr clean
```

### Development Workflow
```bash
# Make script changes
vim dvytr

# Make script executable
chmod +x dvytr

# Test directly
./dvytr <command>

# Test with different directory names/paths
cd /tmp && /path/to/dvytr run
cd ~/projects/tmp && /path/to/dvytr run  # Different hash!
```

## Implementation Notes

### Container Name Generation (dvytr:82-102)
- Sanitizes basename: `tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]-'`
- Generates MD5 hash of full path (8 chars)
- Cross-platform: uses `md5sum` (Linux) or `md5` (macOS), falls back to `cksum`

### Config Loading (dvytr:44-79)
- `load_config()`: Sources `.dvytr.conf` if exists
- `load_env_file()`: Parses `.env` line-by-line, validates format
  - Regex: `^[A-Za-z_][A-Za-z0-9_]*=`
  - Adds validated lines to `ENV_VARS[]` array

### Docker Run Flow (dvytr:117-177)
1. Load config and .env
2. Generate container name (or use custom)
3. Check if image exists (build if not)
4. Check if container exists (start if exists, create if not)
5. Build docker args array (ports, env vars, volumes)
6. Execute `docker run -itd` with constructed args

## Naming Conventions

- All command references use `dvytr` (not devyeeter)
- Help text shows: "DevYeeter (dvytr) v1.0.0"
- Container prefix: `dvytr-`
- Config file: `.dvytr.conf`
- Image name: `dvytr:latest`
- Log prefix in entrypoint: `[dvytr]`

## Cross-Platform Considerations

**macOS vs Linux differences:**
- `stat` format flags: `-c` (Linux) vs `-f` (macOS)
- `md5sum` (Linux) vs `md5` (macOS)
- Docker Desktop on macOS handles permissions automatically
- Linux needs explicit UID/GID mapping via entrypoint

**Always test both when:**
- Modifying entrypoint.sh permission logic
- Changing hash generation in `generate_container_name()`
- Adding new file operations

## File Structure

```
dev-yeeter/
├── dvytr              # Main bash script (executable)
├── Dockerfile         # Multi-language dev environment
├── entrypoint.sh      # Dynamic UID/GID adjustment
├── .dvytr.conf.example
├── .env.example
├── .gitignore         # Ignores .dvytr.conf and .env
└── README.md
```

## Refactoring History

The project went through naming changes:
- Originally: `dev-yeeter` command, `.dev-yeeter.conf`
- First refactor: `devyeeter` command, `.devyeeter.conf`
- Current: `dvytr` command, `.dvytr.conf` (middle ground: terse command, clear project name)

When making changes, ensure consistency across:
- Script internal variables
- Help text and version output
- README command examples
- Config file references
- Container/image naming
- Log messages
