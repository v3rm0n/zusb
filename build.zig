const std = @import("std");


pub fn build(b: *std.Build) !void {

    _ = b.addModule("zusb", .{
        .root_source_file = b.path("zusb.zig"),
    });
}
