//! .zenji.json reader/writer — persists the user's environment selection.
//!
//! The file is written to / read from cwd (which is always root_dir after
//! the server applies --root). Format:
//!
//!   { "kind": "python", "label": "Python (.venv)", "binary": ".venv/bin/python" }

const std = @import("std");

const CONFIG_FILE = ".zenji.json";

pub const SavedEnv = struct {
    /// Language tag: "python" | "r" | "julia" | "mojo"
    kind: []const u8,
    /// Human-readable label shown in the UI.
    label: []const u8,
    /// Path to the interpreter binary.
    binary: []const u8,
};

/// Load the saved environment from .zenji.json in `dir`.
/// Returns null if the file does not exist.
/// On success, all strings are allocator-owned — call freeSavedEnv() when done.
pub fn load(io: std.Io, allocator: std.mem.Allocator, dir: []const u8) !?SavedEnv {
    const path = try std.fmt.allocPrint(allocator, "{s}/" ++ CONFIG_FILE, .{dir});
    defer allocator.free(path);
    const cwd = std.Io.Dir.cwd();
    const file = cwd.openFile(io, path, .{}) catch |err| switch (err) {
        error.FileNotFound => return null,
        else => return err,
    };
    defer file.close(io);

    var read_buf: [4096]u8 = undefined;
    var fr = file.reader(io, &read_buf);
    const size = try fr.getSize();
    if (size > read_buf.len) return error.ConfigFileTooLarge;
    const content = try fr.interface.readAlloc(allocator, size);
    defer allocator.free(content);

    const parsed = try std.json.parseFromSlice(
        SavedEnv,
        allocator,
        content,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();

    return SavedEnv{
        .kind   = try allocator.dupe(u8, parsed.value.kind),
        .label  = try allocator.dupe(u8, parsed.value.label),
        .binary = try allocator.dupe(u8, parsed.value.binary),
    };
}

/// Write the environment selection to .zenji.json in `dir`.
pub fn save(io: std.Io, allocator: std.mem.Allocator, dir: []const u8, env: SavedEnv) !void {
    const path = try std.fmt.allocPrint(allocator, "{s}/" ++ CONFIG_FILE, .{dir});
    defer allocator.free(path);

    const json = try std.json.Stringify.valueAlloc(allocator, env, .{});
    defer allocator.free(json);

    const cwd = std.Io.Dir.cwd();
    const file = try cwd.createFile(io, path, .{});
    defer file.close(io);
    try file.writeStreamingAll(io, json);
}

/// Free a SavedEnv returned by load().
pub fn freeSavedEnv(allocator: std.mem.Allocator, env: SavedEnv) void {
    allocator.free(env.kind);
    allocator.free(env.label);
    allocator.free(env.binary);
}
