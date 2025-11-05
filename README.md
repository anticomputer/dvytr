# DevYeeter

A bash-based tool for spinning up fully-featured development Docker containers with your current working directory mounted as the application base. Perfect for isolated development environments with all common programming languages and tools pre-installed.

## Features

- **Multi-language Support**: C/C++, Go, Rust, Python 3, Node.js, TypeScript
- **Modern Package Managers**: pnpm (primary), npm, pip, cargo, go modules
- **Cross-Platform**: Works on both Linux and MacOS
- **Automatic Mounting**: Current directory auto-mounted to `/workspace`
- **Dedicated User**: Non-root `dev` user with sudo access for better security
- **Configurable**: Port forwarding, environment variables, and volume mounts
- **Easy Management**: Simple commands for start, stop, shell access, and cleanup

## Prerequisites

- Docker installed and running
- Bash shell

## Installation

**One-time setup** - You only need to do this once:

1. Clone this repository:
```bash
git clone <repository-url>
cd dvytr
```

2. Add the tool to your PATH (optional but recommended):
```bash
# Add to ~/.bashrc or ~/.zshrc
export PATH="/path/to/dvytr:$PATH"
```

Or create a symlink:
```bash
sudo ln -s "$(pwd)/dvytr" /usr/local/bin/dvytr
```

3. Build the Docker image (one-time):
```bash
dvytr build
```

**That's it!** The image is now available system-wide. You can use `dvytr` from any project directory without needing the Dockerfile there.

## Quick Start

Navigate to **any** project directory and start a container:

```bash
cd /path/to/your/project
dvytr run
```

Attach to the running container:

```bash
dvytr shell
```

You'll be in a bash shell with your project directory mounted at `/workspace`.

## Commands

### `dvytr run`
Start a new development container with the current directory mounted.

```bash
cd my-project
dvytr run
```

### `dvytr shell`
Attach to the running container and open a bash shell.

```bash
dvytr shell
```

### `dvytr exec <command>`
Execute a command in the running container without attaching.

```bash
dvytr exec python --version
dvytr exec pnpm install
dvytr exec cargo build
```

### `dvytr stop`
Stop the running container (preserves state).

```bash
dvytr stop
```

### `dvytr clean [-i]`
Remove the container. Use `-i` or `--image` to also remove the Docker image.

```bash
dvytr clean          # Remove container only
dvytr clean --image  # Remove container and image
```

### `dvytr list`
List all dvytr containers.

```bash
dvytr list
```

### `dvytr status`
Show status of the current project's container.

```bash
dvytr status
```

### `dvytr build`
Build or rebuild the Docker image.

```bash
dvytr build
```

### `dvytr version`
Show version information.

```bash
dvytr version
```

## Configuration

Create a `.dvytr.conf` file in your project directory to customize the container:

```bash
# Custom container name (optional, overrides automatic naming)
CONTAINER_NAME="my-custom-name"

# Port mappings (host:container)
DOCKER_PORT_MAPPINGS=("8080:8080" "3000:3000")

# Environment variables
ENV_VARS=("NODE_ENV=development" "DEBUG=true")

# Additional volume mounts
ADDITIONAL_VOLUMES=("$HOME/.ssh:/home/dev/.ssh:ro")

# Add project directories to PATH
PATH_DIRS=("bin" "scripts")
```

See `.dvytr.conf.example` for a complete example.

### Adding Directories to PATH

You can add project-specific directories to the container's PATH, making scripts and binaries in those directories directly executable. This is useful for projects with custom tooling in subdirectories.

```bash
# .dvytr.conf
PATH_DIRS=("bin" "scripts" "node_modules/.bin")
```

Paths are relative to `/workspace` (your project root) by default, but absolute paths are also supported. The directories are prepended to PATH, so they take precedence over system binaries.

**Common use cases:**
- `"bin"` - Project-specific scripts and executables
- `"scripts"` - Build or deployment scripts
- `"node_modules/.bin"` - Node.js package binaries (though most package managers handle this automatically)
- `"tools"` - Custom development tools

**Example:**
```bash
# .dvytr.conf
PATH_DIRS=("bin")
```

With this configuration, you can run scripts directly:
```bash
dvytr shell
# Inside container
my-custom-script.sh  # Runs /workspace/bin/my-custom-script.sh
```

### Port Forwarding with Socat (Usually Not Needed)

In rare cases, you may encounter a service that binds only to `127.0.0.1` (localhost) inside the container and cannot be configured to bind to `0.0.0.0`. For these situations, DevYeeter supports automatic port forwarding using socat.

**Important: This is rarely needed!** Most modern dev servers (Vite, Next.js, webpack-dev-server, etc.) can be configured to bind to all interfaces using flags or environment variables. Always try that first:

```bash
# Preferred approach - configure the service directly
ENV_VARS=("VITE_HOST=0.0.0.0")  # For Vite
# or use command flags: vite --host 0.0.0.0
```

If you truly need socat forwarding, add it to `.dvytr.conf`:

```bash
# Format: "container_port:target_host:target_port"
SOCAT_FORWARDS=("3001:127.0.0.1:3000")
DOCKER_PORT_MAPPINGS=("3001:3001")  # Map the forwarding port to host
```

This forwards requests on `0.0.0.0:3001` inside the container to `127.0.0.1:3000`, allowing you to access the service from your host machine at `localhost:3001`.

**When you might need this:**
- Legacy applications that hardcode `127.0.0.1` binding
- Third-party tools without configuration options
- Services where modifying the bind address is impractical

**When you don't need this:**
- Any service that accepts a `--host` flag or environment variable (use that instead!)
- Services you control and can configure

### Environment Variables from .env

