//! Mojo kernel backend stub — not yet implemented.

const std = @import("std");
const CellResult = @import("../types.zig").CellResult;
const Variable = @import("../types.zig").Variable;
const Module = @import("../types.zig").Module;

/// Placeholder Mojo kernel; all methods print a not-implemented message.
pub const MojoKernel = struct {
    allocator: std.mem.Allocator,

    /// Initialize the Mojo kernel. Currently a no-op.
    // TODO: Add Mojo runtime initialization
    pub fn init(allocator: std.mem.Allocator) MojoKernel {
        return .{ .allocator = allocator };
    }

    /// Execute Mojo code. Not yet implemented.
    pub fn execute(_: *MojoKernel, _: [*:0]const u8) !CellResult {
        std.debug.print("Mojo kernel not implemented\n", .{});
        return .{};
    }

    /// Returns user-defined variables. Not yet implemented.
    pub fn getVariables(_: *MojoKernel) ![]const Variable {
        std.debug.print("Mojo kernel getVariables not implemented\n", .{});
        return &.{};
    }

    /// Returns imported modules. Not yet implemented.
    pub fn getModules(_: *MojoKernel) ![]const Module {
        std.debug.print("Mojo kernel getModules not implemented\n", .{});
        return &.{};
    }

    /// Shut down the Mojo kernel. Currently a no-op.
    pub fn deinit(_: *MojoKernel) void {}
};
