//! Path validation utilities for sandbox enforcement.
//!
//! Ensures paths from untrusted sources (e.g. HTTP requests) cannot escape
//! the server's working directory. Call validatePath before any load/save
//! that uses a user-supplied path.

const std = @import("std");
const testing = std.testing;

/// Returns `error.PathEscape` if `path` is absolute or contains a `..` component.
///
/// Call this on every path received from an HTTP request before passing it
/// to Notebook.load() or Notebook.save().
pub fn validatePath(path: []const u8) error{PathEscape}!void {
    if (path.len == 0) return error.PathEscape;
    if (path[0] == '/') return error.PathEscape;
    var it = std.mem.tokenizeScalar(u8, path, '/');
    while (it.next()) |component| {
        if (std.mem.eql(u8, component, "..")) return error.PathEscape;
    }
}

test "validatePath accepts normal paths" {
    try validatePath("notebook.znb");
    try validatePath("notebooks/my_analysis.znb");
    try validatePath("a/b/c.znb");
    try validatePath("./notebook.znb");
}

test "validatePath rejects absolute paths" {
    try testing.expectError(error.PathEscape, validatePath("/etc/passwd"));
    try testing.expectError(error.PathEscape, validatePath("/notebook.znb"));
}

test "validatePath rejects dot-dot components" {
    try testing.expectError(error.PathEscape, validatePath("../secret.znb"));
    try testing.expectError(error.PathEscape, validatePath("notebooks/../../etc/passwd"));
    try testing.expectError(error.PathEscape, validatePath("a/b/../../../etc/passwd"));
}

test "validatePath rejects empty path" {
    try testing.expectError(error.PathEscape, validatePath(""));
}
