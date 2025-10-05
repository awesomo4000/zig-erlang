const std = @import("std");

// Build minimal termcap implementation in Zig
// Exports C-compatible API for Erlang to use

pub fn buildTermcap(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step.Compile {
    const termcap = b.addObject(.{
        .name = "termcap",
        .root_module = b.createModule(.{
            .root_source_file = b.path("build/termcap/termcap.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // Link libc for ioctl and other system calls
    termcap.linkLibC();

    return termcap;
}
