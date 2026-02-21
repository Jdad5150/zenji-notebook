const std = @import("std");
const log = std.log;
const httpz = @import("httpz");

const frontend = @import("frontend");
const index_html = frontend.index_html;

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

    var router = try server.router(.{});
    router.get("/", indexHandler, .{});

    log.info("Zenji-notebook started on port {d}", .{config.port});
    try server.listen();
}

fn indexHandler(req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 200;
    res.content_type = .HTML;
    res.body = index_html;
}
