//! Static asset serving from the embedded frontend bundle.
//!
//! The `static_assets` module is generated at build time by crawler.zig and
//! contains every file from src/frontend/build/ embedded via @embedFile.
//! serveStaticAsset() is registered as the "/*" catch-all route so any request
//! that doesn't match an API route falls through to here.
//!
//! In dev mode, requests are proxied to the Vite dev server at localhost:5173
//! so that HMR works without recompiling the Zig binary.

const std = @import("std");
const httpz = @import("httpz");
const static_assets = @import("static_assets");
const mime = @import("../util/mime.zig");
const Config = @import("./server.zig").Config;

pub fn serveStaticAsset(ctx: *const Config, req: *httpz.Request, res: *httpz.Response) !void {
    const raw = req.url.path;
    const key = if (raw.len > 0 and raw[0] == '/') raw[1..] else raw;

    std.log.info("static request: {s}", .{raw});

    if (ctx.dev) {
        // No file extension = SPA route, serve index.html from disk
        if (std.mem.lastIndexOfScalar(u8, key, '.') == null) {
            const file = try std.fs.cwd().openFile("src/frontend/build/index.html", .{});
            defer file.close();
            res.status = 200;
            res.content_type = .HTML;
            res.body = try file.readToEndAlloc(req.arena, 1024 * 1024 * 10);
            return;
        }

        // Has extension = actual asset, serve from disk
        const path = try std.fmt.allocPrint(req.arena, "src/frontend/build/{s}", .{key});
        const file = std.fs.cwd().openFile(path, .{}) catch {
            res.status = 404;
            return;
        };
        defer file.close();
        res.status = 200;
        res.content_type = mime.contentTypeForPath(key);
        res.body = try file.readToEndAlloc(req.arena, 1024 * 1024 * 10);
        return;
    }

    inline for (@typeInfo(@TypeOf(static_assets.assets)).@"struct".fields) |field| {
        if (std.mem.eql(u8, field.name, key)) {
            res.status = 200;
            res.content_type = mime.contentTypeForPath(field.name);
            res.body = @field(static_assets.assets, field.name);
            return;
        }
    }

    // SPA fallback: serve index.html for any unmatched path
    res.status = 200;
    res.content_type = .HTML;
    res.body = static_assets.assets.@"index.html";
}
