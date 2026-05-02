//! GET /api/notebook — load a notebook from disk and return it as JSON.
//!
//! Query param: ?path=<relative-path-to-.znb>
//! Response: { path, kernel_type, next_cell_id, cells: [...] }

const std = @import("std");
const httpz = @import("httpz");
const Config = @import("../server/server.zig").Config;
const Notebook = @import("../notebook/notebook.zig").Notebook;
const validatePath = @import("../util/path.zig").validatePath;
const Language = @import("../kernel/kernel.zig").Language;
const Cell = @import("../notebook/cell.zig").Cell;
const CellType = @import("../notebook/cell.zig").CellType;
const Output = @import("../notebook/output.zig").Output;
const OutputType = @import("../notebook/output.zig").OutputType;

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

const NotebookJson = struct {
    path: []const u8,
    kernel_type: []const u8,
    next_cell_id: u32,
    cells: []const CellJson,
};

/// GET /api/notebook?path=<path>
pub fn handle(ctx: *const Config, req: *httpz.Request, res: *httpz.Response) !void {
    const arena = req.arena;

    const q = try req.query();
    const path = q.get("path") orelse {
        res.status = 400;
        res.body = "{\"error\":\"missing path\"}";
        return;
    };

    validatePath(path) catch {
        res.status = 400;
        res.body = "{\"error\":\"invalid path\"}";
        return;
    };

    const nb = Notebook.load(ctx.io, path, arena) catch |err| switch (err) {
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

    const cells_json = try arena.alloc(CellJson, nb.cells.len);
    for (nb.cells, 0..) |cell, i| {
        const outputs_json = try arena.alloc(OutputJson, cell.outputs.len);
        for (cell.outputs, outputs_json) |output, *oj| {
            oj.* = .{
                .output_type = @tagName(output.output_type),
                .data = output.data,
            };
        }
        cells_json[i] = .{
            .cell_id = cell.cell_id,
            .cell_type = @tagName(cell.cell_type),
            .execution_count = cell.execution_count,
            .source = cell.source,
            .outputs = outputs_json,
        };
    }

    const nb_json = NotebookJson{
        .path = path,
        .kernel_type = @tagName(nb.meta.kernel_type),
        .next_cell_id = nb.next_cell_id,
        .cells = cells_json,
    };

    res.status = 200;
    res.content_type = .JSON;
    res.body = try std.json.Stringify.valueAlloc(arena, nb_json, .{});
}

/// PUT /api/notebook?path=...
/// Replaces the entire notebook on disk with the body content.
/// Used by the frontend after structural changes (add/delete/move cells).
pub fn handlePut(ctx: *const Config, req: *httpz.Request, res: *httpz.Response) !void {
    const arena = req.arena;

    const q = try req.query();
    const path = q.get("path") orelse {
        res.status = 400;
        res.body = "{\"error\":\"missing path\"}";
        return;
    };

    validatePath(path) catch {
        res.status = 400;
        res.body = "{\"error\":\"invalid path\"}";
        return;
    };

    const NotebookPutBody = struct {
        kernel_type: []const u8 = "python",
        next_cell_id: u32,
        cells: []const struct {
            cell_id: u32,
            cell_type: []const u8,
            source: []const u8,
            outputs: []const struct {
                output_type: []const u8,
                data: []const u8,
            },
        },
    };

    const body = (try req.json(NotebookPutBody)) orelse {
        res.status = 400;
        res.body = "{\"error\":\"missing or invalid body\"}";
        return;
    };

    const kernel_type: Language = if (std.mem.eql(u8, body.kernel_type, "julia"))
        .julia
    else if (std.mem.eql(u8, body.kernel_type, "r"))
        .r
    else if (std.mem.eql(u8, body.kernel_type, "mojo"))
        .mojo
    else
        .python;

    var nb = try Notebook.init(arena, .{ .kernel_type = kernel_type });
    nb.next_cell_id = body.next_cell_id;
    nb.cells = try arena.alloc(Cell, body.cells.len);

    for (body.cells, 0..) |src_cell, i| {
        const cell_type: CellType = if (std.mem.eql(u8, src_cell.cell_type, "markdown")) .markdown else .code;
        nb.cells[i] = try Cell.init(arena, cell_type, src_cell.cell_id, src_cell.source);

        // Restore outputs if present
        if (src_cell.outputs.len > 0) {
            nb.cells[i].outputs = try arena.alloc(Output, src_cell.outputs.len);
            for (src_cell.outputs, 0..) |src_out, j| {
                const out_type: OutputType = if (std.mem.eql(u8, src_out.output_type, "stderr"))
                    .stderr
                else if (std.mem.eql(u8, src_out.output_type, "image_ref"))
                    .image_ref
                else if (std.mem.eql(u8, src_out.output_type, "error"))
                    .err
                else
                    .stdout;
                nb.cells[i].outputs[j] = try Output.init(arena, out_type, src_out.data);
            }
        }
    }

    nb.save(ctx.io, path) catch {
        res.status = 500;
        res.body = "{\"error\":\"failed to save notebook\"}";
        return;
    };

    res.status = 200;
    res.body = "{\"ok\":true}";
}