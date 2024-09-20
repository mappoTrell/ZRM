const std = @import("std");

var instr: [1024]usize = undefined;

var i_ptr: [*]usize = instr[0..];

const reg = enum(u32) { x, y };

const reg_loc = packed struct(usize) {
    reg: reg,
    addr: u32,
};

fn call_I() void {
    @as(*fn () void, @ptrFromInt(i_ptr[0]))();
}

fn add() void {
    const val1 = reg_val(@bitCast(i_ptr[1])).*;
    const val2 = reg_val(@bitCast(i_ptr[2])).*;
    reg_val(@bitCast(i_ptr[3])).* = val1 + val2;

    i_ptr += 4;
}

fn end() void {
    std.debug.print("end\n", .{});
    finished = true;
}

fn reg_val(loc: reg_loc) *usize {
    return switch (loc.reg) {
        .x => &reg_x[loc.addr],
        .y => &reg_y[loc.addr],
    };
}

var reg_x: [32]usize = undefined;
var reg_y: [32]usize = undefined;

var finished = false;

pub fn main() !void {
    instr[0] = @intFromPtr(&add);
    instr[4] = @intFromPtr(&end);

    const t: u32 = @intCast(instr[4]);

    @as(*fn () void, @ptrFromInt(t))();

    //finished = false;

    reg_x[0] = 0;

    reg_x[3] = 4;
    reg_y[4] = 5;

    var x3 = reg_loc{ .reg = .x, .addr = 3 };
    instr[1] = @bitCast(x3);

    x3.addr = 4;
    x3.reg = .y;
    instr[2] = @bitCast(x3);

    x3.addr = 0;
    x3.reg = .x;
    instr[3] = @bitCast(x3);

    while (!finished) {
        call_I();
    }

    std.debug.print("{d}\n", .{reg_x[0]});
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
