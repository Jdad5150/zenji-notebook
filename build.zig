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

const std = @import("std");
const crawler = @import("./crawler.zig");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // -------------------------------------------------------------------------
    // zenji_notebook — main executable
    // -------------------------------------------------------------------------
    const translate_c = b.addTranslateC(.{
        .root_source_file = b.path("src/c.h"),
        .target = target,
        .optimize = optimize,
    });

    switch (target.result.os.tag) {
        .windows => {
            translate_c.addIncludePath(.{ .cwd_relative = "C:\\Users\\jeslitt\\AppData\\Local\\Programs\\Python\\Python313\\Include" });
        },
        .macos => {
            translate_c.addIncludePath(.{ .cwd_relative = "/usr/local/opt/python3/Frameworks/Python.framework/Headers" });
        },
        else => {
            translate_c.addIncludePath(.{ .cwd_relative = "/usr/include/python3.14" });
        },
    }

    const exe = b.addExecutable(.{
        .name = "zenji_notebook",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "c", .module = translate_c.createModule() },
            },
        }),
    });

    switch (target.result.os.tag) {
        .windows => {
            exe.root_module.addLibraryPath(.{ .cwd_relative = "C:\\Users\\jeslitt\\AppData\\Local\\Programs\\Python\\Python313\\libs" });
            exe.root_module.linkSystemLibrary("python313", .{});
        },
        .macos => {
            exe.root_module.linkSystemLibrary("python3", .{});
        },
        else => {
            exe.root_module.linkSystemLibrary("python3.14", .{});
        },
    }

    // httpz is the HTTP server library, pulled in via build.zig.zon.
    const httpz = b.dependency("httpz", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("httpz", httpz.module("httpz"));

    // -------------------------------------------------------------------------
    // Frontend asset embedding
    //
    // crawler.writeRegistry() walks src/frontend/build/ and writes
    // src/assets.zig, which looks like:
    //
    //   pub const assets = .{
    //       .@"index.html" = @embedFile("frontend/build/index.html"),
    //       .@"_app/immutable/..." = @embedFile("frontend/build/_app/..."),
    //       ...
    //   };
    //
    // This file is then imported as the `static_assets` module so the HTTP
    // server can serve every frontend file directly from the binary.
    //
    // NOTE: src/assets.zig is generated — it is .gitignored and must not be
    // edited by hand. Re-run `zig build` after a frontend rebuild to refresh it.
    // -------------------------------------------------------------------------
    try crawler.writeRegistry(b);

    const assets_module = b.createModule(.{
        .root_source_file = b.path("src/assets.zig"),
    });
    exe.root_module.addImport("static_assets", assets_module);

    b.installArtifact(exe);

    // -------------------------------------------------------------------------
    // `zig build test` — run all tests
    //
    // We point the test compile unit at src/test_all.zig so Zig walks the whole
    // source tree and picks up every `test` block.
    // -------------------------------------------------------------------------
    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/test_all.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&b.addRunArtifact(tests).step);

    // -------------------------------------------------------------------------
    // `zig build run` — build and start the server
    // -------------------------------------------------------------------------
    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
}
