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
fn parse() !Module {}

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
