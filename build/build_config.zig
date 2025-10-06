const std = @import("std");

// Erlang/OTP application installation configuration
// This allows fine-grained control over which OTP applications are included in the release

// Directories to exclude when installing Erlang applications
// These are not needed at runtime and save significant space
pub const exclude_dirs = [_][]const u8{
    "test",        // Test suites (can be 1-24MB per app)
    "doc",         // Documentation (160-752KB per app)
    "src",         // Source files (we have compiled .beam files)
    "examples",    // Example code
    "scripts",     // Build/development scripts
    "internal_doc", // Internal documentation
    "uc_spec",     // Unicode spec data (only used at build time)
    "AUTHORS",     // Metadata files
    "Makefile",
    "vsn.mk",
};

// Absolute minimum for a working BEAM VM with basic functionality
pub const minimal_apps = [_][]const u8{
    "kernel", // Core OS interface, file I/O, networking
    "stdlib", // Standard library, data structures
};

// Typical applications for most Erlang programs (same as minimal for now)
pub const standard_apps = minimal_apps;

// Full OTP installation (all available applications)
pub const full_apps = standard_apps ++ [_][]const u8{
    "compiler", // BEAM compiler (needed if compiling .erl at runtime)
    "sasl", // System Architecture Support Libraries (logging, release handling)
    // Additional applications below
    "asn1",
    "common_test",
    "crypto",
    "debugger",
    "dialyzer",
    "diameter",
    "edoc",
    "eldap",
    "erl_interface",
    "et",
    "eunit",
    "ftp",
    "inets",
    "jinterface",
    "megaco",
    "mnesia",
    "observer",
    "odbc",
    "os_mon",
    "parsetools",
    "public_key",
    "reltool",
    "runtime_tools",
    "snmp",
    "ssh",
    "ssl",
    "syntax_tools",
    "tftp",
    "tools",
    "wx",
    "xmerl",
};

// Custom: Define your own application set
pub const custom_apps = minimal_apps ++ [_][]const u8{
    "crypto",
    "ssl",
    // Add whatever your application needs
};

// Default application set to install
pub const default_apps = standard_apps;
