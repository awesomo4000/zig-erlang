const std = @import("std");
const c = @cImport({
    @cInclude("sys/ioctl.h");
    @cInclude("unistd.h");
});

// Export C-compatible termcap API for Erlang
// This is a minimal implementation that just returns ANSI escape sequences
// which work on 99.9% of modern terminals

// tgetent: Initialize terminal
// Returns 1 on success, 0 on failure
export fn tgetent(bp: [*c]u8, name: [*c]const u8) c_int {
    _ = bp;
    _ = name;
    // We don't actually need to do anything here
    // Just return success - all modern terminals support ANSI
    return 1;
}

// tgetstr: Get string capability
// Returns escape sequence for the given capability
export fn tgetstr(id: [*c]const u8, area: [*c][*c]u8) [*c]u8 {
    _ = area; // We return static strings, don't need buffer management

    const id_slice = std.mem.span(id);

    // Cursor movement (parameterized)
    if (std.mem.eql(u8, id_slice, "cm")) {
        return @constCast("\x1b[%i%d;%dH");
    }

    // Clear to end of line
    if (std.mem.eql(u8, id_slice, "ce")) {
        return @constCast("\x1b[K");
    }

    // Clear screen
    if (std.mem.eql(u8, id_slice, "cl")) {
        return @constCast("\x1b[H\x1b[J");
    }

    // Carriage return
    if (std.mem.eql(u8, id_slice, "cr")) {
        return @constCast("\r");
    }

    // Cursor up
    if (std.mem.eql(u8, id_slice, "up")) {
        return @constCast("\x1b[A");
    }

    // Cursor down
    if (std.mem.eql(u8, id_slice, "do")) {
        return @constCast("\n");
    }

    // Cursor forward (right)
    if (std.mem.eql(u8, id_slice, "nd")) {
        return @constCast("\x1b[C");
    }

    // Cursor left
    if (std.mem.eql(u8, id_slice, "le")) {
        return @constCast("\x08"); // backspace
    }

    // Unknown capability
    return null;
}

// tgetnum: Get numeric capability
// Returns terminal dimensions or -1 if not found
export fn tgetnum(id: [*c]const u8) c_int {
    const id_slice = std.mem.span(id);

    // Get terminal size using ioctl
    var ws: c.struct_winsize = undefined;
    if (c.ioctl(c.STDOUT_FILENO, c.TIOCGWINSZ, &ws) == 0) {
        // Columns
        if (std.mem.eql(u8, id_slice, "co")) {
            return @intCast(ws.ws_col);
        }

        // Lines
        if (std.mem.eql(u8, id_slice, "li")) {
            return @intCast(ws.ws_row);
        }
    }

    return -1;
}

// tgetflag: Get boolean capability
// Returns 1 if flag is set, 0 otherwise
export fn tgetflag(id: [*c]const u8) c_int {
    const id_slice = std.mem.span(id);

    // Auto-margin: assume yes for all modern terminals
    if (std.mem.eql(u8, id_slice, "am")) {
        return 1;
    }

    return 0;
}

// tgoto: Format cursor movement string
// Simple implementation that handles the common %d format
export fn tgoto(cap: [*c]const u8, col: c_int, row: c_int) [*c]u8 {
    // Thread-local buffer for formatted output
    const S = struct {
        threadlocal var buffer: [64]u8 = undefined;
    };

    const cap_slice = std.mem.span(cap);

    // Handle the cursor movement format: "\x1b[%i%d;%dH"
    // %i means increment row/col by 1 (1-indexed)
    if (std.mem.indexOf(u8, cap_slice, "%i") != null) {
        const formatted = std.fmt.bufPrintZ(
            &S.buffer,
            "\x1b[{d};{d}H",
            .{ row + 1, col + 1 },
        ) catch return null;
        return @constCast(formatted.ptr);
    }

    // Just return the capability as-is if no formatting needed
    return @constCast(cap);
}

// tputs: Output string with padding
// We ignore padding on modern systems (it's a legacy feature)
export fn tputs(str: [*c]const u8, affcnt: c_int, putc: ?*const fn (c_int) c_int) c_int {
    _ = affcnt;

    if (str == null or putc == null) {
        return -1;
    }

    const str_slice = std.mem.span(str);
    const putc_fn = putc.?;

    // Just output each character
    for (str_slice) |ch| {
        _ = putc_fn(@intCast(ch));
    }

    return 0;
}
