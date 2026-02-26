//! Static asset serving from the embedded frontend bundle.
//!
//! The `static_assets` module is generated at build time by crawler.zig and
//! contains every file from src/frontend/build/ embedded via @embedFile.
//! serveStaticAsset() is registered as the "/*" catch-all route so any request
//! that doesn't match an API route falls through to here.

const std = @import("std");
const httpz = @import("httpz");
const static_assets = @import("static_assets");
const mime = @import("../util/mime.zig");

pub fn serveStaticAsset(req: *httpz.Request, res: *httpz.Response) !void {
    const raw = req.url.path;
    const key = if (raw.len > 0 and raw[0] == '/') raw[1..] else raw;

    inline for (@typeInfo(@TypeOf(static_assets.assets)).@"struct".fields) |field| {
        if (std.mem.eql(u8, field.name, key)) {
            res.status = 200;
            res.content_type = mime.contentTypeForPath(field.name);
            res.body = @field(static_assets.assets, field.name);
            return;
        }
    }

    res.status = 404;
}
