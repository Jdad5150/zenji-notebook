//! Cell type representing a single unit of a notebook.
//!
//! A cell holds source text and zero or more outputs produced by the last
//! execution. Outputs are replaced in full on each run — partial updates
//! are not supported. All memory is owned by the Cell and freed via deinit.

const std = @import("std");
const testing = std.testing;
const Output = @import("output.zig").Output;
const OutputType = @import("output.zig").OutputType;
const FixedBufferStream = @import("../util/test_io.zig").FixedBufferStream;

/// Discriminates whether a cell contains executable code or markdown text.
pub const CellType = enum(u8) {
    code = 0,
    markdown = 1,
};

/// A single cell in a notebook.
///
/// `source` and `outputs` are owned slices — free with deinit.
/// `cell_id` is assigned at creation and never changes, even if the cell
/// is reordered. It is the stable key used for sidecar artifact paths.
pub const Cell = struct {
    cell_type: CellType,
    cell_id: u32,
    execution_count: u32, // 0 = never executed
    source: []u8,
    outputs: []Output,

    /// Creates a cell with empty outputs. Dupes `source` — caller owns the Cell.
    pub fn init(allocator: std.mem.Allocator, cell_type: CellType, cell_id: u32, source: []const u8) !Cell {
        return Cell{
            .cell_type = cell_type,
            .cell_id = cell_id,
            .execution_count = 0,
            .source = try allocator.dupe(u8, source),
            .outputs = try allocator.alloc(Output, 0),
        };
    }

    /// Frees source, all outputs, and the outputs slice.
    pub fn deinit(self: *Cell, allocator: std.mem.Allocator) void {
        for (self.outputs) |*output| {
            output.deinit(allocator);
        }
        allocator.free(self.outputs);
        allocator.free(self.source);
    }

    /// Writes this cell to `writer` in .znb binary format.
    ///
    /// Layout: cell_type (u8) | cell_id (u32 LE) | execution_count (u32 LE)
    ///         | source_len (u32 LE) | source bytes
    ///         | output_count (u8) | outputs...
    pub fn serialize(self: Cell, writer: anytype) !void {
        try writer.writeByte(@intFromEnum(self.cell_type));

        var buf: [4]u8 = undefined;

        std.mem.writeInt(u32, &buf, self.cell_id, .little);
        try writer.writeAll(&buf);

        std.mem.writeInt(u32, &buf, self.execution_count, .little);
        try writer.writeAll(&buf);

        std.mem.writeInt(u32, &buf, @intCast(self.source.len), .little);
        try writer.writeAll(&buf);
        try writer.writeAll(self.source);

        try writer.writeByte(@intCast(self.outputs.len));
        for (self.outputs) |output| {
            try output.serialize(writer);
        }
    }

    /// Reads one Cell from `reader`. Allocates owned source and outputs.
    ///
    /// Returns `error.InvalidCellType` if the type byte is not a known variant.
    /// On partial failure mid-outputs, already-deserialized outputs are freed
    /// before the error is returned — no leaks on corrupt input.
    /// Caller must call deinit on the returned Cell.
    pub fn deserialize(reader: anytype, allocator: std.mem.Allocator) !Cell {
        const type_byte = try reader.readByte();
        const cell_type: CellType = switch (type_byte) {
            0 => .code,
            1 => .markdown,
            else => return error.InvalidCellType,
        };

        var buf: [4]u8 = undefined;

        try reader.readNoEof(&buf);
        const cell_id = std.mem.readInt(u32, &buf, .little);

        try reader.readNoEof(&buf);
        const execution_count = std.mem.readInt(u32, &buf, .little);

        try reader.readNoEof(&buf);
        const source_len = std.mem.readInt(u32, &buf, .little);
        const source = try allocator.alloc(u8, source_len);
        errdefer allocator.free(source);
        try reader.readNoEof(source);

        const output_count = try reader.readByte();
        const outputs = try allocator.alloc(Output, output_count);
        errdefer allocator.free(outputs);

        for (outputs, 0..) |*output, i| {
            output.* = Output.deserialize(reader, allocator) catch |err| {
                for (outputs[0..i]) |*o| o.deinit(allocator);
                return err;
            };
        }

        return Cell{
            .cell_type = cell_type,
            .cell_id = cell_id,
            .execution_count = execution_count,
            .source = source,
            .outputs = outputs,
        };
    }
};

