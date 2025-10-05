# zig-erlang

Building Erlang/OTP 28.1 BEAM VM with JIT using the Zig build system.

## Quick Start

```bash
# Extract Erlang source (if not already done)
tar -xzf erlang-source/otp_src_28.1.tar.gz

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

- **Target:** ARM64 macOS (aarch64-macos-none)
- **Build Tool:** Zig 0.15.1
- **Source:** Erlang/OTP 28.1 (unmodified)
- **Output:** Static executable with JIT support

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
