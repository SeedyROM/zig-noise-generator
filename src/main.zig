const std = @import("std");
const dvui = @import("dvui");

const audio = @import("audio.zig");
const Ui = @import("ui.zig").Ui;

pub fn main() !void {
    // Setup the global allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    // Setup the audio thread message queue.
    var audio_msg_queue = audio.MsgQueue.init(allocator);
    defer audio_msg_queue.deinit();
    // Start the audio thread
    _ = try std.Thread.spawn(.{ .allocator = allocator }, audio.thread, .{&audio_msg_queue});

    // Create the UI
    var ui = try Ui.init(allocator);
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
