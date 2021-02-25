const std = @import("std");
const db = @import("db.zig");

pub fn main() anyerror!void {
    //try enableUtf8OnTerminal();
    const allocator = std.heap.page_allocator;

    const stderr = std.io.getStdErr().writer();
    const stdout = std.io.getStdOut().writer();

    const cwd = std.fs.cwd(); //Current directory folder

    try stdout.print(
        \\ ⚡ Welcome to Handy-Unicode Zig (huz) ⚡
        \\(If the lightning bolt character didn't render, make sure your terminal is set up for UTF-8 support)
        //\\Write help if you need any help
        \\
    , .{});

    var db_exists = try db.checkDbExists();

    try db.openDb();
    defer db.closeDb();

    if (!db_exists) {
        try stderr.print("The codes database does not exist! Creating it from allkeys.txt...\n", .{});
        try db.createTable();
        {
            const file = try cwd.openFile("allkeys.txt", .{ .read = true });
            try db.parseFileAndFillDb(file);
        }
        try stderr.print("Done!\n", .{});
    }

    var buffer: [1024]u8 = undefined;

    while (try prompt(buffer[0..])) |line| {
        try db.prepareSearch(allocator, line);
        try db.runSearch();
    }

    db.deallocSearch(allocator);

    try stdout.writeAll("\nBye bye!\n");
}

fn prompt(buffer: []u8) !?[]u8 {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    try stdout.writeAll("(huz) > ");
    return stdin.readUntilDelimiterOrEof(buffer, '\n');
}
