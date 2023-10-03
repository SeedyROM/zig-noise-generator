const std = @import("std");

const messaging = @import("messaging.zig");

pub const Param = union(enum) {
    amplitude: f32,
    frequency: f32,
};

pub const Msg = union(enum) {
    play,
    stop,
    param: Param,
};

pub const MsgQueue = messaging.Queue(Msg);

pub fn thread(msgs: *MsgQueue) !void {
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

        // Sleep for a bit to make sure we're not spamming the CPU.
        // TODO: This should be a condition variable.
        std.time.sleep(10 * 1000);
    }
}
