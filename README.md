# zig-erlang

Building Erlang/OTP 28.1 BEAM VM with JIT using the Zig build system.

## Quick Start

```bash
# Extract sources (if not already done)
tar -xzf sources/otp_src_28.1.tar.gz -C sources/

# Build
zig build

# Output (organized by platform)
zig-out/aarch64-macos/bin/beam.smp
zig-out/aarch64-macos/bin/erl_child_setup
```

## Documentation

- **[BUILD.md](BUILD.md)** - Detailed build process, generated files, and YCF transformations
- **[beam_sources.md](beam_sources.md)** - Complete source file inventory for BEAM VM

## What This Does

Builds a complete BEAM VM without using autoconf/make:
- ✅ JIT compiler (BEAMASM) for ARM64 and x86_64
- ✅ All runtime systems (scheduler, GC, etc.)
- ✅ NIFs and drivers
- ✅ Process spawning helper (`erl_child_setup`)
- ✅ Vendored libraries (zlib, zstd, pcre, ryu)
- ✅ Minimal termcap implementation (Zig, replaces ncurses)
- ✅ Real YCF coroutine transformations (9,530 lines generated)
- ✅ Cross-compilation support for 4 targets
- ⚠️ No preloaded modules (VM needs external setup)

## Architecture

- **Build Tool:** Zig 0.15.1
- **Source:** Erlang/OTP 28.1 (unmodified)
- **Output:** Static executable with JIT support

### Cross-Compilation Support

Build for all supported targets:
```bash
# Build for specific target
zig build -Dtarget=x86_64-linux-gnu
zig build -Dtarget=aarch64-linux-gnu
zig build -Dtarget=x86_64-macos
zig build -Dtarget=aarch64-macos  # or just: zig build

# Build all targets at once
./scripts/compile-all-targets.sh
```

**Supported Targets (All Working):**
- ✅ **aarch64-macos** - ARM64 macOS (Apple Silicon)
- ✅ **x86_64-macos** - Intel macOS
- ✅ **aarch64-linux-gnu** - ARM64 Linux (glibc)
- ✅ **x86_64-linux-gnu** - x86_64 Linux (glibc)

**Output Structure:**

Each target gets its own directory with bin/ and lib/ subdirectories:
```
zig-out/
├── aarch64-macos/
│   ├── bin/beam.smp
│   └── lib/libtinfo.a
├── x86_64-macos/
│   ├── bin/beam.smp
│   └── lib/libtinfo.a
├── aarch64-linux/
│   ├── bin/beam.smp
│   └── lib/libtinfo.a
└── x86_64-linux/
    ├── bin/beam.smp
    └── lib/libtinfo.a
```

**Binary Sizes:**

Debug builds (default):
- macOS: 49-56MB per platform
- Linux: 70-78MB per platform

Release builds (`-Doptimize=ReleaseSmall`):
- macOS: 3.8-4.2MB per platform
- Linux: 3.7MB per platform

See [BUILD.md](BUILD.md) for detailed size breakdown.

**Key Features:**
- Architecture-aware JIT backend selection (ARM64/x86_64)
- Minimal termcap implementation in Zig (~10KB, replaces ncurses)
- Platform-specific configurations and flags
- Static linking of all dependencies

**Important:** Source tarball must be extracted to `sources/` directory before building.

### Build System Structure

Modularized for AI context optimization:
- `build.zig` - Main build logic, ERTS compilation, cross-compilation
- `build/codegen.zig` - Code generation (Perl scripts, YCF transformations)
- `build/vendor_libs.zig` - Vendor libraries (zlib, zstd, pcre, ryu, asmjit)
- `build/termcap/termcap.zig` - Minimal termcap implementation
- `build/linux_compat.c` - Linux compatibility (closefrom implementation)
- `build/zig_compat.h` - Compatibility for musl vs glibc
- `scripts/compile-all-targets.sh` - Build all 4 targets

## Status

**Working:**
- ✅ Cross-compilation to 4 targets (macOS ARM64/x86_64, Linux ARM64/x86_64)
- ✅ Architecture-specific JIT compilation (BEAMASM)
- ✅ Process spawning helper (`erl_child_setup`) for all targets
- ✅ All vendor libraries built per-target with zig cc
- ✅ Minimal termcap in Zig (replaces ncurses, ~10KB vs ~1.5MB)
- ✅ Linux compatibility layer (closefrom implementation)
- ✅ Zero undefined symbols, all targets link successfully
- ✅ YCF yielding transformations (real coroutine implementations)

**Not Yet Implemented:**
- ⚠️ Runtime environment setup (BINDIR, preloaded modules)
- ⚠️ Full Erlang distribution (just VM binary for now)

See [BUILD.md](BUILD.md) for details on the build process.
