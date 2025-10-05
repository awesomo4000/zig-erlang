const std = @import("std");

const ncurses_root = "sources/ncurses-6.5";

pub fn buildNcurses(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    target_str: []const u8,
) *std.Build.Step.Compile {

    // Build directory - temporary build location in cache
    const build_dir = b.fmt(".zig-cache/ncurses-build/{s}", .{target_str});

    // Library paths (relative to platform-specific directory)
    const lib_output_rel = b.fmt("{s}/lib/libtinfo.a", .{target_str}); // Relative to zig-out
    const lib_build_path = b.fmt("{s}/lib/libtinfo.a", .{build_dir});

    // Check if already built (cache)
    const check_lib = b.addSystemCommand(&.{ "test", "-f", lib_build_path });

    // Create build directory
    const mkdir_cmd = b.addSystemCommand(&.{ "mkdir", "-p", build_dir });

    // Get absolute paths
    const cwd = b.pathFromRoot(".");
    const abs_build_dir = b.fmt("{s}/{s}", .{ cwd, build_dir });
    const abs_ncurses_root = b.fmt("{s}/{s}", .{ cwd, ncurses_root });

    // Determine zig cc target string and CPPFLAGS
    const zig_target = b.fmt("{s}-{s}", .{
        @tagName(target.result.cpu.arch),
        if (target.result.os.tag == .linux)
            "linux-gnu" // Use glibc for Linux
        else
            @tagName(target.result.os.tag),
    });

    // macOS needs custom ospeed type (sys/ttydev.h doesn't exist)
    const ospeed_opt = if (target.result.os.tag == .macos)
        "--with-ospeed=unsigned"
    else
        "";

    // Cross-compilation requires --host
    const host_opt = if (target.result.os.tag == .linux)
        b.fmt("--host={s}", .{zig_target})
    else
        "";

    // Configure ncurses with zig cc
    const configure_cmd = b.addSystemCommand(&.{
        "sh",
        "-c",
        b.fmt(
            \\cd {s} && \
            \\CC="zig cc -target {s}" \
            \\AR="zig ar" \
            \\RANLIB="zig ranlib" \
            \\{s}/configure \
            \\  --prefix={s} \
            \\  --without-shared \
            \\  --without-cxx \
            \\  --without-cxx-binding \
            \\  --without-ada \
            \\  --without-progs \
            \\  --without-tests \
            \\  --without-manpages \
            \\  --without-debug \
            \\  --disable-widec \
            \\  --disable-database \
            \\  --with-termlib \
            \\  --with-default-terminfo-dir=/usr/share/terminfo \
            \\  --enable-termcap \
            \\  {s} \
            \\  {s}
        ,
            .{ build_dir, zig_target, abs_ncurses_root, abs_build_dir, ospeed_opt, host_opt },
        ),
    });
    configure_cmd.step.dependOn(&mkdir_cmd.step);
    configure_cmd.has_side_effects = true;

    // Build ncurses libs only
    const make_cmd = b.addSystemCommand(&.{
        "sh",
        "-c",
        b.fmt("cd {s} && make libs -j$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)", .{build_dir}),
    });
    make_cmd.step.dependOn(&configure_cmd.step);
    make_cmd.has_side_effects = true;

    // Copy library to install prefix lib directory
    const lib_output_path = b.fmt("{s}/{s}", .{ b.install_prefix, lib_output_rel });
    const lib_output_dir = b.fmt("{s}/{s}/lib", .{ b.install_prefix, target_str });
    const copy_lib_cmd = b.addSystemCommand(&.{
        "sh",
        "-c",
        b.fmt("mkdir -p {s} && cp {s} {s}", .{ lib_output_dir, lib_build_path, lib_output_path }),
    });
    copy_lib_cmd.step.dependOn(&make_cmd.step);

    // Create a Compile step that depends on the built library
    const ncurses_module = b.createModule(.{
        .root_source_file = null,
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    const ncurses = b.addLibrary(.{
        .name = "tinfo",
        .root_module = ncurses_module,
        .linkage = .static,
    });

    // Add the built library using absolute path from install prefix
    ncurses.addObjectFile(.{ .cwd_relative = lib_output_path });

    // Add include directory from build dir
    const include_path = b.fmt("{s}/include", .{build_dir});
    ncurses.addIncludePath(b.path(include_path));

    // Ensure the library is built and copied before we try to use it
    ncurses.step.dependOn(&copy_lib_cmd.step);

    // Skip if already built
    check_lib.step.dependOn(&ncurses.step);

    return ncurses;
}
