#!/bin/bash
set -e

# Compile all supported targets for zig-erlang
# Usage: ./compile-all-targets.sh [optimize_mode]
#   optimize_mode: Debug (default), ReleaseFast, ReleaseSafe, ReleaseSmall

OPTIMIZE_MODE="${1:-Debug}"

# Determine host architecture
HOST_ARCH=$(uname -m)
HOST_OS=$(uname -s | tr '[:upper:]' '[:lower:]')

# Map host arch to target format
case "$HOST_ARCH" in
    arm64) HOST_ARCH="aarch64" ;;
    x86_64) HOST_ARCH="x86_64" ;;
esac

case "$HOST_OS" in
    darwin) HOST_OS="macos" ;;
    linux) HOST_OS="linux-gnu" ;;
esac

HOST_TARGET="${HOST_ARCH}-${HOST_OS}"

TARGETS=(
    "aarch64-macos"
    "x86_64-macos"
    "aarch64-linux-gnu"
    "x86_64-linux-gnu"
)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo "Building all targets (host: $HOST_TARGET, optimize: $OPTIMIZE_MODE)..."
echo

for target in "${TARGETS[@]}"; do
    echo "Building $target..."

    # For native target, don't specify -Dtarget (avoids cross-compilation behavior)
    if [ "$target" = "$HOST_TARGET" ]; then
        zig build -Doptimize="$OPTIMIZE_MODE"
    else
        zig build -Dtarget="$target" -Doptimize="$OPTIMIZE_MODE"
    fi

    echo "✓ Built $target"
    echo
done

echo "All targets built successfully!"
echo
echo "Output directories:"
ls -d zig-out/*/
echo
echo "Binaries:"
ls -lh zig-out/*/bin/beam.smp
