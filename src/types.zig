/// The result of executing a single notebook cell.
/// Caller is responsible for freeing `figures` slice if non-null.
pub const CellResult = struct {
    stdout: ?[*:0]const u8 = null,
    stderr: ?[*:0]const u8 = null,
    /// Base64-encoded PNG images captured from matplotlib figures.
    figures: ?[]const [*:0]const u8 = null,
    success: bool = true,
};

/// A user-defined variable in the kernel's namespace.
/// All string fields are allocator-owned copies — safe to use after Python objects are freed.
pub const Variable = struct {
    name: [*:0]const u8,
    value: [*:0]const u8,
    type_name: [*:0]const u8,
};

/// An imported module visible in the kernel's namespace.
pub const Module = struct {
    name: [*:0]const u8,
    /// File path of the module, or "built-in" for modules without a file.
    path: [*:0]const u8,
};
