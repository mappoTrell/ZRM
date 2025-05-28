const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;

const VM = @import("vm.zig");
const Process = @import("Process.zig");
const queue = @import("queue.zig");

const Word = VM.Word;

const Module = @This();

const Function = struct {
    arity: u32,
    label: u32,
};

arena: *std.heap.ArenaAllocator,
alloc: std.mem.Allocator,
name: []u8,
instr: []Word,

labels: [][*]Word,

functions: std.StringHashMapUnmanaged(Function),

pub fn init(alloc: std.mem.Allocator) !Module {
    var arena = try alloc.create(std.heap.ArenaAllocator);
    arena.* = .init(alloc);
    return Module{
        .arena = arena,
        .alloc = arena.allocator(),
        .functions = .empty,
        .labels = undefined,
        .name = undefined,
        .instr = undefined,
    };
}
