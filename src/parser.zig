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
    range: []const u8,
    alloc: std.mem.Allocator,
    arg_array: std.ArrayListUnmanaged(Argument) = .empty,
    arguments: std.ArrayListUnmanaged(u32) = .empty,

    fn init(alloc: std.mem.Allocator) Term {
        return .{
            .alloc = alloc,
            .range = undefined,
        };
    }
};

const States = enum { value, idle, tuple, list, string };
const Argument = union(States) {
    value: Value,
    idle: void,
    tuple: Tuple,
    list: List,
    string: []const u8,
};

const List = struct {
    elements: std.ArrayListUnmanaged(u32) = .empty,
};

const Tuple = struct {
    elements: std.ArrayListUnmanaged(u32) = .empty,
};

const Value = struct {
    range: []const u8,
};

pub const pars_err = error{invalid};

const Pos = struct {
    arg: u32,
    state: States,
    idx: u32,
};

pub fn parse(inp: []const u8, gpa: std.mem.Allocator) !Module {
    const mod: Module = try .init(gpa);
    var state = States.idle;

    var arena: std.heap.ArenaAllocator = .init(gpa);
    defer arena.deinit();
    const alloc = arena.allocator();

    var stack: std.ArrayListUnmanaged(Pos) = .empty;

    var idx: u32 = 0;

    var terms: std.ArrayListUnmanaged(Term) = .empty;

    var last_point: u32 = 0;
    var count: u32 = 0;

    var current_argument: u32 = 0;
    var current_term: Term = .{ .alloc = alloc, .range = undefined };

    std.debug.print("test\n", .{});
    tok: switch (inp[idx]) {
        ' ' => {
            idx += 1;
            continue :tok inp[idx];
        },
        '\'' => {
            if (state != .string) {
                try stack.append(alloc, Pos{ .arg = 0, .idx = idx, .state = .string });
                state = .string;
                const next: u32 = @intCast(std.mem.indexOfAny(u8, inp[idx..], "\'") orelse return error.invalid);
                idx += next;
            } else {
                idx += 1;
                _ = stack.pop();
                state = stack.getLast().state;
            }

            continue :tok inp[idx];
        },
        '{' => {
            std.debug.print("tup\n", .{});
            const tup: Argument = .{ .tuple = .{} };
            if (state == .idle) {
                try current_term.arg_array.append(alloc, tup);
                try current_term.arguments.append(alloc, @intCast(current_term.arg_array.items.len - 1));
            } else {
                try addArg(alloc, tup, &current_term, current_argument);
            }
            current_argument = count;
            count += 1;
            try stack.append(alloc, .{ .idx = idx, .state = .tuple, .arg = current_argument });
            state = .tuple;
            idx += 1;
            continue :tok inp[idx];
        },
        '[' => {
            try addArg(alloc, .{ .list = .{} }, &current_term, current_argument);

            current_argument = count;
            count += 1;
            try stack.append(alloc, .{ .idx = idx, .state = .list, .arg = current_argument });
            state = .list;
            idx += 1;
            continue :tok inp[idx];
        },
        ',' => {
            switch (state) {
                .value => {
                    const arg = stack.pop() orelse return error.invalid;
                    current_argument = stack.getLast().arg;
                    std.debug.print("{any}", .{stack.items});

                    try addArg(alloc, .{ .value = .{ .range = inp[arg.idx..idx] } }, &current_term, current_argument);
                    count += 1;
                },
                else => {},
            }
            state = stack.getLast().state;
            idx += 1;
            continue :tok inp[idx];
        },

        '.' => {
            // const sect_start = stack.pop() orelse return error.invalid;

            std.debug.print("point\n", .{});
            if (stack.pop()) |arg| {
                std.debug.print("{}\n", .{arg});
                if (arg.state != .value) return error.invalid;
                try current_term.arg_array.append(alloc, Argument{ .value = .{ .range = inp[arg.idx..idx] } });
                try current_term.arguments.append(alloc, @intCast(current_term.arg_array.items.len - 1));
            }
            current_term.range = inp[last_point..idx];
            try terms.append(alloc, current_term);
            last_point = idx + 2;
            if (idx != inp.len - 1) {
                idx += 2;
                count = 0;
                current_argument = 0;
                state = .idle;
                current_term = .{ .alloc = alloc, .range = undefined };
                continue :tok inp[idx];
            }
            break :tok;
        },
        ']' => {
            switch (state) {
                .string => {},
                .value => {
                    const arg = stack.pop() orelse return error.invalid;
                    current_argument = stack.getLast().arg;
                    try addArg(alloc, .{ .value = .{ .range = inp[arg.idx..idx] } }, &current_term, current_argument);
                    count += 1;
                },
                else => {},
            }

            const start = stack.pop() orelse return error.invalid;
            if (start.state != .list) return error.invalid;
            const elem = stack.getLastOrNull();

            if (elem) |e| {
                current_argument = e.arg;
                state = e.state;
            }
            idx += 1;
            continue :tok inp[idx];
        },
        '}' => {
            std.debug.print("{any}\n", .{inp[idx]});
            switch (state) {
                .string => {},
                .value => {
                    std.debug.print("{}\n", .{stack.items.len});
                    const arg = stack.pop() orelse return error.invalid;
                    current_argument = stack.getLast().arg;
                    try addArg(alloc, .{ .value = .{ .range = inp[arg.idx..idx] } }, &current_term, current_argument);
                    count += 1;
                },
                else => {},
            }

            const start = stack.pop() orelse return error.invalid;
            if (start.state != .tuple) return error.invalid;
            const elem = stack.getLastOrNull();

            std.debug.print("{}\n", .{stack.items.len});
            if (elem) |e| {
                current_argument = e.arg;
                std.debug.print("{any}", .{e});
                state = e.state;
            }
            idx += 1;
            continue :tok inp[idx];
        },
        else => {
            // std.debug.print("test\n", .{});
            if (state != .value) {
                std.debug.print("test\n", .{});
                try stack.append(alloc, .{ .arg = 0, .idx = idx, .state = .value });
                state = .value;
            }
            const next: u32 = @intCast(std.mem.indexOfAny(u8, inp[idx..], "{}[],\".") orelse return error.invalid);
            std.debug.print("{any}\n", .{inp[idx]});
            idx += next;
            continue :tok inp[idx];
        },
    }
    return mod;
}

fn addArg(alloc: std.mem.Allocator, argument: Argument, term: *Term, c_arg: u32) !void {
    try term.arg_array.append(alloc, argument);
    std.debug.print("{any}", .{term.arg_array.items[c_arg]});
    switch (term.arg_array.items[c_arg]) {
        inline .list, .tuple => |*elem| {
            try elem.elements.append(alloc, @intCast(term.arg_array.items.len - 1));
        },
        else => {
            return error.invalid;
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
    // _ = test_string;

    std.debug.print("test\n", .{});
    try std.testing.expect(.@"return" == std.meta.stringToEnum(functions_names, "return"));
    _ = try parse(test_string[0..], std.testing.allocator);
}
