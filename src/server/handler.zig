//! HTTP route handlers for the Jupyter Server API.
//!
//! Each function corresponds to one API endpoint. Unimplemented endpoints
//! return 501 Not Implemented as a placeholder until they are built out.
//! Static asset serving lives in static.zig, not here.

const std = @import("std");
const httpz = @import("httpz");

const static_assets = @import("static_assets");
const Config = @import("./server.zig").Config;

pub fn indexHandler(ctx: *const Config, req: *httpz.Request, res: *httpz.Response) !void {
    if (ctx.dev) {
        const file = try std.fs.cwd().openFile("src/frontend/build/index.html", .{});
        defer file.close();
        res.status = 200;
        res.content_type = .HTML;
        res.body = try file.readToEndAlloc(req.arena, 1024 * 1024 * 10);
    } else {
        res.status = 200;
        res.content_type = .HTML;
        res.body = static_assets.assets.@"index.html";
    }
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
