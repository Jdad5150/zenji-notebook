//! HTTP server initialisation and lifecycle.
//!
//! Owns the httpz server instance, registers middleware and routes, then
//! blocks on listen(). SIGINT and SIGTERM are caught by a dedicated signal
//! thread that calls server.stop(), allowing listen() to return cleanly.
//!
//! In dev mode, CORS is enabled for the Vite dev server at localhost:5173.
//! The --dev flag is ignored in release builds.

const std = @import("std");
const log = std.log;
const posix = std.posix;
const httpz = @import("httpz");
const routerz = @import("./router.zig");
const middleware = @import("middleware.zig");
const tokenz = @import("../auth/token.zig").Token;

const HttpServer = httpz.Server(*const Config);

fn signalThread(server: *HttpServer) void {
    var mask = posix.sigemptyset();
    posix.sigaddset(&mask, posix.SIG.INT);
    posix.sigaddset(&mask, posix.SIG.TERM);

    var sig: c_int = 0;
    _ = std.c.sigwait(&mask, &sig);

    log.info("shutting down (signal {d})", .{sig});
    server.stop();
}
pub const Config = struct {
    port: u16 = 8888,
    token: ?[]const u8 = null,
    dev: bool = false,
    no_auth: bool = false,
};

pub fn startServer(allocator: std.mem.Allocator, config: Config) !void {
    var server = try httpz.Server(*const Config).init(allocator, .{ .address = .localhost(config.port) }, &config);
    defer server.deinit();
    const logger = try server.middleware(middleware.Logger, .{});

    var tok = tokenz{};
    tok.generate();

    const auth = try server.middleware(middleware.Auth, .{
        .token = &tok,
        .no_auth = config.no_auth,
    });

    const router = try server.router(.{});
    if (config.dev) {
        const cors = try server.middleware(httpz.middleware.Cors, .{
            .origin = "http://localhost:5173",
        });
        router.middlewares = &.{ logger, auth, cors };
    } else {
        router.middlewares = &.{ logger, auth };
    }

    try routerz.registerRoutes(router);

    // Block signals on the main thread before spawning the signal thread,
    // so the OS delivers them to sigwait instead of the default handler.
    var mask = posix.sigemptyset();
    posix.sigaddset(&mask, posix.SIG.INT);
    posix.sigaddset(&mask, posix.SIG.TERM);
    posix.sigprocmask(posix.SIG.BLOCK, &mask, null);

    const thread = try std.Thread.spawn(.{}, signalThread, .{&server});
    thread.detach();

    std.debug.print("Zenji-notebook listening on \x1b]8;;http://localhost:{d}/?token={s}\x1b\\http://localhost:{d}/?token={s}\x1b]8;;\x1b\\\n", .{ config.port, tok.token, config.port, tok.token });
    try server.listen();
}
