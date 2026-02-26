//! Build-time utility that generates src/assets.zig from the compiled frontend.
//!
//! Called eagerly from build.zig before the Zig compiler runs. It walks
//! src/frontend/build/, then writes src/assets.zig with one @embedFile entry
//! per file. The result is imported as the `static_assets` module so the HTTP
//! server can serve all frontend files straight from the binary.
//!
//! src/assets.zig is .gitignored — regenerated on every `zig build`.

const std = @import("std");

pub fn writeRegistry(b: *std.Build) !void {
    var dir = try std.fs.cwd().openDir("src/frontend/build", .{ .iterate = true });
    defer dir.close();

    var walker = try dir.walk(b.allocator);
    defer walker.deinit();

    var registry_code: std.ArrayList(u8) = .empty;
    defer registry_code.deinit(b.allocator);

    const writer = registry_code.writer(b.allocator);

    try writer.writeAll("pub const assets = .{\n");
    while (try walker.next()) |entry| {
        if (entry.kind == .file) {
            try writer.print("    .@\"{s}\" = @embedFile(\"frontend/build/{s}\"),\n", .{ entry.path, entry.path });
        }
    }
    try writer.writeAll("};\n");

    const out_path = b.pathFromRoot("src/assets.zig");
    try std.fs.cwd().writeFile(.{ .sub_path = out_path, .data = registry_code.items });
}
