const std = @import("std");

// Welcome to the jungle
const Debug = @import("builtin").is_test;

inline fn debug(comptime fmt: []const u8, args: anytype) void {
    if (comptime Debug) std.debug.print(fmt ++ "\n", args);
}

pub const BuiltinModel = enum(u8) {
    ja,
    ja_knbc,
    th,
    zh_hans,
    zh_hant,
};

pub const Model = @This();

base_score: i32,
UW1: std.StringHashMapUnmanaged(i32) = .{},
UW2: std.StringHashMapUnmanaged(i32) = .{},
UW3: std.StringHashMapUnmanaged(i32) = .{},
UW4: std.StringHashMapUnmanaged(i32) = .{},
UW5: std.StringHashMapUnmanaged(i32) = .{},
UW6: std.StringHashMapUnmanaged(i32) = .{},
BW1: std.StringHashMapUnmanaged(i32) = .{},
BW2: std.StringHashMapUnmanaged(i32) = .{},
BW3: std.StringHashMapUnmanaged(i32) = .{},
TW1: std.StringHashMapUnmanaged(i32) = .{},
TW2: std.StringHashMapUnmanaged(i32) = .{},
TW3: std.StringHashMapUnmanaged(i32) = .{},
TW4: std.StringHashMapUnmanaged(i32) = .{},

pub const InitFromJsonError = std.json.Scanner.NextError || std.mem.Allocator.Error;

// Budoux models are generally small so this does not have to be a streaming parser
pub fn initFromJson(allocator: std.mem.Allocator, bytes: []const u8) InitFromJsonError!@This() {
    var scanner = std.json.Scanner.initCompleteInput(allocator, bytes);
    defer scanner.deinit();

    var self: @This() = .{ .base_score = 0 };
    errdefer self.deinit(allocator);

    while (true) {
        const root = try scanner.next();
        switch (root) {
            .object_begin => continue,
            .object_end => break,
            .string => {},
            else => return error.SyntaxError,
        }

        var map: ?*std.StringHashMapUnmanaged(i32) = null;
        inline for (std.meta.fields(@This())) |f| {
            if (f.type == std.StringHashMapUnmanaged(i32) and std.mem.eql(u8, f.name, root.string)) {
                map = &@field(self, f.name);
            }
        }
        if (map == null) return error.SyntaxError;

        while (true) {
            var el = try scanner.next();
            switch (el) {
                .object_begin => continue,
                .object_end => break,
                else => {},
            }
            if (el != .string) return error.SyntaxError;
            const key = el.string;
            el = try scanner.next();
            if (el != .number) return error.SyntaxError;
            const value = std.fmt.parseInt(i32, el.number, 10) catch return error.SyntaxError;
            try map.?.putNoClobber(allocator, try allocator.dupe(u8, key), value);
        }
    }

    inline for (std.meta.fields(@This())) |f| {
        if (f.type == std.StringHashMapUnmanaged(i32)) {
            var iter = @field(self, f.name).iterator();
            while (iter.next()) |entry| self.base_score += entry.value_ptr.*;
        }
    }
    return self;
}

fn decompressBuiltinModel(allocator: std.mem.Allocator, model: BuiltinModel) ![]const u8 {
    const compressed = switch (model) {
        .ja => @embedFile("budoux-ja"),
        .ja_knbc => @embedFile("budoux-ja-knbc"),
        .th => @embedFile("budoux-th"),
        .zh_hans => @embedFile("budoux-zh-hans"),
        .zh_hant => @embedFile("budoux-zh-hant"),
    };
    var rstream = std.io.fixedBufferStream(compressed);
    var wstream: std.ArrayListUnmanaged(u8) = .{};
    try std.compress.zlib.decompress(rstream.reader(), wstream.writer(allocator));
    return wstream.items;
}

pub const InitError = InitFromJsonError ||
    std.compress.flate.inflate.Inflate(.zlib, std.io.FixedBufferStream([]u8).Reader).Error;

