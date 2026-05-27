//! Path validation utilities.
//!
//! The server accepts absolute paths (so users can browse their entire
//! filesystem) but still rejects `..` components to prevent path traversal
//! attacks between sibling directories.

const std = @import("std");
const testing = std.testing;

/// Returns `error.PathEscape` if `path` is empty or contains a `..` component.
/// Absolute paths (starting with `/`) are allowed — the server is a local
/// single-user tool and intentionally supports browsing the whole filesystem.
pub fn validatePath(path: []const u8) error{PathEscape}!void {
    if (path.len == 0) return error.PathEscape;
    var it = std.mem.tokenizeScalar(u8, path, '/');
    while (it.next()) |component| {
        if (std.mem.eql(u8, component, "..")) return error.PathEscape;
    }
}

test "validatePath accepts relative paths" {
    try validatePath("notebook.znb");
    try validatePath("notebooks/my_analysis.znb");
    try validatePath("a/b/c.znb");
    try validatePath("./notebook.znb");
}

test "validatePath accepts absolute paths" {
    try validatePath("/home/user/project/notebook.znb");
    try validatePath("/tmp/test.znb");
}

test "validatePath rejects dot-dot components" {
    try testing.expectError(error.PathEscape, validatePath("../secret.znb"));
    try testing.expectError(error.PathEscape, validatePath("notebooks/../../etc/passwd"));
    try testing.expectError(error.PathEscape, validatePath("a/b/../../../etc/passwd"));
}

test "validatePath rejects empty path" {
    try testing.expectError(error.PathEscape, validatePath(""));
}
