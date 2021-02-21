const std = @import("std");
const db = @import("db.zig");

pub fn main() anyerror!void {
    try enableUtf8OnTerminal();

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

fn enableUtf8OnTerminal() !void {
    if (system("chcp 65001") != 0)
        std.debug.print("Could not set terminal to utf8, make sure it can print all characters.\n", .{});
}

pub extern "c" fn system([*:0]const u8) c_int;

