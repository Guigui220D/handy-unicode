const std = @import("std");
const builtin = @import("builtin");

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

    const cf_text_format: c_uint = 1;
    const gmem_moveable: c_uint = 2;
};

extern "c" fn system([*:0]const u8) c_int;

pub fn unused(allocator: *std.mem.Allocator, text: []const u8) !void {
    if (builtin.os.tag != .windows)
        @compileError("Not implemented for other things than windows\n");
    //NO, BAD SOLUTION
    {
        var temp = try std.fs.cwd().openFile("tmp.tmp", .{.write = true});
        defer temp.close();

        try temp.writeAll(text);
    }

    if (system("clip tmp.tmp") != 0)
        return error.CopyFailed;
}

pub fn putInClipboard(allocator: *std.mem.Allocator, text: []const u8) !void {
    if (builtin.os.tag == .windows) {
        //var utf16 = try std.unicode.utf8ToUtf16LeWithNull(allocator, text);
        //defer allocator.free(utf16);
        //std.debug.print("utf16: {s}\n", .{std.mem.toBytes(utf16)});

        //Null terminator stuff :/
        var len: usize = text.len + 1;
        var ptr = win.GlobalAlloc(win.gmem_moveable, len) orelse return error.WinMemFail;

        ptr = win.GlobalLock(ptr) orelse {
            std.debug.print("Win Error: {}\n", .{win.GetLastError()});
            return error.WinError;
        };
        
        @memcpy(@ptrCast([*]u8, ptr), text.ptr, text.len);
        @ptrCast([*]u8, ptr)[len] = 0;

        if (win.GlobalUnlock(ptr) == 0) {
            if (win.GetLastError() != 0) {
                std.debug.print("Win Error: {}\n", .{win.GetLastError()});
                return error.WinError;
            }
        }

        //I hate the windows api
        if (win.OpenClipboard(win.GetConsoleWindow().?) == 0) {
            std.debug.print("Win Error: {}\n", .{win.GetLastError()});
            return error.WinError;
        }
        
        defer _ = win.CloseClipboard();

        if (win.EmptyClipboard() == 0) {
            std.debug.print("Win Error: {}\n", .{win.GetLastError()});
            return error.WinError;
        }

        if (win.SetClipboardData(win.cf_text_format, ptr) == null) {
            std.debug.print("Win Error: {}\n", .{win.GetLastError()});
            return error.CouldntCopy;
        }
    } else @compileError("Clipboard actions are not implemented yet for anything other than windows.");
}