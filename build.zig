const std = @import("std");

// These need to match the upstream filenames
const models = .{
    "ja",
    "ja_knbc",
    "th",
    "zh-hans",
    "zh-hant",
};

fn compressModels(b: *std.Build) ![]const u8 {
    const tmp = b.makeTempPath();
    var tmp_dir = try std.fs.openDirAbsolute(tmp, .{});
    defer tmp_dir.close();
    const budoux = b.dependency("budoux", .{});
    inline for (models) |name| {
        var arena = std.heap.ArenaAllocator.init(b.allocator);
        defer arena.deinit();

        const compressed_model = blk: {
            const model_path = std.fmt.comptimePrint("budoux/models/{s}.json", .{name});
            const path = budoux.path(model_path).getPath(b);
            var file = try std.fs.openFileAbsolute(path, .{ .mode = .read_only });
            defer file.close();
            var buf = std.ArrayList(u8).init(arena.allocator());
            try std.compress.zlib.compress(file.reader(), buf.writer(), .{
                .level = .best,
            });
            break :blk buf.items;
        };

        var file = try tmp_dir.createFile(name ++ ".z", .{});
        defer file.close();
        try file.writeAll(compressed_model);
    }
    return tmp;
}

fn addModels(b: *std.Build, mod: *std.Build.Module, dir: []const u8) !void {
    inline for (models) |name| {
        var arena = std.heap.ArenaAllocator.init(b.allocator);
        defer arena.deinit();
        const path = try std.fmt.allocPrint(arena.allocator(), "{s}/{s}.z", .{ dir, name });
        var import: [("budoux-" ++ name).len]u8 = ("budoux-" ++ name).*;
        std.mem.replaceScalar(u8, &import, '_', '-');
        mod.addAnonymousImport(import[0..], .{
            .root_source_file = .{ .path = path },
        });
    }
}

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const dir = try compressModels(b);

    const mod = b.addModule("zig-budoux", .{
        .root_source_file = .{ .path = "src/budoux.zig" },
    });
    try addModels(b, mod, dir);

    const lib = b.addStaticLibrary(.{
        .name = "budoux",
        .root_source_file = .{ .path = "src/c.zig" },
        .target = target,
        .optimize = .ReleaseFast,
        .pic = true, // to stop clang from complaining
    });
    lib.addIncludePath(.{ .path = "include" });
    lib.installHeader("include/budoux.h", "budoux.h");
    try addModels(b, &lib.root_module, dir);
    b.installArtifact(lib);

    const exe_test = b.addTest(.{
        .root_source_file = .{ .path = "src/budoux.zig" },
        .target = target,
        .optimize = optimize,
    });
    try addModels(b, &exe_test.root_module, dir);
    const run_test_exe = b.addRunArtifact(exe_test);
    const run_test = b.step("test", "Run unit tests");
    run_test.dependOn(&run_test_exe.step);

    const docs_step = b.step("docs", "Build the project documentation");

    const doc_obj = b.addObject(.{
        .name = "docs",
        .root_source_file = .{ .path = "src/budoux.zig" },
        .target = target,
        .optimize = optimize,
    });
    try addModels(b, &doc_obj.root_module, dir);

    const install_docs = b.addInstallDirectory(.{
        .source_dir = doc_obj.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = std.fmt.comptimePrint("docs/{s}", .{"zig-budoux"}),
    });

    docs_step.dependOn(&install_docs.step);
}
