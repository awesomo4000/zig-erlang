# Build Process and Generated Files

This document explains how we build Erlang/OTP using Zig instead of the standard autoconf/make build system, and specifically how we handle code generation and cross-compilation.

## Overview

The standard Erlang build process generates many files during compilation. We replicate these steps using Erlang's existing tools and support cross-compilation to multiple targets.

## Generated Files We Create (Via Scripts)

These files are generated using Erlang's existing Perl scripts:

| File | Generator Script | Purpose |
|------|-----------------|---------|
| `beam_opcodes.c/h` | `utils/beam_makeops` | VM instruction opcodes and dispatch table |
| `erl_bif_table.c/h` | `utils/make_tables` | Built-in function (BIF) dispatch table |
| `erl_atom_table.c/h` | `utils/make_tables` | Pre-allocated atom table |
| `erl_guard_bifs.c` | `utils/make_tables` | Guard BIF implementations and `erts_u_bifs` array |
| `erl_dirty_bif_wrap.c` | `utils/make_tables` | Dirty scheduler BIF wrappers |
| `driver_tab.c` | `utils/make_driver_tab` | Static driver and NIF registration table |

These are generated in `generated/{target}/{opt_mode}/jit/` by `build.zig` during the build process.

## YCF (Yielding C Functions) Transformation

**What YCF Does:**
Transforms blocking C functions into cooperative multitasking functions that can:
- **Yield** - pause execution and save state
- **Resume** - continue from saved state later
- **Destroy** - cleanup saved state

Example: `erts_qsort_helper()` becomes:
- `erts_qsort_ycf_gen_yielding()` - yielding version
- `erts_qsort_ycf_gen_continue()` - resume function
- `erts_qsort_ycf_gen_destroy()` - cleanup function

**Our Implementation:**
We compile and run the real YCF tool from `erts/lib_src/yielding_c_fun/`:
1. Compile YCF compiler as a native host tool
2. Run YCF on source files to generate yielding implementations
3. Produces real `.ycf.h` headers with ~9,530 lines of generated code

| Generated File | Source | Functions Transformed |
|---------------|--------|----------------------|
| `utils.ycf.h` | `beam/utils.c` | `erts_qsort_helper` |
| `erl_map.ycf.h` | `beam/erl_map.c` | Map operations |
| `erl_db_insert_list.ycf.h` | `beam/erl_db_insert_list.c` | ETS insert operations |

**Result:**
- ✅ Full cooperative multitasking support
- ✅ Proper scheduler yielding for long operations
- ✅ Production-quality latency characteristics

### Preloaded Modules (preload.c)

**Normal Erlang Build:**
1. Compiles essential Erlang modules to `.beam` bytecode:
   - `init.beam`, `erlang.beam`, `erts_internal.beam`, etc. (19 modules total)
2. Embeds them as C byte arrays using `utils/make_preload`:

```c
const unsigned char preloaded_init[] = { 0x46, 0x4f, 0x52, 0x31, ... };
const unsigned char preloaded_erlang[] = { 0x46, 0x4f, 0x52, 0x31, ... };

const struct {
   char* name;
   int size;
   const unsigned char* code;
} pre_loaded[] = {
  {"init", 12345, preloaded_init},
  {"erlang", 23456, preloaded_erlang},
  ...
};
```

**What We Did Instead:**
Created minimal stub:
```c
const struct {
   char* name;
   int size;
   const unsigned char* code;
} pre_loaded[] = {
  {0, 0, 0}  // Empty - no preloaded modules
};
```

**Trade-off:**
- ✅ Avoids bootstrapping the Erlang compiler
- ❌ VM won't be functional without loading these modules externally

## Polling System (erl_poll.c)

**Special Case:** We compile the same source file twice with different flags:

```zig
// Kernel poll version (epoll/kqueue)
beam.addCSourceFiles(.{
    .files = &[_][]const u8{"sys/common/erl_poll.c"},
    .flags = common_flags ++ [_][]const u8{"-DERTS_KERNEL_POLL_VERSION"},
});

// Fallback version (select/poll)
beam.addCSourceFiles(.{
    .files = &[_][]const u8{"sys/common/erl_poll.c"},
    .flags = common_flags ++ [_][]const u8{"-DERTS_NO_KERNEL_POLL_VERSION"},
});
```

This generates both high-performance (kernel) and portable (fallback) I/O polling implementations.

## Cross-Compilation Support

The build system supports cross-compilation to multiple targets:

### Supported Targets

| Target | Architecture | OS | JIT Backend | Status |
|--------|-------------|-----|-------------|--------|
| `aarch64-macos` | ARM64 | macOS | BEAMASM ARM64 | ✅ Working |
| `x86_64-macos` | x86_64 | macOS | BEAMASM x86_64 | ✅ Working |
| `aarch64-linux-gnu` | ARM64 | Linux (glibc) | BEAMASM ARM64 | ✅ Working |
| `x86_64-linux-gnu` | x86_64 | Linux (glibc) | BEAMASM x86_64 | ✅ Working |

### Per-Target Builds

