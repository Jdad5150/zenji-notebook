//! Entry point for zenji-notebook.
//!
//! Parses CLI arguments and starts the HTTP server. All server logic lives
//! in src/server/. Supported flags:
//!   --port <n>     Listen port (default 8888)
//!   --token <tok>  Auth token
//!   --dev          Enable dev mode
//!   --no-auth      Disable token authentication

const std = @import("std");
const httpz = @import("httpz");
const server = @import("server/server.zig");

const Arg = enum {
    @"--port",
    @"--dev",
    @"--no-auth",
    @"--token",
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
            .@"--dev" => config.dev = true,
            .@"--no-auth" => config.no_auth = true,
            .@"--token" => {
                if (i + 1 >= args.len) return error.MissingToken;
                i += 1;
                config.token = args[i];
            },
            .unknown => {},
        }
    }

    return config;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    
    const config = try parseArgs(args);   

    try server.startServer(allocator, config);
}
