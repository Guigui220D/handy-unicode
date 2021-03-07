const std = @import("std");

//This is used to have a digit in front of each result on query
pub fn circledDigit(digit: u3) []const u8 {
    return switch (digit) {
        0 => "➀",
        1 => "➁",
        2 => "➂",
        3 => "➃",
        4 => "➄",
        5 => "➅",
        6 => "➆",
        7 => "➇",
    };
}

pub fn checkQueryWord(slice: []const u8) !void {
    const a = std.ascii;
    for (slice) |c| {
        if (!a.isASCII(c))
            return error.NonAlphaNumChar;
        if (a.isCntrl(c))
            return error.CntrlChar;
        if (!a.isAlNum(c) and c != ' ')
            return error.NonAlphaNumChar;
    }
}
