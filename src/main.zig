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

    // Define the UI state
    const UiState = struct {
        playing: bool,
        amplitude: f32,
        frequency: f32,
    };
    // Default UI state
    var ui_state = UiState{ .amplitude = 0.5, .frequency = 0.5, .playing = true };

    // Draw the UI
    while (true) {
        ui.clear();

        try ui.beginFrame();
        if (try ui.shouldQuit()) {
            break;
        }

        // Do our UI in it's own block...
        {
            const box_margin = .{ .x = 16, .y = 16, .w = 16, .h = 16 };

            var box = try dvui.box(@src(), .vertical, .{ .expand = .both, .color_style = .window, .margin = box_margin });
            defer box.deinit();

            try dvui.label(@src(), "Amplitude", .{}, .{ .expand = .horizontal });
            if (try dvui.slider(@src(), .horizontal, &ui_state.amplitude, .{ .expand = .horizontal })) {
                try audio_msg_queue.put(.{ .param = .{ .amplitude = ui_state.amplitude } });
            }

            try dvui.label(@src(), "Frequency", .{}, .{ .expand = .horizontal });
            if (try dvui.slider(@src(), .horizontal, &ui_state.frequency, .{ .expand = .horizontal })) {
                try audio_msg_queue.put(.{ .param = .{ .frequency = ui_state.frequency } });
            }

            {
                var v_box = try dvui.box(@src(), .horizontal, .{ .expand = .horizontal, .margin = box_margin });
                defer v_box.deinit();

                if (try dvui.button(@src(), "Play", .{ .expand = .horizontal })) {
                    if (!ui_state.playing) {
                        try audio_msg_queue.put(.play);
                        ui_state.playing = true;
                    }
                }
                if (try dvui.button(@src(), "Stop", .{ .expand = .horizontal })) {
                    if (ui_state.playing) {
                        try audio_msg_queue.put(.stop);
                        ui_state.playing = false;
                    }
                }
            }
        }

        try ui.endFrame();
        try ui.render();
        try ui.waitNextFrame();
    }

    std.log.info("Exiting", .{});

    // TODO(SeedyROM): Put??? me back!!! I AM BACKKKKKKKKK!!!!
    // _ = gpa.deinit();
}
