const std = @import("std");
const assert = std.debug.assert;
const Process = @import("Process.zig");
const queue = @import("queue.zig");
const VM_Pool = @import("VM_Pool.zig");

pub var vm_pool: VM_Pool = undefined;

const VM = @This();
_: void align(std.atomic.cache_line) = {},
pub threadlocal var current_process: ?*Process = null;
pub threadlocal var i_ptr: *[*]Word = undefined;
pub threadlocal var reg_x: *[32]Word = undefined;
pub threadlocal var reg_y: *[32]Word = undefined;
pub threadlocal var y_ptr: Word = 0;
pub threadlocal var finished = false;
var alloc: std.mem.Allocator = undefined;

threadlocal var current_reductions: u64 = 0;
const max_reductions: u64 = 1;

// proc_queue: queue.Queue(*Process, 6),

pub const instr_t = *const fn () void;

pub const reg = enum(u29) { x, y };

pub const d_type = enum(u3) { Instr, Int, Float, Reg, Instr_ptr, NOOP };

pub const Reg_Loc = packed struct(u61) {
    reg: reg,
    addr: u32,
};
pub const Word = packed struct(u64) {
    w_type: d_type,
    data: u61,

    pub fn getFloat(Self: Word) ?f32 {
        if (Self.w_type != .Float) return null;
        return (@bitCast(@as(u32, @truncate(Self.data))));
    }

    pub fn getInt(Self: Word) ?i61 {
        if (Self.w_type != .Int) return null;
        return (@bitCast(Self.data));
    }

    pub fn fromInstrPtr(arg_ptr: [*]Word) Word {
        const data: u61 = @intFromPtr(arg_ptr);
        return .{ .data = data, .w_type = .Instr_ptr };
    }

    pub fn to_u64(Self: Word) u64 {
        return @bitCast(Self);
    }
};

pub fn call_I() void {
    if (current_reductions >= max_reductions) {
        std.debug.print("red_count\n", .{});
        current_reductions = 0;
        return;
    }
    std.debug.print("red_count:{}\n", .{current_reductions});

    current_reductions += 1;
    const word: Word = i_ptr.*[0];
    assert(word.w_type == .Instr);
    @call(.always_tail, @as(*fn () void, @ptrFromInt(word.to_u64())), .{});
}

pub fn createWord(T: type, data: T) ?Word {
    var word: Word = undefined;
    switch (T) {
        instr_t => {
            // word.w_type = .Instr;
            // word.data = @intCast(@intFromPtr(data));
            word = @bitCast(@intFromPtr(data));
            // word.w_type = .Instr;
        },
        Reg_Loc => {
            word.w_type = .Reg;
            word.data = @bitCast(data);
        },
        f32 => {
            word.w_type = .Float;
            word.data = @intCast(@as(u32, @bitCast(data)));
        },

        else => {
            return null;
        },
    }
    return word;
}

pub const m_ops = enum { add, sub, div, mul };

pub const add = math(.add);
pub const sub = math(.sub);
pub const div = math(.div);
pub const mul = math(.mul);

pub fn math(comptime op: m_ops) fn () void {
    const math_t = struct {
        inline fn ops(comptime T: type, a: T, b: T) T {
            if (op == .div) {
                assert(b != 0);
            }

            if (T == i61) {
                return switch (op) {
                    .add => a +% b,
                    .sub => a -% b,
                    .mul => a *% b,
                    .div => @divTrunc(a, b),
                };
            } else {
                return switch (op) {
                    .add => a + b,
                    .sub => a - b,
                    .mul => a * b,
                    .div => a / b,
                };
            }
        }

        fn operation() void {
            const r1: *Word = reg_val(i_ptr.*[1]).?;
            const r2: *Word = reg_val(i_ptr.*[2]).?;
            const r3: *Word = reg_val(i_ptr.*[3]).?;

            const x: Word = r1.*;
            const y: Word = r2.*;

            const xi = x.getInt();
            const xf = x.getFloat();

            const yi = y.getInt();
            const yf = y.getFloat();

            const res_type: d_type = if (x.w_type == .Float or y.w_type == .Float) .Float else .Int;

            const res: u61 = switch (res_type) {
                .Float => @intCast(@as(u32, @bitCast(@This().ops(f32, (xf orelse @floatFromInt(xi.?)), (yf orelse @floatFromInt(yi.?)))))),
                .Int => @bitCast(@This().ops(i61, xi.?, yi.?)),
                else => unreachable,
            };

            r3.* = Word{ .w_type = res_type, .data = res };

            i_ptr.* += 4;
            @call(.always_inline, call_I, .{});
        }
    };

    return math_t.operation;
}

