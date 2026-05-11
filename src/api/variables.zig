//! GET /api/variables — return kernel namespace variables and modules.
//!
//! Used by the DataExplorer panel in the frontend to show live variable state.
//! Returns both user-defined variables and imported modules visible in the
//! kernel namespace. Response is a JSON object with `variables` and `modules`
//! arrays, each containing { name, type, value } entries.

const std = @import("std");
const httpz = @import("httpz");
const Config = @import("../server/server.zig").Config;

const VariableJson = struct {
    name: []const u8,
    type: []const u8,
    value: []const u8,
};

const ModuleJson = struct {
    name: []const u8,
    path: []const u8,
};

const ResponseJson = struct {
    variables: []const VariableJson,
    modules: []const ModuleJson,
};

/// GET /api/variables
pub fn handle(ctx: *const Config, req: *httpz.Request, res: *httpz.Response) !void {
    const arena = req.arena;
    ctx.kernel_mutex.lockUncancelable(ctx.io);
    defer ctx.kernel_mutex.unlock(ctx.io);

    const vars = try ctx.kernel.getVariables();
    defer {
        for (vars) |v| {
            ctx.kernel.allocator().free(std.mem.span(v.name));
            ctx.kernel.allocator().free(std.mem.span(v.value));
            ctx.kernel.allocator().free(std.mem.span(v.type_name));
        }
        ctx.kernel.allocator().free(vars);
    }

    const mods = try ctx.kernel.getEnvironment();
    defer {
        for (mods) |m| {
            ctx.kernel.allocator().free(std.mem.span(m.name));
            if (!std.mem.eql(u8, std.mem.span(m.path), "built-in")) {
                ctx.kernel.allocator().free(std.mem.span(m.path));
            }
        }
        ctx.kernel.allocator().free(mods);
    }

    const vars_json = try arena.alloc(VariableJson, vars.len);
    for (vars, 0..) |v, i| {
        vars_json[i] = .{
            .name = std.mem.span(v.name),
            .type = std.mem.span(v.type_name),
            .value = std.mem.span(v.value),
        };
    }

    const mods_json = try arena.alloc(ModuleJson, mods.len);
    for (mods, 0..) |m, i| {
        mods_json[i] = .{
            .name = std.mem.span(m.name),
            .path = std.mem.span(m.path),
        };
    }

    const response = ResponseJson{
        .variables = vars_json,
        .modules = mods_json,
    };

    res.status = 200;
    res.content_type = .JSON;
    res.body = try std.json.Stringify.valueAlloc(arena, response, .{});
}
