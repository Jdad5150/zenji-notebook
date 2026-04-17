//! Root test file for the Zenji Notebook test suite.
//!
//! This file imports every module in the project so that `zig build test`
//! picks up all `test` blocks automatically. Individual modules can still
//! be tested directly via the build system or command line, but this file
//! ensures nothing is missed in a full test run.
//!
//! When adding a new module, add a corresponding `_ = @import(...)` line here.

test {
    // Transport
    _ = @import("transport/zmq.zig");
    _ = @import("transport/context.zig");
    _ = @import("transport/socket.zig");
    _ = @import("transport/poller.zig");

    // Protocol
    _ = @import("protocol/channel.zig");
    _ = @import("protocol/header.zig");
    _ = @import("protocol/hmac.zig");
    _ = @import("protocol/message.zig");
    _ = @import("protocol/wire.zig");

    // Kernel
    _ = @import("kernel/connection.zig");
    _ = @import("kernel/manager.zig");
    _ = @import("kernel/pool.zig");
    _ = @import("kernel/process.zig");
    _ = @import("kernel/spec.zig");

    // Notebook
    _ = @import("notebook/convert.zig");
    _ = @import("notebook/format.zig");
    _ = @import("notebook/io.zig");

    // API
    _ = @import("api/config.zig");
    _ = @import("api/contents.zig");
    _ = @import("api/kernels.zig");
    _ = @import("api/kernelspecs.zig");
    _ = @import("api/sessions.zig");

    // Auth
    _ = @import("auth/cookie.zig");
    _ = @import("auth/token.zig");

    // Server
    _ = @import("server/handler.zig");
    _ = @import("server/middleware.zig");
    _ = @import("server/router.zig");
    _ = @import("server/server.zig");
    _ = @import("server/static.zig");

    // WebSocket
    _ = @import("ws/bridge.zig");
    _ = @import("ws/handler.zig");

    // Util
    _ = @import("util/json.zig");
    _ = @import("util/logging.zig");
    _ = @import("util/mime.zig");
    _ = @import("util/platform.zig");
    _ = @import("util/uuid.zig");
}
