const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Build libzmq from vendored source
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
            "-DZMQ_HAVE_EPOLL",
            "-DPOLLER=epoll",
            "-D_POSIX_C_SOURCE=200809L",
            "-DZMQ_HAVE_STRNLEN=1",
            "-DZMQ_HAVE_UIO=1",
        },
    });

    libzmq.linkLibC();
    libzmq.linkLibCpp();

    // Main executable
    const exe = b.addExecutable(.{
        .name = "zenji_notebook",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const httpz = b.dependency("httpz", .{
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("httpz", httpz.module("httpz"));
    exe.linkLibrary(libzmq);
    exe.addIncludePath(b.path("vendor/libzmq/include"));
    exe.linkLibC();

    const frontend_opts = b.addOptions();
    const index_html_bytes = std.fs.cwd().readFileAlloc(
        b.allocator,
        "frontend/build/index.html",
        10 * 1024 * 1024,
    ) catch @panic("failed to read index.html");
    frontend_opts.addOption([]const u8, "index_html", index_html_bytes);
    exe.root_module.addOptions("frontend", frontend_opts);

    // const bun_build = b.addSystemCommand(&.{ "bun", "run", "build" });
    // bun_build.setCwd(b.path("frontend"));
    // exe.step.dependOn(&bun_build.step);

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
}

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
