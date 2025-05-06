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

const Term = struct {
    range: []u8,
    alloc: std.mem.Allocator,
    args: std.ArrayListUnmanaged(Argument) = .empty,
};

const Argument = struct {
    range: []u8,
};

pub const pars_err = error{invalid};

fn parse(inp: []u8, alloc: std.mem.Allocator) !Module {
    var mod: Module = .init(alloc);

    var stack = std.ArrayListUnmanaged(u32).empty;

    var idx: u32 = 0;

    var not_in_string: bool = false;

    var terms = std.ArrayListUnmanaged(Term).empty;

    var last_point: u32 = 0;

    tok: switch (inp[idx]) {
        '"' => {
            not_in_string = -not_in_string;
            continue :tok idx + 1;
        },
        '{' => {
            if (not_in_string) stack.append(alloc, idx);
            continue :tok idx + 1;
        },
        '.' => {
            if (not_in_string) {
                // const sect_start = stack.pop() orelse return error.invalid;
                terms.append(alloc, .{ .alloc = alloc, .range = inp[last_point + 2 .. idx - 1] });
                last_point = idx;
                if (idx != inp.len - 1) continue :tok idx + 1;
                break :tok;
            }
        },
    }
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
