# zig-erlang

Building Erlang/OTP 28.1 BEAM VM with JIT using the Zig build system.

## Quick Start

```bash
# Extract sources (if not already done)
tar -xzf sources/otp_src_28.1.tar.gz -C sources/
tar -xzf sources/ncurses-6.5.tar.gz -C sources/

# Build
zig build

# Output
zig-out/bin/beam.smp
```

## Documentation

- **[BUILD.md](BUILD.md)** - Detailed build process, generated files, and YCF transformations
- **[beam_sources.md](beam_sources.md)** - Complete source file inventory for BEAM VM

## What This Does

Builds a complete BEAM VM (56MB executable) without using autoconf/make:
- ✅ JIT compiler (BEAMASM) for ARM64
- ✅ All runtime systems (scheduler, GC, etc.)
- ✅ NIFs and drivers
- ✅ Vendored libraries (zlib, zstd, pcre, ryu)
- ✅ Real YCF coroutine transformations (9,530 lines generated)
- ⚠️ No preloaded modules (VM needs external setup)

## Architecture

- **Primary Target:** ARM64 macOS (aarch64-macos-none)
- **Cross-Compilation:** x86_64 Linux (experimental, 30/33 steps working)
- **Build Tool:** Zig 0.15.1
- **Source:** Erlang/OTP 28.1 (unmodified)
- **Output:** Static executable with JIT support

### Cross-Compilation Support

Cross-compile for Linux:
```bash
zig build -Dtarget=x86_64-linux-gnu
```

**Cross-Compilation Status (Linux x86_64):**
- ✅ 30/33 build steps succeed
- ✅ ncurses made optional (skipped when cross-compiling)
- ✅ `_GNU_SOURCE` flags added for Linux extensions
- ✅ Platform-specific config.h generated via Docker (without termcap)
- ⚠️ 5 remaining errors (ARM JIT code compiled for x86 target)

**Generating Linux config.h:**
```bash
# Use Docker to generate Linux-specific configuration (without termcap for cross-compile)
docker run --rm -v $(pwd)/sources/otp-28.1:/tmp/otp -w /tmp/otp \
  debian:bookworm bash -c \
  "apt-get update -qq && \
   apt-get install -y -qq build-essential autoconf perl && \
   ./configure --host=x86_64-unknown-linux-gnu --without-termcap"
```

**Important:** Source tarballs are located in `sources/` directory.

### Build System Structure

Modularized for AI context optimization:
- `build.zig` (999 lines) - Main build logic and ERTS compilation
- `build/codegen.zig` (305 lines) - Code generation (Perl scripts, YCF)
- `build/vendor_libs.zig` (447 lines) - Vendor library builds (zlib, zstd, pcre, etc.)

## Status

**Working:**
- ✅ Compiles all BEAM VM source files
- ✅ Links successfully (zero undefined symbols)
- ✅ Generates 56MB ARM64 executable
- ✅ YCF yielding transformations (real coroutine implementations)
- ✅ All 33 build steps succeed

**Not Yet Implemented:**
- ⚠️ Runtime environment setup (BINDIR, preloaded modules)
- ⚠️ Full Erlang distribution (just VM binary for now)

See [BUILD.md](BUILD.md) for details on the build process.
