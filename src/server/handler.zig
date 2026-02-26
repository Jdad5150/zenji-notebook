//! HTTP route handlers for the Jupyter Server API.
//!
//! Each function corresponds to one API endpoint. Unimplemented endpoints
//! return 501 Not Implemented as a placeholder until they are built out.
//! Static asset serving lives in static.zig, not here.

const std = @import("std");
const httpz = @import("httpz");

const static_assets = @import("static_assets");

pub fn indexHandler(req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 200;
    res.content_type = .HTML;
    res.body = static_assets.assets.@"index.html";
}

// GET /api/
pub fn versionHandler(req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}

// GET /api/spec.yaml
pub fn apiSpecHandler(req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}

// GET /api/me
pub fn meHandler(req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}

// GET /api/status
pub fn statusHandler(req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}

// GET /api/contents/:path
pub fn contentsGetHandler(req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}

// POST /api/contents/:path
pub fn contentsPostHandler(req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}

// PATCH /api/contents/:path
pub fn contentsPatchHandler(req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}

// PUT /api/contents/:path
pub fn contentsPutHandler(req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}

// DELETE /api/contents/:path
pub fn contentsDeleteHandler(req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}

// GET /api/contents/:path/checkpoints
pub fn checkpointsListHandler(req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}

// POST /api/contents/:path/checkpoints
pub fn checkpointsCreateHandler(req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}

// POST /api/contents/:path/checkpoints/:checkpoint_id
pub fn checkpointsRestoreHandler(req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}

// DELETE /api/contents/:path/checkpoints/:checkpoint_id
pub fn checkpointsDeleteHandler(req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}

// GET /api/sessions
pub fn sessionsListHandler(req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}

// POST /api/sessions
pub fn sessionsCreateHandler(req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}

// GET /api/sessions/:session
pub fn sessionGetHandler(req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}

// PATCH /api/sessions/:session
pub fn sessionPatchHandler(req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}

// DELETE /api/sessions/:session
pub fn sessionDeleteHandler(req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}

// GET /api/kernels
pub fn kernelsListHandler(req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}

// POST /api/kernels
pub fn kernelsStartHandler(req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}

// GET /api/kernels/:kernel_id
pub fn kernelGetHandler(req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}

// DELETE /api/kernels/:kernel_id
pub fn kernelDeleteHandler(req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}

// POST /api/kernels/:kernel_id/interrupt
pub fn kernelInterruptHandler(req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}

// POST /api/kernels/:kernel_id/restart
pub fn kernelRestartHandler(req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}

// GET /api/kernelspecs
pub fn kernelspecsHandler(req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}

// GET /api/config/:section_name
pub fn configGetHandler(req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}

// PATCH /api/config/:section_name
pub fn configPatchHandler(req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}

// GET /api/terminals
pub fn terminalsListHandler(req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}

// POST /api/terminals
pub fn terminalsCreateHandler(req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}

// GET /api/terminals/:terminal_id
pub fn terminalGetHandler(req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}

// DELETE /api/terminals/:terminal_id
pub fn terminalDeleteHandler(req: *httpz.Request, res: *httpz.Response) !void {
    _ = req;
    res.status = 501;
}
