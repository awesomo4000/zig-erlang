# Build Process and Generated Files

This document explains how we build Erlang/OTP using Zig instead of the standard autoconf/make build system, and specifically how we handle code generation.

## Overview

The standard Erlang build process generates many files during compilation. We replicate some of these steps and stub others for simplicity.

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

These are generated in `aarch64-macos-none/opt/jit/` by `build.zig` during the build process.

## Files We Stub

### YCF (Yielding C Functions) Files

**Normal Erlang Build:**
1. Compiles the YCF tool (`erts/lib_src/yielding_c_fun/`) - a C source code transformer
2. Runs it on C files to generate yielding versions of functions
3. Produces `.ycf.h` headers with yielding implementations

Example from Makefile.in:
```makefile
$(UTILS_YCF_OUTPUT): beam/utils.c
    yielding_c_fun -yield -f erts_qsort_helper \
        -output_file_name utils.ycf.h utils.c
```

**What YCF Does:**
Transforms blocking C functions into cooperative multitasking functions that can:
- **Yield** - pause execution and save state
- **Resume** - continue from saved state later
- **Destroy** - cleanup saved state

Example: `erts_qsort_helper()` becomes:
- `erts_qsort_ycf_gen_yielding()` - yielding version
- `erts_qsort_ycf_gen_continue()` - resume function
- `erts_qsort_ycf_gen_destroy()` - cleanup function

**What We Did Instead:**
Created stub files that skip YCF transformation:

| Stub File | Purpose |
|-----------|---------|
| `utils.ycf.h` | Empty header with YCF macros |
| `erl_map.ycf.h` | Empty header with YCF macros |
| `erl_db_insert_list.ycf.h` | Empty header with YCF macros |
| `utils_ycf_stubs.c` | Non-yielding implementations that just call standard library functions |

Our stubs use blocking calls (e.g., `qsort()` directly) instead of yielding versions.

**Trade-off:**
- ✅ Simpler build (no YCF tool compilation needed)
- ✅ Works fine for small/medium workloads
- ❌ Long operations can block scheduler threads (worse latency under heavy load)

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

## Source Files Not Modified

**Important:** We do NOT modify any Erlang source code. All files in `otp_src_28.1/` are pristine.

Our stubs and generated files live in `aarch64-macos-none/opt/jit/` - completely separate from the original source tree.

## Build Output

- **Executable:** `zig-out/bin/beam.smp` (56MB ARM64 Mach-O)
- **Build Mode:** JIT-enabled (BEAMASM), optimized
- **Platform:** macOS ARM64 (aarch64-macos-none)

## Future Improvements

To make the VM fully functional, we would need to:
1. Run YCF tool to generate proper yielding versions
2. Compile and embed preloaded Erlang modules
3. Set up proper directory structure and environment variables (BINDIR, ROOTDIR, etc.)

## References

- YCF Tool: `otp_src_28.1/erts/lib_src/yielding_c_fun/`
- Generation Scripts: `otp_src_28.1/erts/emulator/utils/`
- Original Makefile: `otp_src_28.1/erts/emulator/Makefile.in`
- Generated Files: `aarch64-macos-none/opt/jit/`
