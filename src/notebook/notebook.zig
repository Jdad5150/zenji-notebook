//! Notebook type — top-level container for a .znb file.
//!
//! A Notebook owns its cell slice and all memory beneath it.
//! load/save handle file I/O; serialize/deserialize handle the binary format.
//! The .znb binary format is documented in plans.md under "znb Format".

const std = @import("std");
const testing = std.testing;
const Cell = @import("cell.zig").Cell;
const CellType = @import("cell.zig").CellType;
const Output = @import("output.zig").Output;
const OutputType = @import("output.zig").OutputType;
const Language = @import("../kernel/kernel.zig").Language;
const FixedBufferStream = @import("../util/test_io.zig").FixedBufferStream;

const MAGIC = "ZENJI";
const VERSION: u8 = 1;

/// Notebook-level metadata stored in the file header.
pub const NotebookMeta = struct {
    kernel_type: Language,
};

/// A loaded notebook. Owns all memory — free with deinit.
///
/// `next_cell_id` is a monotonic counter; it only increases.
/// Deleting a cell does not decrement it, ensuring sidecar paths remain stable.
pub const Notebook = struct {
    meta: NotebookMeta,
    next_cell_id: u32, // next ID to assign; never reused
    cells: []Cell,

    /// Creates a blank notebook with no cells. Caller must call deinit.
    pub fn init(allocator: std.mem.Allocator, meta: NotebookMeta) !Notebook {
        return Notebook{
            .meta = meta,
            .next_cell_id = 0,
            .cells = try allocator.alloc(Cell, 0),
        };
    }

    /// Frees all cells and the cells slice.
    pub fn deinit(self: *Notebook, allocator: std.mem.Allocator) void {
        for (self.cells) |*cell| {
            cell.deinit(allocator);
        }
        allocator.free(self.cells);
    }

    /// Reads a .znb file from disk and deserializes it.
    ///
    /// Returns `error.InvalidMagic` or `error.UnsupportedVersion` for unrecognized files.
    /// Caller must call deinit on the returned Notebook.
    pub fn load(io: std.Io, path: []const u8, allocator: std.mem.Allocator) !Notebook {
        const cwd = std.Io.Dir.cwd();
        const file = try cwd.openFile(io, path, .{});
        defer file.close(io);
        var buf: [4096]u8 = undefined;
        var fr = file.reader(io, &buf);
        const file_size = try fr.getSize();
        const content = try fr.interface.readAlloc(allocator, file_size);
        defer allocator.free(content);
        var stream = FixedBufferStream{ .buf = content };
        return Notebook.deserialize(stream.reader(), allocator);
    }

    /// Serializes this notebook and writes it to disk, creating or overwriting `path`.
    pub fn save(self: Notebook, io: std.Io, path: []const u8) !void {
        const cwd = std.Io.Dir.cwd();
        const file = try cwd.createFile(io, path, .{});
        defer file.close(io);
        var buf: [4096]u8 = undefined;
        var fw = file.writer(io, &buf);
        try self.serialize(&fw.interface);
        try fw.flush();
    }

    /// Writes this notebook to `writer` in .znb binary format.
    ///
    /// Header layout: magic (5B) | version (u8) | cell_count (u32 LE)
    ///                | next_cell_id (u32 LE) | kernel_type (u8) | cells...
    pub fn serialize(self: Notebook, writer: anytype) !void {
        try writer.writeAll(MAGIC);
        try writer.writeByte(VERSION);

        var buf: [4]u8 = undefined;

        std.mem.writeInt(u32, &buf, @intCast(self.cells.len), .little);
        try writer.writeAll(&buf);

        std.mem.writeInt(u32, &buf, self.next_cell_id, .little);
        try writer.writeAll(&buf);

        try writer.writeByte(@intFromEnum(self.meta.kernel_type));

        for (self.cells) |cell| {
            try cell.serialize(writer);
        }
    }

    /// Reads and validates a notebook from `reader`. Allocates all owned memory.
    ///
    /// Validates magic bytes and version before reading any cells.
    /// On partial cell failure, already-deserialized cells are freed before returning.
    /// Caller must call deinit on the returned Notebook.
    pub fn deserialize(reader: anytype, allocator: std.mem.Allocator) !Notebook {
        var magic: [5]u8 = undefined;
        try reader.readNoEof(&magic);
        if (!std.mem.eql(u8, &magic, MAGIC)) return error.InvalidMagic;

        const version = try reader.readByte();
        if (version != VERSION) return error.UnsupportedVersion;

        var buf: [4]u8 = undefined;

        try reader.readNoEof(&buf);
        const cell_count = std.mem.readInt(u32, &buf, .little);

        try reader.readNoEof(&buf);
        const next_cell_id = std.mem.readInt(u32, &buf, .little);

        const kernel_byte = try reader.readByte();
        const kernel_type: Language = switch (kernel_byte) {
            0 => .python,
            1 => .julia,
            2 => .r,
            3 => .mojo,
            else => return error.InvalidKernelType,
        };

        const cells = try allocator.alloc(Cell, cell_count);
        errdefer allocator.free(cells);

        for (cells, 0..) |*cell, i| {
            cell.* = Cell.deserialize(reader, allocator) catch |err| {
                for (cells[0..i]) |*c| c.deinit(allocator);
                return err;
            };
        }

        return Notebook{
            .meta = .{ .kernel_type = kernel_type },
            .next_cell_id = next_cell_id,
            .cells = cells,
        };
    }

    /// Returns a mutable pointer to the cell with `cell_id`, or null if not found.
    ///
    /// The pointer is valid until the cells slice is reallocated. Do not store it
    /// across any operation that modifies the cells slice.
    pub fn findCell(self: *Notebook, cell_id: u32) ?*Cell {
        for (self.cells) |*cell| {
            if (cell.cell_id == cell_id) return cell;
        }
        return null;
    }
};

