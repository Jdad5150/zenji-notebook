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

/// Language-agnostic category for a variable — used by the frontend for
/// colour-coding without needing to know Python/R/Julia-specific type names.
pub const VarKind = enum {
    scalar,    // single numeric/boolean value
    string,    // single text value
    sequence,  // ordered collection (list, vector, 1-D array)
    mapping,   // key-value store (dict, named list)
    dataframe, // tabular data (DataFrame, data.frame, tibble)
    matrix,    // 2-D numerical array
    tensor,    // N-D array (ndim > 2)
    function,  // callable / closure
    other,     // anything else
};

/// A user-defined variable in the kernel namespace.
/// All fields are allocator-owned copies except `kind`.
pub const Variable = struct {
    name:      []const u8,
    value:     []const u8,
    type_name: []const u8,
    kind:      VarKind = .other,
    /// Dimension string, e.g. "100 × 5" or "200". Null for scalars/strings/functions.
    shape:     ?[]const u8 = null,
};

/// An imported module visible in the kernel namespace.
/// All fields are allocator-owned copies.
pub const Module = struct {
    name: []const u8,
    /// File path of the module, or "built-in" for modules without __file__.
    path: []const u8,
};
