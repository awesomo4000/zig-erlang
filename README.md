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
- ✅ Cross-compilation support for 6 targets
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
zig build -Dtarget=x86_64-linux-musl
zig build -Dtarget=aarch64-linux-musl
zig build -Dtarget=x86_64-macos
zig build -Dtarget=aarch64-macos  # or just: zig build
zig build -Dtarget=x86_64-windows-gnu
zig build -Dtarget=aarch64-windows-gnu

# Build all targets at once
./scripts/compile-all-targets.sh
```

**Supported Targets:**
- ✅ **aarch64-macos** - ARM64 macOS (Apple Silicon)
- ✅ **x86_64-macos** - Intel macOS
- ✅ **aarch64-linux-gnu** - ARM64 Linux (glibc, dynamic)
- ✅ **x86_64-linux-gnu** - x86_64 Linux (glibc, dynamic)
- ✅ **aarch64-linux-musl** - ARM64 Linux (musl, fully static)
- ✅ **x86_64-linux-musl** - x86_64 Linux (musl, fully static)
- ✅ **aarch64-windows-gnu** - ARM64 Windows (builds)
- ✅ **x86_64-windows-gnu** - x86_64 Windows (builds)

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
├── x86_64-linux/
│   ├── bin/beam.smp
│   └── lib/libtinfo.a
├── aarch64-windows/
│   └── bin/beam.smp.exe
└── x86_64-windows/
    └── bin/beam.smp.exe
```

**Binary Sizes:**

Debug builds (default):
- macOS: 49-56MB per platform
- Linux (glibc): 70-78MB per platform
- Linux (musl): 80MB per platform
- Windows: 5.8-49MB per platform

Release builds (`-Doptimize=ReleaseSmall`):
- macOS: 3.8-4.2MB per platform
- Linux (glibc): 3.7-3.8MB per platform
- Linux (musl): 3.8MB per platform (fully static, zero dependencies)
- Windows: TBD

See [BUILD.md](BUILD.md) for detailed size breakdown.

**Key Features:**
- Architecture-aware JIT backend selection (ARM64/x86_64)
- Minimal termcap implementation in Zig (~10KB, replaces ncurses)
- Platform-specific configurations and flags
- Static linking of all dependencies
- Fully static musl binaries for portable Linux deployment

**Important:** Source tarball must be extracted to `sources/` directory before building.

### Build System Structure

Modularized for AI context optimization:
- `build.zig` - Main build logic, ERTS compilation, cross-compilation
- `build/codegen.zig` - Code generation (Perl scripts, YCF transformations)
- `build/vendor_libs.zig` - Vendor libraries (zlib, zstd, pcre, ryu, asmjit)
- `build/termcap_mini.zig` - Minimal termcap implementation
- `build/linux_compat.c` - Linux compatibility (closefrom implementation)
- `build/zig_compat.h` - Compatibility for musl vs glibc
- `scripts/compile-all-targets.sh` - Build all 8 targets

## Status

**Working:**
- ✅ Cross-compilation to 8 targets (macOS, Linux, Windows - ARM64/x86_64)
- ✅ Architecture-specific JIT compilation (BEAMASM)
- ✅ Process spawning helper (`erl_child_setup`) for all targets
- ✅ All vendor libraries built per-target with zig cc
- ✅ Minimal termcap in Zig (replaces ncurses, ~10KB vs ~1.5MB)
- ✅ Linux compatibility layer (closefrom, dlvsym, mallopt for musl)
- ✅ Zero undefined symbols, all targets link successfully
- ✅ YCF yielding transformations (real coroutine implementations)
- ✅ Fully static musl binaries with zero dynamic dependencies

**Not Yet Implemented:**
- ⚠️ Runtime environment setup (BINDIR, preloaded modules)
- ⚠️ Full Erlang distribution (just VM binary for now)

See [BUILD.md](BUILD.md) for details on the build process.
