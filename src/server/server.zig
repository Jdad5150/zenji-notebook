//! HTTP server initialisation and lifecycle.
//!
//! Owns the httpz server instance, registers middleware and routes, then
//! blocks on listen(). SIGINT and SIGTERM are caught by a dedicated signal
//! thread that calls server.stop(), allowing listen() to return cleanly.
//!
//! In dev mode, CORS is enabled for the Vite dev server at localhost:5173.
//! The --dev flag is ignored in release builds.

const std   = @import("std");
const log   = std.log;
const posix = std.posix;
const httpz = @import("httpz");

const routerz   = @import("./router.zig");
const middleware = @import("middleware.zig");
const tokenz    = @import("../auth/token.zig").Token;
const Kernel    = @import("../kernel/kernel.zig").Kernel;
const Language  = @import("../kernel/kernel.zig").Language;
const Notebook  = @import("../notebook/notebook.zig").Notebook;
const Cell      = @import("../notebook/cell.zig").Cell;
const envCfg    = @import("../env/config.zig");
const scanner   = @import("../env/scanner.zig");

const HttpServer = httpz.Server(*const Config);

fn signalThread(server: *HttpServer) void {
    var mask = posix.sigemptyset();
    posix.sigaddset(&mask, posix.SIG.INT);
    posix.sigaddset(&mask, posix.SIG.TERM);

    var sig: c_int = 0;
    _ = std.c.sigwait(&mask, &sig);

    log.info("shutting down (signal {d})", .{sig});
    server.stop();
}

/// Server configuration passed in from the CLI and propagated to all handlers.
pub const Config = struct {
    port: u16 = 8888,
    token: ?[]const u8 = null,
    dev: bool = false,
    no_auth: bool = true,
    /// Root directory to serve notebooks from. Defaults to cwd if null.
    /// startServer will chdir here before anything else, so all relative
    /// paths throughout the app resolve from this location.
    root_dir: ?[]const u8 = null,
    /// Set by startServer from the runtime Io — handlers use this for file I/O.
    io: std.Io = undefined,
    /// GPA allocator — available to handlers that need to allocate memory
    /// outside a request arena (e.g. kernel spawning in the environment API).
    allocator: std.mem.Allocator = undefined,
    /// Active kernel — null until the user selects an environment.
    /// Mutate only while holding kernel_mutex.
    kernel: *?Kernel = undefined,
    /// Serialises access to the kernel across concurrent requests.
    kernel_mutex: *std.Io.Mutex = undefined,
};

fn createExampleNotebook(io: std.Io, allocator: std.mem.Allocator) !void {
    const cwd = std.Io.Dir.cwd();
    if (cwd.openFile(io, "example.znb", .{})) |f| {
        f.close(io);
        return;
    } else |err| if (err != error.FileNotFound) return err;

    var nb = try Notebook.init(allocator, .{ .kernel_type = .python });
    defer nb.deinit(allocator);

    nb.cells = try allocator.alloc(Cell, 2);
    nb.cells[0] = try Cell.init(allocator, .code, 0, "print('Hello from Zenji!')");
    nb.cells[1] = try Cell.init(allocator, .code, 1, "x = 6 * 7\nprint(f'The answer is {x}')");
    nb.next_cell_id = 2;

    try nb.save(io, "example.znb");
    log.info("created example.znb", .{});
}

/// Start the HTTP server and block until SIGINT or SIGTERM is received.
pub fn startServer(io: std.Io, allocator: std.mem.Allocator, config: Config) !void {
    var cfg = config;
    cfg.io = io;
    cfg.allocator = allocator;

    // ── Root directory ────────────────────────────────────────────────────────
    // If the user passed --root, chdir there so every relative path in the app
    // (file browser, notebook load/save, env scanner) resolves from that dir.
    if (cfg.root_dir) |root| {
        var path_buf: [std.fs.max_path_bytes + 1]u8 = undefined;
        const root_z = std.fmt.bufPrintZ(&path_buf, "{s}", .{root}) catch {
            log.err("root path too long: '{s}'", .{root});
            return error.PathTooLong;
        };
        if (std.c.chdir(root_z) != 0) {
            log.err("cannot chdir to '{s}'", .{root});
            return error.ChdirFailed;
        }
        log.info("serving from {s}", .{root});
    }

    // ── Kernel slot ───────────────────────────────────────────────────────────
    // Kernel is optional — null until the user selects an environment.
    // We use a double-pointer so handlers can swap the kernel without the
    // Config pointer itself being mutable.
    var kernel_slot: ?Kernel = null;
    cfg.kernel = &kernel_slot;
    defer if (kernel_slot) |*k| k.deinit();

    // If a .zenji.json already exists, try to start the saved kernel immediately.
    if (envCfg.load(io, allocator) catch null) |saved| {
        defer envCfg.freeSavedEnv(allocator, saved);
        const lang = std.meta.stringToEnum(Language, saved.kind) orelse .python;
        kernel_slot = Kernel.init(lang, io, allocator, saved.binary) catch |err| blk: {
            log.warn("saved kernel '{s}' failed to start: {} — waiting for env selection", .{ saved.binary, err });
            break :blk null;
        };
        if (kernel_slot != null) {
            log.info("kernel started from saved config: {s}", .{saved.binary});
        }
    } else {
        log.info("no environment configured — open the app and select one", .{});
    }

    var kernel_mutex = std.Io.Mutex.init;
    cfg.kernel_mutex = &kernel_mutex;

    // ── HTTP server ───────────────────────────────────────────────────────────
    var server = try httpz.Server(*const Config).init(io, allocator, .{ .address = .localhost(cfg.port) }, &cfg);
    defer server.deinit();
    const logger = try server.middleware(middleware.Logger, .{});

    var tok = tokenz{};
    tok.generate();

    const auth = try server.middleware(middleware.Auth, .{
        .token   = &tok,
        .no_auth = cfg.no_auth,
    });

    const router = try server.router(.{});
    if (cfg.dev) {
        const cors = try server.middleware(httpz.middleware.Cors, .{
            .origin = "http://localhost:5173",
        });
        router.middlewares = &.{ logger, auth, cors };
    } else {
        router.middlewares = &.{ logger, auth };
    }

    try routerz.registerRoutes(router);

    if (cfg.dev) {
        createExampleNotebook(io, allocator) catch |err| {
            log.warn("could not create example.znb: {}", .{err});
        };
    }

    // Block signals on the main thread before spawning the signal thread.
    var mask = posix.sigemptyset();
    posix.sigaddset(&mask, posix.SIG.INT);
    posix.sigaddset(&mask, posix.SIG.TERM);
    posix.sigprocmask(posix.SIG.BLOCK, &mask, null);

    const thread = try std.Thread.spawn(.{}, signalThread, .{&server});
    thread.detach();

    std.debug.print("Zenji-notebook listening on \x1b]8;;http://localhost:{d}/?token={s}\x1b\\http://localhost:{d}/?token={s}\x1b]8;;\x1b\\\n", .{ cfg.port, tok.token, cfg.port, tok.token });
    try server.listen();
}
