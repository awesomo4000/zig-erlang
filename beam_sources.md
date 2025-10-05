# BEAM VM Source Files

This document lists all source files needed to build the BEAM VM for OTP 28.1.

## Configuration
- Target: ARM64 (aarch64) macOS/Linux
- Flavor: JIT (beam.smp with JIT compiler)
- Type: opt (optimized build)

## Common BEAM Sources (beam/)
```
beam/beam_common.c
beam/beam_bif_load.c
beam/beam_bp.c
beam/beam_catches.c
beam/beam_debug.c
beam/beam_load.c
beam/beam_ranges.c
beam/beam_transform_helpers.c
beam/code_ix.c
beam/beam_file.c
beam/beam_types.c
```

## JIT Sources (beam/jit/)

### C Sources
```
beam/jit/asm_load.c
beam/jit/beam_jit_common.c
beam/jit/beam_jit_main.c
beam/jit/beam_jit_metadata.c
```

### C++ Sources (ARM64-specific)
```
beam/jit/arm/beam_asm_global.cpp
beam/jit/arm/beam_asm_module.cpp
beam/jit/arm/process_main.cpp
beam/jit/arm/instr_arith.cpp
beam/jit/arm/instr_bs.cpp
beam/jit/arm/instr_bif.cpp
beam/jit/arm/instr_call.cpp
beam/jit/arm/instr_common.cpp
beam/jit/arm/instr_float.cpp
beam/jit/arm/instr_fun.cpp
beam/jit/arm/instr_guard_bifs.cpp
beam/jit/arm/instr_map.cpp
beam/jit/arm/instr_msg.cpp
beam/jit/arm/instr_select.cpp
beam/jit/arm/instr_trace.cpp
```

### ASMJIT Library (C++)
All files from:
- `asmjit/core/*.cpp`
- `asmjit/arm/*.cpp`

## Runtime System Sources (RUN_OBJS)
```
beam/erl_alloc.c
beam/erl_alloc_util.c
beam/erl_goodfit_alloc.c
beam/erl_bestfit_alloc.c
beam/erl_afit_alloc.c
beam/erl_ao_firstfit_alloc.c
beam/erl_init.c
beam/erl_bif_ddll.c
beam/erl_bif_guard.c
beam/erl_bif_info.c
beam/erl_bif_op.c
beam/erl_bif_os.c
beam/erl_bif_lists.c
beam/erl_bif_persistent.c
beam/erl_bif_atomics.c
beam/erl_bif_counters.c
beam/erl_bif_trace.c
beam/erl_bif_unique.c
beam/erl_guard_bifs.c
beam/erl_dirty_bif_wrap.c
beam/erl_trace.c
beam/copy.c
beam/utils.c
beam/bif.c
beam/io.c
beam/erl_printf_term.c
beam/erl_debug.c
beam/erl_debugger.c
beam/erl_message.c
beam/erl_proc_sig_queue.c
beam/erl_process_dict.c
beam/erl_process_lock.c
beam/erl_port_task.c
beam/erl_arith.c
beam/time.c
beam/erl_time_sup.c
beam/external.c
beam/dist.c
beam/binary.c
beam/erl_db.c
beam/erl_db_util.c
beam/erl_db_hash.c
beam/erl_db_tree.c
beam/erl_db_catree.c
beam/erl_thr_progress.c
beam/big.c
beam/hash.c
beam/index.c
beam/atom.c
beam/module.c
beam/export.c
beam/register.c
beam/break.c
beam/erl_async.c
beam/erl_lock_check.c
beam/erl_dyn_lock_check.c
beam/erl_gc.c
beam/erl_lock_count.c
beam/erl_posix_str.c
beam/erl_bits.c
beam/erl_math.c
beam/erl_fun.c
beam/erl_bif_port.c
beam/erl_term.c
beam/erl_node_tables.c
beam/erl_monitor_link.c
beam/erl_process_dump.c
beam/erl_hl_timer.c
beam/erl_cpu_topology.c
beam/erl_drv_thread.c
beam/erl_bif_chksum.c
beam/erl_bif_re.c
beam/erl_unicode.c
beam/packet_parser.c
beam/safe_hash.c
beam/erl_zlib.c
beam/erl_nif.c
beam/erl_bif_binary.c
beam/erl_thr_queue.c
beam/erl_sched_spec_pre_alloc.c
beam/erl_ptab.c
beam/erl_map.c
beam/erl_msacc.c
beam/erl_lock_flags.c
beam/erl_io_queue.c
beam/erl_flxctr.c
beam/erl_nfunc_sched.c
beam/erl_global_literals.c
beam/erl_term_hashing.c
beam/erl_bif_coverage.c
beam/erl_iolist.c
beam/erl_etp.c
```

