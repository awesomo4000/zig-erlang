const std = @import("std");

// ============================================================================
// Build vendored zlib
// ============================================================================

pub fn buildZlib(
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

pub fn buildZstd(
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

pub fn buildRyu(
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

pub fn buildPcre(
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

pub fn buildEthread(
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

pub fn buildAsmjit(
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

pub fn buildYcf(
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
