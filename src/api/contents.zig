//! GET /api/contents — list directory contents for the file browser.
//!
//! Query param: ?path=<relative-path>  (use "." for the server root)
//! Response: JSON array of { name, path, isDirectory, size? }

const std = @import("std");
const httpz = @import("httpz");
const Config = @import("../server/server.zig").Config;
const validatePath = @import("../util/path.zig").validatePath;

const EntryJson = struct {
    name: []const u8,
    path: []const u8,
    isDirectory: bool,
    size: ?u64,
};

/// GET /api/contents?path=<dir>
pub fn handle(ctx: *const Config, req: *httpz.Request, res: *httpz.Response) !void {
    const arena = req.arena;

    const q = try req.query();
    const raw_path = q.get("path") orelse ".";

    // "." is the safe root; anything else must pass the traversal check.
    if (!std.mem.eql(u8, raw_path, ".")) {
        validatePath(raw_path) catch {
            res.status = 400;
            res.body = "{\"error\":\"invalid path\"}";
            return;
        };
    }

    const dir = std.Io.Dir.cwd().openDir(ctx.io, raw_path, .{ .iterate = true }) catch |err| switch (err) {
        error.FileNotFound, error.NotDir => {
            res.status = 404;
            res.body = "{\"error\":\"directory not found\"}";
            return;
        },
        else => {
            res.status = 500;
            res.body = "{\"error\":\"failed to open directory\"}";
            return;
        },
    };
    defer dir.close(ctx.io);

    var list = std.ArrayList(EntryJson).empty;
    var iter = dir.iterate();
    while (try iter.next(ctx.io)) |entry| {
        const is_dir = entry.kind == .directory;
        // Dupe name before the next iteration invalidates entry.name.
        const name = try arena.dupe(u8, entry.name);
        const entry_path = if (std.mem.eql(u8, raw_path, "."))
            name
        else
            try std.fmt.allocPrint(arena, "{s}/{s}", .{ raw_path, name });

        var size: ?u64 = null;
        if (!is_dir) {
            if (dir.statFile(ctx.io, name, .{})) |st| {
                size = st.size;
            } else |_| {}
        }

        try list.append(arena, .{
            .name = name,
            .path = entry_path,
            .isDirectory = is_dir,
            .size = size,
        });
    }

    res.status = 200;
    res.content_type = .JSON;
    res.body = try std.json.Stringify.valueAlloc(arena, list.items, .{});
}
