//! HTTP route handlers for the Jupyter Server API.
//!
//! Each function corresponds to one API endpoint. Unimplemented endpoints
//! return 501 Not Implemented as a placeholder until they are built out.
//! Static asset serving lives in static.zig, not here.

const std = @import("std");
const httpz = @import("httpz");

const static_assets = @import("static_assets");
const Config = @import("./server.zig").Config;
const executeApi = @import("../api/execute.zig");
const variablesApi = @import("../api/variables.zig");
const contentsApi = @import("../api/contents.zig");
const notebookApi = @import("../api/notebook.zig");

pub fn indexHandler(ctx: *const Config, req: *httpz.Request, res: *httpz.Response) !void {
    _ = ctx;
    _ = req;
    res.status = 200;
    res.content_type = .HTML;
    inline for (@typeInfo(@TypeOf(static_assets.assets)).@"struct".fields) |field| {
        if (comptime std.mem.eql(u8, field.name, "index.html")) {
            res.body = @field(static_assets.assets, field.name);
            return;
        }
    }
    res.body =
        "<html><body><h1>Zenji Notebook</h1>" ++
        "<p>No frontend assets found. Run <code>bun run build</code> " ++
        "inside <code>src/frontend/</code> then <code>zig build</code>.</p></body></html>";
}

// GET /api/contents?path=<dir>
pub fn contentsListHandler(ctx: *const Config, req: *httpz.Request, res: *httpz.Response) !void {
    return contentsApi.handle(ctx, req, res);
}

// GET /api/notebook?path=<path>
pub fn notebookGetHandler(ctx: *const Config, req: *httpz.Request, res: *httpz.Response) !void {
    return notebookApi.handle(ctx, req, res);
}

// PUT /api/notebook?path=<path>
pub fn notebookPutHandler(ctx: *const Config, req: *httpz.Request, res: *httpz.Response) !void {
    return notebookApi.handlePut(ctx, req, res);
}

// POST /api/execute
pub fn executeHandler(ctx: *const Config, req: *httpz.Request, res: *httpz.Response) !void {
    return executeApi.handle(ctx, req, res);
}

// GET /api/variables
pub fn variablesHandler(ctx: *const Config, req: *httpz.Request, res: *httpz.Response) !void {
    return variablesApi.handle(ctx, req, res);
}

// GET /api/
pub fn versionHandler(_: *const Config, req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}

// GET /api/spec.yaml
pub fn apiSpecHandler(_: *const Config, req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}

// GET /api/me
pub fn meHandler(_: *const Config, req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}

// GET /api/status
pub fn statusHandler(_: *const Config, req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}

// GET /api/contents/:path
pub fn contentsGetHandler(_: *const Config, req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}

// POST /api/contents/:path
pub fn contentsPostHandler(_: *const Config, req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}

// PATCH /api/contents/:path
pub fn contentsPatchHandler(_: *const Config, req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}

// PUT /api/contents/:path
pub fn contentsPutHandler(_: *const Config, req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}

// DELETE /api/contents/:path
pub fn contentsDeleteHandler(_: *const Config, req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}

// GET /api/contents/:path/checkpoints
pub fn checkpointsListHandler(_: *const Config, req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}

// POST /api/contents/:path/checkpoints
pub fn checkpointsCreateHandler(_: *const Config, req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}

// POST /api/contents/:path/checkpoints/:checkpoint_id
pub fn checkpointsRestoreHandler(_: *const Config, req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}

// DELETE /api/contents/:path/checkpoints/:checkpoint_id
pub fn checkpointsDeleteHandler(_: *const Config, req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}

// GET /api/sessions
pub fn sessionsListHandler(_: *const Config, req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}

// POST /api/sessions
pub fn sessionsCreateHandler(_: *const Config, req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}

// GET /api/sessions/:session
pub fn sessionGetHandler(_: *const Config, req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}

// PATCH /api/sessions/:session
pub fn sessionPatchHandler(_: *const Config, req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}

// DELETE /api/sessions/:session
pub fn sessionDeleteHandler(_: *const Config, req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}

// GET /api/kernels
pub fn kernelsListHandler(_: *const Config, req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}

// POST /api/kernels
pub fn kernelsStartHandler(_: *const Config, req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}

// GET /api/kernels/:kernel_id
pub fn kernelGetHandler(_: *const Config, req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}

// DELETE /api/kernels/:kernel_id
pub fn kernelDeleteHandler(_: *const Config, req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}

// POST /api/kernels/:kernel_id/interrupt
pub fn kernelInterruptHandler(_: *const Config, req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}

// POST /api/kernels/:kernel_id/restart
pub fn kernelRestartHandler(_: *const Config, req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}

// GET /api/kernelspecs
pub fn kernelspecsHandler(_: *const Config, req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}

// GET /api/config/:section_name
pub fn configGetHandler(_: *const Config, req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}

// PATCH /api/config/:section_name
pub fn configPatchHandler(_: *const Config, req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}

// GET /api/terminals
pub fn terminalsListHandler(_: *const Config, req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}

// POST /api/terminals
pub fn terminalsCreateHandler(_: *const Config, req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}

// GET /api/terminals/:terminal_id
pub fn terminalGetHandler(_: *const Config, req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}

// DELETE /api/terminals/:terminal_id
pub fn terminalDeleteHandler(_: *const Config, req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}
