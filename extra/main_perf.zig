const std = @import("std");
const Io = std.Io;
const fp = @import("fp");

pub fn main(init: std.process.Init) !void {
    const gpa = std.heap.smp_allocator;
    var it = try init.minimal.args.iterateAllocator(gpa);
    defer it.deinit();

    var seed: ?u64 = null;
    var samples: usize = 1_000_000;
    var validate = false;
    var precision: ?usize = null;
    var mode: fp.Mode = .scientific; // TODO: share definitions
    var std_mode: std.fmt.float.Mode = .scientific;
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

    for (0..samples) |_| {
        const f: f64 = @bitCast(rand.int(u64));

        var fp_short_buf: [2048]u8 = undefined;
        var zig_std_short_buf: [2048]u8 = undefined;

        ts = Io.Clock.awake.now(init.io);
        const pf_zig_short_s = try fp.format(f64, &fp_short_buf, f, .{
            .mode = mode,
            .precision = if (precision) |ok| ok else null,
        });
        fp_total_format_time += ts.untilNow(init.io, .awake).toNanoseconds();

        ts = Io.Clock.awake.now(init.io);
        const pf_zig_pf = try fp.parse(f64, pf_zig_short_s);
        fp_total_parse_time += ts.untilNow(init.io, .awake).toNanoseconds();

        ts = Io.Clock.awake.now(init.io);
        const std_zig_short_s = try std.fmt.float.render(&zig_std_short_buf, f, .{
            .mode = std_mode,
            .precision = if (precision) |ok| ok else null,
        });
        std_total_format_time += ts.untilNow(init.io, .awake).toNanoseconds();

        ts = Io.Clock.awake.now(init.io);
        const std_zig_pf = try std.fmt.parseFloat(f64, std_zig_short_s);
        std_total_parse_time += ts.untilNow(init.io, .awake).toNanoseconds();

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

        acc +%= @as(u64, @bitCast(pf_zig_pf));
        acc +%= @as(u64, @bitCast(std_zig_pf));
    }

    std.debug.print(
        \\# mode={t} precision={?} seed=0x{x} accumulator=0x{x}
        \\  pf: format: {:.2}ns, parse: {:.2}ns
        \\ std: format: {:.2}ns, parse: {:.2}ns
        \\
    , .{
        mode,
        precision,
        seed.?,
        acc,
        tm(fp_total_format_time, samples),
        tm(fp_total_parse_time, samples),
        tm(std_total_format_time, samples),
        tm(std_total_parse_time, samples),
    });
}

// Returns the ns per sample
fn tm(total_ns: i96, samples: usize) f64 {
    const n: f64 = @floatFromInt(total_ns);
    const d: f64 = @floatFromInt(samples);
    return n / d;
}
