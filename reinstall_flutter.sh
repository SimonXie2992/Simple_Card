#!/bin/bash
set -e

# Define paths
FLUTTER_DIR="$HOME/Development/flutter"
BACKUP_DIR="$HOME/Development/flutter_backup_$(date +%s)"

echo "Starting Flutter reinstall..."

# 1. Backup existing Flutter SDK
if [ -d "$FLUTTER_DIR" ]; then
    echo "Backing up current Flutter SDK to $BACKUP_DIR..."
    mv "$FLUTTER_DIR" "$BACKUP_DIR"
else
    echo "No existing Flutter directory found at $FLUTTER_DIR."
fi

# 2. Clone fresh Flutter SDK
echo "Cloning stable channel from git..."
git clone https://github.com/flutter/flutter.git -b stable "$FLUTTER_DIR"

# 3. Initialize Flutter
echo "Initializing Flutter (this may take a few minutes)..."
"$FLUTTER_DIR/bin/flutter" doctor

echo "Flutter successfully reinstalled!"
