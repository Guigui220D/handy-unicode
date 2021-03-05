const std = @import("std");
const builtin = @import("builtin");

//extern "c" fn system([*:0]const u8) c_int;

pub fn putInClipboard(allocator: *std.mem.Allocator, utf8: []const u8) anyerror!void {
    switch (builtin.os.tag) {
        .windows => try win.putInClipboard(allocator, utf8),
        else => return error.ClipboardNotAvailable,
    }
}

const win = struct {
    extern "user32" fn SetClipboardData(uFormat: c_uint, hMem: ?*c_void) ?*c_void;
    extern "user32" fn OpenClipboard(hWndNewOwner: [*c]c_int) c_int;
    extern "user32" fn CloseClipboard() c_int;
    extern "user32" fn EmptyClipboard() c_int;
    extern "user32" fn GetLastError() c_ulong;

    extern "kernel32" fn GlobalAlloc(uFlags: c_uint, dwBytes: usize) ?*c_void;
    extern "kernel32" fn GlobalLock(hMem: ?*c_void) ?*c_void;
    extern "kernel32" fn GlobalUnlock(hMem: ?*c_void) c_int;
    extern "kernel32" fn GetConsoleWindow() [*c]c_int;

    const cf_text_format: c_uint = 13;
    const gmem_moveable: c_uint = 2;

    fn putInClipboard(allocator: *std.mem.Allocator, utf8: []const u8) !void {
        var utf16 = try std.unicode.utf8ToUtf16LeWithNull(allocator, utf8);
        defer allocator.free(utf16);

        var text: []const u8 = std.mem.sliceAsBytes(utf16);

        //std.debug.print("{} utf16 bytes: {x}\n", .{text.len, text});

        var ptr = win.GlobalAlloc(win.gmem_moveable, text.len + 2) orelse {
            std.debug.warn("Win Error: {}\n", .{win.GetLastError()});
            return error.WinError;
        };

        {
            var buf = win.GlobalLock(ptr) orelse {
                std.debug.warn("Win Error: {}\n", .{win.GetLastError()});
                return error.WinError;
            };

            @memcpy(@ptrCast([*]u8, buf), text.ptr, text.len + 2);
        }

        if (win.GlobalUnlock(ptr) == 0) {
            if (win.GetLastError() != 0) {
                std.debug.warn("Win Error: {}\n", .{win.GetLastError()});
                return error.WinError;
            }
        }

        if (win.OpenClipboard(win.GetConsoleWindow().?) == 0) {
            std.debug.warn("Win Error: {}\n", .{win.GetLastError()});
            return error.WinError;
        }

        defer _ = win.CloseClipboard();

        if (win.EmptyClipboard() == 0) {
            std.debug.warn("Win Error: {}\n", .{win.GetLastError()});
            return error.WinError;
        }

        if (win.SetClipboardData(win.cf_text_format, ptr) == null) {
            std.debug.warn("Win Error: {}\n", .{win.GetLastError()});
            return error.CouldntCopy;
        }
    }
};
