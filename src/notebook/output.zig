//! Output type for a single cell execution result.
//!
//! Text outputs (stdout, stderr, errors) are stored inline as UTF-8 slices.
//! Binary outputs (images) are stored as a path fragment into the sidecar
//! directory — the actual file lives at `.{notebook_name}/{cell_id}/{index}`.
//! All memory is owned by the Output and freed via deinit.

const std = @import("std");
const testing = std.testing;
const FixedBufferStream = @import("../util/test_io.zig").FixedBufferStream;

/// Discriminates the kind of data stored in an Output.
pub const OutputType = enum(u8) {
    stdout = 0,
    stderr = 1,
    /// Path fragment into the sidecar directory, e.g. "42/0".
    image_ref = 2,
    err = 3,
};

/// A single output produced by cell execution.
///
/// All string fields are owned slices — free with deinit.
pub const Output = struct {
    output_type: OutputType,
    data: []u8,

    /// Allocates and copies `data`. Caller must call deinit when done.
    pub fn init(allocator: std.mem.Allocator, output_type: OutputType, data: []const u8) !Output {
        return Output{
            .output_type = output_type,
            .data = try allocator.dupe(u8, data),
        };
    }

    /// Frees owned data. Must be called before the Output goes out of scope.
    pub fn deinit(self: *Output, allocator: std.mem.Allocator) void {
        allocator.free(self.data);
    }

    /// Writes this output to `writer` in .znb binary format.
    ///
    /// Layout: output_type (u8) | data_len (u32 LE) | data bytes.
    pub fn serialize(self: Output, writer: anytype) !void {
        try writer.writeByte(@intFromEnum(self.output_type));
        var len_buf: [4]u8 = undefined;
        std.mem.writeInt(u32, &len_buf, @intCast(self.data.len), .little);
        try writer.writeAll(&len_buf);
        try writer.writeAll(self.data);
    }

    /// Reads one Output from `reader`. Allocates owned data.
    ///
    /// Returns `error.InvalidOutputType` if the type byte is not a known variant.
    /// Returns `error.EndOfStream` if the stream ends before all data is read.
    /// Caller must call deinit on the returned Output.
    pub fn deserialize(reader: anytype, allocator: std.mem.Allocator) !Output {
        const type_byte = try reader.readByte();
        const output_type: OutputType = switch (type_byte) {
            0 => .stdout,
            1 => .stderr,
            2 => .image_ref,
            3 => .err,
            else => return error.InvalidOutputType,
        };

        var len_buf: [4]u8 = undefined;
        try reader.readNoEof(&len_buf);
        const data_len = std.mem.readInt(u32, &len_buf, .little);

        const data = try allocator.alloc(u8, data_len);
        errdefer allocator.free(data);
        try reader.readNoEof(data);

        return Output{ .output_type = output_type, .data = data };
    }
};

test "Output.init stores type and dupes data" {
    var out = try Output.init(testing.allocator, .stdout, "hello");
    defer out.deinit(testing.allocator);
    try testing.expectEqual(OutputType.stdout, out.output_type);
    try testing.expectEqualStrings("hello", out.data);
}

test "Output round-trip stdout" {
    var out = try Output.init(testing.allocator, .stdout, "hello world\n");
    defer out.deinit(testing.allocator);

    var buf: [256]u8 = undefined;
    var stream = FixedBufferStream{ .buf = &buf };
    try out.serialize(stream.writer());

    stream.reset();
    var result = try Output.deserialize(stream.reader(), testing.allocator);
    defer result.deinit(testing.allocator);

    try testing.expectEqual(OutputType.stdout, result.output_type);
    try testing.expectEqualStrings(out.data, result.data);
}

test "Output round-trip stderr" {
    var out = try Output.init(testing.allocator, .stderr, "Traceback (most recent call last):\n  ...\n");
    defer out.deinit(testing.allocator);

    var buf: [256]u8 = undefined;
    var stream = FixedBufferStream{ .buf = &buf };
    try out.serialize(stream.writer());

    stream.reset();
    var result = try Output.deserialize(stream.reader(), testing.allocator);
    defer result.deinit(testing.allocator);

    try testing.expectEqual(OutputType.stderr, result.output_type);
    try testing.expectEqualStrings(out.data, result.data);
}

test "Output round-trip image_ref" {
    var out = try Output.init(testing.allocator, .image_ref, "42/0");
    defer out.deinit(testing.allocator);

    var buf: [64]u8 = undefined;
    var stream = FixedBufferStream{ .buf = &buf };
    try out.serialize(stream.writer());

    stream.reset();
    var result = try Output.deserialize(stream.reader(), testing.allocator);
    defer result.deinit(testing.allocator);

    try testing.expectEqual(OutputType.image_ref, result.output_type);
    try testing.expectEqualStrings("42/0", result.data);
}

test "Output round-trip err" {
    var out = try Output.init(testing.allocator, .err, "NameError: name 'x' is not defined");
    defer out.deinit(testing.allocator);

    var buf: [256]u8 = undefined;
    var stream = FixedBufferStream{ .buf = &buf };
    try out.serialize(stream.writer());

    stream.reset();
    var result = try Output.deserialize(stream.reader(), testing.allocator);
    defer result.deinit(testing.allocator);

    try testing.expectEqual(OutputType.err, result.output_type);
    try testing.expectEqualStrings(out.data, result.data);
}

test "Output round-trip empty data" {
    var out = try Output.init(testing.allocator, .stdout, "");
    defer out.deinit(testing.allocator);

    var buf: [16]u8 = undefined;
    var stream = FixedBufferStream{ .buf = &buf };
    try out.serialize(stream.writer());

    stream.reset();
    var result = try Output.deserialize(stream.reader(), testing.allocator);
    defer result.deinit(testing.allocator);

    try testing.expectEqual(OutputType.stdout, result.output_type);
    try testing.expectEqual(@as(usize, 0), result.data.len);
}

test "Output deserialize rejects invalid type byte" {
    var bad: [5]u8 = .{ 0xFF, 0, 0, 0, 0 };
    var stream = FixedBufferStream{ .buf = &bad };
    try testing.expectError(error.InvalidOutputType, Output.deserialize(stream.reader(), testing.allocator));
}

test "Output deserialize fails on truncated data" {
    var buf: [5]u8 = undefined;
    buf[0] = @intFromEnum(OutputType.stdout);
    std.mem.writeInt(u32, buf[1..5], 10, .little);
    var stream = FixedBufferStream{ .buf = &buf };
    try testing.expectError(error.EndOfStream, Output.deserialize(stream.reader(), testing.allocator));
}
