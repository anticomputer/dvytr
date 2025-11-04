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

# Only adjust if there's a mismatch
if [ "$WORKSPACE_UID" != "$CURRENT_UID" ] || [ "$WORKSPACE_GID" != "$CURRENT_GID" ]; then
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
fi

# Execute the command as the dev user
exec gosu dev "$@"
