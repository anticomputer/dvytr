#!/bin/bash
set -e

# This entrypoint script dynamically adjusts the dev user's UID/GID
# to match the owner of the mounted /workspace directory.
# This ensures proper file permissions on Linux hosts.

# If we're not running as root, just execute the command
if [ "$(id -u)" -ne 0 ]; then
    exec "$@"
fi

# Get the UID and GID of the /workspace directory
WORKSPACE_UID=$(stat -c '%u' /workspace 2>/dev/null || stat -f '%u' /workspace 2>/dev/null || echo "1000")
WORKSPACE_GID=$(stat -c '%g' /workspace 2>/dev/null || stat -f '%g' /workspace 2>/dev/null || echo "1000")

# Get current dev user UID and GID
CURRENT_UID=$(id -u dev)
CURRENT_GID=$(id -g dev)

# On macOS Docker Desktop, mounted volumes appear as root-owned (UID=0)
# In this case, keep dev user at UID=1000 since permission mapping is handled by Docker
if [ "$WORKSPACE_UID" = "0" ]; then
    echo "[dvytr] Detected macOS Docker Desktop (workspace shows as root), keeping dev user at UID=1000"
    # Ensure /home/dev is owned by dev user
    chown -R dev:dev /home/dev 2>/dev/null || true
# Only adjust if there's a mismatch and not UID 0
elif [ "$WORKSPACE_UID" != "$CURRENT_UID" ] || [ "$WORKSPACE_GID" != "$CURRENT_GID" ]; then
    echo "[dvytr] Adjusting dev user permissions: UID=$WORKSPACE_UID GID=$WORKSPACE_GID"

    # Modify the dev user's GID if needed
    if [ "$WORKSPACE_GID" != "$CURRENT_GID" ]; then
        groupmod -g "$WORKSPACE_GID" dev 2>/dev/null || true
    fi

    # Modify the dev user's UID if needed
    if [ "$WORKSPACE_UID" != "$CURRENT_UID" ]; then
        usermod -u "$WORKSPACE_UID" dev 2>/dev/null || true
    fi

    # Fix ownership of dev user's home directory and important files
    chown -R "$WORKSPACE_UID:$WORKSPACE_GID" /home/dev 2>/dev/null || true
else
    # UIDs match, just ensure /home/dev permissions are correct
    chown -R dev:dev /home/dev 2>/dev/null || true
fi

# Start socat port forwards if configured
# Expected format: SOCAT_FORWARD_0="5725:127.0.0.1:5724" SOCAT_FORWARD_1="8080:127.0.0.1:3000" etc.
i=0
while true; do
    var_name="SOCAT_FORWARD_$i"
    forward="${!var_name}"

    if [ -z "$forward" ]; then
        break
    fi

    # Parse format: listen_port:target_host:target_port
    listen_port=$(echo "$forward" | cut -d: -f1)
    target_host=$(echo "$forward" | cut -d: -f2)
    target_port=$(echo "$forward" | cut -d: -f3)

    echo "[dvytr] Starting socat forward: 0.0.0.0:$listen_port -> $target_host:$target_port"
    nohup socat TCP4-LISTEN:$listen_port,fork,bind=0.0.0.0,reuseaddr TCP4:$target_host:$target_port >/dev/null 2>&1 &

    i=$((i + 1))
done

# Add custom PATH directories if configured
# Expected format: PATH_DIR_0="bin" PATH_DIR_1="scripts" etc.
CUSTOM_PATH=""
i=0
while true; do
    var_name="PATH_DIR_$i"
    path_dir="${!var_name}"

    if [ -z "$path_dir" ]; then
        break
    fi

    # Convert relative path to absolute (relative to /workspace)
    if [[ "$path_dir" != /* ]]; then
        path_dir="/workspace/$path_dir"
    fi

    if [ -n "$CUSTOM_PATH" ]; then
        CUSTOM_PATH="$path_dir:$CUSTOM_PATH"
    else
        CUSTOM_PATH="$path_dir"
    fi

    echo "[dvytr] Adding to PATH: $path_dir"
    i=$((i + 1))
done

# Prepend custom paths to PATH if any were configured
# Write to /etc/profile.d/ so it persists for all bash sessions (including docker exec)
if [ -n "$CUSTOM_PATH" ]; then
    echo "export PATH=\"$CUSTOM_PATH:\$PATH\"" > /etc/profile.d/dvytr-path.sh
    chmod +x /etc/profile.d/dvytr-path.sh
    export PATH="$CUSTOM_PATH:$PATH"
fi

# Fix SSH agent socket permissions if it exists
# The socket is mounted from host but needs to be accessible by dev user
if [ -n "$SSH_AUTH_SOCK" ] && [ -S "$SSH_AUTH_SOCK" ]; then
    echo "[dvytr] Adjusting SSH agent socket permissions"
    chmod 666 "$SSH_AUTH_SOCK"
fi

# Run initialization script if configured and not already initialized
DVYTR_DIR="/workspace/.dvytr"
INIT_MARKER="$DVYTR_DIR/.initialized"

if [ -n "$DVYTR_INIT_SCRIPT" ] && [ ! -f "$INIT_MARKER" ]; then
    INIT_SCRIPT_PATH="/workspace/$DVYTR_INIT_SCRIPT"

    if [ -f "$INIT_SCRIPT_PATH" ]; then
        echo "[dvytr] Running initialization script: $DVYTR_INIT_SCRIPT"

        # Create .dvytr directory if it doesn't exist
        mkdir -p "$DVYTR_DIR"
        chown "$WORKSPACE_UID:$WORKSPACE_GID" "$DVYTR_DIR" 2>/dev/null || chown dev:dev "$DVYTR_DIR"

        # Run the init script as dev user
        if gosu dev bash "$INIT_SCRIPT_PATH"; then
            # Create marker file on success
            gosu dev touch "$INIT_MARKER"
            echo "[dvytr] Initialization complete"
        else
            echo "[dvytr] WARNING: Initialization script failed (exit code: $?)"
            echo "[dvytr] Container will continue, but dependencies may be missing"
        fi
    else
        echo "[dvytr] WARNING: Init script not found: $INIT_SCRIPT_PATH"
    fi
fi

# Execute the command as the dev user
exec gosu dev "$@"