test "Notebook.init has correct defaults" {
    var nb = try Notebook.init(testing.allocator, .{ .kernel_type = .python });
    defer nb.deinit(testing.allocator);
    try testing.expectEqual(Language.python, nb.meta.kernel_type);
    try testing.expectEqual(@as(u32, 0), nb.next_cell_id);
    try testing.expectEqual(@as(usize, 0), nb.cells.len);
}

test "Notebook round-trip empty" {
    var nb = try Notebook.init(testing.allocator, .{ .kernel_type = .python });
    defer nb.deinit(testing.allocator);
    nb.next_cell_id = 5;

    var buf: [64]u8 = undefined;
    var stream = FixedBufferStream{ .buf = &buf };
    try nb.serialize(stream.writer());

    stream.reset();
    var result = try Notebook.deserialize(stream.reader(), testing.allocator);
    defer result.deinit(testing.allocator);

    try testing.expectEqual(Language.python, result.meta.kernel_type);
    try testing.expectEqual(@as(u32, 5), result.next_cell_id);
    try testing.expectEqual(@as(usize, 0), result.cells.len);
}

test "Notebook round-trip single code cell" {
    var nb = try Notebook.init(testing.allocator, .{ .kernel_type = .python });
    defer nb.deinit(testing.allocator);

    var cell = try Cell.init(testing.allocator, .code, 0, "print('hello')");
    cell.execution_count = 1;
    nb.cells = try testing.allocator.alloc(Cell, 1);
    nb.cells[0] = cell;
    nb.next_cell_id = 1;

    var buf: [512]u8 = undefined;
    var stream = FixedBufferStream{ .buf = &buf };
    try nb.serialize(stream.writer());

    stream.reset();
    var result = try Notebook.deserialize(stream.reader(), testing.allocator);
    defer result.deinit(testing.allocator);

    try testing.expectEqual(@as(usize, 1), result.cells.len);
    try testing.expectEqual(CellType.code, result.cells[0].cell_type);
    try testing.expectEqual(@as(u32, 0), result.cells[0].cell_id);
    try testing.expectEqual(@as(u32, 1), result.cells[0].execution_count);
    try testing.expectEqualStrings("print('hello')", result.cells[0].source);
}

test "Notebook round-trip multiple cells with outputs" {
    var nb = try Notebook.init(testing.allocator, .{ .kernel_type = .python });
    defer nb.deinit(testing.allocator);
    nb.next_cell_id = 3;

    nb.cells = try testing.allocator.alloc(Cell, 3);

    nb.cells[0] = try Cell.init(testing.allocator, .markdown, 0, "# Title");
    nb.cells[1] = try Cell.init(testing.allocator, .code, 1, "x = 42");
    nb.cells[1].execution_count = 1;
    nb.cells[2] = try Cell.init(testing.allocator, .code, 2, "print(x)");
    nb.cells[2].execution_count = 2;
    nb.cells[2].outputs = try testing.allocator.alloc(Output, 1);
    nb.cells[2].outputs[0] = try Output.init(testing.allocator, .stdout, "42\n");

    var buf: [1024]u8 = undefined;
    var stream = FixedBufferStream{ .buf = &buf };
    try nb.serialize(stream.writer());

    stream.reset();
    var result = try Notebook.deserialize(stream.reader(), testing.allocator);
    defer result.deinit(testing.allocator);

    try testing.expectEqual(@as(usize, 3), result.cells.len);
    try testing.expectEqual(CellType.markdown, result.cells[0].cell_type);
    try testing.expectEqualStrings("# Title", result.cells[0].source);
    try testing.expectEqual(@as(u32, 1), result.cells[1].execution_count);
    try testing.expectEqual(@as(usize, 1), result.cells[2].outputs.len);
    try testing.expectEqualStrings("42\n", result.cells[2].outputs[0].data);
}

