//! GET /api/variables — return kernel namespace variables and modules.
//!
//! Used by the DataExplorer panel in the frontend to show live variable state.
//! Returns 503 if no kernel is configured yet.

const std    = @import("std");
const httpz  = @import("httpz");
const Config = @import("../server/server.zig").Config;

const VariableJson = struct {
    name:  []const u8,
    type:  []const u8,
    value: []const u8,
    kind:  []const u8,
    shape: ?[]const u8,
};

const ModuleJson = struct {
    name: []const u8,
    path: []const u8,
};

const ResponseJson = struct {
    variables: []const VariableJson,
    modules:   []const ModuleJson,
};

/// GET /api/variables
pub fn handle(ctx: *const Config, req: *httpz.Request, res: *httpz.Response) !void {
    const arena = req.arena;

    ctx.kernel_mutex.lockUncancelable(ctx.io);
    defer ctx.kernel_mutex.unlock(ctx.io);

    if (ctx.kernel.* == null) {
        res.status = 503;
        res.body = "{\"error\":\"no kernel configured\"}";
        return;
    }

    const k = &ctx.kernel.*.?;

    const vars = try k.getVariables();
    defer {
        for (vars) |v| {
            ctx.allocator.free(v.name);
            ctx.allocator.free(v.value);
            ctx.allocator.free(v.type_name);
            if (v.shape) |s| ctx.allocator.free(s);
        }
        ctx.allocator.free(vars);
    }

    const mods = try k.getEnvironment();
    defer {
        for (mods) |m| {
            ctx.allocator.free(m.name);
            ctx.allocator.free(m.path);
        }
        ctx.allocator.free(mods);
    }

    const vars_json = try arena.alloc(VariableJson, vars.len);
    for (vars, 0..) |v, i| {
        vars_json[i] = .{
            .name  = v.name,
            .type  = v.type_name,
            .value = v.value,
            .kind  = @tagName(v.kind),
            .shape = v.shape,
        };
    }

    const mods_json = try arena.alloc(ModuleJson, mods.len);
    for (mods, 0..) |m, i| {
        mods_json[i] = .{
            .name = m.name,
            .path = m.path,
        };
    }

    res.status = 200;
    res.content_type = .JSON;
    res.body = try std.json.Stringify.valueAlloc(arena, ResponseJson{
        .variables = vars_json,
        .modules   = mods_json,
    }, .{});
}
