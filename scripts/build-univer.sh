#!/bin/bash

# Get script directory and set paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR/.."
STATIC_RESOURCES="$ROOT/force-app/main/default/staticresources"
UNIVER_DIR="$ROOT/univer"

# Add trap to handle Ctrl+C
trap 'echo -e "\nScript interrupted by user. Exiting..."; exit 1' SIGINT

echo "-----------------------------------------"
echo "Checking environment..."
echo "-----------------------------------------"

# Function to compare versions
version_gt() {
    test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"
}

# Check Node.js version
NODE_VERSION=$(node -v | cut -d "v" -f 2)
MIN_NODE_VERSION="20.18.0"

if ! version_gt "$NODE_VERSION" "$MIN_NODE_VERSION"; then
    echo "Node.js version must be >= 20.18.0"
    echo "Current version: $NODE_VERSION"
    echo ""
    echo "Options to upgrade Node.js:"
    echo "1. Download and install from https://nodejs.org/"
    if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
        echo "2. Use nvm-windows to manage multiple versions:"
        echo "   https://github.com/coreybutler/nvm-windows"
    else
        echo "2. Use nvm to manage multiple versions:"
        echo "   curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash"
    fi
    exit 1
fi

# Check pnpm version
if ! command -v pnpm &> /dev/null; then
    echo "pnpm is required but not installed."
    echo "To install pnpm:"
    echo "npm install -g pnpm"
    exit 1
fi

PNPM_VERSION=$(pnpm -v)
MIN_PNPM_VERSION="10.0.0"

if ! version_gt "$PNPM_VERSION" "$MIN_PNPM_VERSION"; then
    echo "pnpm version must be >= 10.0.0"
    echo "Current version: $PNPM_VERSION"
    echo ""
    echo "To upgrade pnpm:"
    echo "npm install -g pnpm@latest"
    exit 1
fi

# Check turbo
if ! command -v turbo &> /dev/null; then
    echo "turbo is required but not installed."
    echo "To install turbo:"
    echo "npm install -g turbo"
    exit 1
fi

echo "✓ Node.js v$NODE_VERSION"
echo "✓ pnpm v$PNPM_VERSION"
echo "✓ turbo is installed"
echo ""

echo "-----------------------------------------"
echo "Building Univer..."
echo "-----------------------------------------"

# Check if node_modules exists in univer directory
if [ ! -d "$UNIVER_DIR/node_modules" ]; then
    echo "Installing dependencies..."
    cd "$UNIVER_DIR" || exit 1
    pnpm install
    cd "$ROOT" || exit 1
fi

# Build Univer
cd "$UNIVER_DIR" || exit 1
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
    local dest_name=$(basename "$dest")
    if [ -f "$src" ]; then
        if cp "$src" "$dest"; then
            local size=$(stat -c%s "$src" 2>/dev/null || stat -f%z "$src" 2>/dev/null)
            # Convert to KB without bc command
            local size_kb=$((size / 1024))
            echo "✓ Copied $dest_name ($size_kb KB)"
        else
            echo "✕ Failed to copy $dest_name"
            return 1
        fi
    else
        echo "- Skipped $dest_name (source file not found)"
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

# Copy facade files (only if they exist in source)
if [ -f "$UNIVER_DIR/packages/sheets/lib/umd/facade.js" ] || [ -f "$UNIVER_DIR/packages/docs/lib/umd/facade.js" ]; then
    echo "Copying facade files..."
    if [ -f "$UNIVER_DIR/packages/sheets/lib/umd/facade.js" ]; then
        copy_file "$UNIVER_DIR/packages/sheets/lib/umd/facade.js" "$STATIC_RESOURCES/univer-sheets-facade.js"
    fi
    if [ -f "$UNIVER_DIR/packages/docs/lib/umd/facade.js" ]; then
        copy_file "$UNIVER_DIR/packages/docs/lib/umd/facade.js" "$STATIC_RESOURCES/univer-docs-facade.js"
    fi
fi

echo "-----------------------------------------"
echo "Build and copy operations completed"
echo "-----------------------------------------" 