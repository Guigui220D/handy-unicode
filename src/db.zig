const std = @import("std");
const sqlite = @import("sqlite");

pub fn main() !void {
    const db = try sqlite.SQLite.open("unicode.db");
    defer db.close() catch unreachable;

    var rows = db.exec(
        \\ CREATE TABLE chars (
        \\     id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\     codepoint INTEGER NOT NULL,
        \\     name TEXT NOT NULL,
        \\     user_notes TEXT
        \\ );
    );
}