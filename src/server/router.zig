//! Route registration for the zenji-notebook HTTP server.
//!
//! Maps every URL pattern to its handler. Frontend assets are served by the
//! catch-all "/*" glob route via static.zig. API routes follow the Jupyter
//! Server HTTP API spec and are implemented in handler.zig.

const std = @import("std");
const httpz = @import("httpz");
const handlerz = @import("./handler.zig");
const staticc = @import("./static.zig");

pub fn registerRoutes(routerz: anytype) !void {
    // Frontend
    routerz.get("/", handlerz.indexHandler, .{});
    routerz.get("/*", staticc.serveStaticAsset, .{});

    // Zenji native API
    routerz.get("/api/variables", handlerz.variablesHandler, .{});
    routerz.get("/api/contents", handlerz.contentsListHandler, .{});
    routerz.get("/api/notebook", handlerz.notebookGetHandler, .{});
    routerz.put("/api/notebook", handlerz.notebookPutHandler, .{});
    routerz.post("/api/execute", handlerz.executeHandler, .{});

    // API version (no auth required)
    routerz.get("/api/", handlerz.versionHandler, .{});

    // API spec
    routerz.get("/api/spec.yaml", handlerz.apiSpecHandler, .{});

    // Identity & status
    routerz.get("/api/me", handlerz.meHandler, .{});
    routerz.get("/api/status", handlerz.statusHandler, .{});

    // Contents
    routerz.get("/api/contents/:path", handlerz.contentsGetHandler, .{});
    routerz.post("/api/contents/:path", handlerz.contentsPostHandler, .{});
    routerz.patch("/api/contents/:path", handlerz.contentsPatchHandler, .{});
    routerz.put("/api/contents/:path", handlerz.contentsPutHandler, .{});
    routerz.delete("/api/contents/:path", handlerz.contentsDeleteHandler, .{});

    // Checkpoints
    routerz.get("/api/contents/:path/checkpoints", handlerz.checkpointsListHandler, .{});
    routerz.post("/api/contents/:path/checkpoints", handlerz.checkpointsCreateHandler, .{});
    routerz.post("/api/contents/:path/checkpoints/:checkpoint_id", handlerz.checkpointsRestoreHandler, .{});
    routerz.delete("/api/contents/:path/checkpoints/:checkpoint_id", handlerz.checkpointsDeleteHandler, .{});

    // Sessions
    routerz.get("/api/sessions", handlerz.sessionsListHandler, .{});
    routerz.post("/api/sessions", handlerz.sessionsCreateHandler, .{});
    routerz.get("/api/sessions/:session", handlerz.sessionGetHandler, .{});
    routerz.patch("/api/sessions/:session", handlerz.sessionPatchHandler, .{});
    routerz.delete("/api/sessions/:session", handlerz.sessionDeleteHandler, .{});

    // Kernels
    routerz.get("/api/kernels", handlerz.kernelsListHandler, .{});
    routerz.post("/api/kernels", handlerz.kernelsStartHandler, .{});
    routerz.get("/api/kernels/:kernel_id", handlerz.kernelGetHandler, .{});
    routerz.delete("/api/kernels/:kernel_id", handlerz.kernelDeleteHandler, .{});
    routerz.post("/api/kernels/:kernel_id/interrupt", handlerz.kernelInterruptHandler, .{});
    routerz.post("/api/kernels/:kernel_id/restart", handlerz.kernelRestartHandler, .{});

    // Kernel specs
    routerz.get("/api/kernelspecs", handlerz.kernelspecsHandler, .{});

    // Config
    routerz.get("/api/config/:section_name", handlerz.configGetHandler, .{});
    routerz.patch("/api/config/:section_name", handlerz.configPatchHandler, .{});

    // Terminals
    routerz.get("/api/terminals", handlerz.terminalsListHandler, .{});
    routerz.post("/api/terminals", handlerz.terminalsCreateHandler, .{});
    routerz.get("/api/terminals/:terminal_id", handlerz.terminalGetHandler, .{});
    routerz.delete("/api/terminals/:terminal_id", handlerz.terminalDeleteHandler, .{});
}