/// Sadly std hash maps can't be filled comptime :(
/// If the status quo ever changes, provide ability to load models comptime
pub fn init(allocator: std.mem.Allocator, model: BuiltinModel) InitError!@This() {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    return initFromJson(allocator, try decompressBuiltinModel(arena.allocator(), model));
}

pub const Map = blk: {
    var count: usize = 0;
    for (std.meta.fields(@This())) |f| count += @intFromBool(f.type == std.StringHashMapUnmanaged(i32));

    var i: usize = 0;
    var fields: [count]std.builtin.Type.EnumField = undefined;
    for (std.meta.fields(@This())) |f| {
        if (f.type == std.StringHashMapUnmanaged(i32)) {
            fields[i] = .{ .name = f.name, .value = i };
            i += 1;
        }
    }

    break :blk @Type(.{
        .Enum = .{
            .tag_type = std.math.IntFittingRange(0, count),
            .fields = &fields,
            .decls = &.{},
            .is_exhaustive = true,
        },
    });
};

pub fn get(self: @This(), comptime map: Map, key: []const u8) i32 {
    if (key.len == 0) return 0;
    const score = @field(self, @tagName(map)).get(key) orelse 0;
    // debug("{s}: {s} => {d}", .{ @tagName(map), key, score });
    return score;
}

pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
    inline for (std.meta.fields(@This())) |f| {
        if (f.type == std.StringHashMapUnmanaged(i32)) {
            var iter = @field(self, f.name).iterator();
            while (iter.next()) |entry| allocator.free(entry.key_ptr.*);
            @field(self, f.name).deinit(allocator);
        }
    }
    self.* = undefined;
}

/// Returns `ChunkIterator`, `sentence` must be a valid utf8 string, it is not checked
/// Caller owns the `sentence` memory, and the memory must be valid for the duration of `ChunkIterator` use
pub inline fn iterator(self: *const @This(), sentence: []const u8) ChunkIterator {
    return .{
        .iterator = .{ .bytes = sentence, .i = 0 },
        .model = self,
        .unicode_len = std.unicode.utf8CountCodepoints(sentence) catch unreachable,
    };
}

