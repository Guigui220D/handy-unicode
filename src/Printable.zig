const std = @import("std");

pub fn format(
    self: @This(),
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    if (self.utf8.len == 1 and std.ascii.isCntrl(self.utf8[0])) {
        var ch = self.utf8[0];
        if (ch == 0x7f)
            ch = 0xa1;
            
        try writer.writeAll("*\"");
        try writer.writeAll(&[_]u8{ 0xe2, 0x90 });
        try writer.writeByte(0x80 | ch);
        try writer.writeByte('"');
    } else {
        try writer.writeAll(self.utf8);
    }
}

utf8: []const u8