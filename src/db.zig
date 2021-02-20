const std = @import("std");
const sqlite = @import("sqlite");

pub fn createDb() !void {
    const db = try sqlite.SQLite.open("unicode.db");
    defer db.close() catch unreachable;

    var rows = db.exec(
        \\ CREATE TABLE chars (
        \\     id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\     codepoint INTEGER NOT NULL,
        \\     name TEXT NOT NULL,
        \\     utf8 BLOB NOT NULL
        \\     user_notes TEXT
        \\     standard_notes TEXT
        \\ );
    );
    while (rows.next()) |row_item| {
        switch (row_item) {
            .Error => |e| {
                std.debug.warn("sqlite3 errmsg: {s}\n", .{database.errmsg()});
                return e;
            },
            else => continue,
        }
    }
}

fn parseFileAndFillDb(file: std.fs.File, database: sqlite.SQLite) !void {
    var reader = file.reader();

    var buffer: [1024]u8 = undefined;

    //Read all lines
    while (try reader.readUntilDelimiterOrEof(buffer[0..], '\n')) |line| {
        if (line.len == 0 or line[0] == '@' or line[0] == '#')
            continue;

        var parts = std.mem.tokenize(line, "#"); // Separate name from actual data
        const data = parts.next() orelse return error.IllFormedCodeFile;
        const name = parts.rest();

        var codepoint = std.mem.tokenize(data, ";").next() orelse return error.IllFormedCodeFile;
        var utf8: [32]u8 = undefined;
        var codepoint_iterator = std.mem.tokenize(codepoint, ' ');
        var i: usize = 0;
        while (codepoint_iterator.next()) |code| {
            i += std.fmt.unicode.utf8Encode(std.fmt.parseInt(code), utf8[i..]);
        }
        
        var buf2: [1024]u8 = undefined;
        var request = try std.fmt.bufPrint(buf2[0..1023], "INSERT INTO unicode(codepoint, name) VALUES ('{s}', '{s}');", .{codepoint, name});
        buf2[request.len] = 0;

        var ans = database.exec(std.mem.spanZ(@ptrCast([*:0]const u8, request.ptr)));
        while (ans.next()) |row_item| {
            switch (row_item) {
                .Error => |e| {
                    std.debug.warn("sqlite3 errmsg: {s}\n", .{database.errmsg()});
                    return e;
                },
                else => continue,
            }
        }

        //std.debug.print("{x}\n", .{id});
    }
}