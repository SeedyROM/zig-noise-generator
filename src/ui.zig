const std = @import("std");
const dvui = @import("dvui");

pub const Ui = struct {
    const Self = @This();
    const Backend = @import("dvui-backend");

    var backend: Backend = undefined;
    var window: dvui.Window = undefined;

    arena: std.heap.ArenaAllocator,
    frame_start: i128,
    frame_end: ?u32,

    pub fn init(allocator: std.mem.Allocator) !Self {
        var arena = std.heap.ArenaAllocator.init(allocator);

        // Create the backend
        std.log.info("Creating backend", .{});
        backend = try Backend.init(.{
            .width = 500,
            .height = 300,
            .title = "Hello World",
            .vsync = true,
        });

        // Create the window
        std.log.info("Creating window", .{});
        window = try dvui.Window.init(@src(), 0, allocator, backend.backend());
        window.theme = &dvui.Adwaita.dark;

        return Self{
            .arena = arena,
            .frame_start = 0,
            .frame_end = null,
        };
    }

    pub fn deinit(self: *Self) void {
        window.deinit();
        backend.deinit();
        self.arena.deinit();
    }

    pub fn clear(_: *Self) void {
        backend.clear();
    }

    pub fn beginFrame(self: *Self) !void {
        // Clear the arena
        _ = self.arena.reset(.free_all);

        // Start the frame
        self.frame_start = window.beginWait(backend.hasEvent());
        try window.begin(self.arena.allocator(), self.frame_start);
    }

    pub fn shouldQuit(_: *Self) !bool {
        return try backend.addAllEvents(&window);
    }

    pub fn endFrame(self: *Self) !void {
        self.frame_end = try window.end(.{});
    }

    pub fn render(_: *Self) !void {
        backend.setCursor(window.cursorRequested());
        backend.renderPresent();
    }

    pub fn waitNextFrame(self: *Self) !void {
        const wait_event_micros = window.waitTime(self.frame_end, null);
        backend.waitEventTimeout(wait_event_micros);
    }
};
