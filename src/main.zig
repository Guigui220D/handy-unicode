const std = @import("std");
const db = @import("db.zig");

pub fn main() anyerror!void {
    const cwd = std.fs.cwd(); //Current directory folder
    const stderr = std.io.getStdErr().writer();

    var db_exists = try db.checkDbExists();

    try db.openDb();
    defer db.closeDb();

    if (!db_exists) {
        try stderr.print("The codes database does not exist! Creating it from allkeys.txt...\n", .{});
        try db.createTable();
        {
            const file = try cwd.openFile("allkeys.txt", .{.read = true});
            try db.parseFileAndFillDb(file);
        }
        try stderr.print("Done!\n", .{});
    }

    //Test
    try db.testing.printSome();
}