test "Cell.init has correct defaults" {
    var cell = try Cell.init(testing.allocator, .code, 1, "print('hi')");
    defer cell.deinit(testing.allocator);
    try testing.expectEqual(CellType.code, cell.cell_type);
    try testing.expectEqual(@as(u32, 1), cell.cell_id);
    try testing.expectEqual(@as(u32, 0), cell.execution_count);
    try testing.expectEqualStrings("print('hi')", cell.source);
    try testing.expectEqual(@as(usize, 0), cell.outputs.len);
}

test "Cell round-trip code cell no outputs" {
    var cell = try Cell.init(testing.allocator, .code, 7, "x = 1 + 1");
    defer cell.deinit(testing.allocator);
    cell.execution_count = 3;

    var buf: [256]u8 = undefined;
    var stream = FixedBufferStream{ .buf = &buf };
    try cell.serialize(stream.writer());

    stream.reset();
    var result = try Cell.deserialize(stream.reader(), testing.allocator);
    defer result.deinit(testing.allocator);

    try testing.expectEqual(CellType.code, result.cell_type);
    try testing.expectEqual(@as(u32, 7), result.cell_id);
    try testing.expectEqual(@as(u32, 3), result.execution_count);
    try testing.expectEqualStrings("x = 1 + 1", result.source);
    try testing.expectEqual(@as(usize, 0), result.outputs.len);
}

test "Cell round-trip markdown cell" {
    var cell = try Cell.init(testing.allocator, .markdown, 2, "# Hello\nThis is a notebook.");
    defer cell.deinit(testing.allocator);

    var buf: [256]u8 = undefined;
    var stream = FixedBufferStream{ .buf = &buf };
    try cell.serialize(stream.writer());

    stream.reset();
    var result = try Cell.deserialize(stream.reader(), testing.allocator);
    defer result.deinit(testing.allocator);

    try testing.expectEqual(CellType.markdown, result.cell_type);
    try testing.expectEqualStrings("# Hello\nThis is a notebook.", result.source);
}

test "Cell round-trip with multiple outputs" {
    var cell = try Cell.init(testing.allocator, .code, 5, "import matplotlib.pyplot as plt\nplt.show()");
    defer cell.deinit(testing.allocator);

    const stdout = try Output.init(testing.allocator, .stdout, "some text\n");
    const img = try Output.init(testing.allocator, .image_ref, "5/0");
    cell.outputs = try testing.allocator.alloc(Output, 2);
    cell.outputs[0] = stdout;
    cell.outputs[1] = img;

    var buf: [512]u8 = undefined;
    var stream = FixedBufferStream{ .buf = &buf };
    try cell.serialize(stream.writer());

    stream.reset();
    var result = try Cell.deserialize(stream.reader(), testing.allocator);
    defer result.deinit(testing.allocator);

    try testing.expectEqual(@as(usize, 2), result.outputs.len);
    try testing.expectEqual(OutputType.stdout, result.outputs[0].output_type);
    try testing.expectEqualStrings("some text\n", result.outputs[0].data);
    try testing.expectEqual(OutputType.image_ref, result.outputs[1].output_type);
    try testing.expectEqualStrings("5/0", result.outputs[1].data);
}

test "Cell round-trip empty source" {
    var cell = try Cell.init(testing.allocator, .code, 0, "");
    defer cell.deinit(testing.allocator);

    var buf: [64]u8 = undefined;
    var stream = FixedBufferStream{ .buf = &buf };
    try cell.serialize(stream.writer());

    stream.reset();
    var result = try Cell.deserialize(stream.reader(), testing.allocator);
    defer result.deinit(testing.allocator);

    try testing.expectEqual(@as(usize, 0), result.source.len);
}

test "Cell deserialize rejects invalid cell type" {
    var buf: [32]u8 = std.mem.zeroes([32]u8);
    buf[0] = 0xFF;
    var stream = FixedBufferStream{ .buf = &buf };
    try testing.expectError(error.InvalidCellType, Cell.deserialize(stream.reader(), testing.allocator));
}

test "Cell round-trip preserves cell_id across many cells" {
    const ids = [_]u32{ 0, 1, 100, 65535, std.math.maxInt(u32) };
    for (ids) |id| {
        var cell = try Cell.init(testing.allocator, .code, id, "pass");
        defer cell.deinit(testing.allocator);

        var buf: [64]u8 = undefined;
        var stream = FixedBufferStream{ .buf = &buf };
        try cell.serialize(stream.writer());

        stream.reset();
        var result = try Cell.deserialize(stream.reader(), testing.allocator);
        defer result.deinit(testing.allocator);

        try testing.expectEqual(id, result.cell_id);
    }
}
