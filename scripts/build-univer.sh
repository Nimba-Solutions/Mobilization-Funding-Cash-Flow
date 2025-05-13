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
MIN_NODE_VERSION="20.0.0"

if ! version_gt "$NODE_VERSION" "$MIN_NODE_VERSION"; then
    echo "Node.js version must be >= 20.0.0"
    echo "Current version: $NODE_VERSION"
    echo ""
    echo "Options to upgrade Node.js:"
    echo "1. Download and install from https://nodejs.org/"
    
    # Detect OS and suggest appropriate nvm
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

echo "✓ Node.js v$NODE_VERSION"
echo "✓ pnpm v$PNPM_VERSION"
echo ""

echo "-----------------------------------------"
echo "Building Univer..."
echo "-----------------------------------------"

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