test "Notebook round-trip all kernel types" {
    const kernels = [_]Language{ .python, .julia, .r, .mojo };
    for (kernels) |lang| {
        var nb = try Notebook.init(testing.allocator, .{ .kernel_type = lang });
        defer nb.deinit(testing.allocator);

        var buf: [64]u8 = undefined;
        var stream = FixedBufferStream{ .buf = &buf };
        try nb.serialize(stream.writer());

        stream.reset();
        var result = try Notebook.deserialize(stream.reader(), testing.allocator);
        defer result.deinit(testing.allocator);

        try testing.expectEqual(lang, result.meta.kernel_type);
    }
}

test "Notebook deserialize rejects invalid magic" {
    var bad = [_]u8{ 'W', 'R', 'O', 'N', 'G', 1, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
    var stream = FixedBufferStream{ .buf = &bad };
    try testing.expectError(error.InvalidMagic, Notebook.deserialize(stream.reader(), testing.allocator));
}

test "Notebook deserialize rejects unsupported version" {
    var buf: [16]u8 = undefined;
    var stream = FixedBufferStream{ .buf = &buf };
    try stream.writer().writeAll("ZENJI");
    try stream.writer().writeByte(0xFF); // unsupported version

    stream.reset();
    try testing.expectError(error.UnsupportedVersion, Notebook.deserialize(stream.reader(), testing.allocator));
}

test "Notebook deserialize rejects invalid kernel type" {
    // header: ZENJI + version(1) + cell_count(0) + next_cell_id(0) + kernel_type(0xFF)
    var buf = [_]u8{ 'Z', 'E', 'N', 'J', 'I', 1, 0, 0, 0, 0, 0, 0, 0, 0, 0xFF };
    var stream = FixedBufferStream{ .buf = &buf };
    try testing.expectError(error.InvalidKernelType, Notebook.deserialize(stream.reader(), testing.allocator));
}

test "findCell returns pointer to matching cell" {
    var nb = try Notebook.init(testing.allocator, .{ .kernel_type = .python });
    defer nb.deinit(testing.allocator);
    nb.cells = try testing.allocator.alloc(Cell, 2);
    nb.cells[0] = try Cell.init(testing.allocator, .code, 0, "x = 1");
    nb.cells[1] = try Cell.init(testing.allocator, .code, 1, "y = 2");

    const found = nb.findCell(1);
    try testing.expect(found != null);
    try testing.expectEqualStrings("y = 2", found.?.source);
}

test "findCell returns null for missing id" {
    var nb = try Notebook.init(testing.allocator, .{ .kernel_type = .python });
    defer nb.deinit(testing.allocator);
    nb.cells = try testing.allocator.alloc(Cell, 1);
    nb.cells[0] = try Cell.init(testing.allocator, .code, 0, "x = 1");

    try testing.expect(nb.findCell(99) == null);
}

test "findCell returns null on empty notebook" {
    var nb = try Notebook.init(testing.allocator, .{ .kernel_type = .python });
    defer nb.deinit(testing.allocator);
    try testing.expect(nb.findCell(0) == null);
}

test "findCell pointer allows mutation" {
    var nb = try Notebook.init(testing.allocator, .{ .kernel_type = .python });
    defer nb.deinit(testing.allocator);
    nb.cells = try testing.allocator.alloc(Cell, 1);
    nb.cells[0] = try Cell.init(testing.allocator, .code, 0, "x = 1");

    const cell = nb.findCell(0).?;
    cell.execution_count = 5;
    try testing.expectEqual(@as(u32, 5), nb.cells[0].execution_count);
}

test "Notebook load/save round-trip with real file" {
    var threaded = std.Io.Threaded.init(testing.allocator, .{ .environ = std.process.Environ.empty });
    defer threaded.deinit();
    const io = threaded.io();

    const tmp_path = "test_nb_roundtrip.znb";
    defer std.Io.Dir.cwd().deleteFile(io, tmp_path) catch {};

    var nb = try Notebook.init(testing.allocator, .{ .kernel_type = .python });
    defer nb.deinit(testing.allocator);
    nb.cells = try testing.allocator.alloc(Cell, 1);
    nb.cells[0] = try Cell.init(testing.allocator, .code, 0, "x = 42");
    nb.cells[0].execution_count = 3;
    nb.next_cell_id = 1;

    try nb.save(io, tmp_path);

    var loaded = try Notebook.load(io, tmp_path, testing.allocator);
    defer loaded.deinit(testing.allocator);

    try testing.expectEqual(Language.python, loaded.meta.kernel_type);
    try testing.expectEqual(@as(u32, 1), loaded.next_cell_id);
    try testing.expectEqual(@as(usize, 1), loaded.cells.len);
    try testing.expectEqual(CellType.code, loaded.cells[0].cell_type);
    try testing.expectEqual(@as(u32, 3), loaded.cells[0].execution_count);
    try testing.expectEqualStrings("x = 42", loaded.cells[0].source);
}
