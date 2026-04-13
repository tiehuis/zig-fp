const std = @import("std");
const Io = std.Io;
const fp = @import("fp");
const zmij = @import("zmij");

pub fn main(init: std.process.Init) !void {
    const gpa = std.heap.smp_allocator;
    var it = try init.minimal.args.iterateAllocator(gpa);
    defer it.deinit();

    var seed: ?u64 = null;
    var samples: usize = 500;
    var validate = false;
    var precision: ?usize = null;
    var mode: fp.Mode = .scientific; // TODO: share definitions
    var std_mode: std.fmt.float.Mode = .scientific;
    var test_zmij = false;
    var iters: usize = 10000;
    var maybe_sample: ?f64 = null;
    while (it.next()) |arg| {
        if (std.mem.startsWith(u8, arg, "--seed=")) {
            seed = try std.fmt.parseUnsigned(usize, arg["--seed=".len..], 10);
        } else if (std.mem.startsWith(u8, arg, "--samples=")) {
            samples = try std.fmt.parseUnsigned(usize, arg["--samples=".len..], 10);
        } else if (std.mem.startsWith(u8, arg, "--validate=")) {
            const suffix = arg["--validate=".len..];
            validate = std.mem.eql(u8, suffix, "true");
        } else if (std.mem.startsWith(u8, arg, "--precision=")) {
            precision = try std.fmt.parseUnsigned(usize, arg["--precision=".len..], 10);
        } else if (std.mem.startsWith(u8, arg, "--mode=")) {
            const suffix = arg["--mode=".len..];
            if (std.mem.eql(u8, suffix, "scientific")) {
                mode = .scientific;
                std_mode = .scientific;
            } else if (std.mem.eql(u8, suffix, "decimal")) {
                mode = .decimal;
                std_mode = .decimal;
            } else {
                return error.InvalidMode;
            }
        } else if (std.mem.startsWith(u8, arg, "--zmij=")) {
            const suffix = arg["--zmij=".len..];
            test_zmij = std.mem.eql(u8, suffix, "true");
        } else if (std.mem.startsWith(u8, arg, "--iters=")) {
            iters = try std.fmt.parseUnsigned(usize, arg["--iters=".len..], 10);
        } else if (std.mem.startsWith(u8, arg, "--sample=")) {
            maybe_sample = try std.fmt.parseFloat(f64, arg["--sample=".len..]);
        }
    }

    var prng = prng: {
        if (seed == null) init.io.random(@ptrCast(&seed));
        break :prng std.Random.DefaultPrng.init(seed.?);
    };
    const rand = prng.random();
    var ts: Io.Timestamp = undefined;

    var acc: i96 = 0;
    var fp_total_format_time: i96 = 0;
    var fp_total_parse_time: i96 = 0;
    var std_total_format_time: i96 = 0;
    var std_total_parse_time: i96 = 0;
    var zmij_total_format_time: i96 = 0;

    for (0..samples) |_| {
        const f: f64 = if (maybe_sample) |sample| sample else @bitCast(rand.int(u64));

        var fp_short_buf: [2048]u8 = undefined;
        var zig_std_short_buf: [2048]u8 = undefined;
        var zmij_short_buf: [2048]u8 = undefined;

        ts = Io.Clock.awake.now(init.io);
        var pf_zig_short_s: []const u8 = undefined;
        for (0..iters) |_| {
            pf_zig_short_s = try fp.format(f64, &fp_short_buf, f, .{
                .mode = mode,
                .precision = if (precision) |ok| ok else null,
            });
            std.mem.doNotOptimizeAway(&fp_short_buf);
        }
        fp_total_format_time += @divTrunc(ts.untilNow(init.io, .awake).toNanoseconds(), iters);

        ts = Io.Clock.awake.now(init.io);
        var pf_zig_pf: f64 = undefined;
        for (0..iters) |_| {
            pf_zig_pf = try fp.parse(f64, pf_zig_short_s);
            std.mem.doNotOptimizeAway(pf_zig_pf);
        }
        fp_total_parse_time += @divTrunc(ts.untilNow(init.io, .awake).toNanoseconds(), iters);
        acc +%= @as(u64, @bitCast(pf_zig_pf));

        ts = Io.Clock.awake.now(init.io);
        var std_zig_short_s: []const u8 = undefined;
        for (0..iters) |_| {
            std_zig_short_s = try std.fmt.float.render(&zig_std_short_buf, f, .{
                .mode = std_mode,
                .precision = if (precision) |ok| ok else null,
            });
            std.mem.doNotOptimizeAway(&zig_std_short_buf);
        }
        std_total_format_time += @divTrunc(ts.untilNow(init.io, .awake).toNanoseconds(), iters);

        ts = Io.Clock.awake.now(init.io);
        var std_zig_pf: f64 = undefined;
        for (0..iters) |_| {
            std_zig_pf = try std.fmt.parseFloat(f64, std_zig_short_s);
            std.mem.doNotOptimizeAway(std_zig_pf);
        }
        std_total_parse_time += @divTrunc(ts.untilNow(init.io, .awake).toNanoseconds(), iters);
        acc +%= @as(u64, @bitCast(std_zig_pf));

        if (test_zmij) {
            ts = Io.Clock.awake.now(init.io);
            for (0..iters) |_| {
                _ = zmij.dtoa(f, &zmij_short_buf);
                std.mem.doNotOptimizeAway(&zmij_short_buf);
            }
            zmij_total_format_time += @divTrunc(ts.untilNow(init.io, .awake).toNanoseconds(), iters);
        }

        if (validate) {
            if (!std.mem.eql(u8, std_zig_short_s, pf_zig_short_s)) {
                std.debug.print("error/fmt:   pf: {s} != std: {s}\n", .{
                    pf_zig_short_s,
                    std_zig_short_s,
                });
                return error.Fail;
            }
            const u_std_zig_pf: u64 = @bitCast(std_zig_pf);
            const u_pf_zig_pf: u64 = @bitCast(pf_zig_pf);
            if (u_std_zig_pf != u_pf_zig_pf) {
                std.debug.print("error/parse: pf: {} != std: {}\n", .{
                    pf_zig_pf,
                    std_zig_pf,
                });
            }
        }
    }

    std.debug.print(
        \\# mode={t} precision={?} seed=0x{x} iters={} accumulator=0x{x} sample={?e}
        \\  pf: format: {:.2}ns, parse: {:.2}ns
        \\ std: format: {:.2}ns, parse: {:.2}ns
        \\
    , .{
        mode,
        precision,
        seed.?,
        iters,
        acc,
        maybe_sample,
        tm(fp_total_format_time, samples),
        tm(fp_total_parse_time, samples),
        tm(std_total_format_time, samples),
        tm(std_total_parse_time, samples),
    });

    if (test_zmij) {
        std.debug.print(
            \\zmij: format: {:.2}ns
            \\
        , .{
            tm(zmij_total_format_time, samples),
        });
    }
}

// Returns the ns per sample
fn tm(total_ns: i96, samples: usize) f64 {
    const n: f64 = @floatFromInt(total_ns);
    const d: f64 = @floatFromInt(samples);
    return n / d;
}
