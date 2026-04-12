const fp = @import("fp");

const F = f64;

export fn print_decimal(buf: [*]u8, buf_len: usize, f: F, precision: usize) usize {
    const p = if (precision == 0) null else precision;
    const slice = fp.format(F, buf[0..buf_len], f, .{ .mode = .decimal, .precision = p }) catch return 0;
    return slice.len;
}

export fn print_scientific(buf: [*]u8, buf_len: usize, f: F, precision: usize) usize {
    const p = if (precision == 0) null else precision;
    const slice = fp.format(F, buf[0..buf_len], f, .{ .mode = .scientific, .precision = p }) catch return 0;
    return slice.len;
}

export fn parse(buf: [*]const u8, buf_len: usize) F {
    return fp.parse(F, buf[0..buf_len]) catch 0;
}
