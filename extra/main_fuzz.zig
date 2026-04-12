const std = @import("std");
const fp = @import("fp");

extern "c" fn uscalec_fixed(dst: [*]u8, f: f64, n: c_int) void;
extern "c" fn uscalec_short(dst: [*]u8, f: f64) void;
extern "c" fn uscalec_parse(src: [*c]const u8, len: usize) f64;

pub fn main(init: std.process.Init) !void {
    const gpa = std.heap.smp_allocator;
    var it = try init.minimal.args.iterateAllocator(gpa);
    defer it.deinit();

    var seed: ?u64 = 0;
    while (it.next()) |arg| {
        if (std.mem.startsWith(u8, arg, "--seed=")) {
            seed = try std.fmt.parseUnsigned(usize, arg["--seed=".len..], 10);
        }
    }

    var prng = prng: {
        if (seed == null) init.io.random(@ptrCast(&seed));
        break :prng std.Random.DefaultPrng.init(seed.?);
    };

    const rand = prng.random();
    var i: usize = 0;
    while (true) : (i += 1) {
        if (i % 1_000_000 == 0) std.debug.print("{}\n", .{i});

        var fail = false;

        const f: f64 = @bitCast(rand.int(u64));
        if (std.math.isNan(f) or std.math.isInf(f) or f <= 0.0) continue;

        //const precision = rand.intRangeAtMost(usize, 1, 10);
        //fail = fail or try checkFixedStd(i, f, precision);

        fail = fail or try checkShortStd(i, f);
        if (fail) break;
    }
}

fn checkShortC(i: usize, f: f64) !bool {
    var zig_short_buf: [256]u8 = undefined;
    const zig_short_s = fp.print(&zig_short_buf, f, .{ .mode = .scientific });

    var c_short_buf: [256]u8 = undefined;
    uscalec_short(&c_short_buf, f);
    const c_short_len = std.mem.len(@as([*c]u8, &c_short_buf));
    const c_short_s = c_short_buf[0..c_short_len];

    const zig_pf = fp.parse(f64, zig_short_s) catch |err| {
        std.debug.print("{} error while parsing: {s}\n", .{ i, c_short_s });
        return err;
    };
    if (zig_pf != f) {
        std.debug.print("{} [short] zig round-trip fail: {} -> {s} -> {}\n", .{
            i,
            f,
            zig_short_s,
            zig_pf,
        });
        return true;
    }
    const c_pf = uscalec_parse(&c_short_buf, c_short_len);
    if (c_pf != f) {
        std.debug.print("{} [short]  c round-trip fail: {} -> {s} -> {}\n", .{
            i,
            f,
            c_short_s,
            c_pf,
        });
        return true;
    }

    if (!std.mem.eql(u8, zig_short_s, c_short_s)) {
        std.debug.print("{} [short] zig: {s} != c: {s}\n", .{
            i,
            zig_short_s,
            c_short_s,
        });
        return true;
    }

    return false;
}

fn checkShortStd(i: usize, f: f64) !bool {
    var zig_short_buf: [256]u8 = undefined;
    const zig_short_s = try fp.format(f64, &zig_short_buf, f, .{ .mode = .scientific });

    var zigstd_short_buf: [256]u8 = undefined;
    const zigstd_short_s = try std.fmt.float.render(&zigstd_short_buf, f, .{ .mode = .scientific });

    if (!std.mem.eql(u8, zig_short_s, zigstd_short_s)) {
        std.debug.print("{} [short] zig: {s} != zig-std: {s}\n", .{
            i,
            zig_short_s,
            zigstd_short_s,
        });
        return true;
    }

    const zig_pf = fp.parse(f64, zig_short_s) catch |err| {
        std.debug.print("{} error while parsing: {s}\n", .{ i, zig_short_s });
        return err;
    };
    if (zig_pf != f) {
        std.debug.print("{} [short] zig round-trip fail: {} -> {s} -> {}\n", .{
            i,
            f,
            zig_short_s,
            zig_pf,
        });
        return true;
    }

    return false;
}

fn checkFixedC(i: usize, f: f64, precision: usize) !bool {
    var zig_fixed_buf: [256]u8 = undefined;
    const zig_fixed_s = fp.print(&zig_fixed_buf, f, .{
        .mode = .scientific,
        .precision = precision - 1,
    });

    var c_fixed_buf: [256]u8 = undefined;
    uscalec_fixed(&c_fixed_buf, f, @intCast(precision));
    const c_fixed_len = std.mem.len(@as([*c]u8, &c_fixed_buf));
    const c_fixed_s = c_fixed_buf[0..c_fixed_len];

    if (!std.mem.eql(u8, zig_fixed_s, c_fixed_s)) {
        std.debug.print("{} [fixed:{}] zig: {s} != c: {s}\n", .{
            i,
            precision,
            zig_fixed_s,
            c_fixed_s,
        });
        return true;
    }

    return false;
}

fn checkFixedStd(i: usize, f: f64, precision: ?usize) !bool {
    var zig_fixed_buf: [256]u8 = undefined;
    const zig_fixed_s = fp.print(&zig_fixed_buf, f, .{
        .mode = .scientific,
        .precision = precision,
    });

    var zigstd_fixed_buf: [256]u8 = undefined;
    const zigstd_fixed_s = try std.fmt.float.render(&zigstd_fixed_buf, f, .{
        .mode = .scientific,
        .precision = precision,
    });

    if (!std.mem.eql(u8, zig_fixed_s, zigstd_fixed_s)) {
        std.debug.print("{} [fixed:{?}] zig: {s} != zig-std: {s}\n", .{
            i,
            precision,
            zig_fixed_s,
            zigstd_fixed_s,
        });
        return true;
    }

    return false;
}
