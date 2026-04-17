//! ZMQ Socket — a single communication endpoint.
//!
//! A Socket is created from a Context and represents one end of a ZMQ
//! communication channel. Each socket has a type that determines its
//! messaging pattern (e.g. DEALER, SUB, REQ).
//!
//! For Jupyter kernel communication, five socket types are used:
//!   - shell   — DEALER — send execute requests, receive replies
//!   - iopub   — SUB    — subscribe to all kernel output
//!   - stdin   — DEALER — handle input prompts from the kernel
//!   - control — DEALER — interrupt or shutdown the kernel
//!   - hb      — REQ    — heartbeat, check the kernel is alive
//!
//! Sockets either bind (listen on a port) or connect (reach out to a port).
//! For Zenji, the server connects to kernel ports — the kernel binds.
//!
//! Multipart messages (required by the Jupyter wire protocol) are sent by
//! calling send() multiple times, passing ZMQ_SNDMORE as the flag for all
//! frames except the last, which gets flag 0.
//!
//! Usage:
//!   var socket = try Socket.init(&ctx, .dealer);
//!   defer socket.deinit() catch {};
//!   try socket.connect("tcp://127.0.0.1:5555");
//!
//! The underlying C functions are:
//!   zmq_socket()    — creates the socket, returns NULL on failure
//!   zmq_close()     — destroys the socket, returns -1 on failure
//!   zmq_bind()      — binds to an address, returns -1 on failure
//!   zmq_unbind()    — unbinds from an address, returns -1 on failure
//!   zmq_connect()   — connects to an address, returns -1 on failure
//!   zmq_disconnect() — disconnects from an address, returns -1 on failure
//!   zmq_send()      — sends a frame, returns bytes sent or -1 on failure
//!   zmq_recv()      — receives a frame, returns bytes received or -1 on failure

const zmq = @import("zmq.zig").c;
const Context = @import("context.zig").Context;

const std = @import("std");
const testing = std.testing;

/// The type of a ZMQ socket, mapped to the integer constants in zmq.h.
/// Only the types needed for Jupyter kernel communication are included.
pub const SocketType = enum(c_int) {
    /// PAIR — one-to-one communication, used for testing.
    pair = 0,
    /// SUB — subscribe to messages from a PUB socket (e.g. iopub channel).
    sub = 2,
    /// REQ — synchronous request, expects a reply (e.g. heartbeat channel).
    req = 3,
    /// REP — synchronous reply, responds to a REQ socket.
    rep = 4,
    /// DEALER — async request/reply, used for shell, stdin, control channels.
    dealer = 5,
};

/// Errors that can occur during socket lifecycle and I/O operations.
pub const SocketError = error{
    /// zmq_socket() returned NULL — ZMQ could not create the socket.
    SocketCreationFailed,
    /// zmq_bind() returned -1 — could not bind to the given address.
    SocketBindingFailed,
    /// zmq_unbind() returned -1 — could not unbind from the given address.
    SocketUnbindingFailed,
    /// zmq_close() returned -1 — socket could not be cleanly closed.
    SocketTerminationFailed,
    /// zmq_connect() returned -1 — could not connect to the given address.
    SocketConnectFailed,
    /// zmq_disconnect() returned -1 — could not disconnect from the given address.
    SocketDisconnectFailed,
    /// zmq_send() returned -1 — frame could not be sent.
    SocketSendFailed,
    /// zmq_recv() returned -1 — frame could not be received.
    SocketReceiveFailed,
};

/// A ZMQ socket. Created from a Context, destroyed before the Context.
pub const Socket = struct {
    /// Opaque pointer to the underlying ZMQ socket object.
    /// Returned by zmq_socket() and passed back to all zmq_* I/O functions.
    handle: *anyopaque,

    /// The type of this socket. Stored for introspection and validation.
    /// Set once at creation — ZMQ does not allow changing the type after init.
    socket_type: SocketType,

    /// Creates a new ZMQ socket of the given type, belonging to the given context.
    /// Returns `SocketCreationFailed` if ZMQ could not allocate the socket.
    pub fn init(context: *Context, socketType: SocketType) !Socket {
        const handle = zmq.zmq_socket(context.handle, @intFromEnum(socketType));
        if (handle == null) return SocketError.SocketCreationFailed;
        return Socket{ .handle = handle.?, .socket_type = socketType };
    }

    /// Closes the socket and releases all associated resources.
    /// Must be called before the owning Context is destroyed.
    /// Returns `SocketTerminationFailed` if ZMQ could not cleanly close.
    pub fn deinit(self: *Socket) !void {
        const result = zmq.zmq_close(self.handle);
        if (result != 0) return SocketError.SocketTerminationFailed;
    }

    /// Binds the socket to a local address so it listens for incoming connections.
    /// Example: "tcp://127.0.0.1:5555"
    /// Returns `SocketBindingFailed` if the address could not be bound.
    pub fn bind(self: *Socket, endpoint: [*:0]const u8) SocketError!void {
        const result = zmq.zmq_bind(self.handle, endpoint);
        if (result != 0) return SocketError.SocketBindingFailed;
    }

    /// Unbinds the socket from a previously bound address.
    /// Returns `SocketUnbindingFailed` if the address could not be unbound.
    pub fn unbind(self: *Socket, endpoint: [*:0]const u8) SocketError!void {
        const result = zmq.zmq_unbind(self.handle, endpoint);
        if (result != 0) return SocketError.SocketUnbindingFailed;
    }

    /// Connects the socket to a remote address.
    /// Example: "tcp://127.0.0.1:5555"
    /// Returns `SocketConnectFailed` if the connection could not be established.
    pub fn connect(self: *Socket, endpoint: [*:0]const u8) SocketError!void {
        const result = zmq.zmq_connect(self.handle, endpoint);
        if (result != 0) return SocketError.SocketConnectFailed;
    }

    /// Disconnects the socket from a previously connected address.
    /// Returns `SocketDisconnectFailed` if the disconnection failed.
    pub fn disconnect(self: *Socket, endpoint: [*:0]const u8) SocketError!void {
        const result = zmq.zmq_disconnect(self.handle, endpoint);
        if (result != 0) return SocketError.SocketDisconnectFailed;
    }

    /// Sends a single message frame.
    /// Pass `zmq.ZMQ_SNDMORE` as the flag if more frames follow.
    /// Pass `0` as the flag for the last (or only) frame.
    /// Returns `SocketSendFailed` if the frame could not be sent.
    pub fn send(self: *Socket, message: []const u8, flag: c_int) SocketError!void {
        const result = zmq.zmq_send(self.handle, message.ptr, message.len, flag);
        if (result < 0) return SocketError.SocketSendFailed;
    }

    /// Receives a single message frame into the provided buffer.
    /// Returns a slice of the buffer containing the received data.
    /// The caller is responsible for providing a buffer large enough for the frame.
    /// Returns `SocketReceiveFailed` if no frame could be received.
    pub fn receive(self: *Socket, buffer: []u8, flag: c_int) SocketError![]u8 {
        const result = zmq.zmq_recv(self.handle, buffer.ptr, buffer.len, flag);
        if (result < 0) return SocketError.SocketReceiveFailed;
        return buffer[0..@intCast(result)];
    }
};

test "Socket init" {
    var ctx = try Context.init();
    var socket = try Socket.init(&ctx, .dealer);
    try socket.deinit();
    try ctx.deinit();
}