pub const ChunkIterator = struct {
    iterator: std.unicode.Utf8Iterator,
    model: *const Model,
    unicode_len: usize,
    unicode_index: usize = 0,
    history: [3]usize = .{ 0, 0, 0 },

    inline fn safeOffset(self: @This(), comptime offset: isize) usize {
        if (offset == 0) {
            return self.unicode_index;
        } else if (offset < 0) {
            const abs = @abs(offset);
            if (abs >= self.unicode_index) return 0;
            return self.unicode_index - abs;
        } else {
            if (offset >= self.unicode_len or self.unicode_index >= self.unicode_len - offset) {
                return self.unicode_len;
            }
            return self.unicode_index + offset;
        }
        unreachable;
    }

    fn unicodeSlice(self: @This(), byte_index: usize, comptime unsafe_from: isize, comptime unsafe_to: isize) []const u8 {
        comptime std.debug.assert(unsafe_to > unsafe_from);
        comptime std.debug.assert(unsafe_from <= 2 and unsafe_from >= -3);
        comptime std.debug.assert(unsafe_to >= -2 and unsafe_to <= 3);
        const a: usize = self.safeOffset(unsafe_from + 1);
        const b: usize = self.safeOffset(unsafe_to + 1);
        if (a == b) return "";
        const from, const to = .{ @min(a, b), @max(a, b) };
        var iter: std.unicode.Utf8Iterator = .{
            .bytes = self.iterator.bytes,
            .i = if (from >= self.unicode_index) byte_index else self.history[self.unicode_index - from],
        };
        var index: usize = if (from >= self.unicode_index) self.unicode_index else from;
        var slice_start: usize = 0;
        while (iter.nextCodepointSlice()) |cp| {
            if (index == from) {
                slice_start = iter.i - cp.len;
            }
            index += 1;
            if (index == to) {
                debug("{d}..{d}: {d} => {d}", .{ unsafe_from, unsafe_to, self.history, if (from >= self.unicode_index) 69 else self.unicode_index - from });
                debug("{d}..{d}: {s}", .{ from, to, self.iterator.bytes[slice_start..iter.i] });
                return self.iterator.bytes[slice_start..iter.i];
            }
        }
        return self.iterator.bytes[slice_start..iter.i];
    }

    pub const Chunk = extern struct {
        begin: usize,
        end: usize,
    };

    /// Returns the next chunk as a `Chunk` containing the `begin` and `end` range
    pub fn nextAsChunk(self: *@This()) ?Chunk {
        const chunk_offset = self.iterator.i;
        while (self.iterator.nextCodepointSlice()) |cp| {
            var score = -self.model.base_score;
            const byte_index = self.iterator.i - cp.len;
            score += 2 * self.model.get(.UW1, self.unicodeSlice(byte_index, -3, -2));
            score += 2 * self.model.get(.UW2, self.unicodeSlice(byte_index, -2, -1));
            score += 2 * self.model.get(.UW3, self.unicodeSlice(byte_index, -1, 0));
            score += 2 * self.model.get(.UW4, self.unicodeSlice(byte_index, 0, 1));
            score += 2 * self.model.get(.UW5, self.unicodeSlice(byte_index, 1, 2));
            score += 2 * self.model.get(.UW6, self.unicodeSlice(byte_index, 2, 3));
            score += 2 * self.model.get(.BW1, self.unicodeSlice(byte_index, -2, 0));
            score += 2 * self.model.get(.BW2, self.unicodeSlice(byte_index, -1, 1));
            score += 2 * self.model.get(.BW3, self.unicodeSlice(byte_index, 0, 2));
            score += 2 * self.model.get(.TW1, self.unicodeSlice(byte_index, -3, 0));
            score += 2 * self.model.get(.TW2, self.unicodeSlice(byte_index, -2, 1));
            score += 2 * self.model.get(.TW3, self.unicodeSlice(byte_index, -1, 2));
            score += 2 * self.model.get(.TW4, self.unicodeSlice(byte_index, 0, 3));

            self.unicode_index += 1;
            const cpy = self.history;
            @memcpy(self.history[1..self.history.len], cpy[0 .. self.history.len - 1]);
            self.history[0] = self.iterator.i;

            debug("{s}, {d}", .{ self.iterator.bytes[chunk_offset..self.iterator.i], score });

            if (score > 0) {
                return .{ .begin = chunk_offset, .end = self.iterator.i };
            }
        }
        // Always return the last chunk
        if (chunk_offset != self.iterator.i) {
            return .{ .begin = chunk_offset, .end = self.iterator.i };
        }
        return null;
    }

    /// Returns the next chunk as a slice
    pub fn next(self: *@This()) ?[]const u8 {
        if (self.nextAsChunk()) |chunk| return self.iterator.bytes[chunk.begin..chunk.end];
        return null;
    }
};

