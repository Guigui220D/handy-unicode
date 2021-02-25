const std = @import("std");
const sqlite = @import("sqlite");

const db_file_name = "codes.db";
var database: sqlite.SQLite = undefined;

pub fn checkDbExists() !bool {
    //Checks if program has access to the db file/if it exists
    if (std.fs.cwd().access(db_file_name, .{ .read = true, .write = true })) {
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
        \\     standard_notes TEXT,
        \\     times_used INTEGER DEFAULT 0
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

        //std.debug.print("{s}\n", .{utf8[0..i]});
        var request = try std.fmt.bufPrint(buf2[0..1023], "INSERT INTO chars(utf8, name) VALUES (X'{x}', '{s}');", .{ utf8[0..i], name });
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

var query: ?[]const u8 = null;
var page: usize = 0;
var search: ?[]const u8 = null;

var result_ids: [8]c_int = undefined;
var result_count: usize = 0;

pub fn setSearch(allocator: *std.mem.Allocator, word: []u8) !void {
    deallocSearch(allocator);
    page = 0;
    search = try allocator.dupe(u8, word);
}

pub fn nextPage() void {
    page += 1;
}

fn prepareQuery(allocator: *std.mem.Allocator) !void {
    const stderr = std.io.getStdErr().writer();

    if (search == null)
        return error.noSearch;

    deallocQuery(allocator);
    //TODO: this is just a prototype
    var temp = try allocator.alloc(u8, std.mem.replacementSize(u8, search.?, "\x0D", ""));
    defer allocator.free(temp);

    _ = std.mem.replace(u8, search.?, "\x0D", "", temp);

    query = try std.fmt.allocPrint(allocator, 
        \\SELECT utf8, name, times_used, id
        \\FROM chars 
        \\WHERE name LIKE '%{s}%' 
        \\ORDER BY times_used DESC
        \\LIMIT 8
        \\OFFSET {}
        \\{c}
        , .{ temp, page * 8, 0 });
}

pub fn deallocQuery(allocator: *std.mem.Allocator) void {
    if (query) |s|
        allocator.free(s);
    query = null;
}

pub fn deallocSearch(allocator: *std.mem.Allocator) void {
    if (search) |s|
        allocator.free(s);
    search = null;
}

pub fn runQuery(allocator: *std.mem.Allocator) !void {
    try prepareQuery(allocator);
    //std.debug.print("query: {s}\n", .{query});
    var rows = database.exec(std.mem.spanZ(@ptrCast([*:0]const u8, query.?.ptr)));

    var selector: usize = 0;
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

        const utf8 = row.columnText(0);
        const name = row.columnText(1);
        const used = row.columnInt(2);
        const id = row.columnInt(3);

        if (utf8.len == 1 and std.ascii.isCntrl(utf8[0])) {
            if (used != 0) {
                std.debug.warn("{} - [cntrl]: {s} (used {} times)\n", .{ selector + 1, name, used });
            } else {
                std.debug.warn("{} - [cntrl]: {s} (never used)\n", .{ selector + 1, name });
            }
        } else {
            if (used != 0) {
                std.debug.warn("{} - {s}: {s} (used {} times)\n", .{ selector + 1, utf8, name, used });
            } else {
                std.debug.warn("{} - {s}: {s} (never used)\n", .{ selector + 1, utf8, name });
            }
        }

        std.debug.assert(selector < 8);
        result_ids[selector] = id;

        selector += 1;
    }

    result_count = selector;

    if (selector == 0) {
        if (page != 0) {
            std.debug.warn("No more results!\n", .{});
            page = 0;
        } else
            std.debug.warn("Nothing found.\n", .{});
    }
}

pub fn select(index: u3) !void {
    if (index < result_count) {
        const id = result_ids[index];
        var found = false;
        var ans = try database.execBind("UPDATE chars SET times_used = times_used + 1 WHERE id == ?;", .{id});
        while (ans.next()) |t| {
            const row = switch (t) {
                .Error => |e| {
                    std.debug.warn("sqlite3 errmsg: {s}\n", .{database.errmsg()});
                    return e;
                },
                else => continue,
            };
        }
        ans = try database.execBind("SELECT utf8 FROM chars WHERE id == ?;", .{id});
        while (ans.next()) |t| {
            const row = switch (t) {
                .Error => |e| {
                    std.debug.warn("sqlite3 errmsg: {s}\n", .{database.errmsg()});
                    return e;
                },
                .Row => |r| r,
                .Done => continue,
            };

            std.debug.assert(!found);
            found = true;
            std.debug.warn("'{s}' copied to clipboard! (actually, this is not implemented)\n", .{row.columnText(0)});
        }
        return;
    } else return error.doesNotExist;
}