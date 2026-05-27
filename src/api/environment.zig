//! GET  /api/environment?dir=<path>  — return detected and saved envs for a directory.
//! POST /api/environment             — save the user's selection and (re)start the kernel.
//! GET  /api/home                    — return the user's home directory path.
//!
//! GET response:
//!   {
//!     "saved":    { "kind": "python", "label": "Python (.venv)", "binary": "/abs/path/python" } | null,
//!     "detected": [ { "kind": "python", "label": "Python (.venv)", "binary": "/abs/path/python" }, ... ]
//!   }
//!
//! POST body:
//!   { "kind": "python", "label": "Python (.venv)", "binary": "/abs/path/.venv/bin/python" }
//!
//! POST response: 200 {} on success, 500 on kernel spawn failure.

const std     = @import("std");
const httpz   = @import("httpz");
const Config  = @import("../server/server.zig").Config;
const Kernel  = @import("../kernel/kernel.zig").Kernel;
const Language = @import("../kernel/kernel.zig").Language;
const scanner = @import("../env/scanner.zig");
const envCfg  = @import("../env/config.zig");
const log     = std.log;

const EnvJson = struct {
    kind:   []const u8,
    label:  []const u8,
    binary: []const u8,
};

const GetResponseJson = struct {
    saved:    ?EnvJson,
    detected: []const EnvJson,
};

/// GET /api/environment?dir=<path>
/// `dir` is the directory to scan for environments.
/// Defaults to "." (server cwd) when not provided.
pub fn handleGet(ctx: *const Config, req: *httpz.Request, res: *httpz.Response) !void {
    const arena = req.arena;

    const q = try req.query();
    const dir = q.get("dir") orelse ".";

    // Load saved config
    var saved_json: ?EnvJson = null;
    if (envCfg.load(ctx.io, arena) catch null) |saved| {
        saved_json = .{
            .kind   = saved.kind,
            .label  = saved.label,
            .binary = saved.binary,
        };
    }

    // Scan the requested directory for available environments
    const envs = scanner.scan(ctx.io, arena, dir) catch &.{};
    const detected = try arena.alloc(EnvJson, envs.len);
    for (envs, 0..) |e, i| {
        detected[i] = .{
            .kind   = @tagName(e.kind),
            .label  = e.label,
            .binary = e.binary,
        };
    }

    res.status = 200;
    res.content_type = .JSON;
    res.body = try std.json.Stringify.valueAlloc(arena, GetResponseJson{
        .saved    = saved_json,
        .detected = detected,
    }, .{});
}

/// POST /api/environment
pub fn handlePost(ctx: *const Config, req: *httpz.Request, res: *httpz.Response) !void {
    const arena = req.arena;

    const body = (try req.json(EnvJson)) orelse {
        res.status = 400;
        res.body = "{\"error\":\"missing or invalid body\"}";
        return;
    };

    // Persist the selection
    envCfg.save(ctx.io, ctx.allocator, .{
        .kind   = body.kind,
        .label  = body.label,
        .binary = body.binary,
    }) catch |err| {
        log.err("failed to save .zenji.json: {}", .{err});
        // Non-fatal — continue to spawn the kernel
    };

    // Resolve language
    const lang = std.meta.stringToEnum(Language, body.kind) orelse {
        res.status = 400;
        res.body = "{\"error\":\"unknown language kind\"}";
        return;
    };

    // Spawn the new kernel under the mutex
    ctx.kernel_mutex.lockUncancelable(ctx.io);

    // Tear down the old kernel if one is running
    if (ctx.kernel.*) |*old| {
        old.deinit();
        ctx.kernel.* = null;
    }

    ctx.kernel.* = Kernel.init(lang, ctx.io, ctx.allocator, body.binary) catch |err| {
        ctx.kernel_mutex.unlock(ctx.io);
        log.err("kernel spawn failed for '{s}': {}", .{ body.binary, err });
        res.status = 500;
        res.body = "{\"error\":\"failed to start kernel — check that the binary path is correct\"}";
        return;
    };

    ctx.kernel_mutex.unlock(ctx.io);

    log.info("kernel started: {s} ({s})", .{ body.label, body.binary });

    res.status = 200;
    res.content_type = .JSON;
    res.body = try std.json.Stringify.valueAlloc(arena, .{ .ok = true }, .{});
}

/// GET /api/home — returns the user's home directory path.
/// Used by the frontend file browser to open at a sensible starting location.
pub fn handleHome(_: *const Config, req: *httpz.Request, res: *httpz.Response) !void {
    const arena = req.arena;

    const home_raw = std.c.getenv("HOME") orelse {
        // Fallback: return "/" so the browser can still navigate
        res.status = 200;
        res.content_type = .JSON;
        res.body = "{\"path\":\"/\"}";
        return;
    };
    const home = std.mem.span(home_raw);

    res.status = 200;
    res.content_type = .JSON;
    res.body = try std.json.Stringify.valueAlloc(arena, .{ .path = home }, .{});
}
