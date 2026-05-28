//! Build script for zenji-notebook.
//!
//! Overview of what this build does:
//!   1. Compiles the main Zig executable with httpz for HTTP server.
//!   2. Runs crawler.writeRegistry() to scan src/frontend/build/ and generate
//!      src/assets.zig — an auto-generated file that embeds every frontend
//!      asset at compile time via @embedFile.
//!   3. Exposes a `zig build run` step to run the server locally.
//!
//! Prerequisites before running `zig build`:
//!   - Run `bun run build` inside src/frontend/ at least once so that
//!     src/frontend/build/ exists and src/assets.zig can be generated.
//!
//! NOTE: CPython is no longer embedded. The server instead spawns the Python
//! binary from whatever virtual environment the user selects at runtime.

const std     = @import("std");
const crawler = @import("./crawler.zig");

pub fn build(b: *std.Build) !void {
    const target   = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // ── zenji_notebook — main executable ──────────────────────────────────────
    const exe = b.addExecutable(.{
        .name        = "zenji_notebook",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target           = target,
            .optimize         = optimize,
        }),
    });

    // ── Frontend asset embedding ───────────────────────────────────────────────
    //
    // crawler.writeRegistry() walks src/frontend/build/ and writes
    // src/assets.zig, which embeds every frontend file into the binary via
    // @embedFile so the HTTP server can serve them without external files.
    //
    // NOTE: src/assets.zig is generated — it is .gitignored and must not be
    // edited by hand. Re-run `zig build` after a frontend rebuild to refresh it.
    try crawler.writeRegistry(b);

    const assets_module = b.createModule(.{
        .root_source_file = b.path("src/assets.zig"),
    });
    exe.root_module.addImport("static_assets", assets_module);

    // httpz is the HTTP server library, pulled in via build.zig.zon.
    const httpz = b.dependency("httpz", .{
        .target   = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("httpz", httpz.module("httpz"));

    b.installArtifact(exe);

    // ── `zig build test` — run all tests ─────────────────────────────────────
    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/test_all.zig"),
            .target           = target,
            .optimize         = optimize,
        }),
    });

    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&b.addRunArtifact(tests).step);

    // ── `zig build run` — build and start the server ─────────────────────────
    //
    // Options:
    //   -Droot=<path>   Serve notebooks from this directory (default: cwd)
    //
    // Examples:
    //   zig build run                          # cwd as root, dev mode
    //   zig build run -Droot=/my/project       # point at your project dir
    //   zig build run -- --port 9000           # pass extra flags after --
    const root_opt = b.option([]const u8, "root", "Root directory to serve notebooks from");

    const run_step = b.step("run", "Run the app");
    const run_cmd  = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    // Always pass --dev and --no-auth in development builds.
    run_cmd.addArgs(&.{ "--dev", "--no-auth" });

    // If -Droot was given, forward it to the binary.
    if (root_opt) |root| {
        run_cmd.addArgs(&.{ "--root", root });
    }

    // Allow the user to append extra flags after `--`, e.g. `zig build run -- --port 9000`
    if (b.args) |args| run_cmd.addArgs(args);
}
