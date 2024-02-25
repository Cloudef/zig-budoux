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

export fn budoux_iterator_init(model: *budoux.Model, sentence: [*c]u8) callconv(.C) ?*budoux.ChunkIterator {
    const iter = gpa.allocator().create(budoux.ChunkIterator) catch return null;
    iter.* = model.iterator(std.mem.span(sentence));
    return iter;
}

export fn budoux_iterator_next(iter: *budoux.ChunkIterator) callconv(.C) budoux.ChunkIterator.Chunk {
    return iter.nextAsChunk() orelse .{ .begin = 0, .end = 0 };
}

export fn budoux_iterator_deinit(iter: *budoux.ChunkIterator) callconv(.C) void {
    gpa.allocator().destroy(iter);
}
