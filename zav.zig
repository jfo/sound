const std = @import("std");

pub fn main() !void {
    const cwd = std.fs.cwd();
    var file = try cwd.createFile("sine.wav", .{});
    _ = try file.write("sdfjio");
    _ = file.close();
    std.debug.print("{}\n{}", .{ cwd, file });
}
