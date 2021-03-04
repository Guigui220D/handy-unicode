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

        try writer.writeByte('<');
        try writer.writeAll(&[_]u8{ 0xe2, 0x90 });
        try writer.writeByte(0x80 | ch);
        try writer.writeByte('>');
    } else {
        //This is awful
        if (self.id < 470 or (self.utf8.len == 2 and self.utf8[0] == 0xc2 and self.utf8[1] == 0x85)) {
            try writer.writeAll("<ctrl>");
        } else {
            try writer.writeAll(self.utf8);
        }
    }
}

utf8: []const u8,
id: c_int //Find better solution
