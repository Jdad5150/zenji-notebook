test {
    // Kernel
    _ = @import("kernel/kernel.zig");
    _ = @import("kernel/pythonkernel.zig");
    _ = @import("kernel/juliakernel.zig");
    _ = @import("kernel/rkernel.zig");
    _ = @import("kernel/mojokernel.zig");

    // Notebook
    _ = @import("notebook/output.zig");
    _ = @import("notebook/cell.zig");
    _ = @import("notebook/notebook.zig");

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

    // Util
    _ = @import("util/json.zig");
    _ = @import("util/logging.zig");
    _ = @import("util/mime.zig");
    _ = @import("util/platform.zig");
    _ = @import("util/uuid.zig");
}
