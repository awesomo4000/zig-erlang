const std = @import("std");
const vendor_libs = @import("vendor_libs.zig");

// Source directory paths
const otp_root = "sources/otp-28.1";

pub fn generateSources(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    enable_jit: bool,
) *std.Build.Step {
    const gen_step = b.step("generate", "Generate source files");

    // Determine target architecture string
    const target_str = b.fmt("{s}-{s}-{s}", .{
        @tagName(target.result.cpu.arch),
        @tagName(target.result.os.tag),
        @tagName(target.result.abi),
    });

    const flavor = if (enable_jit) "jit" else "emu";
    const build_type = "opt";

    // Output directory for generated files: generated/target/type/flavor
    const gen_dir = b.fmt("generated/{s}/{s}/{s}", .{ target_str, build_type, flavor });

    // Determine JIT backend architecture
    const jit_arch = switch (target.result.cpu.arch) {
        .aarch64, .aarch64_be => "arm",
        .x86_64, .x86 => "x86",
        else => "arm", // Default to ARM for unsupported architectures
    };

    // Create generation directory
    const mkdir_cmd = b.addSystemCommand(&.{ "mkdir", "-p", gen_dir });
    gen_step.dependOn(&mkdir_cmd.step);

    const emulator_path = otp_root ++ "/erts/emulator";

    // Generate erl_alloc_types.h
    const alloc_types_out = b.fmt("{s}/erl_alloc_types.h", .{gen_dir});
    const alloc_vars = if (enable_jit)
        &[_][]const u8{ "threads", "nofrag", "beamasm", "unix" }
    else
        &[_][]const u8{ "threads", "nofrag", "unix" };

    const gen_alloc_cmd = b.addSystemCommand(&.{
        "perl",
        emulator_path ++ "/utils/make_alloc_types",
        "-src",
        emulator_path ++ "/beam/erl_alloc.types",
        "-dst",
        alloc_types_out,
    });
    for (alloc_vars) |v| {
        gen_alloc_cmd.addArg(v);
    }
    gen_alloc_cmd.step.dependOn(&mkdir_cmd.step);
    gen_step.dependOn(&gen_alloc_cmd.step);

    // Copy asmjit.h to asmjit.hpp for JIT build (header file needs .hpp extension)
    if (enable_jit) {
        const asmjit_dir = b.fmt("{s}/asmjit", .{gen_dir});
        const mkdir_asmjit = b.addSystemCommand(&.{ "mkdir", "-p", asmjit_dir });
        mkdir_asmjit.step.dependOn(&mkdir_cmd.step);

        const copy_asmjit_hpp = b.addSystemCommand(&.{
            "cp",
            emulator_path ++ "/asmjit/asmjit.h",
            b.fmt("{s}/asmjit.hpp", .{asmjit_dir}),
        });
        copy_asmjit_hpp.step.dependOn(&mkdir_asmjit.step);
        gen_step.dependOn(&copy_asmjit_hpp.step);

        // Generate beam_asm_global.hpp for JIT
        const beam_asm_global_out = b.fmt("{s}/beam_asm_global.hpp", .{gen_dir});
        const beam_asm_cmd = b.fmt("perl {s}/beam/jit/{s}/beam_asm_global.hpp.pl > {s}", .{ emulator_path, jit_arch, beam_asm_global_out });
        const gen_beam_asm_global = b.addSystemCommand(&.{
            "sh",
            "-c",
            beam_asm_cmd,
        });
        gen_beam_asm_global.step.dependOn(&mkdir_cmd.step);
        gen_step.dependOn(&gen_beam_asm_global.step);
    }

    // Generate opcodes
    // This generates: beam_opcodes.c/h, beam_cold.h, beam_warm.h, beam_hot.h
    const jit_arg = if (enable_jit) "yes" else "no";
    const gen_opcodes = b.addSystemCommand(&.{
        "perl",
        emulator_path ++ "/utils/beam_makeops",
        "-wordsize",
        "64",
        "-code-model",
        "unknown",
        "-outdir",
        gen_dir,
        "-jit",
        jit_arg,
        "-DUSE_VM_PROBES=0",
        "-emulator",
        otp_root ++ "/lib/compiler/src/genop.tab",
        emulator_path ++ "/beam/predicates.tab",
        emulator_path ++ "/beam/generators.tab",
        b.fmt("{s}/beam/jit/{s}/ops.tab", .{ emulator_path, jit_arch }),
        b.fmt("{s}/beam/jit/{s}/predicates.tab", .{ emulator_path, jit_arch }),
        b.fmt("{s}/beam/jit/{s}/generators.tab", .{ emulator_path, jit_arch }),
    });
    gen_opcodes.step.dependOn(&mkdir_cmd.step);
    gen_step.dependOn(&gen_opcodes.step);

    // Generate BIF and atom tables
    // This generates: erl_bif_table.c/h, erl_bif_list.h, erl_atom_table.c/h, erl_guard_bifs.c, erl_dirty_bif_wrap.c
    const gen_tables = b.addSystemCommand(&.{
        "perl",
        emulator_path ++ "/utils/make_tables",
        "-src",
        gen_dir,
        "-include",
        gen_dir,
        "-dst",
        "no", // DS_TEST - dirty scheduler test (disabled for normal builds)
        "-jit",
        jit_arg,
        emulator_path ++ "/beam/atom.names",
        emulator_path ++ "/beam/erl_dirty_bif.tab",
        emulator_path ++ "/beam/bif.tab",
    });
    gen_tables.step.dependOn(&mkdir_cmd.step);
    gen_step.dependOn(&gen_tables.step);

    // Generate erl_version.h
    const version_out = b.fmt("{s}/erl_version.h", .{gen_dir});
    const gen_version = b.addSystemCommand(&.{
        "perl",
        emulator_path ++ "/utils/make_version",
        "-o",
        version_out,
        "OTP-28.1", // SYSTEM_VSN
        "28.1", // OTP_VERSION
        "16.1", // VSN (ERTS version from vsn.mk)
        target_str, // TARGET
    });
    gen_version.step.dependOn(&mkdir_cmd.step);
    gen_step.dependOn(&gen_version.step);

    // Generate erl_compile_flags.h
    const compile_flags_out = b.fmt("{s}/erl_compile_flags.h", .{gen_dir});
    const gen_compile_flags = b.addSystemCommand(&.{
        "perl",
        emulator_path ++ "/utils/make_compiler_flags",
        "-o",
        compile_flags_out,
        "-v",
        "CONFIG_H",
        "N/A",
        "-v",
        "CFLAGS",
        "-O2",
        "-v",
        "LDFLAGS",
        "",
    });
    gen_compile_flags.step.dependOn(&mkdir_cmd.step);
    gen_step.dependOn(&gen_compile_flags.step);

    // Generate driver_tab.c
    const driver_tab_out = b.fmt("{s}/driver_tab.c", .{gen_dir});
    const gen_driver_tab = b.addSystemCommand(&.{
        "perl",
        emulator_path ++ "/utils/make_driver_tab",
        "-o",
        driver_tab_out,
        "-drivers",
        "inet_drv",
        "ram_file_drv",
        "-nifs",
        "prim_socket_nif",
        "prim_net_nif",
        "prim_tty_nif",
        "erl_tracer_nif",
        "prim_buffer_nif",
        "prim_file_nif",
        "zlib_nif",
        "zstd_nif",
    });
    gen_driver_tab.step.dependOn(&mkdir_cmd.step);
    gen_step.dependOn(&gen_driver_tab.step);

    // ========================================================================
    // YCF (Yielding C Functions) - Generate real yielding function headers
    // ========================================================================

    // Build the YCF tool for the host system (it runs during build, not on target)
    const ycf_tool = vendor_libs.buildYcf(b, b.graph.host, .ReleaseFast);

    // Generate utils.ycf.h from beam/utils.c
    const utils_ycf_out = b.fmt("{s}/utils.ycf.h", .{gen_dir});
    const gen_utils_ycf = b.addRunArtifact(ycf_tool);
    gen_utils_ycf.addArgs(&.{
        "-yield",
        "-only_yielding_funs",
        "-f",
        "erts_qsort",
        "-f",
        "erts_qsort_helper",
        "-f",
        "erts_qsort_partion_array",
        "-output_file_name",
        utils_ycf_out,
        emulator_path ++ "/beam/utils.c",
    });
    gen_utils_ycf.step.dependOn(&ycf_tool.step);
    gen_utils_ycf.step.dependOn(&mkdir_cmd.step);
    gen_step.dependOn(&gen_utils_ycf.step);

    // Generate erl_map.ycf.h from beam/erl_map.c
    const map_ycf_out = b.fmt("{s}/erl_map.ycf.h", .{gen_dir});
    const gen_map_ycf = b.addRunArtifact(ycf_tool);
    gen_map_ycf.addArgs(&.{
        "-yield",
        "-static_aux_funs",
        "-only_yielding_funs",
        "-fnoauto",
        "maps_keys_1_helper",
        "-fnoauto",
        "maps_values_1_helper",
        "-fnoauto",
        "maps_from_keys_2_helper",
        "-fnoauto",
        "maps_from_list_1_helper",
        // Also transform functions called by the above (wrapped in INCLUDE_YCF_TRANSFORMED_ONLY_FUNCTIONS)
        "-f",
        "hashmap_keys",
        "-f",
        "hashmap_values",
        "-f",
        "hashmap_from_validated_list",
        "-output_file_name",
        map_ycf_out,
        emulator_path ++ "/beam/erl_map.c",
    });
    gen_map_ycf.step.dependOn(&ycf_tool.step);
    gen_map_ycf.step.dependOn(&mkdir_cmd.step);
    gen_step.dependOn(&gen_map_ycf.step);

    // Generate erl_db_insert_list.ycf.h from beam/erl_db.c
    const db_insert_ycf_out = b.fmt("{s}/erl_db_insert_list.ycf.h", .{gen_dir});
    const gen_db_insert_ycf = b.addRunArtifact(ycf_tool);
    gen_db_insert_ycf.addArgs(&.{
        "-yield",
        "-static_aux_funs",
        "-only_yielding_funs",
        "-f",
        "ets_insert_2_list_check",
        "-f",
        "ets_insert_new_2_list_has_member",
        "-f",
        "ets_insert_2_list_from_p_heap",
        "-f",
        "ets_insert_2_list_destroy_copied_dbterms",
        "-f",
        "ets_insert_2_list_copy_term_list",
        "-f",
        "ets_insert_new_2_dbterm_list_has_member",
        "-f",
        "ets_insert_2_list_insert_db_term_list",
        "-f",
        "ets_insert_2_list",
        "-fnoauto",
        "ets_insert_2_list_lock_tbl",
        "-output_file_name",
        db_insert_ycf_out,
        emulator_path ++ "/beam/erl_db.c",
    });
    gen_db_insert_ycf.step.dependOn(&ycf_tool.step);
    gen_db_insert_ycf.step.dependOn(&mkdir_cmd.step);
    gen_step.dependOn(&gen_db_insert_ycf.step);

    // Generate preload.c - minimal stub with no preloaded modules
    const preload_out = b.fmt("{s}/preload.c", .{gen_dir});
    const preload_content =
        \\/*
        \\ * Minimal preload stub - no modules preloaded for minimal build
        \\ * Generated for zig-erlang minimal build
        \\ */
        \\
        \\#ifdef HAVE_CONFIG_H
        \\#  include "config.h"
        \\#endif
        \\
        \\#include "sys.h"
        \\
        \\/* Preload structure */
        \\const struct {
        \\   char* name;
        \\   int size;
        \\   const unsigned char* code;
        \\} pre_loaded[] = {
        \\  {0, 0, 0}  /* terminator */
        \\};
        \\
    ;
    const create_preload = b.addSystemCommand(&.{
        "sh",
        "-c",
        b.fmt("cat > {s} << 'PRELOADEOF'\n{s}\nPRELOADEOF", .{ preload_out, preload_content }),
    });
    create_preload.step.dependOn(&mkdir_cmd.step);
    gen_step.dependOn(&create_preload.step);

    return gen_step;
}
