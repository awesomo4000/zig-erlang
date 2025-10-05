#!/bin/bash
# Generate Windows config.h files using zig cc as cross-compiler
set -e

ARCH=${1:-x86_64}  # x86_64 or aarch64
OTP_SRC="sources/otp-28.1"
BUILD_DIR="build-temp-windows-${ARCH}"

echo "Generating Windows config.h for ${ARCH} using zig cc..."

# Clean previous build
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Create wrapper scripts for zig cc to pretend to be cl.exe/MSVC
mkdir -p wrapper
cat > wrapper/cc << 'EOF'
#!/bin/bash
exec zig cc -target ${ZIG_TARGET} "$@"
EOF
chmod +x wrapper/cc

cat > wrapper/cl.exe << 'EOF'
#!/bin/bash
exec zig cc -target ${ZIG_TARGET} "$@"
EOF
chmod +x wrapper/cl.exe

cat > wrapper/link.exe << 'EOF'
#!/bin/bash
exec zig cc -target ${ZIG_TARGET} "$@"
EOF
chmod +x wrapper/link.exe

cat > wrapper/rc.exe << 'EOF'
#!/bin/bash
# Resource compiler stub - just return success
exit 0
EOF
chmod +x wrapper/rc.exe

# Set up environment
export ZIG_TARGET="${ARCH}-windows-gnu"
export PATH="$(pwd)/wrapper:$PATH"
export CC="$(pwd)/wrapper/cc"
export CXX="$(pwd)/wrapper/cc"
export AR="ar"
export RANLIB="ranlib"
export OVERRIDE_TARGET="win32"

# Determine mingw host triplet
if [ "$ARCH" = "x86_64" ]; then
    HOST_TRIPLET="x86_64-w64-mingw32"
else
    HOST_TRIPLET="aarch64-w64-mingw32"
fi

# Run configure
echo "Running configure for Windows ${ARCH} (${HOST_TRIPLET})..."
../$OTP_SRC/configure \
    --build=x86_64-apple-darwin \
    --host=${HOST_TRIPLET} \
    --without-javac \
    --without-odbc \
    --without-ssl \
    --without-wx \
    --without-termcap \
    2>&1 | tee configure.log || true

# Check what was generated
echo ""
echo "Generated config files:"
find . -name "config.h" -o -name "*config*.h" 2>/dev/null | sort

# Copy to sources directory with simplified naming
CONFIG_DIR="${ARCH}-unknown-windows"
if [ -f "../$OTP_SRC/erts/${HOST_TRIPLET}/config.h" ]; then
    mkdir -p "../$OTP_SRC/erts/${CONFIG_DIR}"
    cp "../$OTP_SRC/erts/${HOST_TRIPLET}/config.h" "../$OTP_SRC/erts/${CONFIG_DIR}/"
    echo "Copied config.h to $OTP_SRC/erts/${CONFIG_DIR}/"
fi

# Copy other config headers if they exist
for header in "../$OTP_SRC/erts/include/${HOST_TRIPLET}"/*.h "../$OTP_SRC/erts/include/internal/${HOST_TRIPLET}"/*.h; do
    if [ -f "$header" ]; then
        target_dir="../$OTP_SRC/$(dirname $header | sed "s|${HOST_TRIPLET}|${CONFIG_DIR}|" | sed 's|.*/sources/otp-28.1/||')"
        mkdir -p "$target_dir"
        cp "$header" "$target_dir/"
        echo "Copied $(basename $header) to $target_dir/"
    fi
done

echo ""
echo "Done! Check $BUILD_DIR for generated files"
