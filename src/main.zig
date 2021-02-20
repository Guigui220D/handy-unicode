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
    var rows = db.exec("SELECT codepoint, comment FROM unicode WHERE id < 500 AND id > 480;");

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

        const codepoint = row.columnText(0);
        const comment = row.columnText(1);

        std.debug.warn("{s}: {s}\n", .{ comment, codepoint });
    }
}