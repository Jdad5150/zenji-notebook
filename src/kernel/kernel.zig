const PythonKernel = @import("pythonkernel.zig").PythonKernel;
const JuliaKernel = @import("juliakernel.zig").JuliaKernel;
const RKernel = @import("rkernel.zig").RKernel;
const MojoKernel = @import("mojokernel.zig").MojoKernel;
const CellResult = @import("../types.zig").CellResult;
const Variable = @import("../types.zig").Variable;
const Module = @import("../types.zig").Module;
const std = @import("std");

pub const KernelError = error{
    InitFailed,
};

pub const Language = enum(u8) { python = 0, julia = 1, r = 2, mojo = 3 };

/// A language-agnostic kernel interface. All interaction with the underlying
/// interpreter goes through these methods — callers never touch backend types directly.
pub const Kernel = union(Language) {
    python: PythonKernel,
    julia: JuliaKernel,
    r: RKernel,
    mojo: MojoKernel,

    /// Create a new kernel for the given language.
    pub fn init(language: Language, allocator: std.mem.Allocator) Kernel {
        switch (language) {
            .python => return .{ .python = PythonKernel.init(allocator) },
            .r => return .{ .r = RKernel.init(allocator) },
            .julia => return .{ .julia = JuliaKernel.init(allocator) },
            .mojo => return .{ .mojo = MojoKernel.init(allocator) },
        }
    }

    /// Execute a cell of code. Returns captured stdout, stderr, and any figures.
    pub fn execute(self: *Kernel, code: [*:0]const u8) !CellResult {
        switch (self.*) {
            .python => |*k| return try k.execute(code),
            .r => |*k| return try k.execute(code),
            .julia => |*k| return try k.execute(code),
            .mojo => |*k| return try k.execute(code),
        }
    }

    /// Returns user-defined variables (excludes modules and internal state).
    /// Caller must free the returned slice.
    pub fn getVariables(self: *Kernel) ![]const Variable {
        switch (self.*) {
            .python => |*k| return try k.getVariables(),
            .r => |*k| return try k.getVariables(),
            .julia => |*k| return try k.getVariables(),
            .mojo => |*k| return try k.getVariables(),
        }
    }

    /// Returns imported modules visible in the kernel namespace.
    /// Caller must free the returned slice.
    pub fn getEnvironment(self: *Kernel) ![]const Module {
        switch (self.*) {
            .python => |*k| return try k.getModules(),
            .r => |*k| return try k.getModules(),
            .julia => |*k| return try k.getModules(),
            .mojo => |*k| return try k.getModules(),
        }
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
