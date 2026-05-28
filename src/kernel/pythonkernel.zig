//! Python kernel backend — executes code via a persistent subprocess worker.
//!
//! On init, the worker script is written to /tmp and the venv Python binary is
//! spawned. Each execute/variables/modules call sends a single JSON command line
//! to the worker's stdin and reads a single JSON response line back from stdout.
//! The worker stays alive between calls so variables persist across cells.
//!
//! The worker script is embedded at compile time so nothing extra needs to be
//! distributed alongside the server binary.

const std = @import("std");
const CellResult = @import("../types.zig").CellResult;
const Variable   = @import("../types.zig").Variable;
const VarKind    = @import("../types.zig").VarKind;
const Module     = @import("../types.zig").Module;

/// Embedded worker script — written to disk on first kernel init.
const worker_script: []const u8 = @embedFile("worker.py");

/// Fixed temp path for the worker. One server instance per user so no collision.
const WORKER_PATH: [:0]const u8 = "/tmp/.zenji_worker.py";

pub const PythonKernel = struct {
    child:      std.process.Child,
    /// Stored so deinit() and the helpers can call wait() and writeStreamingAll().
    io:         std.Io,
    allocator:  std.mem.Allocator,
    /// Internal read buffer for stdout — allows efficient line-by-line reads.
    read_buf:   [65536]u8,
    read_start: usize,
    read_end:   usize,

    /// Spawn the Python worker using the given venv binary path.
    /// The binary should be something like ".venv/bin/python".
    pub fn init(io: std.Io, allocator: std.mem.Allocator, binary: []const u8) !PythonKernel {
        try writeWorkerScript();

        // -u = unbuffered so responses arrive immediately
        const child = try std.process.spawn(io, .{
            .argv   = &.{ binary, "-u", WORKER_PATH },
            .stdin  = .pipe,
            .stdout = .pipe,
            .stderr = .ignore,
        });

        return .{
            .child      = child,
            .io         = io,
            .allocator  = allocator,
            .read_buf   = undefined,
            .read_start = 0,
            .read_end   = 0,
        };
    }

    /// Execute a cell of Python code.
    /// Returns captured stdout, stderr, and any matplotlib figures.
    /// All non-null strings in the result are allocator-owned — caller must free.
    pub fn execute(self: *PythonKernel, code: []const u8) !CellResult {
        try self.sendJson(.{ .cmd = "execute", .code = code });

        const line = try self.readLine();
        defer self.allocator.free(line);

        const ExecuteResponse = struct {
            stdout:  []const u8         = "",
            stderr:  []const u8         = "",
            figures: []const []const u8 = &.{},
        };

        const parsed = try std.json.parseFromSlice(
            ExecuteResponse,
            self.allocator,
            line,
            .{ .ignore_unknown_fields = true },
        );
        defer parsed.deinit();

        const stdout = if (parsed.value.stdout.len > 0)
            try self.allocator.dupe(u8, parsed.value.stdout)
        else
            null;
        errdefer if (stdout) |s| self.allocator.free(s);

        const stderr = if (parsed.value.stderr.len > 0)
            try self.allocator.dupe(u8, parsed.value.stderr)
        else
            null;
        errdefer if (stderr) |s| self.allocator.free(s);

        var figs: ?[][]const u8 = null;
        if (parsed.value.figures.len > 0) {
            const arr = try self.allocator.alloc([]const u8, parsed.value.figures.len);
            errdefer self.allocator.free(arr);
            for (parsed.value.figures, 0..) |fig, i| {
                arr[i] = try self.allocator.dupe(u8, fig);
            }
            figs = arr;
        }

        return .{
            .stdout  = stdout,
            .stderr  = stderr,
            .figures = figs,
            .success = parsed.value.stderr.len == 0,
        };
    }

    /// Returns user-defined variables from the kernel namespace.
    /// The returned slice and all strings inside are allocator-owned — caller must free.
    pub fn getVariables(self: *PythonKernel) ![]const Variable {
        try self.sendJson(.{ .cmd = "variables" });

        const line = try self.readLine();
        defer self.allocator.free(line);

        const Entry = struct {
            name:  []const u8,
            value: []const u8,
            type:  []const u8,
            kind:  []const u8 = "other",
            shape: ?[]const u8 = null,
        };
        const VarsResponse = struct {
            variables: []const Entry = &.{},
        };

        const parsed = try std.json.parseFromSlice(
            VarsResponse,
            self.allocator,
            line,
            .{ .ignore_unknown_fields = true },
        );
        defer parsed.deinit();

        const vars = try self.allocator.alloc(Variable, parsed.value.variables.len);
        for (parsed.value.variables, 0..) |v, i| {
            vars[i] = .{
                .name      = try self.allocator.dupe(u8, v.name),
                .value     = try self.allocator.dupe(u8, v.value),
                .type_name = try self.allocator.dupe(u8, v.type),
                .kind      = std.meta.stringToEnum(VarKind, v.kind) orelse .other,
                .shape     = if (v.shape) |s| try self.allocator.dupe(u8, s) else null,
            };
        }
        return vars;
    }

    /// Returns imported modules visible in the kernel namespace.
    /// The returned slice and all strings inside are allocator-owned — caller must free.
    pub fn getModules(self: *PythonKernel) ![]const Module {
        try self.sendJson(.{ .cmd = "modules" });

        const line = try self.readLine();
        defer self.allocator.free(line);

        const Entry = struct {
            name: []const u8,
            path: []const u8,
        };
        const ModsResponse = struct {
            modules: []const Entry = &.{},
        };

        const parsed = try std.json.parseFromSlice(
            ModsResponse,
            self.allocator,
            line,
            .{ .ignore_unknown_fields = true },
        );
        defer parsed.deinit();

        const mods = try self.allocator.alloc(Module, parsed.value.modules.len);
        for (parsed.value.modules, 0..) |m, i| {
            mods[i] = .{
                .name = try self.allocator.dupe(u8, m.name),
                .path = try self.allocator.dupe(u8, m.path),
            };
        }
        return mods;
    }

    /// Send a quit command to the worker and wait for it to exit.
    pub fn deinit(self: *PythonKernel) void {
        self.sendJson(.{ .cmd = "quit" }) catch {};
        _ = self.child.wait(self.io) catch {};
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Internal helpers
    // ─────────────────────────────────────────────────────────────────────────

    /// Serialize `value` as JSON and write it as a single newline-terminated
    /// message to the worker's stdin pipe.
    fn sendJson(self: *PythonKernel, value: anytype) !void {
        const json = try std.json.Stringify.valueAlloc(self.allocator, value, .{});
        defer self.allocator.free(json);
        // Single write: json + newline so the worker sees a complete line.
        const msg = try std.mem.concat(self.allocator, u8, &.{ json, "\n" });
        defer self.allocator.free(msg);
        try self.child.stdin.?.writeStreamingAll(self.io, msg);
    }

    /// Read one newline-terminated line from the worker stdout.
    /// The returned slice is allocator-owned — caller must free.
    fn readLine(self: *PythonKernel) ![]u8 {
        var result: std.ArrayList(u8) = .empty;
        errdefer result.deinit(self.allocator);

        while (true) {
            // Refill the internal buffer when empty.
            if (self.read_start >= self.read_end) {
                const n = try std.posix.read(self.child.stdout.?.handle, &self.read_buf);
                if (n == 0) return error.WorkerEndOfStream;
                self.read_start = 0;
                self.read_end   = n;
            }

            const chunk = self.read_buf[self.read_start..self.read_end];
            if (std.mem.indexOfScalar(u8, chunk, '\n')) |nl| {
                try result.appendSlice(self.allocator, chunk[0..nl]);
                self.read_start += nl + 1;
                return result.toOwnedSlice(self.allocator);
            }
            try result.appendSlice(self.allocator, chunk);
            self.read_start = self.read_end;
        }
    }
};

// ─────────────────────────────────────────────────────────────────────────────
// Module-level helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Write the embedded worker script to the well-known temp path.
/// Uses the C standard library so no io context is required.
fn writeWorkerScript() !void {
    const f = std.c.fopen(WORKER_PATH, "wb") orelse return error.CannotCreateWorkerScript;
    defer _ = std.c.fclose(f);
    const n = std.c.fwrite(worker_script.ptr, 1, worker_script.len, f);
    if (n != worker_script.len) return error.WorkerScriptWriteIncomplete;
}