pub fn comp(comptime op: std.math.CompareOperator) fn () void {
    return struct {
        fn operation() void {
            const r1: *Word = reg_val(i_ptr.*[1]).?;
            const r2: *Word = reg_val(i_ptr.*[2]).?;

            if (std.math.compare(r1.data, op, r2.data)) {
                i_ptr.* += 4;
                @call(.always_inline, call_I, .{});
            } else {
                const r3: Word = i_ptr.*[3];
                assert(r3.w_type == .Instr_ptr);
                i_ptr.* = @ptrFromInt(r3.data);
            }
        }
    }.operation;
}

pub fn end() void {
    std.debug.print("end\n", .{});
    finished = true;
    return;
}

pub fn reg_val(w: Word) ?*Word {
    if (w.w_type != .Reg) return null;

    const loc: Reg_Loc = @bitCast(w.data);

    return switch (loc.reg) {
        .x => &reg_x[loc.addr],
        .y => &reg_y[loc.addr],
    };
}

pub fn alloc_stack() void {
    const arg1: Word = i_ptr.*[1];
    var x = arg1.getInt() orelse 0;
    x = @max(x, 0);
    y_ptr += x;

    i_ptr.* += 1;

    @call(.always_inline, call_I, .{});
}

pub fn move() void {
    const arg1: Word = i_ptr.*[1];
    const arg2: Word = i_ptr.*[2];
    const wrd_op = reg_val(arg1);

    const val: Word = if (wrd_op) |i| i.* else arg1;

    const tar = reg_val(arg2).?;

    tar.* = val;

    i_ptr.* += 3;

    @call(.always_inline, call_I, .{});
}

pub fn dealloc_stack() void {
    const arg1: Word = i_ptr.*[1];
    var x = arg1.getInt() orelse 0;
    x = @max(x, 0);
    y_ptr -= x;

    i_ptr.* += 1;
}

pub fn call_fn() void {
    const arg1: Word = i_ptr.*[1];
    assert(arg1.w_type == .Instr_ptr);
    reg_y[y_ptr] = Word.fromInstrPtr(i_ptr.* + 2);
    i_ptr.* = @ptrFromInt(arg1.data);
}

pub fn return_fn() void {
    const ret: Word = reg_y[y_ptr];
    assert(ret.w_type == .Instr_ptr);
    i_ptr.* = @ptrFromInt(ret.data);
    reg_y[y_ptr] = .{ .w_type = .NOOP, .data = undefined };
}

///test
pub fn loadProcess(proc: *Process) void {
    current_process = proc;
    i_ptr = &proc.iptr;
    reg_x = &proc.reg_x;
    reg_y = &proc.reg_y;
}

pub fn run(proc_t: *VM_Pool.Task) !void {
    loadProcess(proc_t.process);
    current_reductions = 0;
    finished = false;
    std.debug.print("test", .{});
    call_I();
    if (!finished) {
        vm_pool.schedule(VM_Pool.Batch.from(proc_t));
        return;
    }
    alloc.destroy(proc_t);
}

pub fn schedule_process(proc: *Process) !void {
    try vm_pool.schedule_process(proc, alloc);
}

pub fn init(n_alloc: std.mem.Allocator) !void {
    vm_pool = .init(.{ .max_threads = 3 });
    alloc = n_alloc;
}

pub fn deinit() void {
    vm_pool.shutdown();
    vm_pool.deinit();
}
