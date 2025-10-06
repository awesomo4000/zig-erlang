const std = @import("std");
const codegen = @import("build/codegen.zig");
const vendor_libs = @import("build/vendor_libs.zig");

// Source directory paths
const otp_root = "sources/otp-28.1";

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

    // Build minimal termcap library in Zig
    const termcap_lib = vendor_libs.buildTermcap(b, target, optimize);

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
        .termcap = termcap_lib,
        .asmjit = asmjit,
        .static_link = static_link,
        .enable_jit = enable_jit,
        .gen_step = gen_step,
    });

    // ============================================================================
    // erl_child_setup - Process spawning helper
    // ============================================================================

    const child_setup = buildErlChildSetup(b, target, optimize, .{
        .ethread = ethread,
        .gen_step = gen_step,
    });

    // ============================================================================
    // Installation
    // ============================================================================

    // Install to platform-specific directory: zig-out/{target}/bin/
    const install_step = b.getInstallStep();
    install_step.dependOn(&b.addInstallArtifact(beam, .{
        .dest_dir = .{
            .override = .{
                .custom = b.fmt("{s}/bin", .{target_str}),
            },
        },
    }).step);
    if (child_setup) |cs| {
        install_step.dependOn(&b.addInstallArtifact(cs, .{
            .dest_dir = .{
                .override = .{
                    .custom = b.fmt("{s}/bin", .{target_str}),
                },
            },
        }).step);
    }

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
    termcap: *std.Build.Step.Compile,
    asmjit: ?*std.Build.Step.Compile,
    static_link: bool,
    enable_jit: bool,
    gen_step: *std.Build.Step,
};

// ============================================================================
// Build erl_child_setup helper
// ============================================================================

const ChildSetupOptions = struct {
    ethread: *std.Build.Step.Compile,
    gen_step: *std.Build.Step,
};

