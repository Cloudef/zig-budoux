const std = @import("std");
const budoux = @import("budoux.zig");

const c = @cImport({
    @cInclude("budoux.h");
});

comptime {
    // Sucks but size_t isn't part of the C compiler but rather part of the C stdlib.
    // The effect is that on your C side, you might get slightly larger temporary structs
    // than what is neccessary. There is however no ABI issue here, because BudouxChunkIterator
    // and BudouxChunk values are copied from the Zig structs and back, e.g. the Zig code does not
    // use the C structs directly.
    std.debug.assert(@sizeOf(c.budoux_size_t) >= @sizeOf(usize));
    for (std.meta.fields(budoux.BuiltinModel)) |v| {
        std.debug.assert(@field(c, "budoux_model_" ++ v.name) == v.value);
    }
}

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

export fn budoux_init_from_json(bytes: [*]u8, len: c.budoux_size_t) callconv(.C) ?*budoux.Model {
    const model = gpa.allocator().create(budoux.Model) catch return null;
    model.* = budoux.initFromJson(gpa.allocator(), bytes[0..len]) catch return null;
    return model;
}

export fn budoux_init_from_zlib_json(bytes: [*]u8, len: c.budoux_size_t) callconv(.C) ?*budoux.Model {
    const model = gpa.allocator().create(budoux.Model) catch return null;
    model.* = budoux.initFromZlibJson(gpa.allocator(), bytes[0..len]) catch return null;
    return model;
}

export fn budoux_init(builtin: c.BudouxPrebuiltModel) callconv(.C) ?*budoux.Model {
    const model = gpa.allocator().create(budoux.Model) catch return null;
    model.* = budoux.init(gpa.allocator(), @enumFromInt(builtin)) catch return null;
    return model;
}

export fn budoux_deinit(model: *budoux.Model) callconv(.C) void {
    model.deinit(gpa.allocator());
    gpa.allocator().destroy(model);
}

export fn budoux_iterator_init(model: *budoux.Model, sentence: [*:0]u8) callconv(.C) c.BudouxChunkIterator {
    const slice = std.mem.span(sentence);
    return budoux_iterator_init_from_slice(model, sentence, slice.len);
}

export fn budoux_iterator_init_from_slice(model: *budoux.Model, sentence: [*]u8, len: c.budoux_size_t) callconv(.C) c.BudouxChunkIterator {
    const iter = model.iterator(sentence[0..len]);
    return .{
        .model = @ptrCast(iter.model),
        .bytes = sentence[0..len].ptr,
        .bytes_len = len,
        .i = iter.iterator.i,
        .i_codepoint = iter.i_codepoint,
        .history = iter.history,
    };
}

export fn budoux_iterator_next(c_iter: *c.BudouxChunkIterator) callconv(.C) c.BudouxChunk {
    var iter: budoux.ChunkIterator = .{
        .model = @ptrCast(c_iter.model),
        .iterator = .{ .bytes = c_iter.bytes[0..c_iter.bytes_len], .i = @truncate(c_iter.i) },
        .i_codepoint = @truncate(c_iter.i_codepoint),
        .history = .{ @truncate(c_iter.history[0]), @truncate(c_iter.history[1]), @truncate(c_iter.history[2]) },
    };
    const maybe_chunk = iter.nextAsChunk();
    c_iter.i = iter.iterator.i;
    c_iter.i_codepoint = iter.i_codepoint;
    c_iter.history = iter.history;
    if (maybe_chunk) |chunk| return .{ .begin = chunk.begin, .end = chunk.end };
    return .{ .begin = 0, .end = 0 };
}
