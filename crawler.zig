//! Build-time utility that generates src/assets.zig from the compiled frontend.
//!
//! Called eagerly from build.zig before the Zig compiler runs. It walks
//! src/frontend/build/, then writes src/assets.zig with one @embedFile entry
//! per file. The result is imported as the `static_assets` module so the HTTP
//! server can serve all frontend files straight from the binary.
//!
//! src/assets.zig is .gitignored — regenerated on every `zig build`.
//! If src/frontend/build/ does not exist, an empty registry is written and a
//! warning is printed. Run `bun run build` inside src/frontend/ to populate it.

const std = @import("std");

pub fn writeRegistry(b: *std.Build) !void {
    const io = b.graph.io;
    const allocator = b.allocator;
    const cwd = std.Io.Dir.cwd();

    var registry_code: std.ArrayList(u8) = .empty;
    defer registry_code.deinit(allocator);

    try registry_code.appendSlice(allocator, "pub const assets = .{\n");

    if (cwd.openDir(io, "src/frontend/build", .{ .iterate = true })) |dir| {
        var mdir = dir;
        defer mdir.close(io);

        var walker = try mdir.walk(allocator);
        defer walker.deinit();

        while (try walker.next(io)) |entry| {
            if (entry.kind == .file) {
                try registry_code.print(
                    allocator,
                    "    .@\"{s}\" = @embedFile(\"frontend/build/{s}\"),\n",
                    .{ entry.path, entry.path },
                );
            }
        }
    } else |err| switch (err) {
        error.FileNotFound, error.NotDir => std.log.warn(
            "src/frontend/build not found — embedded assets will be empty." ++
                " Run `bun run build` inside src/frontend/ first.",
            .{},
        ),
        else => return err,
    }

    try registry_code.appendSlice(allocator, "};\n");

    const out_path = b.pathFromRoot("src/assets.zig");
    try cwd.writeFile(io, .{ .sub_path = out_path, .data = registry_code.items });
}
