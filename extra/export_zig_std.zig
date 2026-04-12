const std = @import("std");

const F = f64;

export fn print_decimal(buf: [*]u8, buf_len: usize, f: F, precision: usize) usize {
    const p = if (precision == 0) null else precision;
    const slice = std.fmt.float.render(buf[0..buf_len], f, .{ .mode = .decimal, .precision = p }) catch "";
    return slice.len;
}

export fn print_scientific(buf: [*]u8, buf_len: usize, f: F, precision: usize) usize {
    const p = if (precision == 0) null else precision;
    const slice = std.fmt.float.render(buf[0..buf_len], f, .{ .mode = .scientific, .precision = p }) catch "";
    return slice.len;
}

export fn parse(buf: [*]const u8, buf_len: usize) F {
    return std.fmt.parseFloat(F, buf[0..buf_len]) catch 0;
}
