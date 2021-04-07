const std = @import("std");
const db = @import("db.zig");

pub fn main() anyerror!void {
    //try enableUtf8OnTerminal();
    const allocator = std.heap.page_allocator;

    const stderr = std.io.getStdErr().writer();
    const stdout = std.io.getStdOut().writer();

    const cwd = std.fs.cwd(); //Current directory folder

    try stdout.writeAll(
        \\ ⚡ Welcome to Handy-Unicode Zig (huz) ⚡
        \\(If the lightning bolt character didn't render, make sure your terminal is set up for UTF-8 support)
        \\Write "help" if you need any 📕
        \\
    );

    var db_exists = try db.checkDbExists();

    try db.openDb();
    defer db.closeDb();

    if (!db_exists) {
        try stdout.writeAll("Creating the db from allkeys.txt for the first time ⏳ (This could take a few minutes, do not close the program)\n");
        var timer = try std.time.Timer.start();
        try db.createTable();
        {
            const file = cwd.openFile("allkeys.txt", .{ .read = true }) catch |err| switch (err) {
                error.FileNotFound, error.AccessDenied => {
                    try stderr.print("Could not open allkeys.txt 😢 ({})", .{err});
                    return;
                },
                else => return err,
            };
            try db.parseFileAndFillDb(file);
        }
        try stdout.print("Done! (took {}s)\n", .{@divTrunc(timer.read(), 1_000_000_000)});
    }

    var buffer: [1024]u8 = undefined;

    while (try prompt(buffer[0..])) |_line| {
        var buf2: [1024]u8 = undefined;
        var line = _line;

        line.ptr = &buf2;
        line.len = std.mem.replacementSize(u8, _line, "\x0D", "");
        _ = std.mem.replace(u8, _line, "\x0D", "", line);

        if (line.len != 0) {
            switch (line[0]) {
                ':' => {
                    try db.setSearch(allocator, line[1..]);
                    db.runQuery(allocator) catch |err| {
                        if (err == error.UnsafeQuery) {
                            try stderr.writeAll("Search has special characters and is unsafe at the moment. Please only use alphanum 🔠🔢\n");
                        } else
                            return err;
                    };
                },
                '1'...'8' => {
                    var index: u3 = @truncate(u3, line[0] - '1');
                    db.select(allocator, index) catch |err| switch (err) {
                        error.doesNotExist => try stderr.print("Last search page does not have a result with index {c} 🤔\n", .{line[0]}),
                        else => return err,
                    };
                },
                //'a' => try db.testing.printAll(),
                'q' => break,
                'h' => try showHelp(),
                else => try stderr.writeAll("Invalid command. Type \"help\" 📕\n"),
            }
        } else {
            db.runQuery(allocator) catch |err| {
                if (err == error.noSearch) {
                    try stderr.writeAll("No search was started. Write\":some words\" to start a query! 👓\n");
                } else return err;
            };
        }
    }

    db.deallocQuery(allocator);
    db.deallocSearch(allocator);

    try stdout.writeAll("\nBye bye!\n");
}

fn prompt(buffer: []u8) !?[]u8 {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    try stdout.writeAll("(⚡huz) > ");
    return stdin.readUntilDelimiterOrEof(buffer, '\n');
}

fn showHelp() !void {
    const stdout = std.io.getStdOut().writer();

    try stdout.writeAll(
        \\     ⋯⋯⋯⋯⋯
        \\ Thanks for using HandyUnicode!
        \\ 
        \\ If characters don't render properly, make sure your terminal is set up for utf8, and has a complete font for unicode
        \\
        \\ Commands:
        \\  • ":search": Stars a new query
        \\      Not case sensitive, and words can be out of order
        \\      You will get a page of up to 8 results numbered. You can press enter to see the next page
        \\      Results are sorted by use count
        \\      You can use "my words" to have a strict order
        \\      You can use -words to remove search results that satisfy this search term;
        \\  • Enter: See the next page of the current query if there is one
        \\      If you reach "no more results", you can just press again to redo the query;
        \\  • 1-8 (a digit): Select a character among the last results
        \\      The character will be copied to clipboard if it can, and its use count will be incremented;
        \\  • q..: Quit the program;
        \\  • h..: Show this menu!
        \\
        \\  First startup:
        \\      The program will load the 'allkeys.txt' file (created by the unicode organization) and create the database
        \\      If that process was interrupted, an incomplete db will exist. You need to delete it (codes.db) and restart
        \\
        \\  Contact: gderex8@orange.fr
        \\     ⋯⋯⋯⋯⋯
        \\
    );
}
