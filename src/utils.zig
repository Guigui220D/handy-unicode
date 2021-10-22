const std = @import("std");

//This is used to have a digit in front of each result on query
pub fn circledDigit(digit: u3) []const u8 {
    return switch (digit) {
        0 => "𝟭",
        1 => "𝟮",
        2 => "𝟯",
        3 => "𝟰",
        4 => "𝟱",
        5 => "𝟲",
        6 => "𝟳",
        7 => "𝟴",
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
