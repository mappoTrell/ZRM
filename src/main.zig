const std = @import("std");

var instr: [1024]usize = undefined;

const i_ptr: usize = 0;

const reg = enum(u32) { x, y };

const reg_loc = packed struct(usize) {
    reg: reg,
    addr: u32,
};

fn call_I() void {
    @as(*fn () void, @ptrFromInt(instr[i_ptr]))();
}

fn add() void {}

var reg_x: [32]usize = undefined;

pub fn main() !void {
    const i = &add;

    const t = @intFromPtr(i);

    instr[i_ptr] = t;
    call_I();
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
