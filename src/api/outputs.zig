//! GET /outputs — serve a sidecar image artifact back to the browser.
//!
//! Query params:
//!   path  — notebook path  (e.g. "example.znb" or "notebooks/foo.znb")
//!   ref   — image reference stored in the .znb  (e.g. "0/0" = cell_id/fig_idx)
//!
//! The sidecar layout mirrors what execute.zig writes:
//!   .{notebook_stem}/{cell_id}/{fig_idx}.png
//!
//! Returns 200 image/png on success, 404 if the file is missing, 400 for bad params.

const std    = @import("std");
const httpz  = @import("httpz");
const Config = @import("../server/server.zig").Config;
const validatePath = @import("../util/path.zig").validatePath;

pub fn handle(ctx: *const Config, req: *httpz.Request, res: *httpz.Response) !void {
    const arena = req.arena;

    const q       = try req.query();
    const nb_path = q.get("path") orelse {
        res.status = 400;
        res.body   = "{\"error\":\"missing path\"}";
        return;
    };
    const ref = q.get("ref") orelse {
        res.status = 400;
        res.body   = "{\"error\":\"missing ref\"}";
        return;
    };

    // Validate notebook path — no ".." or absolute traversal.
    validatePath(nb_path) catch {
        res.status = 400;
        res.body   = "{\"error\":\"invalid path\"}";
        return;
    };

    // Validate ref — must be exactly "{digits}/{digits}", e.g. "0/0".
    var slash_count: usize = 0;
    for (ref) |c| {
        if (c == '/') { slash_count += 1; continue; }
        if (c < '0' or c > '9') {
            res.status = 400;
            res.body   = "{\"error\":\"invalid ref\"}";
            return;
        }
    }
    if (slash_count != 1 or ref.len < 3) {
        res.status = 400;
        res.body   = "{\"error\":\"invalid ref\"}";
        return;
    }

    // Reconstruct the sidecar path the same way execute.zig builds it.
    const stem    = std.fs.path.stem(nb_path);
    const dir     = std.fs.path.dirname(nb_path);
    const sidecar = if (dir) |d|
        try std.fmt.allocPrint(arena, "{s}/.{s}", .{ d, stem })
    else
        try std.fmt.allocPrint(arena, ".{s}", .{stem});

    const png_path = try std.fmt.allocPrint(arena, "{s}/{s}.png", .{ sidecar, ref });

    // Open, read, and return the PNG.
    const cwd  = std.Io.Dir.cwd();
    const file = cwd.openFile(ctx.io, png_path, .{}) catch |err| switch (err) {
        error.FileNotFound => {
            res.status = 404;
            res.body   = "{\"error\":\"image not found\"}";
            return;
        },
        else => return err,
    };
    defer file.close(ctx.io);

    var buf: [8192]u8 = undefined;
    var fr = file.reader(ctx.io, &buf);
    const size = try fr.getSize();
    const data = try fr.interface.readAlloc(arena, @intCast(size));

    res.status       = 200;
    res.content_type = .PNG;
    res.body         = data;
}
