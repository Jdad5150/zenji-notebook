//! Raw C interop layer for libzmq.
//!
//! This file is the only place in the codebase that directly touches the
//! libzmq C headers. Everything else in the transport layer imports this
//! module and calls C functions through the `c` namespace.
//!
//! The include path for zmq.h is configured in build.zig:
//!   exe.addIncludePath(b.path("vendor/libzmq/include"));
//!
//! libzmq is compiled from vendored C++ source and linked statically, so
//! the final binary has no runtime dependency on a system libzmq.

pub const c = @cImport({
    @cInclude("zmq.h");
});
