const std = @import("std");
const assert = std.debug.assert;

const queue = @import("queue.zig");

const VM = @import("vm.zig");
const Process = @This();

iptr: [*]VM.Word,
reg_x: [32]VM.Word,
reg_y: [32]VM.Word,

pub const new = Process{
    .iptr = undefined,
    .reg_x = undefined,
    .reg_y = undefined,
};
