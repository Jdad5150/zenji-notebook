//! Static asset serving from the embedded frontend bundle.
//!
//! The `static_assets` module is generated at build time by crawler.zig and
//! contains every file from src/frontend/build/ embedded via @embedFile.
//! serveStaticAsset() is registered as the "/*" catch-all route so any request
//! that doesn't match an API route falls through to here.
//!
//! In dev mode, assets are served from src/frontend/build/ on disk instead of
//! the embedded binary. Run `vite build --watch` alongside the server and
//! manually reload the browser.

const std = @import("std");
const httpz = @import("httpz");
const static_assets = @import("static_assets");
const mime = @import("../util/mime.zig");
const Config = @import("./server.zig").Config;

pub fn serveStaticAsset(ctx: *const Config, req: *httpz.Request, res: *httpz.Response) !void {
    const raw = req.url.path;
    const key = if (raw.len > 0 and raw[0] == '/') raw[1..] else raw;

    if (ctx.dev) {
        const cwd = std.Io.Dir.cwd();

        // No file extension = SPA route, serve index.html from disk.
        if (std.mem.lastIndexOfScalar(u8, key, '.') == null) {
            const file = try cwd.openFile(ctx.io, "src/frontend/build/index.html", .{});
            defer file.close(ctx.io);
            var buf: [8192]u8 = undefined;
            var fr = file.reader(ctx.io, &buf);
            const size = try fr.getSize();
            res.status = 200;
            res.content_type = .HTML;
            res.body = try fr.interface.readAlloc(req.arena, @intCast(size));
            return;
        }

        // Has extension = actual asset, serve from disk.
        const path = try std.fmt.allocPrint(req.arena, "src/frontend/build/{s}", .{key});
        if (cwd.openFile(ctx.io, path, .{})) |file| {
            defer file.close(ctx.io);
            var buf: [8192]u8 = undefined;
            var fr = file.reader(ctx.io, &buf);
            const size = try fr.getSize();
            res.status = 200;
            res.content_type = mime.contentTypeForPath(key);
            res.body = try fr.interface.readAlloc(req.arena, @intCast(size));
        } else |_| {
            res.status = 404;
        }
        return;
    }

    // Production: serve from embedded assets.
    inline for (@typeInfo(@TypeOf(static_assets.assets)).@"struct".fields) |field| {
        if (std.mem.eql(u8, field.name, key)) {
            res.status = 200;
            res.content_type = mime.contentTypeForPath(field.name);
            res.body = @field(static_assets.assets, field.name);
            return;
        }
    }

    // SPA fallback: serve index.html for any unmatched path.
    res.status = 200;
    res.content_type = .HTML;
    inline for (@typeInfo(@TypeOf(static_assets.assets)).@"struct".fields) |field| {
        if (comptime std.mem.eql(u8, field.name, "index.html")) {
            res.body = @field(static_assets.assets, field.name);
            return;
        }
    }
    res.body =
        "<html><body><h1>Zenji Notebook</h1>" ++
        "<p>No frontend assets found. Run <code>bun run build</code> " ++
        "inside <code>src/frontend/</code> then <code>zig build</code>.</p></body></html>";
}
