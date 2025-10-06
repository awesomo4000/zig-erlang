#!/usr/bin/env bash
set -euo pipefail

echo "==> Building minimal BEAM VM with ReleaseSmall..."
zig build -Doptimize=ReleaseSmall

# Detect target architecture
ARCH=$(uname -m)
OS=$(uname -s | tr '[:upper:]' '[:lower:]')

case "$ARCH" in
    arm64) TARGET_ARCH="aarch64" ;;
    x86_64) TARGET_ARCH="x86_64" ;;
    *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

case "$OS" in
    darwin) TARGET_OS="macos" ;;
    linux) TARGET_OS="linux-gnu" ;;
    mingw*|msys*|cygwin*) TARGET_OS="windows-gnu" ;;
    *) echo "Unsupported OS: $OS"; exit 1 ;;
esac

TARGET="${TARGET_ARCH}-${TARGET_OS}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BIN_DIR="${PROJECT_ROOT}/zig-out/${TARGET}/bin"
ROOT_DIR="${PROJECT_ROOT}/zig-out/${TARGET}"

# Windows needs .exe extension
if [[ "$TARGET_OS" == "windows-gnu" ]]; then
    BEAM_EXE="beam.smp.exe"
else
    BEAM_EXE="beam.smp"
fi

echo "==> Target: ${TARGET}"
echo "==> Testing BEAM VM..."

# Run Erlang code that prints "it works" and exits
OUTPUT=$(BINDIR="${BIN_DIR}" ROOTDIR="${ROOT_DIR}" "${BIN_DIR}/${BEAM_EXE}" -- \
    -root "${ROOT_DIR}" \
    -bindir "${BIN_DIR}" \
    -progname erl -- \
    -home "${HOME}" \
    -noshell \
    -eval 'io:format("hello from Erlang!~n").' \
    -s init stop 2>&1)

echo "${OUTPUT}"

# Check if output contains "it works"
if echo "${OUTPUT}" | grep -q "hello"; then
    echo ""
    echo "✅ Test PASSED: BEAM VM is working correctly!"
    exit 0
else
    echo ""
    echo "❌ Test FAILED: Expected output 'it works' not found"
    exit 1
fi