Each target gets its own:
- **Generated files** in `generated/{target}/{opt_mode}/jit/`
- **JIT backend** (ARM64 or x86_64 BEAMASM)
- **Vendor libraries** (zlib, zstd, pcre, ryu, asmjit) built with `zig cc -target {target}`
- **Minimal termcap** implementation in Zig

### Build Script

Use `scripts/compile-all-targets.sh` to build all 4 targets:
```bash
./scripts/compile-all-targets.sh
# Creates platform-specific directories with bin/ and lib/ subdirectories
```

## Vendor Libraries

All third-party libraries are vendored and built from source:

| Library | Version | Purpose | Built With |
|---------|---------|---------|------------|
| zlib | 1.3.1 | Compression | zig cc (per-target) |
| zstd | 1.5.6 | Compression | zig cc (per-target) |
| pcre | 8.45 | Regex | zig cc (per-target) |
| ryu | Latest | Float printing | zig cc (per-target) |
| asmjit | Latest | JIT assembly | zig cc (arch-specific) |

### Minimal Termcap (Zig Implementation)

Replaced ncurses with a minimal termcap implementation in Zig (~150 lines):
- Implements 6 termcap functions: `tgetent`, `tgetstr`, `tgetnum`, `tgetflag`, `tgoto`, `tputs`
- Returns ANSI escape sequences (compatible with 99.9% of modern terminals)
- Uses `ioctl(TIOCGWINSZ)` for dynamic terminal dimensions
- No external dependencies or database files
- Result: ~10KB vs ~1.5MB (ncurses libtinfo.a)

## Helper Binaries

### erl_child_setup

Process spawning helper that handles `fork()/exec()` for the BEAM VM.

**Purpose:**
Avoids forking the multi-GB BEAM process directly. Instead, BEAM forks a small helper once at startup, then communicates with it over a Unix domain socket to spawn child processes.

**Why it exists:**
- **Page table overhead**: Even with copy-on-write, forking a large process requires copying page tables (~20MB for 10GB process)
- **Virtual memory limits**: Systems with strict overcommit disabled require swap space for theoretical full copies
- **Lock contention**: Memory management locks are held during fork, blocking other threads

**Source files:**
- `erts/emulator/sys/unix/erl_child_setup.c` - Main implementation
- `erts/emulator/sys/unix/sys_uds.c` - Unix domain socket utilities
- `erts/emulator/beam/hash.c` - Hash table for PID tracking

**Build details:**
- Links with ethread library for threading support
- Includes platform-specific headers from `erts/{target}/` and `erts/include/{target}/`

**Linux compatibility:**
- `closefrom()` is BSD-only, not available in glibc
- Provided in `build/linux_compat.c` with fallback implementation using `/dev/fd` or loop

## Source Files Not Modified

**Important:** We do NOT modify any Erlang source code. All files in `sources/otp-28.1/` are pristine.

Our generated files live in `generated/{target}/{opt_mode}/jit/` - completely separate from the original source tree.

## Build Output

Platform-specific output directories in `zig-out/`:

```
zig-out/
├── aarch64-macos/
│   └── bin/
│       ├── beam.smp
│       └── erl_child_setup
├── x86_64-macos/
│   └── bin/
│       ├── beam.smp
│       └── erl_child_setup
├── aarch64-linux/
│   └── bin/
│       ├── beam.smp
│       └── erl_child_setup
└── x86_64-linux/
    └── bin/
        ├── beam.smp
        └── erl_child_setup
```

All builds are JIT-enabled with architecture-specific BEAMASM backends.

### Binary Sizes

**Debug Builds** (default, with debug symbols):

| Target | beam.smp | erl_child_setup | Total |
|--------|----------|-----------------|-------|
| aarch64-macos | 57MB | 555KB | 57.5MB |
| x86_64-macos | 50MB | 522KB | 50.5MB |
| aarch64-linux | 79MB | 2.5MB | 81.5MB |
| x86_64-linux | 72MB | 2.4MB | 74.4MB |

**Release Builds** (`-Doptimize=ReleaseSmall`):

| Target | beam.smp | erl_child_setup | Total |
|--------|----------|-----------------|-------|
| aarch64-macos | 4.2MB | ~50KB | 4.25MB |
| x86_64-macos | 3.8MB | ~50KB | 3.85MB |
| aarch64-linux | 3.7MB | ~200KB | 3.9MB |
| x86_64-linux | 3.7MB | ~200KB | 3.9MB |

## Future Improvements

To make the VM fully functional, we would need to:
1. ✅ ~~Run YCF tool to generate proper yielding versions~~ (DONE)
2. Compile and embed preloaded Erlang modules
3. Set up proper directory structure and environment variables (BINDIR, ROOTDIR, etc.)

## References

- YCF Tool: `sources/otp-28.1/erts/lib_src/yielding_c_fun/`
- Generation Scripts: `sources/otp-28.1/erts/emulator/utils/`
- Original Makefile: `sources/otp-28.1/erts/emulator/Makefile.in`
- Generated Files: `generated/{target}/{opt_mode}/jit/`
- Build System: `build.zig`, `build/codegen.zig`, `build/vendor_libs.zig`, `build/termcap.zig`
