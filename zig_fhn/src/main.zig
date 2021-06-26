// no native support to https
const Client = @import("requestz").Client;
const std = @import("std");

const memory_size = 80 * 1024 * 1024; // 80 MB

fn print(comptime fmt: []const u8, args: anytype) void {
    const stdout = std.io.getStdOut().writer();
    stdout.print(fmt, args) catch unreachable;
}

const stories_url = "https://hacker-news.firebaseio.com/v0/topstories.json";
const item_base_url = "https://hacker-news.firebaseio.com/v0/item/";
const stories_limit = 500;

pub fn main() !void {
    // allocator
    // const page_allocator = &std.heap.c_allocator;
    const page_allocator = &std.heap.page_allocator;
    var buffer = try page_allocator.*.alloc(u8, 80 * 1024 * 1024);
    defer page_allocator.*.free(buffer);
    const fixed_allocator = &std.heap.FixedBufferAllocator.init(buffer).allocator;
    var arena = std.heap.ArenaAllocator.init(fixed_allocator);
    defer arena.deinit();
    var allocator = &arena.allocator;

    var client = try Client.init(allocator);
    defer client.deinit();
    var response = try client.get(stories_url, .{});

    print("{}\n", .{response.status});
    defer response.deinit();
}
