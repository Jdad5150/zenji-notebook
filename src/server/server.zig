//! HTTP server initialisation and lifecycle.
//!
//! Owns the httpz server instance, wires up the router, and blocks on listen.
//! Configuration (port, auth token, dev mode) is passed in via Config.

const std = @import("std");
const log = std.log;
const httpz = @import("httpz");
const routerz = @import("./router.zig");
pub const Config = struct {
    port: u16 = 8888,
    token: ?[]const u8 = null,
    dev: bool = false,
    no_auth: bool = false,
};

pub fn startServer(allocator: std.mem.Allocator, config: Config) !void {
    var server = try httpz.Server(void).init(allocator, .{ .address = .localhost(config.port) }, {});
    defer {
        server.stop();
        server.deinit();
    }

    const router = try server.router(.{});
    try routerz.registerRoutes(router);

    log.info("Zenji-notebook started on port {d}", .{config.port});
    try server.listen();
}
