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
- **ncurses** (libtinfo.a) cross-compiled with platform-specific flags

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
| ncurses | 6.5 | Terminal (libtinfo.a only) | zig cc + autoconf (per-target) |

### ncurses Build

ncurses uses its autoconf/make build system with zig cc:
- Configure with `CC="zig cc -target {target}"`
- Build only `libtinfo.a` (termcap functions: tgetent, tgetnum, tgetflag, tgetstr, tgoto, tputs)
- Platform-specific flags:
  - macOS: `--with-ospeed=unsigned` (sys/ttydev.h doesn't exist)
  - Linux: `--host={target}` for cross-compilation

## Source Files Not Modified

**Important:** We do NOT modify any Erlang source code. All files in `sources/otp-28.1/` are pristine.

Our generated files live in `generated/{target}/{opt_mode}/jit/` - completely separate from the original source tree.

## Build Output

Platform-specific output directories in `zig-out/`:

```
zig-out/
├── aarch64-macos/
│   ├── bin/beam.smp          (56MB ARM64 Mach-O)
│   └── lib/libtinfo.a        (1.1MB static lib)
├── x86_64-macos/
│   ├── bin/beam.smp          (49MB x86_64 Mach-O)
│   └── lib/libtinfo.a        (1.0MB static lib)
├── aarch64-linux/
│   ├── bin/beam.smp          (78MB ARM64 ELF)
│   └── lib/libtinfo.a        (1.2MB static lib)
└── x86_64-linux/
    ├── bin/beam.smp          (70MB x86_64 ELF)
    └── lib/libtinfo.a        (1.1MB static lib)
```

All builds are JIT-enabled with architecture-specific BEAMASM backends.

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
- Build System: `build.zig`, `build/codegen.zig`, `build/vendor_libs.zig`, `build/ncurses_lib.zig`
