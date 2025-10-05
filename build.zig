const std = @import("std");
const codegen = @import("build/codegen.zig");
const vendor_libs = @import("build/vendor_libs.zig");

// Source directory paths
const otp_root = "sources/otp-28.1";
const ncurses_root = "sources/ncurses-6.5";

pub fn build(b: *std.Build) void {
    // Target and optimization options
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Build options
    const enable_jit = b.option(bool, "jit", "Enable JIT compilation (default: true)") orelse true;
    const static_link = b.option(bool, "static", "Build fully static binaries") orelse false;

    // ============================================================================
    // Code Generation Step
    // ============================================================================

    const gen_step = codegen.generateSources(b, target, enable_jit);

    // Determine config directory for platform-specific headers
    const config_dir = getConfigDirName(b, target);

    // ============================================================================
    // Dependencies
    // ============================================================================

    const zlib = vendor_libs.buildZlib(b, target, optimize);
    const zstd = vendor_libs.buildZstd(b, target, optimize);
    // Determine target directory name for platform-specific output
    const target_str = b.fmt("{s}-{s}", .{
        @tagName(target.result.cpu.arch),
        @tagName(target.result.os.tag),
    });

    const ryu = vendor_libs.buildRyu(b, target, optimize);
    const pcre = vendor_libs.buildPcre(b, target, optimize, config_dir);
    const ethread = vendor_libs.buildEthread(b, target, optimize, config_dir);

    // Build vendored ncurses for all targets using zig cc
    const ncurses = vendor_libs.buildNcurses(b, target, optimize, target_str);

    const asmjit = if (enable_jit) vendor_libs.buildAsmjit(b, target, optimize) else null;

    // ============================================================================
    // ERTS - Erlang Runtime System
    // ============================================================================

    const beam = buildERTS(b, target, optimize, .{
        .zlib = zlib,
        .zstd = zstd,
        .ryu = ryu,
        .pcre = pcre,
        .ethread = ethread,
        .ncurses = ncurses,
        .asmjit = asmjit,
        .static_link = static_link,
        .enable_jit = enable_jit,
        .gen_step = gen_step,
    });

    // ============================================================================
    // Installation
    // ============================================================================

    // Install to platform-specific directory: zig-out/{target}/bin/beam.smp
    const install_step = b.getInstallStep();
    install_step.dependOn(&b.addInstallArtifact(beam, .{
        .dest_dir = .{
            .override = .{
                .custom = b.fmt("{s}/bin", .{target_str}),
            },
        },
    }).step);

    // ============================================================================
    // Tests
    // ============================================================================

    const test_step = b.step("test", "Run unit tests");
    _ = test_step;
}

// ============================================================================
// Build ERTS (Erlang Runtime System)
// ============================================================================

const ERTSOptions = struct {
    zlib: *std.Build.Step.Compile,
    zstd: *std.Build.Step.Compile,
    ryu: *std.Build.Step.Compile,
    pcre: *std.Build.Step.Compile,
    ethread: *std.Build.Step.Compile,
    ncurses: ?*std.Build.Step.Compile,
    asmjit: ?*std.Build.Step.Compile,
    static_link: bool,
    enable_jit: bool,
    gen_step: *std.Build.Step,
};


fn getConfigDirName(b: *std.Build, target: std.Build.ResolvedTarget) []const u8 {
    // Map Zig target to autoconf-style config directory name
    // Format: {cpu}-{vendor}-{os}[{version}]
    const cpu = @tagName(target.result.cpu.arch);
    const os = target.result.os.tag;

    // For macOS, use apple-darwin format with OS version
    if (os == .macos) {
        return b.fmt("{s}-apple-darwin24.6.0", .{cpu});
    }

    // For Linux, use standard GNU triplet format
    if (os == .linux) {
        return b.fmt("{s}-unknown-linux-gnu", .{cpu});
    }

    // Fallback for other platforms
    return b.fmt("{s}-unknown-{s}", .{cpu, @tagName(os)});
}

