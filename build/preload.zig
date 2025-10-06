const std = @import("std");

// Build function to create preload object
pub fn buildPreload(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step.Compile {
    const preload = b.addObject(.{
        .name = "preload",
        .root_module = b.createModule(.{
            .root_source_file = b.path("build/preload.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    return preload;
}

// Preloaded Erlang modules embedded at compile time
// These are the core modules that must be available before the code loader starts

// Embed all preloaded beam files
// Note: @embedFile paths are relative to this file (build/preload.zig)
const atomics_beam = @embedFile("sources/otp-28.1/erts/preloaded/ebin/atomics.beam");
const counters_beam = @embedFile("sources/otp-28.1/erts/preloaded/ebin/counters.beam");
const erl_init_beam = @embedFile("sources/otp-28.1/erts/preloaded/ebin/erl_init.beam");
const erl_prim_loader_beam = @embedFile("sources/otp-28.1/erts/preloaded/ebin/erl_prim_loader.beam");
const erl_tracer_beam = @embedFile("sources/otp-28.1/erts/preloaded/ebin/erl_tracer.beam");
const erlang_beam = @embedFile("sources/otp-28.1/erts/preloaded/ebin/erlang.beam");
const erts_code_purger_beam = @embedFile("sources/otp-28.1/erts/preloaded/ebin/erts_code_purger.beam");
const erts_dirty_process_signal_handler_beam = @embedFile("sources/otp-28.1/erts/preloaded/ebin/erts_dirty_process_signal_handler.beam");
const erts_internal_beam = @embedFile("sources/otp-28.1/erts/preloaded/ebin/erts_internal.beam");
const erts_literal_area_collector_beam = @embedFile("sources/otp-28.1/erts/preloaded/ebin/erts_literal_area_collector.beam");
const erts_trace_cleaner_beam = @embedFile("sources/otp-28.1/erts/preloaded/ebin/erts_trace_cleaner.beam");
const init_beam = @embedFile("sources/otp-28.1/erts/preloaded/ebin/init.beam");
const persistent_term_beam = @embedFile("sources/otp-28.1/erts/preloaded/ebin/persistent_term.beam");
const prim_buffer_beam = @embedFile("sources/otp-28.1/erts/preloaded/ebin/prim_buffer.beam");
const prim_eval_beam = @embedFile("sources/otp-28.1/erts/preloaded/ebin/prim_eval.beam");
const prim_file_beam = @embedFile("sources/otp-28.1/erts/preloaded/ebin/prim_file.beam");
const prim_inet_beam = @embedFile("sources/otp-28.1/erts/preloaded/ebin/prim_inet.beam");
const prim_net_beam = @embedFile("sources/otp-28.1/erts/preloaded/ebin/prim_net.beam");
const prim_socket_beam = @embedFile("sources/otp-28.1/erts/preloaded/ebin/prim_socket.beam");
const prim_zip_beam = @embedFile("sources/otp-28.1/erts/preloaded/ebin/prim_zip.beam");
const socket_registry_beam = @embedFile("sources/otp-28.1/erts/preloaded/ebin/socket_registry.beam");
const zlib_beam = @embedFile("sources/otp-28.1/erts/preloaded/ebin/zlib.beam");

// C-compatible preloaded module structure
const PreloadedModule = extern struct {
    name: ?[*:0]const u8,
    size: c_int,
    code: ?[*]const u8,
};

// Export the preloaded modules array for C code
// This matches the structure expected by erts/emulator/beam/beam_load.c
export const pre_loaded: [23]PreloadedModule = .{
    .{ .name = "atomics", .size = atomics_beam.len, .code = atomics_beam.ptr },
    .{ .name = "counters", .size = counters_beam.len, .code = counters_beam.ptr },
    .{ .name = "erl_init", .size = erl_init_beam.len, .code = erl_init_beam.ptr },
    .{ .name = "erl_prim_loader", .size = erl_prim_loader_beam.len, .code = erl_prim_loader_beam.ptr },
    .{ .name = "erl_tracer", .size = erl_tracer_beam.len, .code = erl_tracer_beam.ptr },
    .{ .name = "erlang", .size = erlang_beam.len, .code = erlang_beam.ptr },
    .{ .name = "erts_code_purger", .size = erts_code_purger_beam.len, .code = erts_code_purger_beam.ptr },
    .{ .name = "erts_dirty_process_signal_handler", .size = erts_dirty_process_signal_handler_beam.len, .code = erts_dirty_process_signal_handler_beam.ptr },
    .{ .name = "erts_internal", .size = erts_internal_beam.len, .code = erts_internal_beam.ptr },
    .{ .name = "erts_literal_area_collector", .size = erts_literal_area_collector_beam.len, .code = erts_literal_area_collector_beam.ptr },
    .{ .name = "erts_trace_cleaner", .size = erts_trace_cleaner_beam.len, .code = erts_trace_cleaner_beam.ptr },
    .{ .name = "init", .size = init_beam.len, .code = init_beam.ptr },
    .{ .name = "persistent_term", .size = persistent_term_beam.len, .code = persistent_term_beam.ptr },
    .{ .name = "prim_buffer", .size = prim_buffer_beam.len, .code = prim_buffer_beam.ptr },
    .{ .name = "prim_eval", .size = prim_eval_beam.len, .code = prim_eval_beam.ptr },
    .{ .name = "prim_file", .size = prim_file_beam.len, .code = prim_file_beam.ptr },
    .{ .name = "prim_inet", .size = prim_inet_beam.len, .code = prim_inet_beam.ptr },
    .{ .name = "prim_net", .size = prim_net_beam.len, .code = prim_net_beam.ptr },
    .{ .name = "prim_socket", .size = prim_socket_beam.len, .code = prim_socket_beam.ptr },
    .{ .name = "prim_zip", .size = prim_zip_beam.len, .code = prim_zip_beam.ptr },
    .{ .name = "socket_registry", .size = socket_registry_beam.len, .code = socket_registry_beam.ptr },
    .{ .name = "zlib", .size = zlib_beam.len, .code = zlib_beam.ptr },
    .{ .name = null, .size = 0, .code = undefined }, // terminator
};
