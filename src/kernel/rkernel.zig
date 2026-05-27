//! R kernel backend stub — not yet implemented.

const std = @import("std");
const CellResult = @import("../types.zig").CellResult;
const Variable = @import("../types.zig").Variable;
const Module = @import("../types.zig").Module;

/// Placeholder R kernel; all methods print a not-implemented message.
pub const RKernel = struct {
    allocator: std.mem.Allocator,

    /// Initialize the R kernel. Currently a no-op.
    // TODO: Add R runtime initialization
    pub fn init(allocator: std.mem.Allocator) RKernel {
        return .{ .allocator = allocator };
    }

    /// Execute R code. Not yet implemented.
    pub fn execute(_: *RKernel, _: []const u8) !CellResult {
        std.debug.print("R kernel not implemented\n", .{});
        return .{};
    }

    /// Returns user-defined variables. Not yet implemented.
    pub fn getVariables(_: *RKernel) ![]const Variable {
        std.debug.print("R kernel getVariables not implemented\n", .{});
        return &.{};
    }

    /// Returns imported modules. Not yet implemented.
    pub fn getModules(_: *RKernel) ![]const Module {
        std.debug.print("R kernel getModules not implemented\n", .{});
        return &.{};
    }

    /// Shut down the R kernel. Currently a no-op.
    pub fn deinit(_: *RKernel) void {}
};
