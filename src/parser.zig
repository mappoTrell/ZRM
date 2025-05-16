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

    fn init(alloc: std.mem.Allocator) Term {
        return .{
            .alloc = alloc,
            .range = undefined,
        };
    }
};

const Argument = union(States) {
    list: List,
    value: Value,
    tuple: Tuple,
    idle: void,
    string: []u8,
};

const List = struct {
    elements: std.ArrayListUnmanaged(u32),
};

const Tuple = struct {
    elements: std.ArrayListUnmanaged(u32),
};

const Value = struct {
    range: []u8,
};

pub const pars_err = error{invalid};

const States = enum { value, idle, tuple, list, string };

const Pos = struct {
    arg: u32,
    state: States,
    idx: u32,
};

fn parse(inp: []u8, alloc: std.mem.Allocator) !Module {
    var mod: Module = .init(alloc);
    var state = States.idle;

    var stack = std.ArrayListUnmanaged(Pos).empty;

    var idx: u32 = 0;

    var terms = std.ArrayListUnmanaged(Term).empty;

    var last_point: u32 = 0;

    terms.append(alloc, .init(alloc));

    var current_argument: u32 = undefined;

    tok: switch (inp[idx]) {
        '"' => {
            if (state != .string) {
                stack.append(alloc, .{ .idx = idx, .state = .string });
                state = .string;
            }
            _ = stack.pop();
            state = stack.getLast().state;

            idx += 1;
            continue :tok idx;
        },
        '{' => {
            if (state != .string) {
                switch (terms.getLast().args.items[current_argument]) {
                    .list, .tuple => |*elem| {
                        .elements.append(Argument{ .tuple = .{ .elements = .empty } });
                        current_argument = elem.elements.items.len;
                    },
                    else => {
                        return error.invalid;
                    },
                }
                stack.append(alloc, .{ .idx = idx, .state = .tuple, .arg = current_argument });
                state = .tuple;
            }
            idx += 1;
            continue :tok idx;
        },
        ',' => {
            switch (state) {
                .string => {},
                .value => {
                    switch (current_argument.*) {
                        .list, .tuple => |*elem| {
                            elem.elements.append(Argument{ .value = .{ .range = inp[stack.pop().?.idx..idx] } });
                        },
                        else => {
                            return error.invalid;
                        },
                    }
                },
            }
            state = stack.getLast().state;
            idx += 1;
            continue :tok idx;
        },

        '.' => {
            if (state != .string) {
                // const sect_start = stack.pop() orelse return error.invalid;
                terms.append(alloc, .{ .alloc = alloc, .range = inp[last_point + 2 .. idx - 1] });
                last_point = idx;
                if (idx != inp.len - 1) {
                    terms.append(alloc, .init(alloc));
                    current_argument = &terms.getLast().args;
                    idx += 1;
                    continue :tok idx;
                }
                break :tok;
            }
        },
        '}' => {
            switch (state) {
                .string => {},
                .value => {
                    switch (current_argument.*) {
                        .list, .tuple => |*elem| {
                            elem.elements.append(Argument{ .value = .{ .range = inp[stack.pop().?.idx..idx] } });
                        },
                        else => {
                            return error.invalid;
                        },
                    }
                },
            }

            _ = stack.pop();
            const elem = stack.getLastOrNull();

            if (elem) |e| {
                current_argument = e.arg;
            }
            idx += 1;
            continue :tok idx;
        },
        else => {
            if (state != .string and state != .value) {
                stack.append(alloc, .{ .idx = idx, .state = .value });
                state = .value;
            }
            idx += 1;
            continue :tok idx;
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
