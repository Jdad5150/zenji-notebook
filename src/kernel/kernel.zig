//! Language-agnostic kernel dispatcher that routes calls to backend implementations.

const PythonKernel = @import("pythonkernel.zig").PythonKernel;
const JuliaKernel = @import("juliakernel.zig").JuliaKernel;
const RKernel = @import("rkernel.zig").RKernel;
const MojoKernel = @import("mojokernel.zig").MojoKernel;
const CellResult = @import("../types.zig").CellResult;
const Variable = @import("../types.zig").Variable;
const Module = @import("../types.zig").Module;
const std = @import("std");

/// Supported notebook kernel languages; stored as u8 in the .znb file header.
pub const Language = enum(u8) { python = 0, julia = 1, r = 2, mojo = 3 };

/// A language-agnostic kernel interface. All interaction with the underlying
/// interpreter goes through these methods — callers never touch backend types directly.
pub const Kernel = union(Language) {
    python: PythonKernel,
    julia: JuliaKernel,
    r: RKernel,
    mojo: MojoKernel,

    /// Create a new kernel for the given language using the supplied interpreter binary.
    /// For Python, `binary` is the path to the venv python (e.g. ".venv/bin/python").
    /// Stub kernels (Julia, R, Mojo) ignore `binary` for now.
    pub fn init(language: Language, io: std.Io, alloc: std.mem.Allocator, binary: []const u8) !Kernel {
        return switch (language) {
            .python => .{ .python = try PythonKernel.init(io, alloc, binary) },
            .r => .{ .r = try RKernel.init(io, alloc, binary) },
            .julia => .{ .julia = JuliaKernel.init(alloc) },
            .mojo => .{ .mojo = MojoKernel.init(alloc) },
        };
    }

    /// Returns the allocator used by this kernel.
    pub fn allocator(self: *Kernel) std.mem.Allocator {
        return switch (self.*) {
            .python => |k| k.allocator,
            .r => |k| k.allocator,
            .julia => |k| k.allocator,
            .mojo => |k| k.allocator,
        };
    }

    /// Execute a cell of code. Returns captured stdout, stderr, and any figures.
    pub fn execute(self: *Kernel, code: []const u8) !CellResult {
        return switch (self.*) {
            .python => |*k| try k.execute(code),
            .r => |*k| try k.execute(code),
            .julia => |*k| try k.execute(code),
            .mojo => |*k| try k.execute(code),
        };
    }

    /// Returns user-defined variables (excludes modules and internal state).
    /// Caller must free the returned slice and each variable's strings.
    pub fn getVariables(self: *Kernel) ![]const Variable {
        return switch (self.*) {
            .python => |*k| try k.getVariables(),
            .r => |*k| try k.getVariables(),
            .julia => |*k| try k.getVariables(),
            .mojo => |*k| try k.getVariables(),
        };
    }

    /// Returns imported modules visible in the kernel namespace.
    /// Caller must free the returned slice and each module's strings.
    pub fn getEnvironment(self: *Kernel) ![]const Module {
        return switch (self.*) {
            .python => |*k| try k.getModules(),
            .r => |*k| try k.getModules(),
            .julia => |*k| try k.getModules(),
            .mojo => |*k| try k.getModules(),
        };
    }

    /// Shut down the interpreter and release resources.
    pub fn deinit(self: *Kernel) void {
        switch (self.*) {
            .python => |*k| k.deinit(),
            .r => |*k| k.deinit(),
            .julia => |*k| k.deinit(),
            .mojo => |*k| k.deinit(),
        }
    }
};
