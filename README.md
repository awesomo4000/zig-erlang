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

- **[BUILD.md](BUILD.md)** - Detailed build process, generated files, and YCF stubs explanation
- **[beam_sources.md](beam_sources.md)** - Complete source file inventory for BEAM VM

## What This Does

Builds a complete BEAM VM (56MB executable) without using autoconf/make:
- ✅ JIT compiler (BEAMASM) for ARM64
- ✅ All runtime systems (scheduler, GC, etc.)
- ✅ NIFs and drivers
- ✅ Vendored libraries (zlib, zstd, pcre, ryu)
- ⚠️ Non-yielding stubs (simplified for minimal build)
- ⚠️ No preloaded modules (VM needs external setup)

## Architecture

- **Target:** ARM64 macOS (aarch64-macos-none)
- **Build Tool:** Zig 0.15.1
- **Source:** Erlang/OTP 28.1 (unmodified)
- **Output:** Static executable with JIT support

## Status

**Working:**
- ✅ Compiles all BEAM VM source files
- ✅ Links successfully (zero undefined symbols)
- ✅ Generates 56MB ARM64 executable

**Not Yet Implemented:**
- ⚠️ Runtime environment setup (BINDIR, preloaded modules)
- ⚠️ YCF yielding transformations (using non-yielding stubs)
- ⚠️ Full Erlang distribution (just VM binary for now)

See [BUILD.md](BUILD.md) for details on the trade-offs.
