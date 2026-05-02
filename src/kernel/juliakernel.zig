//! Julia kernel backend stub — not yet implemented.

const std = @import("std");
const CellResult = @import("../types.zig").CellResult;
const Variable = @import("../types.zig").Variable;
const Module = @import("../types.zig").Module;

/// Placeholder Julia kernel; all methods print a not-implemented message.
pub const JuliaKernel = struct {
    allocator: std.mem.Allocator,

    /// Initialize the Julia kernel. Currently a no-op.
    // TODO: Add Julia runtime initialization
    pub fn init(allocator: std.mem.Allocator) JuliaKernel {
        return .{ .allocator = allocator };
    }

    /// Execute Julia code. Not yet implemented.
    pub fn execute(_: *JuliaKernel, _: [*:0]const u8) !CellResult {
        std.debug.print("Julia kernel not implemented\n", .{});
        return .{};
    }

    /// Returns user-defined variables. Not yet implemented.
    pub fn getVariables(_: *JuliaKernel) ![]const Variable {
        std.debug.print("Julia kernel getVariables not implemented\n", .{});
        return &.{};
    }

    /// Returns imported modules. Not yet implemented.
    pub fn getModules(_: *JuliaKernel) ![]const Module {
        std.debug.print("Julia kernel getModules not implemented\n", .{});
        return &.{};
    }

    /// Shut down the Julia kernel. Currently a no-op.
    pub fn deinit(_: *JuliaKernel) void {}
};
