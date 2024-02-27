const std = @import("std");
const budoux = @import("budoux.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

export fn budoux_init_from_json(bytes: [*c]u8) callconv(.C) ?*budoux.Model {
    const model = gpa.allocator().create(budoux.Model) catch return null;
    model.* = budoux.initFromJson(gpa.allocator(), std.mem.span(bytes)) catch return null;
    return model;
}

export fn budoux_init(builtin: budoux.BuiltinModel) callconv(.C) ?*budoux.Model {
    const model = gpa.allocator().create(budoux.Model) catch return null;
    model.* = budoux.init(gpa.allocator(), builtin) catch return null;
    return model;
}

export fn budoux_deinit(model: *budoux.Model) callconv(.C) void {
    model.deinit(gpa.allocator());
    gpa.allocator().destroy(model);
}

pub const BudouxChunkIterator = extern struct {
    model: *const budoux.Model,
    bytes: [*c]u8,
    i: usize,
    i_codepoint: usize,
    history: [3]usize,
};

export fn budoux_iterator_init(model: *budoux.Model, sentence: [*c]u8) callconv(.C) BudouxChunkIterator {
    const iter = model.iterator(std.mem.span(sentence));
    return .{
        .model = iter.model,
        .bytes = sentence,
        .i = iter.iterator.i,
        .i_codepoint = iter.i_codepoint,
        .history = iter.history,
    };
}

export fn budoux_iterator_next(c_iter: *BudouxChunkIterator) callconv(.C) budoux.ChunkIterator.Chunk {
    var iter: budoux.ChunkIterator = .{
        .model = c_iter.model,
        .iterator = .{ .bytes = std.mem.span(c_iter.bytes), .i = c_iter.i },
        .i_codepoint = c_iter.i_codepoint,
        .history = c_iter.history,
    };
    const chunk = iter.nextAsChunk();
    c_iter.i = iter.iterator.i;
    c_iter.i_codepoint = iter.i_codepoint;
    c_iter.history = iter.history;
    return chunk orelse .{ .begin = 0, .end = 0 };
}
