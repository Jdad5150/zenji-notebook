//! Build script for zenji-notebook.
//!
//! Overview of what this build does:
//!   1. Compiles libzmq from vendored C++ source into a static library.
//!   2. Compiles the main Zig executable, linking against libzmq and httpz.
//!   3. Runs crawler.writeRegistry() to scan src/frontend/build/ and generate
//!      src/assets.zig — an auto-generated file that embeds every frontend
//!      asset at compile time via @embedFile.
//!   4. Exposes a `zig build run` step to run the server locally.
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
    // libzmq — vendored C++ static library
    //
    // ZeroMQ is used for Jupyter kernel communication (the wire protocol runs
    // over ZMQ sockets). We compile it from source so the binary is fully
    // self-contained with no runtime dependency on a system libzmq.
    // -------------------------------------------------------------------------
    const libzmq = b.addLibrary(.{
        .name = "zmq",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
        .linkage = .static,
    });

    libzmq.addIncludePath(b.path("vendor/libzmq/include"));
    libzmq.addIncludePath(b.path("vendor/libzmq/src"));

    libzmq.addCSourceFiles(.{
        .root = b.path("vendor/libzmq/src"),
        .files = &zmq_sources,
        .flags = &.{
            "-std=c++11",
            "-DZMQ_HAVE_EPOLL", // use epoll as the I/O poller (Linux)
            "-DPOLLER=epoll",
            "-D_POSIX_C_SOURCE=200809L",
            "-DZMQ_HAVE_STRNLEN=1",
            "-DZMQ_HAVE_UIO=1",
        },
    });

    libzmq.linkLibC();
    libzmq.linkLibCpp();

    // -------------------------------------------------------------------------
    // zenji_notebook — main executable
    // -------------------------------------------------------------------------
    const exe = b.addExecutable(.{
        .name = "zenji_notebook",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // httpz is the HTTP server library, pulled in via build.zig.zon.
    const httpz = b.dependency("httpz", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("httpz", httpz.module("httpz"));

    // Link the vendored libzmq we built above.
    exe.linkLibrary(libzmq);
    exe.addIncludePath(b.path("vendor/libzmq/include"));
    exe.linkLibC();

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
    // We point the test compile unit at src/main.zig so Zig walks the whole
    // source tree and picks up every `test` block. libzmq and its include path
    // are linked in the same way as the main executable so that @cImport works.
    // -------------------------------------------------------------------------
    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/test_all.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    tests.linkLibrary(libzmq);
    tests.addIncludePath(b.path("vendor/libzmq/include"));
    tests.linkLibC();

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

// Full list of libzmq C++ translation units to compile.
// Taken directly from the vendored source — do not prune without checking
// whether the removed file is actually unused.
const zmq_sources = [_][]const u8{
    "address.cpp",
    "channel.cpp",
    "client.cpp",
    "clock.cpp",
    "ctx.cpp",
    "curve_mechanism_base.cpp",
    "dealer.cpp",
    "decoder_allocators.cpp",
    "dgram.cpp",
    "dish.cpp",
    "dist.cpp",
    "endpoint.cpp",
    "epoll.cpp",
    "err.cpp",
    "fq.cpp",
    "gather.cpp",
    "io_object.cpp",
    "io_thread.cpp",
    "ip.cpp",
    "ip_resolver.cpp",
    "ipc_address.cpp",
    "ipc_connecter.cpp",
    "ipc_listener.cpp",
    "lb.cpp",
    "mailbox.cpp",
    "mailbox_safe.cpp",
    "mechanism.cpp",
    "mechanism_base.cpp",
    "metadata.cpp",
    "msg.cpp",
    "mtrie.cpp",
    "null_mechanism.cpp",
    "object.cpp",
    "options.cpp",
    "own.cpp",
    "pair.cpp",
    "peer.cpp",
    "pipe.cpp",
    "plain_client.cpp",
    "plain_server.cpp",
    "poll.cpp",
    "poller_base.cpp",
    "polling_util.cpp",
    "precompiled.cpp",
    "proxy.cpp",
    "pub.cpp",
    "pull.cpp",
    "push.cpp",
    "radio.cpp",
    "radix_tree.cpp",
    "random.cpp",
    "raw_decoder.cpp",
    "raw_encoder.cpp",
    "raw_engine.cpp",
    "reaper.cpp",
    "rep.cpp",
    "req.cpp",
    "router.cpp",
    "scatter.cpp",
    "select.cpp",
    "server.cpp",
    "session_base.cpp",
    "signaler.cpp",
    "socket_base.cpp",
    "socket_poller.cpp",
    "socks.cpp",
    "socks_connecter.cpp",
    "stream.cpp",
    "stream_connecter_base.cpp",
    "stream_engine_base.cpp",
    "stream_listener_base.cpp",
    "sub.cpp",
    "tcp.cpp",
    "tcp_address.cpp",
    "tcp_connecter.cpp",
    "tcp_listener.cpp",
    "thread.cpp",
    "timers.cpp",
    "trie.cpp",
    "udp_address.cpp",
    "udp_engine.cpp",
    "v1_decoder.cpp",
    "v1_encoder.cpp",
    "v2_decoder.cpp",
    "v2_encoder.cpp",
    "v3_1_encoder.cpp",
    "xpub.cpp",
    "xsub.cpp",
    "zap_client.cpp",
    "zmq.cpp",
    "zmq_utils.cpp",
    "zmtp_engine.cpp",
};
