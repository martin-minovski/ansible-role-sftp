#!/bin/bash
# /usr/local/sbin/sftp-perm-watcher.sh

TARGET_DIR="$1"
OWNER="$2"
GROUP="$3"

if [ -z "$TARGET_DIR" ] || [ -z "$OWNER" ] || [ -z "$GROUP" ]; then
    echo "Usage: $0 <target_dir> <owner> <group>"
    exit 1
fi

# 1. Startup Baseline Sweep (Safely ignoring dependencies)
echo "Performing baseline sweep on $TARGET_DIR..."
# Change ownership, but skip dependency folders
find "$TARGET_DIR" -maxdepth 1 -mindepth 1 -not -name "node_modules" -not -name "vendor" -exec chown -R "$OWNER:$GROUP" {} +

# Fix permissions, but skip dependency folders so we don't break executables
find "$TARGET_DIR" -type d -not -path "*/node_modules/*" -not -path "*/vendor/*" -exec chmod 2775 {} +
find "$TARGET_DIR" -type f -not -path "*/node_modules/*" -not -path "*/vendor/*" -exec chmod 0664 {} +

echo "Baseline secure. Entering real-time watch mode..."

# 2. Event-Driven Real-Time Enforcement
# Added --exclude to ignore node_modules and vendor directories
inotifywait -m -r -e create,close_write,moved_to \
    --excludei '(/node_modules/|/vendor/)' \
    --format '%w%f' "$TARGET_DIR" 2>/dev/null | while read -r CHANGED_PATH; do

    [ ! -e "$CHANGED_PATH" ] && continue

    chown "$OWNER:$GROUP" "$CHANGED_PATH"

    if [ -d "$CHANGED_PATH" ]; then
        chmod 2775 "$CHANGED_PATH"
    elif [ -f "$CHANGED_PATH" ]; then
        chmod 0664 "$CHANGED_PATH"
    fi
done