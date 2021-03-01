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

    var tokens = std.mem.tokenize(self.user_query, " ");
    
    var first = true;
    while (tokens.next()) |word| {
        var ignore = (word[0] == '-');

        var kept = word;
        if (ignore)
            kept = kept[1..];

        if (first) {
            try writer.writeAll("WHERE ");
        } else
            try writer.writeAll("AND ");
        
        try writer.writeAll("name ");

        if (ignore)
            try writer.writeAll("NOT ");

        try writer.print("LIKE '%{s}%'\n", .{ kept });

        first = false;
    }

    const page_size = options.width orelse 8;

    try writer.print(
        \\ORDER BY times_used DESC
        \\LIMIT {}
        \\OFFSET {}
        , .{page_size, self.page * page_size}
    );
}

user_query: []const u8,
page: usize,