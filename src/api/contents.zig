//! GET /api/contents — list directory contents for the file browser.
//!
//! Query param: ?path=<path>
//!   - "." for the server root (cwd)
//!   - An absolute path like "/home/user/projects" to browse anywhere
//! Response: JSON array of { name, path, isDirectory, size? }
//!   Paths in the response are absolute when the request path is absolute.

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

    // Reject ".." components but allow absolute paths.
    if (!std.mem.eql(u8, raw_path, ".")) {
        validatePath(raw_path) catch {
            res.status = 400;
            res.body = "{\"error\":\"invalid path\"}";
            return;
        };
    }

    const is_abs = raw_path.len > 0 and raw_path[0] == '/';

    const dir = (if (is_abs)
        std.Io.Dir.openDirAbsolute(ctx.io, raw_path, .{ .iterate = true })
    else
        std.Io.Dir.cwd().openDir(ctx.io, raw_path, .{ .iterate = true })) catch |err| switch (err) {
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

    var list: std.ArrayList(EntryJson) = .empty;
    var iter = dir.iterate();
    while (try iter.next(ctx.io)) |entry| {
        const is_dir = entry.kind == .directory;
        const name = try arena.dupe(u8, entry.name);

        // Build the entry path that the client will use for subsequent requests.
        // For absolute parent paths, return absolute child paths.
        const entry_path = if (is_abs)
            try std.fmt.allocPrint(arena, "{s}/{s}", .{ raw_path, name })
        else if (std.mem.eql(u8, raw_path, "."))
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
            .name        = name,
            .path        = entry_path,
            .isDirectory = is_dir,
            .size        = size,
        });
    }

    // Sort: directories first, then alphabetically within each group.
    std.mem.sort(EntryJson, list.items, {}, struct {
        fn lessThan(_: void, a: EntryJson, b: EntryJson) bool {
            if (a.isDirectory != b.isDirectory) return a.isDirectory;
            return std.mem.lessThan(u8, a.name, b.name);
        }
    }.lessThan);

    res.status = 200;
    res.content_type = .JSON;
    res.body = try std.json.Stringify.valueAlloc(arena, list.items, .{});
}
