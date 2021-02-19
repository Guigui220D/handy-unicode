const std = @import("std");
const sqlite = @import("sqlite");   //Available because in build.zig I added this package

pub fn main() anyerror!void {
    const db_name = "codes.db";

    const cwd = std.fs.cwd(); //Current directory folder
    const stderr = std.io.getStdErr().writer();

    var must_create_db = false;

    //Checks if program has access to the db file/if it exists
    cwd.access(db_name, .{.read = true, .write = true}) catch |err| {
        if (err == error.FileNotFound) {
            must_create_db = true;
        } else
            return err;
    };

    const db = try sqlite.SQLite.open(db_name);
    defer db.close() catch unreachable;

    if (must_create_db) {
        try stderr.print("The codes database does not exist! Creating it from allkeys.txt...\n", .{});
        try createDb(db);
        try stderr.print("Done!\n", .{});
    }

    //Test
    var rows = db.exec("SELECT codepoint, comment FROM unicode WHERE id < 10;");

    while (rows.next()) |row_item| {
        const row = switch (row_item) {
            // Ignore when statements are completed
            .Done => continue,
            .Row => |r| r,
            .Error => |e| {
                std.debug.warn("sqlite3 errmsg: {s}\n", .{db.errmsg()});
                return e;
            },
        };

        const id = row.columnInt(0);
        const username = row.columnText(1);

        std.debug.warn(" {}\t{s}\n", .{ id, username });
    }
}

fn createDb(database: sqlite.SQLite) !void {
    const cwd = std.fs.cwd();
    const file = try cwd.openFile("allkeys.txt", .{.read = true});
    return parseFileAndCreateDb(file, database);
}

fn parseFileAndCreateDb(file: std.fs.File, database: sqlite.SQLite) !void {
    var reader = file.reader();

    var buffer: [1024]u8 = undefined;
    
    _ = database.exec(
        \\ CREATE TABLE unicode(
        \\  id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\  codepoint TEXT NOT NULL,
        \\  comment TEXT NOT NULL
        \\ );
    );

    //Read all lines
    while (try reader.readUntilDelimiterOrEof(buffer[0..], '\n')) |line| {
        if (line.len == 0 or line[0] == '@' or line[0] == '#')
            continue;

        var parts = std.mem.tokenize(line, "#");    //Separate comment from actual data
        const data = parts.next() orelse return error.IllFormedCodeFile;
        const comment = parts.rest();

        var codepoint = std.mem.tokenize(data, ";").next() orelse return error.IllFormedCodeFile;
        
        var buf2: [1024]u8 = undefined;
        var request = try std.fmt.bufPrint(buf2[0..1023], "INSERT INTO unicode(codepoint, comment) VALUES ('{s}', '{s}');{c}", .{codepoint, comment, 0});

        var ans = database.exec(request[0.. :0]);
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
