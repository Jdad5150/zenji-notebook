//! Shared result and introspection types returned by all kernel backends.

/// The result of executing a single notebook cell.
/// stdout, stderr, and each figure string are allocator-owned — caller must free.
pub const CellResult = struct {
    stdout: ?[]const u8 = null,
    stderr: ?[]const u8 = null,
    /// Base64-encoded PNG images captured from matplotlib figures.
    /// Each string and the slice itself are allocator-owned.
    figures: ?[][]const u8 = null,
    success: bool = true,
};

/// A user-defined variable in the kernel namespace.
/// All fields are allocator-owned copies.
pub const Variable = struct {
    name: []const u8,
    value: []const u8,
    type_name: []const u8,
};

/// An imported module visible in the kernel namespace.
/// All fields are allocator-owned copies.
pub const Module = struct {
    name: []const u8,
    /// File path of the module, or "built-in" for modules without __file__.
    path: []const u8,
};
