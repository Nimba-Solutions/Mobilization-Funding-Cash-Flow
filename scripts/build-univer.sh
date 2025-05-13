#!/bin/bash

# Get script directory and set paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR/.."
STATIC_RESOURCES="$ROOT/force-app/main/default/staticresources"
UNIVER_DIR="$ROOT/univer"

# Add trap to handle Ctrl+C
trap 'echo -e "\nScript interrupted by user. Exiting..."; exit 1' SIGINT

echo "-----------------------------------------"
echo "Building Univer..."
echo "-----------------------------------------"

# Check if pnpm is installed
if ! command -v pnpm &> /dev/null; then
    echo "pnpm is not installed. Please install it first:"
    echo "npm install -g pnpm"
    exit 1
fi

# Build Univer
cd "$UNIVER_DIR" || exit 1
echo "Installing dependencies..."
pnpm install

echo "Building packages..."
pnpm build

echo "-----------------------------------------"
echo "Copying UMD files to staticresources..."
echo "-----------------------------------------"

# Create the directory if it doesn't exist
mkdir -p "$STATIC_RESOURCES"

# Function to copy file and echo status
copy_file() {
    local src="$1"
    local dest="$2"
    if [ -f "$src" ]; then
        if cp "$src" "$dest"; then
            echo "SUCCESS: Copied $(basename "$src")"
        else
            echo "FAILED: Could not copy $(basename "$src")"
            return 1
        fi
    else
        echo "SKIPPED: File not found - $(basename "$src")"
    fi
}

# Copy core UMD files
echo "Copying core files..."
copy_file "$UNIVER_DIR/packages/core/lib/umd/index.js" "$STATIC_RESOURCES/univer-core.js"
copy_file "$UNIVER_DIR/packages/sheets/lib/umd/index.js" "$STATIC_RESOURCES/univer-sheets.js"
copy_file "$UNIVER_DIR/packages/docs/lib/umd/index.js" "$STATIC_RESOURCES/univer-docs.js"
copy_file "$UNIVER_DIR/packages/engine-render/lib/umd/index.js" "$STATIC_RESOURCES/univer-engine-render.js"
copy_file "$UNIVER_DIR/packages/engine-formula/lib/umd/index.js" "$STATIC_RESOURCES/univer-engine-formula.js"

# Copy UI files
echo "Copying UI files..."
copy_file "$UNIVER_DIR/packages/sheets-ui/lib/umd/index.js" "$STATIC_RESOURCES/univer-sheets-ui.js"
copy_file "$UNIVER_DIR/packages/docs-ui/lib/umd/index.js" "$STATIC_RESOURCES/univer-docs-ui.js"

# Copy facade files (if they exist)
echo "Copying facade files..."
copy_file "$UNIVER_DIR/packages/sheets/lib/umd/facade.js" "$STATIC_RESOURCES/univer-sheets-facade.js"
copy_file "$UNIVER_DIR/packages/docs/lib/umd/facade.js" "$STATIC_RESOURCES/univer-docs-facade.js"

echo "-----------------------------------------"
echo "Build and copy operations completed"
echo "-----------------------------------------" 