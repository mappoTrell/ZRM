const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;

const input = @embedFile("genop.tab");

fn createFnEnum(comptime in: [:0]const u8, file: std.fs.File) !void {
    // @compileError(in);
    var tokenizer = std.mem.tokenizeScalar(u8, in[0 .. in.len - 1], '\n');
    var buf: [100]u8 = undefined;
    while (tokenizer.next()) |line| {
        // @compileLog(fields);
        if (!std.ascii.isDigit(line[0])) {
            continue;
        }
        const idx1 = std.mem.indexOf(u8, line, ":") orelse continue;

        const idx2 = std.mem.indexOf(u8, line, "/") orelse continue;

        if (line[idx1 + 2] == '-') continue;

        const num = try std.fmt.parseUnsigned(u8, line[0..idx1], 10);
        var p_line: []u8 = undefined;
        p_line = try std.fmt.bufPrint(buf[0..], "{s} = {d},\n", .{ line[idx1 + 2 .. idx2], num });
        if (std.mem.eql(u8, line[idx1 + 2 .. idx2], "return") or std.mem.eql(u8, line[idx1 + 2 .. idx2], "catch") or std.mem.eql(u8, line[idx1 + 2 .. idx2], "try")) {
            p_line = try std.fmt.bufPrint(buf[0..], "@\"{s}\" = {d},\n", .{ line[idx1 + 2 .. idx2], num });
        }
        std.debug.print("{s}", .{p_line});
        try file.writeAll(p_line);

        // @compileError(fields);
    }
}

pub fn main() !void {
    var arena_state = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const args = try std.process.argsAlloc(arena);

    if (args.len != 2) fatal("wrong number of arguments", .{});

    const output_file_path = args[1];
    var output_file = std.fs.cwd().createFile(output_file_path, .{}) catch |err| {
        fatal("unable to open '{s}': {s}", .{ output_file_path, @errorName(err) });
    };
    defer output_file.close();

    try output_file.writeAll(
        \\pub const Function_Table = enum(u8) {
    );
    try createFnEnum(input, output_file);
    try output_file.writeAll("};");
    return std.process.cleanExit();
}
fn fatal(comptime format: []const u8, args: anytype) noreturn {
    std.debug.print(format, args);
    std.process.exit(1);
}
