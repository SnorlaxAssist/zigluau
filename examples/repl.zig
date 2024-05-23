//! Simple Lua interpreter
//! This is a modified program from Programming in Lua 4th Edition

const std = @import("std");

// The ziglua module is made available in build.zig
const zigluau = @import("zigluau");

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    // Initialize The Lua vm and get a reference to the main thread
    //
    // Passing a Zig allocator to the Lua state requires a stable pointer
    var lua = try zigluau.Luau.init(&allocator);
    defer lua.deinit();

    // Open all Lua standard libraries
    lua.openLibs();

    var stdin = std.io.getStdIn().reader();
    var stdout = std.io.getStdOut().writer();

    var buffer: [256]u8 = undefined;
    while (true) {
        _ = try stdout.write("> ");

        // Read a line of input
        const len = try stdin.read(&buffer);
        if (len == 0) break; // EOF
        if (len >= buffer.len - 1) {
            try stdout.print("error: line too long!\n", .{});
            continue;
        }

        // Ensure the buffer is null-terminated so the Lua API can read the length
        buffer[len] = 0;

        // Compile a line of Luau code
        const bytecode = try zigluau.compile(allocator, buffer[0..len :0], .{});
        lua.loadBytecode("CLI", bytecode) catch |err| switch (err) {
            error.Fail => {
                // If there was an error, Lua will place an error string on the top of the stack.
                // Here we print out the string to inform the user of the issue.
                try stdout.print("{s}\n", .{lua.toString(-1) catch unreachable});

                // Remove the error from the stack and go back to the prompt
                lua.pop(1);
                return;
            },
            else => unreachable,
        };
        allocator.free(bytecode);

        // Execute a line of Lua code
        lua.pcall(0, 0, 0) catch {
            // Error handling here is the same as above.
            try stdout.print("{s}\n", .{lua.toString(-1) catch unreachable});
            lua.pop(1);
        };
    }
}
