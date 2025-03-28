const std = @import("std");
const Type = std.builtin.Type;
const aValue = std.atomic.Value;

fn Slot(T: type) type {
    return struct {
        const Self = @This();

        data: T,
        ready: aValue(bool) = .init(false),

        fn read(self: Self) ?T {
            if (!self.ready.load(.acquire)) {
                return null;
            }
            return self.data;
        }

        fn write(self: *Self, data: T) void {
            self.data = data;
            self.ready.store(true, .release);
        }
    };
}

// fn Adress( , comptime size: u8) type {
//     const s_info = @typeInfo(size);
//     const p_type = switch (s_info) {
//         .Int => |integer| {
//             const bits = integer.bits;
//             Type.Int{ .bits = 64 - bits, .signedness = .unsigned };
//         },
//         else => @compileError("wrong type"),
//     };

//     return packed struct(u64) {
//         pointer: p_type,
//         index: size,

//         fn get_pointer(self: @This()) Buffer(T: type, comptime size: u64){}
//     };
// }

pub fn Queue(T: type, comptime align_log: u64) type {
    const size = align_log - 1;

    const size_type = std.meta.Int(.unsigned, align_log);
    const p_type = std.meta.Int(.unsigned, 64 - align_log);
    const align_size: u64 = 0b1 << align_log;

    return struct {
        const Self = @This();

        pub const Buffer = struct {
            const array_size: u64 = 0b1 << size;

            pub const Adress = packed struct(u64) {
                index: size_type,
                pointer: p_type,
                pub fn to_u64(self: Adress) u64 {
                    return @bitCast(self);
                }

                pub inline fn get_pointer(self: @This()) ?*align(align_size) Buffer {
                    if (self.pointer == 0) return null;

                    // const comp: u64 = @bitCast(self);
                    return @ptrFromInt(self.pointer << align_log);
                }
            };

            slots: [array_size]Slot(T) = undefined,
            next: aValue(u64) = .init(0),
            refc: aValue(i16) = .init(1),

            fn uref(self: *Buffer, amount: i16) bool {
                const prev = self.refc.fetchAdd(amount, .release);
                std.debug.print("dealloc {} {}\n", .{ prev, amount });

                if (prev + amount > 0) return false;
                return true;
            }

            const new = Buffer{
                .next = .init(0),
                .refc = .init(1),
            };

            fn deinit(_: *Self) void {
                // self.alloc.destroy(self);
            }
        };

        consumer: aValue(u64) = .init(0),
        producer: aValue(u64) = .init(0),

        // alloc: std.heap.MemoryPoolAligned(Buffer, align_size),
        alloc: std.mem.Allocator,

        pub fn init(alloc: std.mem.Allocator) !Self {
            return Self{
                .alloc = alloc,
                .producer = .init(0),
                .consumer = .init(0),
            };
        }

        pub fn get_consumer(self: Self) ?*Buffer {
            const w: Buffer.Adress = @bitCast(self.consumer.load(.acquire));
            return w.get_pointer();
        }

        pub fn push(noalias self: *@This(), value: T) !void {
            var cached_buff: ?*align(align_size) Buffer = null;
            defer {
                if (cached_buff) |c_buff| {
                    self.alloc.destroy(c_buff);
                }
            }

            while (true) {
                const addr: Buffer.Adress = @bitCast(self.producer.fetchAdd(1, .acquire));

                //std.debug.print("addr: {}\n", .{addr});
                if (addr.index < Buffer.array_size and addr.pointer != 0) {
                    addr.get_pointer().?.slots[addr.index].write(value);
                    return;
                }

                var prev =
                    if (addr.pointer != 0)
                        &addr.get_pointer().?.next
                    else
                        &self.consumer;

                var next = prev.load(.acquire);
                std.debug.print("{}", .{next});
                if (next == 0) {
                    if (cached_buff == null) {
                        cached_buff = &(try self.alloc.alignedAlloc(Buffer, align_size, 1))[0];
                        std.debug.assert(std.mem.Alignment.check(.@"16", @intFromPtr(cached_buff.?)));

                        cached_buff.?.refc.raw = 1;
                        cached_buff.?.next.raw = 0;
                    }

                    next = @intFromPtr(cached_buff.?);
                    std.debug.print("t:{}\n", .{@ctz(@intFromPtr(cached_buff))});
                    std.debug.print("test2: {*}\n", .{cached_buff.?});

                    if (prev.cmpxchgWeak(0, next, .release, .acquire)) |updated| {
                        next = updated;
                    } else {
                        cached_buff = null;
                    }
                }
                var new = self.producer.load(.monotonic);
                std.debug.print("test2: {X}\n", .{next});
                const new_addr: Buffer.Adress = @bitCast(new);
                tes: while (true) {
                    if (new_addr.pointer != addr.pointer) {
                        std.debug.print("test\n", .{});
                        if (addr.get_pointer()) |buf| {
                            if (buf.uref(-1)) {
                                _ = buf.refc.load(.acquire);
                                self.alloc.free(buf);
                            }
                        }
                        break :tes;
                    }

                    if (self.producer.cmpxchgStrong(new, next + 1, .release, .monotonic)) |updated| {
                        new = updated;
                        std.debug.print("test3: {X}\n", .{new});
                        continue :tes;
                    }

                    var old_buf = addr.get_pointer();
                    var inc = addr.index -% Buffer.array_size;

                    std.debug.print("test4: {X}\n", .{next});
                    const next_pointer = @as(Buffer.Adress, @bitCast(next)).get_pointer().?;
                    if (old_buf == null) {
                        std.debug.print("test5\n", .{});
                        old_buf = next_pointer;
                        inc = 0;
                    }
                    std.debug.print("{*}", .{next_pointer});
                    std.debug.print("inc: {}\n", .{inc});
                    _ = old_buf.?.uref(@intCast(inc));
                    return next_pointer.slots[0].write(value);
                }
            }
        }

        pub fn pop(self: *@This()) ?T {
            var addr: Buffer.Adress = @bitCast(self.consumer.load(.acquire));
            std.debug.print("addr: {}\n", .{addr});
            if (addr.pointer == 0) return null;

            var idx = addr.index;
            var buf = addr.get_pointer().?;

            if (idx >= Buffer.array_size) {
                const next = buf.next.load(.acquire);
                if (next == 0) return null;
                if (buf.uref(-1)) {
                    _ = buf.refc.load(.acquire);
                    self.alloc.free(buf);
                }
                buf = @as(Buffer.Adress, @bitCast(next)).get_pointer().?;
                idx = 0;

                self.consumer.store(@intFromPtr(buf), .unordered);
            }

            const val = buf.slots[idx].read() orelse return null;
            //std.debug.print("buf {*}\n", .{buf});
            self.consumer.store(@as(u64, @intFromPtr(buf)) + idx + 1, .unordered);

            return val;
        }
    };
}
