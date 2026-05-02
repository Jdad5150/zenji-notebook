//! POST /api/execute — run a single cell and write results back to the .znb file.
//!
//! Request body: { "path": "...", "cell_id": <u32> }
//! Response: the updated cell as JSON on success, or an error object.

const std = @import("std");
const httpz = @import("httpz");
const Config = @import("../server/server.zig").Config;
const Notebook = @import("../notebook/notebook.zig").Notebook;
const Output = @import("../notebook/output.zig").Output;
const validatePath = @import("../util/path.zig").validatePath;

const ExecuteBody = struct {
    path: []const u8,
    cell_id: u32,
};

const OutputJson = struct {
    output_type: []const u8,
    data: []const u8,
};

const CellJson = struct {
    cell_id: u32,
    cell_type: []const u8,
    execution_count: u32,
    source: []const u8,
    outputs: []const OutputJson,
};

/// POST /api/execute
pub fn handle(ctx: *const Config, req: *httpz.Request, res: *httpz.Response) !void {
    const arena = req.arena;

    const body = (try req.json(ExecuteBody)) orelse {
        res.status = 400;
        res.body = "{\"error\":\"missing or invalid body\"}";
        return;
    };

    validatePath(body.path) catch {
        res.status = 400;
        res.body = "{\"error\":\"invalid path\"}";
        return;
    };

    var nb = Notebook.load(ctx.io, body.path, arena) catch |err| switch (err) {
        error.FileNotFound => {
            res.status = 404;
            res.body = "{\"error\":\"notebook not found\"}";
            return;
        },
        else => {
            res.status = 500;
            res.body = "{\"error\":\"failed to load notebook\"}";
            return;
        },
    };

    const cell = nb.findCell(body.cell_id) orelse {
        res.status = 404;
        res.body = "{\"error\":\"cell not found\"}";
        return;
    };

    const code = try arena.dupeZ(u8, cell.source);

    ctx.kernel_mutex.lockUncancelable(ctx.io);
    const result = ctx.kernel.execute(code) catch {
        ctx.kernel_mutex.unlock(ctx.io);
        res.status = 500;
        res.body = "{\"error\":\"execution failed\"}";
        return;
    };
    ctx.kernel_mutex.unlock(ctx.io);

    cell.execution_count += 1;

    var out_count: usize = 0;
    if (result.stdout) |s| if (std.mem.span(s).len > 0) {
        out_count += 1;
    };
    if (result.stderr) |s| if (std.mem.span(s).len > 0) {
        out_count += 1;
    };

    // Arena frees are no-ops — just overwrite the slice pointer.
    cell.outputs = try arena.alloc(Output, out_count);
    var out_idx: usize = 0;

    if (result.stdout) |s| {
        const sl = std.mem.span(s);
        if (sl.len > 0) {
            cell.outputs[out_idx] = try Output.init(arena, .stdout, sl);
            out_idx += 1;
        }
    }
    if (result.stderr) |s| {
        const sl = std.mem.span(s);
        if (sl.len > 0) {
            cell.outputs[out_idx] = try Output.init(arena, .stderr, sl);
            out_idx += 1;
        }
    }

    nb.save(ctx.io, body.path) catch {
        res.status = 500;
        res.body = "{\"error\":\"failed to save notebook\"}";
        return;
    };

    const outputs_json = try arena.alloc(OutputJson, cell.outputs.len);
    for (cell.outputs, 0..) |output, i| {
        outputs_json[i] = .{
            .output_type = @tagName(output.output_type),
            .data = output.data,
        };
    }

    const cell_json = CellJson{
        .cell_id = cell.cell_id,
        .cell_type = @tagName(cell.cell_type),
        .execution_count = cell.execution_count,
        .source = cell.source,
        .outputs = outputs_json,
    };

    res.status = 200;
    res.content_type = .JSON;
    res.body = try std.json.Stringify.valueAlloc(arena, cell_json, .{});
}