DevYeeter automatically loads environment variables from a `.env` file in your project directory. This follows the common convention used by many development tools.

Create a `.env` file in your project directory:

```bash
# .env
NODE_ENV=development
DATABASE_URL=postgresql://localhost:5432/mydb
API_KEY=your-secret-key
DEBUG=true
PORT=3000
```

These variables will be automatically injected into the container environment when you run `dvytr run`. See `.env.example` for more examples.

**Notes:**
- Comments (lines starting with `#`) and empty lines are ignored
- Variables must follow the format `KEY=value`
- Quotes are preserved as part of the value
- Changes to `.env` require restarting the container: `dvytr stop && dvytr run`
- The `.env` file is git-ignored by default to protect secrets

## Installed Tools

The container comes pre-installed with:

### Languages & Runtimes
- **C/C++**: gcc, g++, clang
- **Python**: Python 3.x with pip and venv
- **Node.js**: v20 LTS with npm
- **pnpm**: Primary package manager for Node.js
- **TypeScript**: tsc and ts-node
- **Go**: 1.21.5
- **Rust**: Latest stable with cargo

### Development Tools
- **Debuggers**: gdb, lldb, valgrind
- **Build Tools**: make, cmake, pkg-config
- **Version Control**: git
- **Editors**: vim, emacs (command-line), nano
- **Utilities**: curl, wget, jq, tree, htop

### System
- **User**: Dedicated `dev` user with dynamic UID/GID mapping and sudo access
- **Shell**: bash
- **Base**: Ubuntu 22.04 LTS
- **Permission Handling**: Automatic UID/GID adjustment via entrypoint script

## Usage Examples

### Node.js/TypeScript Project

```bash
cd my-node-app
dvytr run
dvytr shell

# Inside container
pnpm install
pnpm dev
```

### Python Project

```bash
cd my-python-app
dvytr run
dvytr shell

# Inside container
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python app.py
```

### Go Project

```bash
cd my-go-app
dvytr run
dvytr shell

# Inside container
go mod download
go build
./my-go-app
```

### Rust Project

```bash
cd my-rust-app
dvytr run
dvytr shell

# Inside container
cargo build
cargo run
```

### With Environment Variables (.env)

```bash
cd my-project

# Create .env file with your variables
cat > .env <<EOF
DATABASE_URL=postgresql://localhost:5432/mydb
API_KEY=secret-key-123
NODE_ENV=development
DEBUG=true
EOF

# Start container (automatically loads .env)
dvytr run
dvytr shell

# Inside container - variables are available
echo $DATABASE_URL  # postgresql://localhost:5432/mydb
echo $API_KEY       # secret-key-123
node app.js         # Your app can access these env vars
```

### With Port Forwarding

Create `.dvytr.conf`:

```bash
DOCKER_PORT_MAPPINGS=("8080:8080" "3000:3000")
```

Then:

```bash
dvytr run
dvytr shell

# Inside container, start your server on port 8080 or 3000
# Access from host at localhost:8080 or localhost:3000
```

### With Vite Dev Server

For Vite (or other dev servers), configure them to bind to all interfaces:

```bash
# .dvytr.conf
DOCKER_PORT_MAPPINGS=("5173:5173")
ENV_VARS=("VITE_HOST=0.0.0.0")
```

Then just run your dev server normally:

```bash
dvytr run
dvytr shell

# Inside container
pnpm dev  # or npm run dev, vite, etc.
# Vite automatically uses VITE_HOST=0.0.0.0

# Access from host at localhost:5173
```

## How It Works

1. **One Image, Many Containers**: The Docker image is built once and stored in Docker's image cache. You can use it from any directory on your system without needing the Dockerfile there.
2. **Container Naming**: Containers are named `dvytr-<directory-name>-<hash>` by default
   - The hash is based on the full directory path, ensuring uniqueness
   - Same directory always gets the same container name (deterministic)
   - Different paths with same basename (e.g., `/tmp` vs `~/projects/tmp`) get different containers
3. **Volume Mounting**: Current directory is mounted to `/workspace` in the container
4. **Dynamic Permission Mapping**:
   - On container start, an entrypoint script detects the UID/GID of the mounted `/workspace`
   - The `dev` user's UID/GID is automatically adjusted to match your host user
   - All development tools in `/home/dev` remain accessible
   - Files created in the container are owned by your host user
   - Works seamlessly on both Linux and macOS
5. **Persistence**: Containers are stopped/started rather than recreated, preserving state
6. **Isolation**: Each project directory gets its own container

## Platform Notes

### Linux
- Dynamic UID/GID mapping ensures files created in the container match your host user ownership
- The `dev` user inside the container automatically adopts your host UID/GID
- Works with any user ID, not just 1000
- All development tools remain accessible regardless of your host UID

### macOS
- Docker Desktop's built-in file sharing handles ownership seamlessly
- The entrypoint script detects macOS and works transparently
- Performance may be slower for large projects due to filesystem virtualization

## Troubleshooting

### Container won't start
```bash
# Check Docker is running
docker ps

# Rebuild the image
dvytr build

# Check for port conflicts
dvytr clean
dvytr run
```

### Permission issues (Linux)
The container automatically detects and matches your host user's UID/GID. If you still encounter permission issues:
```bash
# Check the container logs for any UID/GID adjustment messages
# Use 'dvytr list' to see your container name
docker logs dvytr-<directory-name>-<hash>

# Rebuild the container to ensure the latest entrypoint script is used
dvytr clean
dvytr build
dvytr run
```

### Port already in use
Check your `.dvytr.conf` for port conflicts or stop other services using those ports.

## License

MIT

## Contributing

Contributions welcome! Please open an issue or pull request.
