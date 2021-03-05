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