fn buildErlChildSetup(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    options: ChildSetupOptions,
) ?*std.Build.Step.Compile {
    // erl_child_setup is Unix-only, skip for Windows
    if (target.result.os.tag == .windows) {
        return null;
    }

    // Create module for erl_child_setup
    const child_module = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    const child_setup = b.addExecutable(.{
        .name = "erl_child_setup",
        .root_module = child_module,
    });

    child_setup.step.dependOn(options.gen_step);

    // Add include directories
    const config_dir = getConfigDirName(b, target);
    child_setup.addIncludePath(b.path(b.fmt("{s}/erts/{s}", .{ otp_root, config_dir })));
    child_setup.addIncludePath(b.path(b.fmt("{s}/erts/include", .{otp_root})));
    child_setup.addIncludePath(b.path(b.fmt("{s}/erts/include/{s}", .{ otp_root, config_dir })));
    child_setup.addIncludePath(b.path(b.fmt("{s}/erts/include/internal", .{otp_root})));
    child_setup.addIncludePath(b.path(b.fmt("{s}/erts/emulator/beam", .{otp_root})));
    child_setup.addIncludePath(b.path(b.fmt("{s}/erts/emulator/sys/unix", .{otp_root})));
    child_setup.addIncludePath(b.path(b.fmt("{s}/erts/emulator/sys/common", .{otp_root})));
    child_setup.addIncludePath(b.path("build/generated"));

    // Add source files
    const child_flags = &.{
        "-DHAVE_CONFIG_H",
        "-D_GNU_SOURCE",
        "-include",
        "build/zig_compat.h",
    };

    child_setup.addCSourceFile(.{
        .file = b.path(b.fmt("{s}/erts/emulator/sys/unix/erl_child_setup.c", .{otp_root})),
        .flags = child_flags,
    });
    child_setup.addCSourceFile(.{
        .file = b.path(b.fmt("{s}/erts/emulator/sys/unix/sys_uds.c", .{otp_root})),
        .flags = child_flags,
    });
    child_setup.addCSourceFile(.{
        .file = b.path(b.fmt("{s}/erts/emulator/beam/hash.c", .{otp_root})),
        .flags = child_flags,
    });

    // Add Linux/musl compatibility functions
    if (target.result.os.tag == .linux or target.result.abi == .musl) {
        child_setup.addCSourceFile(.{
            .file = b.path("build/linux_compat.c"),
            .flags = &.{},
        });
    }

    // Link ethread library for threading support
    child_setup.linkLibrary(options.ethread);

    return child_setup;
}

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

    // For Windows, use simple format (config files are in build/windows_config/)
    if (os == .windows) {
        return b.fmt("{s}-unknown-windows", .{cpu});
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

    // Use platform-specific sys directory
    const sys_dir = if (target.result.os.tag == .windows) "/sys/win32" else "/sys/unix";
    beam.addIncludePath(b.path(b.fmt("{s}{s}", .{ emulator_path, sys_dir })));
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

    // For Windows, use pre-generated config from build/windows_config/
    if (target.result.os.tag == .windows) {
        const cpu = @tagName(target.result.cpu.arch);
        beam.addIncludePath(b.path(b.fmt("build/windows_config/{s}", .{cpu})));
    } else {
        beam.addIncludePath(b.path(b.fmt("{s}/{s}", .{erts_path, target_config_dir})));
    }

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

    // Platform-specific base flags
    const base_flags = if (target.result.os.tag == .windows)
        // Windows-specific flags
        // Note: zig automatically defines _WIN32_WINNT, so we don't redefine it
        // STATIC_ERLANG_DRIVER prevents macro conflicts in erl_win_dyn_driver.h
        // -fms-extensions enables __try/__except SEH support
        // Permissive flags needed for OTP's Windows C code (works with MSVC)
        &[_][]const u8{
            "-DHAVE_CONFIG_H",
            "-D_THREAD_SAFE",
            "-D_REENTRANT",
            "-DUSE_THREADS",
            "-D__WIN32__",
            "-DWINVER=0x0600",
            "-DSTATIC_ERLANG_DRIVER",
            "-DSTATIC_ERLANG_NIF",
            "-std=gnu99",
            "-fms-extensions",
            "-fno-common",
            "-fno-strict-aliasing",
            "-Wno-visibility",
            "-Wno-incompatible-pointer-types",
            "-Wno-int-conversion",
            "-Wno-deprecated-non-prototype",
            "-Wno-incompatible-function-pointer-types",
            "-Wno-pointer-sign",
            "-Wno-implicit-function-declaration",
            "-Wno-incompatible-library-redeclaration",
            "-Wno-comment",
            "-Wno-incompatible-pointer-types-discards-qualifiers",
            "-Wno-unused-value",
            "-Wno-return-type",
            "-Wno-cast-qual",
        }
    else if (target.result.os.tag == .linux)
        // Linux requires _GNU_SOURCE for extensions like syscall(), memrchr()
        // Include zig_compat.h to provide missing function declarations for musl libc
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
        // macOS and other Unix-like systems
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
    const max_base_flags = 32; // Buffer size for base_flags (plenty of headroom)
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

    // Windows cross-compilation: Use patched version of prim_socket_nif.c for Windows
    const prim_socket_nif_src = if (target.result.os.tag == .windows)
        "build/windows_compat/nifs/common/prim_socket_nif.c"
    else
        emulator_path ++ "/nifs/common/prim_socket_nif.c";

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
        prim_socket_nif_src,
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
    // System sources (platform-specific)
    // ========================================================================

    // Windows cross-compilation: Use patched versions for Windows
    const sys_sources = if (target.result.os.tag == .windows) [_][]const u8{
        "build/windows_compat/sys/win32/sys.c",
        emulator_path ++ "/sys/win32/sys_env.c",
        "build/windows_compat/sys/win32/sys_float.c",
        emulator_path ++ "/sys/win32/sys_time.c",
        emulator_path ++ "/sys/win32/sys_interrupt.c",
        emulator_path ++ "/sys/win32/erl_win32_sys_ddll.c",
        emulator_path ++ "/sys/win32/erl_poll.c",
        emulator_path ++ "/sys/win32/dosmap.c",
        // Common sources
        emulator_path ++ "/sys/common/erl_check_io.c",
        emulator_path ++ "/sys/common/erl_mseg.c",
        emulator_path ++ "/sys/common/erl_mmap.c",
        emulator_path ++ "/sys/common/erl_osenv.c",
        emulator_path ++ "/sys/common/erl_sys_common_misc.c",
        emulator_path ++ "/sys/common/erl_os_monotonic_time_extender.c",
        // Windows NIFs
        emulator_path ++ "/nifs/win32/win_prim_file.c",
        "build/windows_compat/nifs/win32/win_socket_asyncio.c",
    } else [_][]const u8{
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
    // Skip for Windows - Windows uses its own erl_poll.c in sys/win32
    if (target.result.os.tag != .windows) {
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
    }

    // ========================================================================
    // Main entry point (platform-specific)
    // ========================================================================

    const main_file = if (target.result.os.tag == .windows)
        emulator_path ++ "/sys/win32/erl_main.c"
    else
        emulator_path ++ "/sys/unix/erl_main.c";

    beam.addCSourceFile(.{
        .file = b.path(main_file),
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

        const cpp_flags = if (target.result.os.tag == .windows)
            &[_][]const u8{
                "-DHAVE_CONFIG_H",
                "-D_THREAD_SAFE",
                "-D_REENTRANT",
                "-DUSE_THREADS",
                "-D__WIN32__",
                "-DWINVER=0x0600",
                "-DSTATIC_ERLANG_DRIVER",
                "-DSTATIC_ERLANG_NIF",
                "-DBEAMASM",
                "-std=c++17",
                "-fno-common",
                "-fms-extensions",
                "-Wno-visibility",
                "-Wno-incompatible-pointer-types",
                "-Wno-int-conversion",
                "-Wno-deprecated-non-prototype",
                "-Wno-incompatible-function-pointer-types",
                "-Wno-pointer-sign",
                "-Wno-implicit-function-declaration",
                "-Wno-incompatible-library-redeclaration",
                "-Wno-comment",
                "-Wno-incompatible-pointer-types-discards-qualifiers",
                "-Wno-unused-value",
            }
        else if (target.result.os.tag == .linux)
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

    // Link minimal termcap library (provides termcap functions)
    beam.addObject(options.termcap);

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
