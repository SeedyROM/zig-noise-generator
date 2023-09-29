const std = @import("std");
const dvui = @import("dvui");

const UI = @import("./ui.zig");

pub fn main() !void {
    // Setup the global allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    // Create the UI
    var ui = try UI.init(allocator, .{
        .width = 800,
        .height = 600,
        .title = "Hello World",
        .vsync = true,
    });
    // Defer the UI deinit
    defer ui.deinit();

    // Draw the UI
    while (!try ui.shouldQuit()) {
        try ui.beginFrame();

        try ui.endFrame();
        try ui.render();
        try ui.waitNextFrame();
    }
}
