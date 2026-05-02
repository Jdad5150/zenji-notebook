//! In-memory reader/writer for use in tests.
//!
//! Replaces std.io.fixedBufferStream, which was removed in Zig 0.16.0.
//! Not intended for production use — test files only.

const std = @import("std");

/// A fixed-size in-memory stream with separate writer and reader positions sharing state.
///
/// Typical usage: write with stream.writer(), call stream.reset(), read back with stream.reader().
pub const FixedBufferStream = struct {
    buf: []u8,
    pos: usize = 0,

    /// Returns a writer that appends to this stream starting at the current position.
    pub fn writer(self: *FixedBufferStream) Writer {
        return .{ .stream = self };
    }

    /// Returns a reader that reads from this stream starting at the current position.
    pub fn reader(self: *FixedBufferStream) Reader {
        return .{ .stream = self };
    }

    /// Resets the position to zero so the buffer can be read from the beginning.
    pub fn reset(self: *FixedBufferStream) void {
        self.pos = 0;
    }

    /// Writer handle for a FixedBufferStream.
    pub const Writer = struct {
        stream: *FixedBufferStream,

        /// Writes a single byte. Returns `error.NoSpaceLeft` if the buffer is full.
        pub fn writeByte(self: Writer, byte: u8) !void {
            if (self.stream.pos >= self.stream.buf.len) return error.NoSpaceLeft;
            self.stream.buf[self.stream.pos] = byte;
            self.stream.pos += 1;
        }

        /// Writes all bytes in `data`. Returns `error.NoSpaceLeft` if insufficient space remains.
        pub fn writeAll(self: Writer, data: []const u8) !void {
            if (self.stream.pos + data.len > self.stream.buf.len) return error.NoSpaceLeft;
            @memcpy(self.stream.buf[self.stream.pos..][0..data.len], data);
            self.stream.pos += data.len;
        }
    };

    /// Reader handle for a FixedBufferStream.
    pub const Reader = struct {
        stream: *FixedBufferStream,

        /// Reads and returns a single byte. Returns `error.EndOfStream` if no bytes remain.
        pub fn readByte(self: Reader) !u8 {
            if (self.stream.pos >= self.stream.buf.len) return error.EndOfStream;
            const byte = self.stream.buf[self.stream.pos];
            self.stream.pos += 1;
            return byte;
        }

        /// Reads exactly `dest.len` bytes into `dest`. Returns `error.EndOfStream` if fewer remain.
        pub fn readNoEof(self: Reader, dest: []u8) !void {
            if (self.stream.pos + dest.len > self.stream.buf.len) return error.EndOfStream;
            @memcpy(dest, self.stream.buf[self.stream.pos..][0..dest.len]);
            self.stream.pos += dest.len;
        }
    };
};
