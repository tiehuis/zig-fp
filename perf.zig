const std = @import("std");
const fp = @import("fp.zig");

pub fn main() !void {
    var prng = prng: {
        var seed: u64 = 0;
        //try std.posix.getrandom(std.mem.asBytes(&seed));
        seed = 0;
        break :prng std.Random.DefaultPrng.init(seed);
    };
    const rand = prng.random();
    var timer = try std.time.Timer.start();

    var acc: u64 = 0;
    var fp_total_format_time: u64 = 0;
    var fp_total_parse_time: u64 = 0;
    var std_total_format_time: u64 = 0;
    var std_total_parse_time: u64 = 0;

    const precision: ?usize = null;

    const samples = 1_000_000;
    var i: usize = 0;
    while (i < samples) : (i += 1) {
        const f: f64 = @bitCast(rand.int(u64));

        var zig_short_buf: [256]u8 = undefined;

        timer.reset();
        const pf_zig_short_s = fp.print(f64, &zig_short_buf, f, .{ .mode = .scientific, .precision = if (precision) |ok| ok + 1 else null });
        fp_total_format_time += timer.lap();

        timer.reset();
        const pf_zig_pf = try fp.parseFloat(f64, pf_zig_short_s);
        fp_total_parse_time += timer.read();

        timer.reset();
        const std_zig_short_s = try std.fmt.float.render(&zig_short_buf, f, .{ .mode = .scientific, .precision = if (precision) |ok| ok else null });
        std_total_format_time += timer.lap();

        timer.reset();
        const std_zig_pf = try std.fmt.parseFloat(f64, std_zig_short_s);
        std_total_parse_time += timer.read();

        if (false) {
            if (!std.mem.eql(u8, std_zig_short_s, pf_zig_short_s)) {
                std.debug.print("error/fmt:   pf: {s} != std: {s}\n", .{ std_zig_short_s, pf_zig_short_s });
                return error.Fail;
            }
            const u_std_zig_pf: u64 = @bitCast(std_zig_pf);
            const u_pf_zig_pf: u64 = @bitCast(pf_zig_pf);
            if (u_std_zig_pf != u_pf_zig_pf) {
                std.debug.print("error/parse: pf: {} != std: {}\n", .{ std_zig_pf, pf_zig_pf });
            }
        }

        acc +%= @as(u64, @bitCast(pf_zig_pf));
        acc +%= @as(u64, @bitCast(std_zig_pf));
    }

    std.debug.print(
        \\acc: {}
        \\  pf: format: {:.2}ns, parse: {:.2}ns
        \\ std: format: {:.2}ns, parse: {:.2}ns
        \\
    , .{
        acc,
        tm(fp_total_format_time, samples),
        tm(fp_total_parse_time, samples),
        tm(std_total_format_time, samples),
        tm(std_total_parse_time, samples),
    });
}

// Returns the ns per sample
fn tm(total_ns: u64, samples: usize) f64 {
    const n: f64 = @floatFromInt(total_ns);
    const d: f64 = @floatFromInt(samples);
    return n / d;
}
