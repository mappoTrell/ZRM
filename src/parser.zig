const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;

const Module = @import("Module.zig");
const VM = @import("vm.zig");
const Process = @import("Process.zig");
const queue = @import("queue.zig");

const input = @embedFile("genop.tab");

const Word = VM.Word;

const keywords = enum {};

pub const functions_names = @import("function_table").Function_Table;

pub const function_table: [256]*const fn () void = blk: {
    var table: [256]*const fn () void = 256 ** &VM.not_implemented();
    table[19] = &VM.return_fn();
    break :blk table;
};

const Node = struct {
    range: []u8,
    children: []Node,
};

pub const pars_err = error{invalid};

fn parse(inp: []u8, alloc: std.mem.Allocator) !Module {
    var mod: Module = .init(alloc);

    var stack = std.ArrayListUnmanaged(u8).empty;

    var char: u8 = std.mem.indexOfAny(u8, inp, "{}\"") orelse return pars_err.invalid;

    tok: switch (char) {}
}

test {
    const test_string =
        \\{labels, 2}.
        \\{function, square, 1, 2}.
        \\  {label,1}.
        \\    {func_info,{atom,square},{atom,square},1}.
        \\  {label,2}.
        \\    {gc_bif,'*',{f,0},1,[{x,0},{x,0}],{x,0}}.
        \\    return.
    ;
    _ = test_string;
    try std.testing.expect(.@"return" == std.meta.stringToEnum(functions_names, "return"));
}
