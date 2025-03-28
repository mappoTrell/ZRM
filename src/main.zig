const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;

const VM = @import("vm.zig");
const Module = @import("Module.zig");
const Process = @import("Process.zig");
const queue = @import("queue.zig");

const parser = @import("parser.zig");

var instr: [1024]VM.Word = undefined;

var as: u64 align(32) = 45;
var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
pub fn main() !void {
    _ = Module;
    _ = parser.functions_names;
    const y = queue.Queue(u64, 4);
    const t = y.Buffer.Adress{ .index = 3, .pointer = 5 };

    as += 4;
    std.debug.print("t:{b}\n", .{(t.to_u64())});
    std.debug.print("t:{}\n", .{@ctz(t.to_u64())});

    std.debug.print("\n", .{});
    const gpa, const is_debug = gpa: {
        if (builtin.target.os.tag == .wasi) break :gpa .{ std.heap.wasm_allocator, false };
        break :gpa switch (builtin.mode) {
            .Debug, .ReleaseSafe => .{ debug_allocator.allocator(), true },
            .ReleaseFast, .ReleaseSmall => .{ std.heap.smp_allocator, false },
        };
    };
    defer if (is_debug) {
        _ = debug_allocator.deinit();
    };
    // std.debug.print("{}\n", .{vm.proc_queue.get_consumer().?.refc.raw});
    var proc: Process = .new;
    proc.iptr = instr[0..];
    // VM.loadProcess(&proc);

    try VM.init(gpa);
    defer VM.deinit();
    // var yy: y = try .init(debug_alloc.allocator());
    // for (0..513) |i| {
    //     //std.debug.print("\n it:{}\n", .{i});
    //     try yy.push(i);
    // }
    // for (0..531) |_| {
    //     _ = yy.pop();
    // }

    proc.reg_x[0] = VM.Word{ .w_type = .Int, .data = 1 };
    proc.reg_x[1] = VM.createWord(f32, 20).?;
    proc.reg_x[3] = VM.createWord(f32, 80).?;

    instr[0] = VM.createWord(VM.instr_t, &VM.math(.add)).?;
    std.debug.print("{b}\n", .{instr[0].to_u64()});
    instr[1] = VM.createWord(VM.Reg_Loc, VM.Reg_Loc{ .reg = .x, .addr = 0 }).?;
    std.debug.print("{b}\n", .{instr[1].to_u64()});
    instr[2] = VM.createWord(VM.Reg_Loc, VM.Reg_Loc{ .reg = .x, .addr = 1 }).?;
    instr[3] = VM.createWord(VM.Reg_Loc, VM.Reg_Loc{ .reg = .x, .addr = 1 }).?;
    std.debug.print("{b}\n", .{instr[3].to_u64()});

    instr[4] = VM.createWord(VM.instr_t, &VM.move).?;

    instr[5] = VM.createWord(VM.Reg_Loc, VM.Reg_Loc{ .reg = .x, .addr = 1 }).?;
    instr[6] = VM.createWord(VM.Reg_Loc, VM.Reg_Loc{ .reg = .x, .addr = 4 }).?;

    instr[7] = VM.createWord(VM.instr_t, &VM.comp(.gt)).?;
    instr[8] = VM.createWord(VM.Reg_Loc, VM.Reg_Loc{ .reg = .x, .addr = 1 }).?;
    instr[9] = VM.createWord(VM.Reg_Loc, VM.Reg_Loc{ .reg = .x, .addr = 3 }).?;
    instr[10] = VM.Word{ .w_type = .Instr_ptr, .data = @intCast(@intFromPtr(&instr[0])) };
    instr[11] = VM.createWord(VM.instr_t, &VM.end).?;

    // VM.call_I();
    // const t: u32 = @intCast(instr[4]);
    // @as(*fn () void, @ptrFromInt(t))();

    try VM.schedule_process(&proc);
    //std.debug.print("{d}\n", .{@bitSizeOf(Word2)});

    //finished = false;

    // const p = Word2{ .int = 10 };
    // _ = p;

    // reg_x[0] = 0;

    // reg_x[3] = 4;
    // reg_y[4] = 5;

    // const x: f32 = 20.5;

    // const tr: i56 = std.math.minInt(i56);

    // const hg = x + tr;
    // const y: u56 = @intCast(@as(u32, @bitCast(x)));

    // const z: f32 = @bitCast(@as(u32, @truncate(y)));

    // _ = z;

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
    std.time.sleep(std.time.ns_per_s * 5);

    const x: VM.Word = proc.reg_x[4];

    std.debug.print("{},{d}\n", .{ x.w_type, x.getFloat().? });
}

test "simple test" {
    _ = parser;
    var list = std.ArrayList(i32).init(std.testing.allocator);

    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
