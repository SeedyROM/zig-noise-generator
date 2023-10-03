const std = @import("std");
const dvui = @import("dvui");
const UiBackend = @import("dvui-backend");

pub const Ui = struct {
    const Self = @This();

    arena: std.heap.ArenaAllocator,

    backend: UiBackend,
    window: dvui.Window,

    frame_start: i128,
    frame_end: ?u32,

    pub fn init(allocator: std.mem.Allocator, backend: UiBackend, window: dvui.Window) !Self {
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

    pub fn clear(self: *Self) void {
        self.backend.clear();
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

const AudioParam = union(enum) {
    amplitude: f32,
    frequency: f32,
};

const AudioMsg = union(enum) {
    play,
    stop,
    param: AudioParam,
};

fn MsgQueue(comptime T: type) type {
    return struct {
        const Self = @This();
        const Queue = std.atomic.Queue(T);

        allocator: std.mem.Allocator,
        queue: Queue,

        /// Create a new message queue using the given allocator.
        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{
                .allocator = allocator,
                .queue = Queue.init(),
            };
        }

        /// Dealloc all messages left in the queue.
        pub fn deinit(self: *Self) void {
            while (true) {
                var msg = self.queue.get();
                if (msg == null) {
                    break;
                }
                self.allocator.destroy(msg.?);
            }
        }

        /// Add a message to the queue.
        pub fn put(self: *Self, msg: T) !void {
            const node = try self.allocator.create(Queue.Node);
            node.* = .{
                .data = msg,
                .prev = undefined,
                .next = undefined,
            };
            self.queue.put(node);
        }

        /// Get the next message from the queue.
        pub fn get(self: *Self) ?*Queue.Node {
            var node = self.queue.get();
            return node;
        }

        /// Deallocate a node
        pub fn free(self: *Self, node: *Queue.Node) void {
            self.allocator.destroy(node);
        }
    };
}

pub fn main() !void {
    // Setup the global allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    // Setup the audio thread message queue.
    var audio_msg_queue = MsgQueue(AudioMsg).init(allocator);
    defer audio_msg_queue.deinit();
    // Start the audio thread
    _ = try std.Thread.spawn(.{ .allocator = allocator }, audio, .{&audio_msg_queue});

    // Create the backend
    std.log.info("Creating backend", .{});
    var backend = try UiBackend.init(.{
        .width = 500,
        .height = 300,
        .title = "Hello World",
        .vsync = true,
    });

    // Create the window
    std.log.info("Creating window", .{});
    var window = try dvui.Window.init(@src(), 0, allocator, backend.backend());
    window.theme = &dvui.Adwaita.dark;

    // Create the UI
    var ui = try Ui.init(allocator, backend, window);
    // Defer the UI deinit
    defer ui.deinit();

    // Program state
    var amplitude_value: f32 = 0.9;
    var frequency_value: f32 = 0.5;

    // Draw the UI
    while (true) {
        ui.clear();

        try ui.beginFrame();
        if (try ui.shouldQuit()) {
            break;
        }

        {
            const box_margin = .{ .x = 16, .y = 16, .w = 16, .h = 16 };

            var box = try dvui.box(@src(), .vertical, .{ .expand = .both, .color_style = .window, .margin = box_margin });
            defer box.deinit();

            try dvui.label(@src(), "Amplitude", .{}, .{ .expand = .horizontal });
            if (try dvui.slider(@src(), .horizontal, &amplitude_value, .{ .expand = .horizontal })) {
                try audio_msg_queue.put(.{ .param = .{ .amplitude = amplitude_value } });
            }

            try dvui.label(@src(), "Frequency", .{}, .{ .expand = .horizontal });
            if (try dvui.slider(@src(), .horizontal, &frequency_value, .{ .expand = .horizontal })) {
                try audio_msg_queue.put(.{ .param = .{ .frequency = frequency_value } });
            }

            {
                var v_box = try dvui.box(@src(), .horizontal, .{ .expand = .horizontal, .margin = box_margin });
                defer v_box.deinit();

                if (try dvui.button(@src(), "Play", .{ .expand = .horizontal })) {
                    try audio_msg_queue.put(.play);
                }
                if (try dvui.button(@src(), "Stop", .{ .expand = .horizontal })) {
                    try audio_msg_queue.put(.stop);
                }
            }
        }

        try ui.endFrame();
        try ui.render();
        try ui.waitNextFrame();
    }

    std.log.info("Exiting", .{});

    // TODO(SeedyROM): Put me back!!!
    // _ = gpa.deinit();
}

fn audio(msgs: *MsgQueue(AudioMsg)) !void {
    std.log.info("Audio thread started", .{});

    const State = struct {
        amplitude: f32,
        frequency: f32,
    };

    var state = State{
        .amplitude = 0.0,
        .frequency = 0.0,
    };

    while (true) {
        var next = msgs.get();
        if (next != null) {
            defer msgs.free(next.?);
            var msg = next.?.data;
            switch (msg) {
                .play => {
                    std.log.debug("Audio thread: play", .{});
                },
                .stop => {
                    std.log.debug("Audio thread: stop", .{});
                },
                .param => |param| {
                    switch (param) {
                        .amplitude => |amplitude| {
                            std.log.debug("Audio thread: amplitude {d}", .{amplitude});
                            state.amplitude = amplitude;
                        },
                        .frequency => |frequency| {
                            std.log.debug("Audio thread: frequency {d}", .{frequency});
                            state.frequency = frequency;
                        },
                    }
                },
            }
        }

        // Sleep for a bit to make sure the main thread has time to join.
        std.time.sleep(10 * 1000);
    }
}
