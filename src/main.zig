//! Entry point for zenji-notebook.
//!
//! Parses CLI arguments and starts the HTTP server. All server logic lives
//! in src/server/. Supported flags:
//!   --port <n>     Listen port (default 8888)
//!   --token <tok>  Auth token
//!   --dev          Enable dev mode
//!   --no-auth      Disable token authentication
//!   --root <path>  Root directory to serve notebooks from (default: cwd)

const std = @import("std");
const httpz = @import("httpz");
const server = @import("server/server.zig");

const Arg = enum {
    @"--port",
    @"--dev",
    @"--no-auth",
    @"--token",
    @"--root",
    unknown,
};

fn parseArgs(args: []const []const u8) !server.Config {
    var config = server.Config{};
    var i: usize = 1;    
    
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        const parsed = std.meta.stringToEnum(Arg, arg) orelse .unknown;
        switch (parsed) {
            .@"--port" => {
                if (i + 1 >= args.len) return error.MissingPort;
                i += 1;
                config.port = try std.fmt.parseInt(u16, args[i], 10);
            },
            .@"--dev" => if (@import("builtin").mode == .Debug) {
                config.dev = true;
            },
            .@"--no-auth" => config.no_auth = true,
            .@"--token" => {
                if (i + 1 >= args.len) return error.MissingToken;
                i += 1;
                config.token = args[i];
            },
            .@"--root" => {
                if (i + 1 >= args.len) return error.MissingRoot;
                i += 1;
                config.root_dir = args[i];
            },
            .unknown => {},
        }
    }

    return config;
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    const args = try init.minimal.args.toSlice(init.arena.allocator());
    var config = try parseArgs(args);

    var explicit_no_auth: bool = false;
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--no-auth")) {
            explicit_no_auth = true;
            break;
        }
    }

    if (config.token != null and !explicit_no_auth) {
        config.no_auth = false;
    }

    try server.startServer(init.io, allocator, config);
}
