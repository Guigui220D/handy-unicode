const std = @import("std");
const sqlite = @import("sqlite");

const db_file_name = "codes.db";
var database: sqlite.SQLite = undefined;

pub fn checkDbExists() !bool {
    //Checks if program has access to the db file/if it exists
    if (std.fs.cwd().access(db_file_name, .{.read = true, .write = true})) {
        return true;
    } else |err|
        return if (err == error.FileNotFound) false else err;
}

pub fn openDb() !void {
    database = try sqlite.SQLite.open(db_file_name);
}

pub fn closeDb() void {
    database.close() catch unreachable;
}

pub fn createTable() !void {
    var ans = database.exec(
        \\ CREATE TABLE chars (
        \\     id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\     name TEXT NOT NULL,
        \\     utf8 BLOB NOT NULL,
        \\     user_notes TEXT,
        \\     standard_notes TEXT
        \\ );
    );
    while (ans.next()) |row_item| {
        switch (row_item) {
            .Error => |e| {
                std.debug.warn("sqlite3 errmsg: {s}\n", .{database.errmsg()});
                return e;
            },
            else => continue,
        }
    }
}

pub fn parseFileAndFillDb(file: std.fs.File) !void {
    var reader = file.reader();

    var buffer: [1024]u8 = undefined;
    var buf2: [1024]u8 = undefined;

    //Read all lines
    while (try reader.readUntilDelimiterOrEof(buffer[0..], '\n')) |line| {
        if (line.len == 0 or line[0] == '@' or line[0] == '#')
            continue;

        var parts = std.mem.tokenize(line, "#"); // Separate name from actual data
        const data = parts.next() orelse return error.IllFormedCodeFile;
        const name = parts.rest();

        var codepoint = std.mem.tokenize(data, ";").next() orelse return error.IllFormedCodeFile;
        var utf8: [32]u8 = undefined;
        var codepoint_iterator = std.mem.tokenize(codepoint, " ");
        var i: usize = 0;
        while (codepoint_iterator.next()) |code|
            i += try std.unicode.utf8Encode(try std.fmt.parseInt(u21, code, 16), utf8[i..]);

        std.debug.print("{s}\n", .{utf8[0..i]});
        var request = try std.fmt.bufPrint(buf2[0..1023], "INSERT INTO chars(utf8, name) VALUES (X'{x}', '{s}');", .{utf8[0..i], name});
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






pub const testing = struct {    //Namespace for testing functions
    pub fn printSome() !void {
        var rows = database.exec("SELECT utf8, name FROM chars;");

        while (rows.next()) |row_item| {
            const row = switch (row_item) {
                // Ignore when statements are completed
                .Done => continue,
                .Row => |r| r,
                .Error => |e| {
                    std.debug.warn("sqlite3 errmsg: {s}\n", .{database.errmsg()});
                    return e;
                },
            };

            const codepoint = row.columnText(0);
            const name = row.columnText(1);

            std.debug.warn("{s}: {s}\n", .{ name, codepoint });
        }
    }
};