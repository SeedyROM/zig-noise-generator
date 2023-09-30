const std = @import("std");
const dvui = @import("dvui");

pub const Ui = struct {
    const Self = @This();
    const UiBackend = @import("dvui-backend");

    arena: std.heap.ArenaAllocator,

    backend: UiBackend,
    window: dvui.Window,

    frame_start: i128,
    frame_end: ?u32,

    pub fn init(allocator: std.mem.Allocator, opts: UiBackend.initOptions) !Self {
        var backend = try UiBackend.init(opts);

        var window = try dvui.Window.init(@src(), 0, allocator, backend.backend());
        window.theme = &dvui.Adwaita.dark;

        var arena = std.heap.ArenaAllocator.init(allocator);

        return Self{
            .arena = arena,
            .backend = backend,
            .window = window,
            .frame_start = 0,
            .frame_end = null,
        };
    }

    pub fn deinit(self: *Self) void {
        self.window.deinit();
        self.backend.deinit();
        self.arena.deinit();
    }

    pub fn beginFrame(self: *Self) !void {
        // Clear the arena
        _ = self.arena.reset(.free_all);

        // Start the frame
        self.frame_start = self.window.beginWait(self.backend.hasEvent());
        try self.window.begin(self.arena.allocator(), self.frame_start);
    }

    pub fn shouldQuit(self: *Self) !bool {
        return try self.backend.addAllEvents(&self.window);
    }

    pub fn endFrame(self: *Self) !void {
        self.frame_end = try self.window.end(.{});
    }

    pub fn render(self: *Self) !void {
        self.backend.setCursor(self.window.cursorRequested());
        self.backend.renderPresent();
    }

    pub fn waitNextFrame(self: *Self) !void {
        const wait_event_micros = self.window.waitTime(self.frame_end, null);
        self.backend.waitEventTimeout(wait_event_micros);
    }
};

pub fn main() !void {
    // Setup the global allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    // Create the UI
    var ui = try Ui.init(allocator, .{
        .width = 1024,
        .height = 768,
        .title = "Hello World",
        .vsync = true,
    });
    // Defer the UI deinit
    defer ui.deinit();

    // Draw the UI
    while (true) {
        try ui.beginFrame();
        if (try ui.shouldQuit()) {
            break;
        }

        try ui.endFrame();
        try ui.render();
        try ui.waitNextFrame();
    }
}
