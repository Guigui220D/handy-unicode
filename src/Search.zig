const std = @import("std");

pub fn format(
    self: @This(),
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    try writer.writeAll(
        \\SELECT utf8, name, times_used, id
        \\FROM chars 
    );

    var rest = self.user_query;
    var tokens = std.mem.tokenize(rest, " ");

    var first = true;
    while (tokens.next()) |word| : (rest = tokens.rest()) {
        var kept = word;
        var ignore = (kept[0] == '-');
        
        if (ignore) {
            rest = rest[1..];
            kept = kept[1..];
        }

        if (kept.len == 0)
            continue;

        if (kept[0] == '"') {
            rest = rest[1..];
            kept = for (rest) |c, i| {
                if (c == '"') {
                    const quoted = rest[0..i];
                    tokens = std.mem.tokenize(rest[(i + 1)..], " ");
                    break quoted;
                }
            } else blk: {
                tokens = std.mem.tokenize("", " ");
                break :blk rest;
            };
        }

        if (first) {
            try writer.writeAll("WHERE ");
        } else
            try writer.writeAll("AND ");

        try writer.writeAll("name ");

        if (ignore)
            try writer.writeAll("NOT ");

        try writer.print("LIKE '%{s}%'\n", .{kept});

        first = false;
    }

    const page_size = options.width orelse 8;

    try writer.print(
        \\ORDER BY times_used DESC
        \\LIMIT {}
        \\OFFSET {}
    , .{ page_size, self.page * page_size });
}

user_query: []const u8,
page: usize,
