const std = @import("std");
const httpz = @import("httpz");

const frontend = @import("frontend");
const index_html = frontend.index_html;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var server = try httpz.Server(void).init(allocator, .{ .address = .localhost(8888) }, {});
    defer {
        server.stop();
        server.deinit();
    }

    var router = try server.router(.{});
    router.get("/", indexHandler, .{});

    std.debug.print("Zenji listening on http://localhost:8888\n", .{});
    try server.listen();
}

fn indexHandler(req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 200;
    res.content_type = .HTML;
    res.body = index_html;
}
