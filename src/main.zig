const std = @import("std");

const assert = std.debug.assert;

var instr: [1024]u64 = undefined;

const instr_t = *const fn () void;

var i_ptr: [*]u64 = instr[0..];

const reg = enum(u24) { x, y };

const d_type = enum(u8) { Instr, Int, Float, Reg, Instr_ptr, NOOP };

const Reg_Loc = packed struct(u56) {
    reg: reg,
    addr: u32,
};

const Word = packed struct(u64) {
    w_type: d_type,
    data: u56,

    fn getFloat(Self: Word) ?f32 {
        if (Self.w_type != .Float) return null;
        return (@bitCast(@as(u32, @truncate(Self.data))));
    }

    fn getInt(Self: Word) ?i56 {
        if (Self.w_type != .Int) return null;
        return (@bitCast(Self.data));
    }

    fn fromInstrPtr(arg_ptr: [*]u64) Word {
        const data: u56 = @intFromPtr(arg_ptr);
        return .{ .data = data, .w_type = .Instr_ptr };
    }
};

fn call_I() void {
    const word: Word = @bitCast(i_ptr[0]);
    assert(word.w_type == .Instr);
    @as(*fn () void, @ptrFromInt(word.data))();
}

fn createWord(comptime T: type, data: T) ?Word {
    var word: Word = undefined;
    switch (T) {
        instr_t => {
            word.w_type = .Instr;
            word.data = @intCast(@intFromPtr(data));
        },
        Reg_Loc => {
            word.w_type = .Reg;
            word.data = @bitCast(data);
        },
        else => {
            return null;
        },
    }
    return word;
}

const m_ops = enum { add, sub, div, mul };

const add = math(.add);
const sub = math(.sub);
const div = math(.div);
const mul = math(.mul);

fn math(comptime op: m_ops) fn () void {
    const math_t = struct {
        inline fn ops(comptime T: type, a: T, b: T) T {
            if (ops == .div) {
                assert(b != 0);
            }

            if (T == i56) {
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
            const r1: *u64 = reg_val(@bitCast(i_ptr[1])).?;
            const r2: *u64 = reg_val(@bitCast(i_ptr[2])).?;
            const r3: *u64 = reg_val(@bitCast(i_ptr[3])).?;

            const x: Word = @bitCast(r1.*);
            const y: Word = @bitCast(r2.*);

            const xi = x.getInt();
            const xf = x.getFloat();

            const yi = y.getInt();
            const yf = y.getFloat();

            const res_type: d_type = if (x.w_type == .Float or y.w_type == .Float) .Float else .Int;

            const res: u56 = switch (res_type) {
                .Float => @intCast(@as(u32, @bitCast(@This().ops(f32, (xf orelse @floatFromInt(xi.?)), (yf orelse @floatFromInt(yi.?)))))),
                .Int => @bitCast(@This().ops(i56, x, y)),
            };

            r3.* = @bitCast(Word{ .w_type = res_type, .data = res });

            i_ptr += 4;
        }
    };

    return math_t.operation();
}

fn end() void {
    std.debug.print("end\n", .{});
    finished = true;
}

fn reg_val(w: Word) ?*u64 {
    if (w.w_type != .Reg) return null;

    const loc: Reg_Loc = @bitCast(w.data);

    return switch (loc.reg) {
        .x => &reg_x[loc.addr],
        .y => &reg_y[loc.addr],
    };
}

var reg_x: [32]u64 = undefined;
var reg_y: [32]u64 = undefined;
var y_ptr: u64 = 0;

var finished = false;

fn alloc_stack() void {
    const arg1: Word = @bitCast(i_ptr[1]);
    var x = arg1.getInt() orelse 0;
    x = @max(x, 0);
    y_ptr += x;

    i_ptr += 1;
}

fn move() void {
    const arg1: Word = @bitCast(i_ptr[1]);
    const arg2: Word = @bitCast(i_ptr[2]);

    const wrd_op = reg_val(arg1);

    const val: Word = if (wrd_op) |i| @bitCast(i.*) else arg1;

    const tar = reg_val(arg2).?;

    tar.* = @bitCast(val);
}

fn dealloc_stack() void {
    const arg1: Word = @bitCast(i_ptr[1]);
    var x = arg1.getInt() orelse 0;
    x = @max(x, 0);
    y_ptr -= x;

    i_ptr += 1;
}

fn call_fn() void {
    const arg1: Word = @bitCast(i_ptr[1]);
    assert(arg1.w_type == .Instr_ptr);
    reg_y[y_ptr] = @bitCast(Word.fromInstrPtr(i_ptr + 2));
    i_ptr = @ptrFromInt(arg1.data);
}

fn return_fn() void {
    const ret: Word = @bitCast(reg_y[y_ptr]);
    assert(ret.w_type == .Instr_ptr);
    i_ptr = @ptrFromInt(ret.data);
    reg_y[y_ptr] = .{ .w_type = .NOOP, .data = undefined };
}

pub fn main() !void {
    // instr[0] = @intFromPtr(&add);
    // instr[4] = @intFromPtr(&end);
    // const t: u32 = @intCast(instr[4]);

    // @as(*fn () void, @ptrFromInt(t))();

    //std.debug.print("{d}\n", .{@bitSizeOf(Word2)});

    //finished = false;

    // const p = Word2{ .int = 10 };
    // _ = p;

    reg_x[0] = 0;

    reg_x[3] = 4;
    reg_y[4] = 5;

    const x: f32 = 20.5;

    const tr: i56 = std.math.minInt(i56);

    const hg = x + tr;

    const y: u56 = @intCast(@as(u32, @bitCast(x)));

    const z: f32 = @bitCast(@as(u32, @truncate(y)));

    _ = z;

    //_ = createWord(instr_t, &add);

    // var x3 = Reg_Loc{ .reg = .x, .addr = 3 };
    // instr[1] = @bitCast(x3);

    // x3.addr = 4;
    // x3.reg = .y;
    // instr[2] = @bitCast(x3);

    // x3.addr = 0;
    // x3.reg = .x;
    // instr[3] = @bitCast(x3);

    // while (!finished) {
    //     call_I();
    // }

    // const a: u56 = 20;
    // const b: f32 = 30.5;

    // const y = add_I(.Float, a, b) orelse return;

    std.debug.print("{},{d}\n", .{ @TypeOf(hg), hg });
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);

    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
