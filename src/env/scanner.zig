//! Environment scanner — detects virtual environments in any directory.
//!
//! Pass an absolute or relative directory path. All returned binary paths
//! are absolute so the kernel can be spawned from any working directory.

const std = @import("std");

pub const EnvKind = enum { python, r, julia, mojo };

pub const DetectedEnv = struct {
    kind: EnvKind,
    /// Human-readable label, e.g. "Python (.venv)". Allocator-owned.
    label: []const u8,
    /// Absolute path to the interpreter binary. Allocator-owned.
    binary: []const u8,
};

/// Scan `dir_path` for known virtual environment indicators.
/// `dir_path` may be absolute ("/home/user/project") or "." for cwd.
/// Returns a slice of DetectedEnv with absolute binary paths.
/// Caller owns the slice and all strings — call freeEnvs() to release.
pub fn scan(io: std.Io, allocator: std.mem.Allocator, dir_path: []const u8) ![]DetectedEnv {
    // Resolve dir_path to an absolute path so binary paths are always absolute.
    const abs_dir = try resolveAbsolute(allocator, dir_path);
    defer allocator.free(abs_dir);

    var results: std.ArrayList(DetectedEnv) = .empty;
    errdefer {
        for (results.items) |e| {
            allocator.free(e.label);
            allocator.free(e.binary);
        }
        results.deinit(allocator);
    }

    // ── Python: uv / pip / plain venv ────────────────────────────────────────
    for ([_][]const u8{ ".venv", "venv", "env" }) |venv_dir| {
        const bin = try std.fmt.allocPrint(
            allocator, "{s}/{s}/bin/python", .{ abs_dir, venv_dir },
        );
        if (fileExists(io, bin)) {
            errdefer allocator.free(bin);
            const label = try std.fmt.allocPrint(allocator, "Python ({s})", .{venv_dir});
            try results.append(allocator, .{ .kind = .python, .label = label, .binary = bin });
        } else {
            allocator.free(bin);
        }
    }

    // ── Python: pixi ─────────────────────────────────────────────────────────
    {
        const bin = try std.fmt.allocPrint(
            allocator, "{s}/.pixi/envs/default/bin/python", .{abs_dir},
        );
        if (fileExists(io, bin)) {
            errdefer allocator.free(bin);
            const label = try allocator.dupe(u8, "Python (pixi)");
            try results.append(allocator, .{ .kind = .python, .label = label, .binary = bin });
        } else {
            allocator.free(bin);
        }
    }

    // ── R: renv ──────────────────────────────────────────────────────────────
    {
        const renv_path = try std.fmt.allocPrint(allocator, "{s}/renv", .{abs_dir});
        defer allocator.free(renv_path);
        if (dirExists(io, renv_path)) {
            const bin   = try allocator.dupe(u8, "Rscript");
            const label = try allocator.dupe(u8, "R (renv)");
            try results.append(allocator, .{ .kind = .r, .label = label, .binary = bin });
        }
    }

    // ── Julia: Project.toml ──────────────────────────────────────────────────
    {
        const toml_path = try std.fmt.allocPrint(allocator, "{s}/Project.toml", .{abs_dir});
        defer allocator.free(toml_path);
        if (fileExists(io, toml_path)) {
            const bin   = try allocator.dupe(u8, "julia");
            const label = try allocator.dupe(u8, "Julia (Project.toml)");
            try results.append(allocator, .{ .kind = .julia, .label = label, .binary = bin });
        }
    }

    // ── Mojo: pixi ───────────────────────────────────────────────────────────
    {
        const bin = try std.fmt.allocPrint(
            allocator, "{s}/.pixi/envs/default/bin/mojo", .{abs_dir},
        );
        if (fileExists(io, bin)) {
            errdefer allocator.free(bin);
            const label = try allocator.dupe(u8, "Mojo (pixi)");
            try results.append(allocator, .{ .kind = .mojo, .label = label, .binary = bin });
        } else {
            allocator.free(bin);
        }
    }

    return results.toOwnedSlice(allocator);
}

/// Free a slice returned by scan().
pub fn freeEnvs(allocator: std.mem.Allocator, envs: []const DetectedEnv) void {
    for (envs) |e| {
        allocator.free(e.label);
        allocator.free(e.binary);
    }
    allocator.free(envs);
}

// ─────────────────────────────────────────────────────────────────────────────

/// Resolve `path` to an absolute path string (allocator-owned).
fn resolveAbsolute(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    if (path.len > 0 and path[0] == '/') return allocator.dupe(u8, path);
    // Get the current working directory via the C stdlib.
    // getcwd returns [*]u8 (not sentinel-terminated), so use sliceTo with the
    // null terminator that getcwd writes into the buffer.
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const raw = std.c.getcwd(&buf, buf.len) orelse return error.GetCwdFailed;
    const cwd = std.mem.sliceTo(raw, 0);
    if (std.mem.eql(u8, path, ".")) return allocator.dupe(u8, cwd);
    return std.fmt.allocPrint(allocator, "{s}/{s}", .{ cwd, path });
}

fn fileExists(io: std.Io, absolute_path: []const u8) bool {
    const f = std.Io.Dir.openFileAbsolute(io, absolute_path, .{}) catch return false;
    f.close(io);
    return true;
}

fn dirExists(io: std.Io, absolute_path: []const u8) bool {
    const d = std.Io.Dir.openDirAbsolute(io, absolute_path, .{}) catch return false;
    d.close(io);
    return true;
}