fn buildERTS(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    options: ERTSOptions,
) *std.Build.Step.Compile {
    const erts_path = otp_root ++ "/erts";
    const emulator_path = erts_path ++ "/emulator";

    // Determine target architecture string and generated file directory
    const target_str = b.fmt("{s}-{s}-{s}", .{
        @tagName(target.result.cpu.arch),
        @tagName(target.result.os.tag),
        @tagName(target.result.abi),
    });
    const flavor = if (options.enable_jit) "jit" else "emu";
    const build_type = "opt";
    const gen_dir = b.fmt("generated/{s}/{s}/{s}", .{ target_str, build_type, flavor });

    // Determine JIT backend architecture
    const jit_arch = switch (target.result.cpu.arch) {
        .aarch64, .aarch64_be => "arm",
        .x86_64, .x86 => "x86",
        else => "arm", // Default to ARM for unsupported architectures
    };

    // Determine if we're cross-compiling
    const is_cross_compiling = !target.result.os.tag.isDarwin() or target.result.cpu.arch != b.graph.host.result.cpu.arch;

    // Create module for C-only code (no root Zig source file)
    const beam_module = b.createModule(.{
        .root_source_file = null,
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .link_libcpp = true,
    });

    // Main BEAM emulator executable
    const beam = b.addExecutable(.{
        .name = if (options.enable_jit) "beam.smp" else "beam.emu.smp",
        .root_module = beam_module,
        .linkage = if (options.static_link) .static else null,
    });

    // Depend on code generation
    beam.step.dependOn(options.gen_step);

    // ========================================================================
    // Include paths
    // ========================================================================

    beam.addIncludePath(b.path(erts_path ++ "/include"));
    beam.addIncludePath(b.path(erts_path ++ "/include/internal"));
    beam.addIncludePath(b.path(emulator_path));
    beam.addIncludePath(b.path(emulator_path ++ "/beam"));
    beam.addIncludePath(b.path(emulator_path ++ "/sys/unix"));
    beam.addIncludePath(b.path(emulator_path ++ "/sys/common"));
    beam.addIncludePath(b.path(emulator_path ++ "/drivers/common"));
    beam.addIncludePath(b.path(emulator_path ++ "/drivers/unix"));
    beam.addIncludePath(b.path(emulator_path ++ "/nifs/common"));
    beam.addIncludePath(b.path(emulator_path ++ "/nifs/unix"));
    beam.addIncludePath(b.path(emulator_path ++ "/openssl/include"));
    beam.addIncludePath(b.path(emulator_path ++ "/zlib"));
    beam.addIncludePath(b.path(emulator_path ++ "/zstd"));
    beam.addIncludePath(b.path(emulator_path ++ "/ryu"));
    beam.addIncludePath(b.path(emulator_path ++ "/pcre"));

    // JIT include paths
    if (options.enable_jit) {
        beam.addIncludePath(b.path(emulator_path ++ "/beam/jit"));
        beam.addIncludePath(b.path(b.fmt("{s}/beam/jit/{s}", .{ emulator_path, jit_arch })));
    }

    // Add generated file directory to include path
    beam.addIncludePath(b.path(gen_dir));

    // Platform-specific config (from configure)
    const target_config_dir = getConfigDirName(b, target);
    beam.addIncludePath(b.path(b.fmt("{s}/include/{s}", .{erts_path, target_config_dir})));
    beam.addIncludePath(b.path(b.fmt("{s}/include/internal/{s}", .{erts_path, target_config_dir})));
    beam.addIncludePath(b.path(b.fmt("{s}/{s}", .{erts_path, target_config_dir})));

    // Add generated directory for erl_version.h and other generated files
    beam.addIncludePath(b.path(gen_dir));

    // Add vendored macOS SDK headers when cross-compiling to macOS
    if (is_cross_compiling and target.result.os.tag == .macos) {
        beam.addIncludePath(b.path("build/macos_sdk_headers"));
    }

    // ========================================================================
    // Compiler flags
    // ========================================================================

    // Linux requires _GNU_SOURCE for extensions like syscall(), memrchr()
    // When cross-compiling, disable termcap/ncurses since headers aren't available
    // Include zig_compat.h to provide missing function declarations in musl libc
    const base_flags = if (target.result.os.tag == .linux)
        &[_][]const u8{
            "-DHAVE_CONFIG_H",
            "-D_THREAD_SAFE",
            "-D_REENTRANT",
            "-DPOSIX_THREADS",
            "-DUSE_THREADS",
            "-D_GNU_SOURCE",
            "-include", "build/zig_compat.h",
            "-std=c11",
            "-fno-common",
            "-fno-strict-aliasing",
        }
    else
        &[_][]const u8{
            "-DHAVE_CONFIG_H",
            "-D_THREAD_SAFE",
            "-D_REENTRANT",
            "-DPOSIX_THREADS",
            "-DUSE_THREADS",
            "-std=c11",
            "-fno-common",
            "-fno-strict-aliasing",
        };

    // For JIT builds, add BEAMASM to all C files
    const max_base_flags = 11; // Max length of base_flags (Linux with _GNU_SOURCE and zig_compat.h)
    var common_flags_buf: [max_base_flags + 1][]const u8 = undefined;
    const common_flags = if (options.enable_jit) blk: {
        @memcpy(common_flags_buf[0..base_flags.len], base_flags);
        common_flags_buf[base_flags.len] = "-DBEAMASM";
        break :blk common_flags_buf[0..base_flags.len + 1];
    } else base_flags;

    // ========================================================================
    // Common BEAM sources
    // ========================================================================

    const common_sources = [_][]const u8{
        emulator_path ++ "/beam/beam_common.c",
        emulator_path ++ "/beam/beam_bif_load.c",
        emulator_path ++ "/beam/beam_bp.c",
        emulator_path ++ "/beam/beam_catches.c",
        emulator_path ++ "/beam/beam_debug.c",
        emulator_path ++ "/beam/beam_load.c",
        emulator_path ++ "/beam/beam_ranges.c",
        emulator_path ++ "/beam/beam_transform_helpers.c",
        emulator_path ++ "/beam/code_ix.c",
        emulator_path ++ "/beam/beam_file.c",
        emulator_path ++ "/beam/beam_types.c",
    };

    beam.addCSourceFiles(.{
        .files = &common_sources,
        .flags = common_flags,
    });

    // Add MD5 from openssl directory - needs ERLANG_OPENSSL_INTEGRATION flag
    const md5_base_flags = if (target.result.os.tag == .linux)
        &[_][]const u8{
            "-DHAVE_CONFIG_H",
            "-D_THREAD_SAFE",
            "-D_REENTRANT",
            "-DPOSIX_THREADS",
            "-DUSE_THREADS",
            "-D_GNU_SOURCE",
            "-std=c11",
            "-fno-common",
            "-fno-strict-aliasing",
        }
    else
        &[_][]const u8{
            "-DHAVE_CONFIG_H",
            "-D_THREAD_SAFE",
            "-D_REENTRANT",
            "-DPOSIX_THREADS",
            "-DUSE_THREADS",
            "-std=c11",
            "-fno-common",
            "-fno-strict-aliasing",
        };

    const max_md5_flags = 11; // Max length including JIT and integration flags
    var md5_flags_buf: [max_md5_flags][]const u8 = undefined;
    const md5_flags = blk: {
        @memcpy(md5_flags_buf[0..md5_base_flags.len], md5_base_flags);
        if (options.enable_jit) {
            md5_flags_buf[md5_base_flags.len] = "-DBEAMASM";
            md5_flags_buf[md5_base_flags.len + 1] = "-DERLANG_OPENSSL_INTEGRATION";
            break :blk md5_flags_buf[0..md5_base_flags.len + 2];
        } else {
            md5_flags_buf[md5_base_flags.len] = "-DERLANG_OPENSSL_INTEGRATION";
            break :blk md5_flags_buf[0..md5_base_flags.len + 1];
        }
    };
    beam.addCSourceFile(.{
        .file = b.path(emulator_path ++ "/openssl/crypto/md5/md5_dgst.c"),
        .flags = md5_flags,
    });

    // ========================================================================
    // Runtime system sources
    // ========================================================================

    const run_sources = [_][]const u8{
        emulator_path ++ "/beam/erl_alloc.c",
        emulator_path ++ "/beam/erl_alloc_util.c",
        emulator_path ++ "/beam/erl_goodfit_alloc.c",
        emulator_path ++ "/beam/erl_bestfit_alloc.c",
        emulator_path ++ "/beam/erl_afit_alloc.c",
        emulator_path ++ "/beam/erl_ao_firstfit_alloc.c",
        emulator_path ++ "/beam/erl_init.c",
        emulator_path ++ "/beam/erl_bif_ddll.c",
        emulator_path ++ "/beam/erl_bif_guard.c",
        emulator_path ++ "/beam/erl_bif_info.c",
        emulator_path ++ "/beam/erl_bif_op.c",
        emulator_path ++ "/beam/erl_bif_os.c",
        emulator_path ++ "/beam/erl_bif_lists.c",
        emulator_path ++ "/beam/erl_bif_persistent.c",
        emulator_path ++ "/beam/erl_bif_atomics.c",
        emulator_path ++ "/beam/erl_bif_counters.c",
        emulator_path ++ "/beam/erl_bif_trace.c",
        emulator_path ++ "/beam/erl_bif_unique.c",
        emulator_path ++ "/beam/erl_trace.c",
        emulator_path ++ "/beam/copy.c",
        emulator_path ++ "/beam/utils.c",
        emulator_path ++ "/beam/bif.c",
        emulator_path ++ "/beam/io.c",
        emulator_path ++ "/beam/erl_printf_term.c",
        emulator_path ++ "/beam/erl_debug.c",
        emulator_path ++ "/beam/erl_debugger.c",
        emulator_path ++ "/beam/erl_message.c",
        emulator_path ++ "/beam/erl_proc_sig_queue.c",
        emulator_path ++ "/beam/erl_process.c",
        emulator_path ++ "/beam/erl_process_dict.c",
        emulator_path ++ "/beam/erl_process_lock.c",
        emulator_path ++ "/beam/erl_port_task.c",
        emulator_path ++ "/beam/erl_arith.c",
        emulator_path ++ "/beam/time.c",
        emulator_path ++ "/beam/erl_time_sup.c",
        emulator_path ++ "/beam/external.c",
        emulator_path ++ "/beam/dist.c",
        emulator_path ++ "/beam/binary.c",
        emulator_path ++ "/beam/erl_db.c",
        emulator_path ++ "/beam/erl_db_util.c",
        emulator_path ++ "/beam/erl_db_hash.c",
        emulator_path ++ "/beam/erl_db_tree.c",
        emulator_path ++ "/beam/erl_db_catree.c",
        emulator_path ++ "/beam/erl_thr_progress.c",
        emulator_path ++ "/beam/big.c",
        emulator_path ++ "/beam/hash.c",
        emulator_path ++ "/beam/index.c",
        emulator_path ++ "/beam/atom.c",
        emulator_path ++ "/beam/module.c",
        emulator_path ++ "/beam/export.c",
        emulator_path ++ "/beam/register.c",
        emulator_path ++ "/beam/break.c",
        emulator_path ++ "/beam/erl_async.c",
        emulator_path ++ "/beam/erl_lock_check.c",
        emulator_path ++ "/beam/erl_dyn_lock_check.c",
        emulator_path ++ "/beam/erl_gc.c",
        emulator_path ++ "/beam/erl_lock_count.c",
        emulator_path ++ "/beam/erl_posix_str.c",
        emulator_path ++ "/beam/erl_bits.c",
        emulator_path ++ "/beam/erl_math.c",
        emulator_path ++ "/beam/erl_fun.c",
        emulator_path ++ "/beam/erl_bif_port.c",
        emulator_path ++ "/beam/erl_term.c",
        emulator_path ++ "/beam/erl_node_tables.c",
        emulator_path ++ "/beam/erl_monitor_link.c",
        emulator_path ++ "/beam/erl_process_dump.c",
        emulator_path ++ "/beam/erl_hl_timer.c",
        emulator_path ++ "/beam/erl_cpu_topology.c",
        emulator_path ++ "/beam/erl_drv_thread.c",
        emulator_path ++ "/beam/erl_bif_chksum.c",
        emulator_path ++ "/beam/erl_bif_re.c",
        emulator_path ++ "/beam/erl_unicode.c",
        emulator_path ++ "/beam/packet_parser.c",
        emulator_path ++ "/beam/safe_hash.c",
        emulator_path ++ "/beam/erl_zlib.c",
        emulator_path ++ "/beam/erl_nif.c",
        emulator_path ++ "/beam/erl_bif_binary.c",
        emulator_path ++ "/beam/erl_thr_queue.c",
        emulator_path ++ "/beam/erl_sched_spec_pre_alloc.c",
        emulator_path ++ "/beam/erl_ptab.c",
        emulator_path ++ "/beam/erl_map.c",
        emulator_path ++ "/beam/erl_msacc.c",
        emulator_path ++ "/beam/erl_lock_flags.c",
        emulator_path ++ "/beam/erl_io_queue.c",
        emulator_path ++ "/beam/erl_flxctr.c",
        emulator_path ++ "/beam/erl_nfunc_sched.c",
        emulator_path ++ "/beam/erl_global_literals.c",
        emulator_path ++ "/beam/erl_term_hashing.c",
        emulator_path ++ "/beam/erl_bif_coverage.c",
        emulator_path ++ "/beam/erl_iolist.c",
        emulator_path ++ "/beam/erl_etp.c",
    };

    beam.addCSourceFiles(.{
        .files = &run_sources,
        .flags = common_flags,
    });

    // ========================================================================
    // NIFs (Native Implemented Functions)
    // ========================================================================

    const nif_sources = [_][]const u8{
        emulator_path ++ "/nifs/common/prim_tty_nif.c",
        emulator_path ++ "/nifs/common/erl_tracer_nif.c",
        emulator_path ++ "/nifs/common/prim_buffer_nif.c",
        emulator_path ++ "/nifs/common/prim_file_nif.c",
        emulator_path ++ "/nifs/common/zlib_nif.c",
        emulator_path ++ "/nifs/common/zstd_nif.c",
        emulator_path ++ "/nifs/common/socket_dbg.c",
        emulator_path ++ "/nifs/common/socket_tarray.c",
        emulator_path ++ "/nifs/common/socket_util.c",
        emulator_path ++ "/nifs/common/prim_socket_nif.c",
        emulator_path ++ "/nifs/common/prim_net_nif.c",
    };

    beam.addCSourceFiles(.{
        .files = &nif_sources,
        .flags = common_flags,
    });

    // ========================================================================
    // Drivers
    // ========================================================================

    const driver_sources = [_][]const u8{
        emulator_path ++ "/drivers/common/inet_drv.c",
        emulator_path ++ "/drivers/common/ram_file_drv.c",
    };

    beam.addCSourceFiles(.{
        .files = &driver_sources,
        .flags = common_flags,
    });

    // ========================================================================
    // System sources (Unix)
    // ========================================================================

    const sys_sources = [_][]const u8{
        emulator_path ++ "/sys/unix/sys.c",
        emulator_path ++ "/sys/unix/sys_drivers.c",
        emulator_path ++ "/sys/unix/sys_env.c",
        emulator_path ++ "/sys/unix/sys_uds.c",
        emulator_path ++ "/sys/unix/sys_float.c",
        emulator_path ++ "/sys/unix/sys_time.c",
        emulator_path ++ "/sys/unix/sys_signal_stack.c",
        emulator_path ++ "/sys/unix/erl_unix_sys_ddll.c",
        // erl_poll.c compiled separately with different flags (see below)
        emulator_path ++ "/sys/common/erl_check_io.c",
        emulator_path ++ "/sys/common/erl_mseg.c",
        emulator_path ++ "/sys/common/erl_mmap.c",
        emulator_path ++ "/sys/common/erl_osenv.c",
        emulator_path ++ "/sys/common/erl_sys_common_misc.c",
        emulator_path ++ "/sys/common/erl_os_monotonic_time_extender.c",
        // Unix-specific NIFs (actually in nifs/unix)
        emulator_path ++ "/nifs/unix/unix_prim_file.c",
        emulator_path ++ "/nifs/unix/unix_socket_syncio.c",
    };

    beam.addCSourceFiles(.{
        .files = &sys_sources,
        .flags = common_flags,
    });

    // Compile erl_poll.c twice with different flags to generate both
    // kernel poll (epoll/kqueue) and fallback (select/poll) versions
    const poll_kernel_flags = b.allocator.alloc([]const u8, common_flags.len + 1) catch @panic("OOM");
    @memcpy(poll_kernel_flags[0..common_flags.len], common_flags);
    poll_kernel_flags[common_flags.len] = "-DERTS_KERNEL_POLL_VERSION";

    beam.addCSourceFiles(.{
        .files = &[_][]const u8{emulator_path ++ "/sys/common/erl_poll.c"},
        .flags = poll_kernel_flags,
    });

    const poll_flbk_flags = b.allocator.alloc([]const u8, common_flags.len + 1) catch @panic("OOM");
    @memcpy(poll_flbk_flags[0..common_flags.len], common_flags);
    poll_flbk_flags[common_flags.len] = "-DERTS_NO_KERNEL_POLL_VERSION";

    beam.addCSourceFiles(.{
        .files = &[_][]const u8{emulator_path ++ "/sys/common/erl_poll.c"},
        .flags = poll_flbk_flags,
    });

    // ========================================================================
    // Main entry point (Unix-specific)
    // ========================================================================

    beam.addCSourceFile(.{
        .file = b.path(emulator_path ++ "/sys/unix/erl_main.c"),
        .flags = common_flags,
    });

    // ========================================================================
    // JIT or Interpreter
    // ========================================================================

    if (options.enable_jit) {
        // JIT-specific C sources
        const jit_c_sources = [_][]const u8{
            emulator_path ++ "/beam/jit/asm_load.c",
        };

        beam.addCSourceFiles(.{
            .files = &jit_c_sources,
            .flags = common_flags,
        });

        // JIT-specific C++ sources (common + architecture-specific)
        // Architecture-specific instruction files
        const jit_arch_sources = [_][]const u8{
            "beam_asm_global.cpp",
            "beam_asm_module.cpp",
            "process_main.cpp",
            "instr_arith.cpp",
            "instr_bs.cpp",
            "instr_bif.cpp",
            "instr_call.cpp",
            "instr_common.cpp",
            "instr_float.cpp",
            "instr_fun.cpp",
            "instr_guard_bifs.cpp",
            "instr_map.cpp",
            "instr_msg.cpp",
            "instr_select.cpp",
            "instr_trace.cpp",
        };

        // Build full paths for architecture-specific sources
        var jit_cpp_sources_buf: [3 + jit_arch_sources.len][]const u8 = undefined;
        jit_cpp_sources_buf[0] = emulator_path ++ "/beam/jit/beam_jit_common.cpp";
        jit_cpp_sources_buf[1] = emulator_path ++ "/beam/jit/beam_jit_main.cpp";
        jit_cpp_sources_buf[2] = emulator_path ++ "/beam/jit/beam_jit_metadata.cpp";
        for (jit_arch_sources, 0..) |src, i| {
            jit_cpp_sources_buf[3 + i] = b.fmt("{s}/beam/jit/{s}/{s}", .{ emulator_path, jit_arch, src });
        }
        const jit_cpp_sources = jit_cpp_sources_buf[0..];

        const cpp_flags = if (target.result.os.tag == .linux)
            &[_][]const u8{
                "-DHAVE_CONFIG_H",
                "-D_THREAD_SAFE",
                "-D_REENTRANT",
                "-DPOSIX_THREADS",
                "-DUSE_THREADS",
                "-D_GNU_SOURCE",
                "-DBEAMASM",
                "-std=c++17",
                "-fno-common",
            }
        else
            &[_][]const u8{
                "-DHAVE_CONFIG_H",
                "-D_THREAD_SAFE",
                "-D_REENTRANT",
                "-DPOSIX_THREADS",
                "-DUSE_THREADS",
                "-DBEAMASM",
                "-std=c++17",
                "-fno-common",
            };

        beam.addCSourceFiles(.{
            .files = jit_cpp_sources,
            .flags = cpp_flags,
        });

        // ASMJIT library include path
        beam.addIncludePath(b.path(emulator_path ++ "/asmjit"));

        // Link ASMJIT library
        if (options.asmjit) |asmjit_lib| {
            beam.linkLibrary(asmjit_lib);
        }

    } else {
        // Interpreter mode
        const emu_sources = [_][]const u8{
            emulator_path ++ "/beam/emu/emu_load.c",
        };

        beam.addCSourceFiles(.{
            .files = &emu_sources,
            .flags = common_flags,
        });
    }

    // ========================================================================
    // Generated sources
    // ========================================================================

    // Add generated C source files from the gen_dir
    const generated_sources = [_][]const u8{
        b.fmt("{s}/beam_opcodes.c", .{gen_dir}),
        b.fmt("{s}/erl_atom_table.c", .{gen_dir}),
        b.fmt("{s}/erl_bif_table.c", .{gen_dir}),
        b.fmt("{s}/erl_guard_bifs.c", .{gen_dir}),
        b.fmt("{s}/erl_dirty_bif_wrap.c", .{gen_dir}),
        b.fmt("{s}/driver_tab.c", .{gen_dir}),
        b.fmt("{s}/preload.c", .{gen_dir}),
    };

    beam.addCSourceFiles(.{
        .files = &generated_sources,
        .flags = common_flags,
    });

    // ========================================================================
    // Link libraries
    // ========================================================================

    beam.linkLibrary(options.zlib);
    beam.linkLibrary(options.zstd);
    beam.linkLibrary(options.ryu);
    beam.linkLibrary(options.pcre);
    beam.linkLibrary(options.ethread);

    // Link vendored ncurses (provides termcap functions)
    if (options.ncurses) |ncurses_lib| {
        beam.linkLibrary(ncurses_lib);
    }

    // Platform-specific system libraries
    if (target.result.os.tag == .macos) {
        // On macOS host, we can link system libraries even when cross-compiling to different arch
        const is_macos_host = b.graph.host.result.os.tag.isDarwin();
        if (is_macos_host) {
            // Add SDK library and framework paths for system libraries
            const sdk_path_result = b.run(&.{ "xcrun", "--show-sdk-path" });
            const sdk_path = std.mem.trim(u8, sdk_path_result, " \n\r\t");
            const sdk_lib_path = b.fmt("{s}/usr/lib", .{sdk_path});
            const sdk_framework_path = b.fmt("{s}/System/Library/Frameworks", .{sdk_path});
            beam.addLibraryPath(.{ .cwd_relative = sdk_lib_path });
            beam.addFrameworkPath(.{ .cwd_relative = sdk_framework_path });
            beam.linkFramework("CoreFoundation");
        }
        beam.linkSystemLibrary("pthread");
        beam.linkSystemLibrary("m");
    } else if (target.result.os.tag == .linux) {
        beam.linkSystemLibrary("pthread");
        beam.linkSystemLibrary("m");
        beam.linkSystemLibrary("rt");
        beam.linkSystemLibrary("util");
        beam.linkSystemLibrary("dl");
    }

    return beam;
}