test "ja" {
    const allocator = std.testing.allocator;
    var model = try Model.init(allocator, .ja);
    defer model.deinit(allocator);

    {
        var iter = model.iterator("今日は天気です。");
        try std.testing.expectEqualSlices(u8, "今日は", iter.next().?);
        try std.testing.expectEqualSlices(u8, "天気です。", iter.next().?);
    }

    const tests = [_][]const u8{
        "今日は_とても_良い_天気です。",
        "これ以上_利用する_場合は_教えてください。",
        "食器は_そのまま_入れて_大丈夫です。",
        "ダウンロード_ありがとう_ございます。",
        "ご利用_ありがとう_ございました。",
        "要点を_まとめる_必要が_ある。",
        "目指すのは_あらゆる_人に_便利な_ソフトウェア",
        "商品が_まもなく_到着します。",
        "プロジェクトが_ようやく_日の_目を_見る。",
        "明け方に_ようやく_目覚めると、",
        "明け方_ようやく_目覚めると、",
        "これは_たまたま_見つけた_宝物",
        "歩いていて_たまたま_目に_入った_光景",
        "あなたの_意図した_とおりに_情報を_伝える。",
        "あの_イーハトーヴォの_すきとおった_風、_夏でも_底に_冷たさを_もつ_青い_そら、_うつくしい_森で_飾られた_モリーオ市、_郊外の_ぎらぎら_ひかる_草の_波。",
        "購入された_お客様のみ_入れます。",
        "購入された_お客様のみ_入場できます。",
        "パワーのみ_有効だ",
        // These are for newer models (tracking git budoux)
        // "小さな_つぶや_空気中の_ちり",
        // "光が_どんどん_空_いっぱいに_広がる",
        // "太陽の_位置が_ちがうから",
        // "太陽が_しずむころに_帰る",
        // "多すぎると_うまく_いかない",
        // "世界の_子どもの_命や_権利",
        // "「ふだん_どおり」を_保つ",
        // "おもちゃや_遊びに_使える",
        // "コントロールできない_ほど_感情移入してしまう",
        // "いつも_甘えがちに_なる",
        // "存在が_浮かび_上がった。",
    };

    inline for (tests) |tst| {
        @setEvalBranchQuota(100000);
        const sz = comptime std.mem.replacementSize(u8, tst, "_", "");
        var buf: [sz]u8 = undefined;
        _ = std.mem.replace(u8, tst, "_", "", &buf);
        var iter = model.iterator(buf[0..]);
        var toks = std.mem.tokenizeScalar(u8, tst, '_');
        while (true) {
            const a, const b = .{ iter.next(), toks.next() };
            if (a == null and b == null) break;
            if (a == null or b == null) return error.BoundaryMismatch;
            debug("{s} == {s}", .{ a.?, b.? });
            try std.testing.expectEqualSlices(u8, a.?, b.?);
        }
    }
}

test "ja-knbc" {
    const allocator = std.testing.allocator;
    var model = try Model.init(allocator, .ja_knbc);
    defer model.deinit(allocator);
    var iter = model.iterator("今日は天気です。");
    try std.testing.expectEqualSlices(u8, "今日は", iter.next().?);
    try std.testing.expectEqualSlices(u8, "天気です。", iter.next().?);
}

test "th" {
    const allocator = std.testing.allocator;
    var model = try Model.init(allocator, .th);
    defer model.deinit(allocator);
    var iter = model.iterator("วันนี้อากาศดี");
    try std.testing.expectEqualSlices(u8, "วัน", iter.next().?);
    try std.testing.expectEqualSlices(u8, "นี้", iter.next().?);
    try std.testing.expectEqualSlices(u8, "อากาศ", iter.next().?);
    try std.testing.expectEqualSlices(u8, "ดี", iter.next().?);
}

test "zh-hans" {
    const allocator = std.testing.allocator;
    var model = try Model.init(allocator, .zh_hans);
    defer model.deinit(allocator);
    var iter = model.iterator("今天是晴天。");
    try std.testing.expectEqualSlices(u8, "今天", iter.next().?);
    try std.testing.expectEqualSlices(u8, "是", iter.next().?);
    try std.testing.expectEqualSlices(u8, "晴天。", iter.next().?);
}

test "zh-hant" {
    const allocator = std.testing.allocator;
    var model = try Model.init(allocator, .zh_hant);
    defer model.deinit(allocator);
    var iter = model.iterator("今天是晴天。");
    try std.testing.expectEqualSlices(u8, "今天", iter.next().?);
    try std.testing.expectEqualSlices(u8, "是", iter.next().?);
    try std.testing.expectEqualSlices(u8, "晴天。", iter.next().?);
}
