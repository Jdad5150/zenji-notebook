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

    // ── Kernel access ─────────────────────────────────────────────────────────
    ctx.kernel_mutex.lockUncancelable(ctx.io);

    // Check that a kernel has been configured.
    if (ctx.kernel.* == null) {
        ctx.kernel_mutex.unlock(ctx.io);
        res.status = 503;
        res.body = "{\"error\":\"no kernel configured — select an environment first\"}";
        return;
    }

    const result = blk: {
        // SAFETY: we checked non-null above and hold the mutex, so this is safe.
        const k = &ctx.kernel.*.?;
        break :blk k.execute(cell.source) catch |err| {
            std.log.err("kernel execute failed: {}", .{err});
            ctx.kernel_mutex.unlock(ctx.io);
            res.status = 500;
            res.body = "{\"error\":\"execution failed\"}";
            return;
        };
    };
    ctx.kernel_mutex.unlock(ctx.io);

    // Free the result strings when we're done building the response.
    const kernel_alloc = ctx.allocator;
    defer {
        if (result.stdout) |s| kernel_alloc.free(s);
        if (result.stderr) |s| kernel_alloc.free(s);
        if (result.figures) |figs| {
            for (figs) |f| kernel_alloc.free(f);
            kernel_alloc.free(figs);
        }
    }

    cell.execution_count += 1;

    // Count non-empty outputs (stdout, stderr, figures).
    var out_count: usize = 0;
    if (result.stdout) |s| if (s.len > 0) {
        out_count += 1;
    };
    if (result.stderr) |s| if (s.len > 0) {
        out_count += 1;
    };
    if (result.figures) |figs| {
        out_count += figs.len;
    }

    cell.outputs = try arena.alloc(Output, out_count);
    var out_idx: usize = 0;

    if (result.stdout) |s| if (s.len > 0) {
        cell.outputs[out_idx] = try Output.init(arena, .stdout, s);
        out_idx += 1;
    };
    if (result.stderr) |s| if (s.len > 0) {
        cell.outputs[out_idx] = try Output.init(arena, .stderr, s);
        out_idx += 1;
    };
    if (result.figures) |figs| {
        // Compute sidecar directory: .{stem} next to the notebook file.
        const stem = std.fs.path.stem(body.path);
        const dir = std.fs.path.dirname(body.path);
        const sidecar = if (dir) |d|
            try std.fmt.allocPrint(arena, "{s}/.{s}", .{ d, stem })
        else
            try std.fmt.allocPrint(arena, ".{s}", .{stem});

        // Cell sub-directory inside the sidecar.
        const cell_dir = try std.fmt.allocPrint(arena, "{s}/{d}", .{ sidecar, cell.cell_id });
        try std.Io.Dir.cwd().createDirPath(ctx.io, cell_dir);

        for (figs, 0..) |fig_b64, fig_idx| {
            // Decode base64 → raw PNG bytes.
            const decoder = std.base64.standard.Decoder;
            const decoded_len = try decoder.calcSizeForSlice(fig_b64);
            const png_bytes = try arena.alloc(u8, decoded_len);
            try decoder.decode(png_bytes, fig_b64);

            // Write PNG to sidecar.
            const png_path = try std.fmt.allocPrint(arena, "{s}/{d}.png", .{ cell_dir, fig_idx });
            try std.Io.Dir.cwd().writeFile(ctx.io, .{ .sub_path = png_path, .data = png_bytes });

            // Store only the path reference in the .znb.
            const ref = try std.fmt.allocPrint(arena, "{d}/{d}", .{ cell.cell_id, fig_idx });
            cell.outputs[out_idx] = try Output.init(arena, .image_ref, ref);
            out_idx += 1;
        }
    }

    nb.save(ctx.io, body.path) catch {
        res.status = 500;
        res.body = "{\"error\":\"failed to save notebook\"}";
        return;
    };

    // Build the JSON response.
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