// ============================================================================
// Build vendored zlib
// ============================================================================

fn buildZlib(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step.Compile {
    const zlib_module = b.createModule(.{
        .root_source_file = null,
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    const zlib = b.addLibrary(.{
        .name = "z",
        .root_module = zlib_module,
        .linkage = .static,
    });

    const zlib_path = "otp_src_28.1/erts/emulator/zlib";

    zlib.addIncludePath(b.path(zlib_path));
    zlib.addCSourceFiles(.{
        .files = &.{
            zlib_path ++ "/adler32.c",
            zlib_path ++ "/compress.c",
            zlib_path ++ "/crc32.c",
            zlib_path ++ "/deflate.c",
            zlib_path ++ "/inffast.c",
            zlib_path ++ "/inflate.c",
            zlib_path ++ "/inftrees.c",
            zlib_path ++ "/trees.c",
            zlib_path ++ "/uncompr.c",
            zlib_path ++ "/zutil.c",
        },
        .flags = &.{"-std=c11"},
    });

    return zlib;
}

// ============================================================================
// Build vendored zstd
// ============================================================================

fn buildZstd(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step.Compile {
    const zstd_module = b.createModule(.{
        .root_source_file = null,
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    const zstd = b.addLibrary(.{
        .name = "zstd",
        .root_module = zstd_module,
        .linkage = .static,
    });

    const zstd_path = "otp_src_28.1/erts/emulator/zstd";

    zstd.addIncludePath(b.path(zstd_path));
    zstd.addIncludePath(b.path(zstd_path ++ "/common"));
    zstd.addIncludePath(b.path(zstd_path ++ "/compress"));
    zstd.addIncludePath(b.path(zstd_path ++ "/decompress"));

    const zstd_sources = [_][]const u8{
        zstd_path ++ "/common/entropy_common.c",
        zstd_path ++ "/common/fse_decompress.c",
        zstd_path ++ "/common/debug.c",
        zstd_path ++ "/common/xxhash.c",
        zstd_path ++ "/common/pool.c",
        zstd_path ++ "/common/threading.c",
        zstd_path ++ "/common/zstd_common.c",
        zstd_path ++ "/common/error_private.c",
        zstd_path ++ "/compress/zstd_preSplit.c",
        zstd_path ++ "/compress/zstd_compress_superblock.c",
        zstd_path ++ "/compress/zstdmt_compress.c",
        zstd_path ++ "/compress/zstd_double_fast.c",
        zstd_path ++ "/compress/zstd_fast.c",
        zstd_path ++ "/compress/zstd_compress_sequences.c",
        zstd_path ++ "/compress/zstd_ldm.c",
        zstd_path ++ "/compress/hist.c",
        zstd_path ++ "/compress/zstd_compress.c",
        zstd_path ++ "/compress/zstd_lazy.c",
        zstd_path ++ "/compress/zstd_compress_literals.c",
        zstd_path ++ "/compress/huf_compress.c",
        zstd_path ++ "/compress/zstd_opt.c",
        zstd_path ++ "/compress/fse_compress.c",
        zstd_path ++ "/decompress/zstd_ddict.c",
        zstd_path ++ "/decompress/huf_decompress.c",
        zstd_path ++ "/decompress/zstd_decompress.c",
        zstd_path ++ "/decompress/zstd_decompress_block.c",
    };

    zstd.addCSourceFiles(.{
        .files = &zstd_sources,
        .flags = &.{"-std=c11"},
    });

    return zstd;
}

// ============================================================================
// Build vendored ryu (float formatting)
// ============================================================================

fn buildRyu(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step.Compile {
    const ryu_module = b.createModule(.{
        .root_source_file = null,
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    const ryu = b.addLibrary(.{
        .name = "ryu",
        .root_module = ryu_module,
        .linkage = .static,
    });

    const ryu_path = "otp_src_28.1/erts/emulator/ryu";

    ryu.addIncludePath(b.path(ryu_path));
    ryu.addCSourceFile(.{
        .file = b.path(ryu_path ++ "/d2s.c"),
        .flags = &.{"-std=c11"},
    });

    return ryu;
}

// ============================================================================
// Build vendored pcre (regex)
// ============================================================================

fn buildPcre(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step.Compile {
    const pcre_path = "otp_src_28.1/erts/emulator/pcre";

    // Generate pcre2_match_loop_break_cases.gen.h
    const gen_break_cases = b.addSystemCommand(&.{
        "sh",
        "-c",
        "grep -n 'COST_CHK(' " ++ pcre_path ++ "/pcre2_match.c | grep -E -v 'define|DBG_FAKE_' | awk -F: '{print $1}' | while read line; do echo \"case $line: goto L_LOOP_COUNT_$line;\"; done > " ++ pcre_path ++ "/pcre2_match_loop_break_cases.gen.h",
    });

    // Generate pcre2_match_yield_coverage.gen.h
    const gen_yield_cov = b.addSystemCommand(&.{
        "sh",
        "-c",
        "INDEX=0; grep -n 'COST_CHK(' " ++ pcre_path ++ "/pcre2_match.c | grep -v 'define' | awk -F: '{print $1}' | while read line; do echo \"#define ERLANG_YIELD_POINT_$line $INDEX\"; echo \"$line,\"; INDEX=$((INDEX + 1)); done > " ++ pcre_path ++ "/pcre2_match_yield_coverage.gen.h; echo \"#define ERLANG_YIELD_POINT_CNT $INDEX\" >> " ++ pcre_path ++ "/pcre2_match_yield_coverage.gen.h",
    });

    const pcre_module = b.createModule(.{
        .root_source_file = null,
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    const pcre = b.addLibrary(.{
        .name = "pcre",
        .root_module = pcre_module,
        .linkage = .static,
    });

    // Depend on generated headers
    pcre.step.dependOn(&gen_break_cases.step);
    pcre.step.dependOn(&gen_yield_cov.step);

    pcre.addIncludePath(b.path(pcre_path));
    pcre.addIncludePath(b.path("otp_src_28.1/erts/aarch64-apple-darwin24.6.0"));

    const pcre_sources = [_][]const u8{
        pcre_path ++ "/pcre2_ucptables.c",
        pcre_path ++ "/pcre2_chkdint.c",
        pcre_path ++ "/pcre2_xclass.c",
        pcre_path ++ "/pcre2_script_run.c",
        pcre_path ++ "/pcre2_string_utils.c",
        pcre_path ++ "/pcre2_pattern_info.c",
        pcre_path ++ "/pcre2_extuni.c",
        pcre_path ++ "/pcre2_chartables.c",
        pcre_path ++ "/pcre2_match.c",
        pcre_path ++ "/pcre2_substring.c",
        pcre_path ++ "/pcre2_compile.c",
        pcre_path ++ "/pcre2_ord2utf.c",
        pcre_path ++ "/pcre2_tables.c",
        pcre_path ++ "/pcre2_ucd.c",
        pcre_path ++ "/pcre2_find_bracket.c",
        pcre_path ++ "/pcre2_compile_class.c",
        pcre_path ++ "/pcre2_study.c",
        pcre_path ++ "/pcre2_valid_utf.c",
        pcre_path ++ "/pcre2_context.c",
        pcre_path ++ "/pcre2_match_data.c",
        pcre_path ++ "/pcre2_error.c",
        pcre_path ++ "/pcre2_config.c",
        pcre_path ++ "/pcre2_newline.c",
        pcre_path ++ "/pcre2_auto_possess.c",
        pcre_path ++ "/pcre2_serialize.c",
    };

    pcre.addCSourceFiles(.{
        .files = &pcre_sources,
        .flags = &.{
            "-std=c11",
            "-DHAVE_CONFIG_H",
            "-DERLANG_INTEGRATION",
        },
    });

    return pcre;
}

// ============================================================================
// Build ethread (Erlang threading library)
// ============================================================================

fn buildEthread(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step.Compile {
    const ethread_module = b.createModule(.{
        .root_source_file = null,
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    const ethread = b.addLibrary(.{
        .name = "ethread",
        .root_module = ethread_module,
        .linkage = .static,
    });

    const lib_src_path = "otp_src_28.1/erts/lib_src";
    const erts_path = "otp_src_28.1/erts";

    ethread.addIncludePath(b.path(erts_path ++ "/aarch64-apple-darwin24.6.0")); // For config.h
    ethread.addIncludePath(b.path(erts_path ++ "/include"));
    ethread.addIncludePath(b.path(erts_path ++ "/include/internal"));
    ethread.addIncludePath(b.path(erts_path ++ "/include/aarch64-apple-darwin24.6.0"));
    ethread.addIncludePath(b.path(erts_path ++ "/include/internal/aarch64-apple-darwin24.6.0"));

    const ethread_sources = [_][]const u8{
        // pthread sources
        lib_src_path ++ "/pthread/ethread.c",
        lib_src_path ++ "/pthread/ethr_event.c",
        // common sources
        lib_src_path ++ "/common/erl_printf.c",
        lib_src_path ++ "/common/erl_printf_format.c",
        lib_src_path ++ "/common/erl_misc_utils.c",
        lib_src_path ++ "/common/ethr_atomics.c",
        lib_src_path ++ "/common/ethr_aux.c",
        lib_src_path ++ "/common/ethr_cbf.c",
        lib_src_path ++ "/common/ethr_mutex.c",
    };

    ethread.addCSourceFiles(.{
        .files = &ethread_sources,
        .flags = &.{
            "-std=c11",
            "-DHAVE_CONFIG_H",
            "-D_THREAD_SAFE",
            "-D_REENTRANT",
            "-DPOSIX_THREADS",
            "-DUSE_THREADS",
        },
    });

    return ethread;
}

// ============================================================================
// Build vendored asmjit (JIT assembler library)
// ============================================================================

fn buildAsmjit(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step.Compile {
    const asmjit_module = b.createModule(.{
        .root_source_file = null,
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .link_libcpp = true,
    });

    const asmjit = b.addLibrary(.{
        .name = "asmjit",
        .root_module = asmjit_module,
        .linkage = .static,
    });

    const asmjit_path = "otp_src_28.1/erts/emulator/asmjit";

    // Include paths for asmjit headers
    asmjit.addIncludePath(b.path(asmjit_path));

    // ASMJIT compiler flags (from ASMJIT_FLAGS in Makefile)
    const asmjit_flags = [_][]const u8{
        "-std=c++17",
        "-DASMJIT_EMBED=1",
        "-DASMJIT_NO_BUILDER=1",
        "-DASMJIT_NO_DEPRECATED=1",
        "-DASMJIT_STATIC=1",
        "-DASMJIT_NO_FOREIGN=1",
        "-fno-common",
    };

    // Core C++ sources
    const core_sources = [_][]const u8{
        asmjit_path ++ "/core/archtraits.cpp",
        asmjit_path ++ "/core/assembler.cpp",
        asmjit_path ++ "/core/builder.cpp",
        asmjit_path ++ "/core/codeholder.cpp",
        asmjit_path ++ "/core/codewriter.cpp",
        asmjit_path ++ "/core/compiler.cpp",
        asmjit_path ++ "/core/constpool.cpp",
        asmjit_path ++ "/core/cpuinfo.cpp",
        asmjit_path ++ "/core/emithelper.cpp",
        asmjit_path ++ "/core/emitter.cpp",
        asmjit_path ++ "/core/emitterutils.cpp",
        asmjit_path ++ "/core/environment.cpp",
        asmjit_path ++ "/core/errorhandler.cpp",
        asmjit_path ++ "/core/formatter.cpp",
        asmjit_path ++ "/core/func.cpp",
        asmjit_path ++ "/core/funcargscontext.cpp",
        asmjit_path ++ "/core/globals.cpp",
        asmjit_path ++ "/core/inst.cpp",
        asmjit_path ++ "/core/instdb.cpp",
        asmjit_path ++ "/core/jitallocator.cpp",
        asmjit_path ++ "/core/jitruntime.cpp",
        asmjit_path ++ "/core/logger.cpp",
        asmjit_path ++ "/core/operand.cpp",
        asmjit_path ++ "/core/osutils.cpp",
        asmjit_path ++ "/core/ralocal.cpp",
        asmjit_path ++ "/core/rapass.cpp",
        asmjit_path ++ "/core/rastack.cpp",
        asmjit_path ++ "/core/string.cpp",
        asmjit_path ++ "/core/support.cpp",
        asmjit_path ++ "/core/target.cpp",
        asmjit_path ++ "/core/type.cpp",
        asmjit_path ++ "/core/virtmem.cpp",
        asmjit_path ++ "/core/zone.cpp",
        asmjit_path ++ "/core/zonehash.cpp",
        asmjit_path ++ "/core/zonelist.cpp",
        asmjit_path ++ "/core/zonestack.cpp",
        asmjit_path ++ "/core/zonetree.cpp",
        asmjit_path ++ "/core/zonevector.cpp",
    };

    // ARM64-specific C++ sources
    const arm_sources = [_][]const u8{
        asmjit_path ++ "/arm/a64assembler.cpp",
        asmjit_path ++ "/arm/a64builder.cpp",
        asmjit_path ++ "/arm/a64compiler.cpp",
        asmjit_path ++ "/arm/a64emithelper.cpp",
        asmjit_path ++ "/arm/a64formatter.cpp",
        asmjit_path ++ "/arm/a64func.cpp",
        asmjit_path ++ "/arm/a64instapi.cpp",
        asmjit_path ++ "/arm/a64instdb.cpp",
        asmjit_path ++ "/arm/a64operand.cpp",
        asmjit_path ++ "/arm/a64rapass.cpp",
        asmjit_path ++ "/arm/armformatter.cpp",
    };

    asmjit.addCSourceFiles(.{
        .files = &core_sources,
        .flags = &asmjit_flags,
    });

    asmjit.addCSourceFiles(.{
        .files = &arm_sources,
        .flags = &asmjit_flags,
    });

    return asmjit;
}

// ============================================================================
// Build YCF (Yielding C Functions) tool
// ============================================================================

fn buildYcf(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step.Compile {
    const ycf_module = b.createModule(.{
        .root_source_file = null,
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    const ycf = b.addExecutable(.{
        .name = "yielding_c_fun",
        .root_module = ycf_module,
    });

    const ycf_path = "otp_src_28.1/erts/lib_src/yielding_c_fun";

    ycf.addIncludePath(b.path(ycf_path));

    const ycf_flags = [_][]const u8{
        "-std=c99",
    };

    const ycf_sources = [_][]const u8{
        ycf_path ++ "/ycf_lexer.c",
        ycf_path ++ "/ycf_main.c",
        ycf_path ++ "/ycf_node.c",
        ycf_path ++ "/ycf_parser.c",
        ycf_path ++ "/ycf_printers.c",
        ycf_path ++ "/ycf_string.c",
        ycf_path ++ "/ycf_symbol.c",
        ycf_path ++ "/ycf_utils.c",
        ycf_path ++ "/ycf_yield_fun.c",
    };

    ycf.addCSourceFiles(.{
        .files = &ycf_sources,
        .flags = &ycf_flags,
    });

    return ycf;
}
