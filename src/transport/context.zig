//! ZMQ Context — the foundation of all ZeroMQ communication.
//!
//! A Context is the first thing you create and the last thing you destroy.
//! It manages ZMQ's internal I/O threads and acts as a factory for all
//! sockets. Every socket in the application must belong to a context.
//!
//! There should only ever be ONE context for the entire program — treat it
//! as a singleton. Create it at startup, pass it down to whatever needs it,
//! and destroy it on shutdown.
//!
//! Usage:
//!   var ctx = try Context.init();
//!   defer ctx.deinit() catch {};
//!
//! The underlying C functions are:
//!   zmq_ctx_new()  — creates the context, returns NULL on failure
//!   zmq_ctx_term() — destroys the context, returns -1 on failure

const zmq = @import("zmq.zig").c;
const std = @import("std");
const testing = std.testing;

/// Errors that can occur during context lifecycle operations.
pub const ContextError = error{
    /// zmq_ctx_new() returned NULL — ZMQ could not allocate the context.
    ContextCreationFailed,
    /// zmq_ctx_term() returned -1 — context could not be cleanly destroyed.
    ContextTerminationFailed,
    /// Reserved for future use with zmq_ctx_shutdown().
    ContextShutdownFailed,
    /// Reserved for future use with zmq_ctx_set().
    ContextSetFailed,
};

/// A ZMQ context. Owns the ZMQ runtime for the lifetime of the program.
pub const Context = struct {
    /// Opaque pointer to the underlying zmq context object.
    /// Returned by zmq_ctx_new() and passed back to all zmq_ctx_* functions.
    handle: *anyopaque,

    /// Creates a new ZMQ context.
    /// Returns `ContextCreationFailed` if ZMQ could not allocate the context.
    pub fn init() ContextError!Context {
        const handle = zmq.zmq_ctx_new();
        if (handle == null) return ContextError.ContextCreationFailed;
        return Context{ .handle = handle.? };
    }

    /// Destroys the ZMQ context and releases all associated resources.
    /// All sockets belonging to this context must be closed before calling deinit.
    /// Returns `ContextTerminationFailed` if ZMQ could not cleanly shut down.
    pub fn deinit(self: *Context) ContextError!void {
        const result = zmq.zmq_ctx_term(self.handle);
        if (result != 0) return ContextError.ContextTerminationFailed;
    }
};

test "Context init" {
    var ctx = try Context.init();
    try testing.expect(@intFromPtr(ctx.handle) != 0);
    try ctx.deinit();
}