## Socket NIFs (nifs/common)
```
nifs/common/socket_dbg.c
nifs/common/socket_tarray.c
nifs/common/socket_util.c
nifs/common/prim_socket_nif.c
nifs/common/prim_net_nif.c
nifs/common/prim_tty_nif.c
nifs/common/erl_tracer_nif.c
nifs/common/prim_buffer_nif.c
nifs/common/prim_file_nif.c
nifs/common/zlib_nif.c
nifs/common/zstd_nif.c
```

## Drivers (drivers/common)
```
drivers/common/inet_drv.c
drivers/common/ram_file_drv.c
```

## OS-Specific Sources (sys/unix)
```
sys/unix/sys.c
sys/unix/sys_drivers.c
sys/unix/sys_env.c
sys/unix/sys_uds.c
sys/unix/driver_tab.c
sys/unix/unix_prim_file.c
sys/unix/sys_float.c
sys/unix/sys_time.c
sys/unix/sys_signal_stack.c
sys/unix/unix_socket_syncio.c
```

## Common System Sources (sys/common)
```
sys/common/erl_poll.c
sys/common/erl_check_io.c
sys/common/erl_mseg.c
sys/common/erl_mmap.c
sys/common/erl_osenv.c
sys/common/erl_unix_sys_ddll.c  (for Unix)
sys/common/erl_sys_common_misc.c
sys/common/erl_os_monotonic_time_extender.c
```

## Init/Main
```
beam/erl_main.c
```

## Generated Sources (to be created during build)
Located in `<target>/<type>/<flavor>/` (e.g., `aarch64-apple-darwin24.6.0/opt/jit/`)
```
beam_opcodes.c
beam_opcodes.h
beam_asm_global.hpp (JIT only)
erl_bif_table.c
erl_bif_table.h
erl_bif_list.h
erl_atom_table.c
erl_atom_table.h
erl_guard_bifs.c (may be generated or source)
erl_dirty_bif_wrap.c (may be generated or source)
erl_alloc_types.h
driver_tab.c
preload.c
```

In `<target>/`:
```
erl_version.h
```

## Vendored Libraries

### zlib (erts/emulator/zlib)
```
zlib/adler32.c
zlib/compress.c
zlib/crc32.c
zlib/deflate.c
zlib/gzclose.c
zlib/gzlib.c
zlib/gzread.c
zlib/gzwrite.c
zlib/infback.c
zlib/inffast.c
zlib/inflate.c
zlib/inftrees.c
zlib/trees.c
zlib/uncompr.c
zlib/zutil.c
```

### pcre (for regex support)
Located in `erts/emulator/pcre/`

### ryu (for float formatting)
Located in `erts/emulator/ryu/`

### zstd (Zstandard compression)
Located in `erts/emulator/zstd/`

## Build Notes

1. All object files go into `$(OBJDIR)` which is typically `$(TARGET)/$(TYPE)/$(FLAVOR)/obj`
2. Generated files must be created before compiling main sources
3. JIT builds require C++ compiler for JIT and asmjit sources
4. Profile-guided optimization (PGO) is supported but optional
5. For minimal build, can skip: LTTNG, DTrace, some NIFs
