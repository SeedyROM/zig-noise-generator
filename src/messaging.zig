const std = @import("std");

pub fn Queue(comptime T: type) type {
    return struct {
        const Self = @This();
        const InnerQueue = std.atomic.Queue(T);

        allocator: std.mem.Allocator,
        queue: InnerQueue,

        /// Create a new message queue using the given allocator.
        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{
                .allocator = allocator,
                .queue = InnerQueue.init(),
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
            const node = try self.allocator.create(InnerQueue.Node);
            node.* = .{
                .data = msg,
                .prev = undefined,
                .next = undefined,
            };
            self.queue.put(node);
        }

        /// Get the next message from the queue.
        pub fn get(self: *Self) ?*InnerQueue.Node {
            var node = self.queue.get();
            return node;
        }

        /// Deallocate a node
        pub fn free(self: *Self, node: *InnerQueue.Node) void {
            self.allocator.destroy(node);
        }
    };
}
