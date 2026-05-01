const std = @import("std");
const CellResult = @import("../types.zig").CellResult;
const Variable = @import("../types.zig").Variable;
const Module = @import("../types.zig").Module;

pub const JuliaKernel = struct {
    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator) JuliaKernel {
        // TODO Add kernel initialization for Julia Lang
        return .{ .allocator = allocator };
    }
    pub fn execute(_: *JuliaKernel, _: [*:0]const u8) !CellResult {
        std.debug.print("Julia kernel not implemented\n", .{});
        return .{};
    }

    pub fn getVariables(_: *JuliaKernel) ![]const Variable {
        std.debug.print("Julia kernel getVariables not implemented\n", .{});
        return &.{};
    }

    pub fn getModules(_: *JuliaKernel) ![]const Module {
        std.debug.print("R kernel getModules not implemented\n", .{});
        return &.{};
    }


    pub fn deinit(_: *JuliaKernel) void {}
};
