const std = @import("std");

/// Minimal in-memory stream for use in tests. Provides writer/reader
/// with the same interface our serialize/deserialize functions expect.
pub const FixedBufferStream = struct {
    buf: []u8,
    pos: usize = 0,

    pub fn writer(self: *FixedBufferStream) Writer {
        return .{ .stream = self };
    }

    pub fn reader(self: *FixedBufferStream) Reader {
        return .{ .stream = self };
    }

    pub fn reset(self: *FixedBufferStream) void {
        self.pos = 0;
    }

    pub const Writer = struct {
        stream: *FixedBufferStream,

        pub fn writeByte(self: Writer, byte: u8) !void {
            if (self.stream.pos >= self.stream.buf.len) return error.NoSpaceLeft;
            self.stream.buf[self.stream.pos] = byte;
            self.stream.pos += 1;
        }

        pub fn writeAll(self: Writer, data: []const u8) !void {
            if (self.stream.pos + data.len > self.stream.buf.len) return error.NoSpaceLeft;
            @memcpy(self.stream.buf[self.stream.pos..][0..data.len], data);
            self.stream.pos += data.len;
        }
    };

    pub const Reader = struct {
        stream: *FixedBufferStream,

        pub fn readByte(self: Reader) !u8 {
            if (self.stream.pos >= self.stream.buf.len) return error.EndOfStream;
            const byte = self.stream.buf[self.stream.pos];
            self.stream.pos += 1;
            return byte;
        }

        pub fn readNoEof(self: Reader, dest: []u8) !void {
            if (self.stream.pos + dest.len > self.stream.buf.len) return error.EndOfStream;
            @memcpy(dest, self.stream.buf[self.stream.pos..][0..dest.len]);
            self.stream.pos += dest.len;
        }
    };
};
