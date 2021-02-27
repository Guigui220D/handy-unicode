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
        if (line.len != 0) {
            switch (line[0]) {
                ':' => {
                    try db.setSearch(allocator, line[1..]);
                    try db.runQuery(allocator);
                },
                '>' => {
                    db.runQuery(allocator) catch |err| {
                        if (err == error.noSearch) {
                            try stderr.writeAll("No search was started!\n");
                        } else return err;
                    };
                },
                '1'...'8' => {
                    var index: u3 = @truncate(u3, line[0] - '1');
                    db.select(allocator, index) catch |err| switch (err) {
                        error.doesNotExist => try stderr.print("Last search page does not have a result with index {c}\n", .{ line[0] }),
                        else => return err
                    };
                },
                'q' => break,
                else => try stderr.print("Get some help lol\n", .{})
            }
        }
    }

    db.deallocQuery(allocator);
    db.deallocSearch(allocator);

    try stdout.writeAll("\nBye bye!\n");
}

fn prompt(buffer: []u8) !?[]u8 {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    try stdout.writeAll("(huz) > ");
    return stdin.readUntilDelimiterOrEof(buffer, '\n');
}
