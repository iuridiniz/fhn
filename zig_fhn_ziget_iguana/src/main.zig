const std = @import("std");
const ziget = @import("ziget");

const stories_url = "https://hacker-news.firebaseio.com/v0/topstories.json";
const item_base_url = "https://hacker-news.firebaseio.com/v0/item";
const stories_limit = 500;

const Story = struct {
    // by: []u8 = "",
    // descendants: u32 = 0,
    id: u32 = 0,
    // kids: []u32,
    // score: u32 = 0,
    // time: u32 = 0,
    title: ?[]u8 = null,
    // type: u8[] = "",
    url: ?[]u8 = null,
    number: u32 = 0,
    fetched: bool = false,
};

var stdout_lock = std.Thread.Mutex.AtomicMutex{};

fn print(comptime fmt: []const u8, args: anytype) void {
    var hold = stdout_lock.acquire();
    defer hold.release();
    const stdout = std.io.getStdOut().writer();
    stdout.print(fmt, args) catch unreachable;
}

fn no_op(_: []const u8) void {}

const Shared = struct {
    ids: []const u32,
    cursor_ids: u32,
    lock: std.Thread.Mutex.AtomicMutex,
    allocator: *std.mem.Allocator,
};

fn fetch_worker(sh: *Shared) void {
    var allocator = sh.allocator;
    // const allocator = ok: {
    //     var buffer: [200 * 1024]u8 = undefined;
    //     var fba = std.heap.FixedBufferAllocator.init(&buffer);
    //     break :ok &fba.allocator;
    // };
    while (true) {
        var i: u32 = undefined;
        {
            var lock = sh.lock.acquire();
            defer lock.release();
            i = sh.cursor_ids;
            if (i >= sh.ids.len) {
                break;
            }
            sh.cursor_ids += 1;
        }
        var story = Story{
            .number = i + 1,
            .id = sh.ids[i],
        };

        const raw_url = std.fmt.allocPrint(
            allocator,
            "{s}/{d}.json?print=pretty",
            .{ item_base_url, sh.ids[i] },
        ) catch |err| {
            print("error: {any}\n", .{err});

            continue;
        };
        defer allocator.free(raw_url);

        const url = ziget.url.parseUrl(raw_url) catch |err| {
            print("error: {any}\n", .{err});
            continue;
        };
        var downloadState = ziget.request.DownloadState.init();

        const options = ziget.request.DownloadOptions{
            .flags = 0,
            .allocator = allocator,
            .maxRedirects = 0,
            .forwardBufferSize = 8192,
            .maxHttpResponseHeaders = 8192,
            .onHttpRequest = no_op,
            .onHttpResponse = no_op,
        };

        var text = std.ArrayList(u8).init(allocator);
        defer text.deinit();

        ziget.request.download(url, text.writer(), options, &downloadState) catch |err| {
            print("error: {any}\n", .{err});
            continue;
        };

        // Parse json
        var stream = std.json.TokenStream.init(text.items);
        var fetched_story = std.json.parse(Story, &stream, .{
            .allocator = allocator,
            .ignore_unknown_fields = true,
        }) catch |err| {
            print("error: {any}\n", .{err});
            continue;
        };
        defer {
            std.json.parseFree(Story, fetched_story, .{
                .allocator = allocator,
                .ignore_unknown_fields = true,
            });
        }

        story.title = fetched_story.title;
        story.url = fetched_story.url;
        story.fetched = true;

        print(
            \\ [{d}/{d}] id: {d}
            \\         title: {s}
            \\         url: {s}
            \\
            \\
        , .{
            story.number,
            sh.ids.len,
            story.id,
            story.title,
            story.url,
        });
    }
}

pub fn main() anyerror!void {
    const allocator = std.heap.page_allocator;

    var limit: usize = stories_limit;
    var num_threads: usize = 10;

    var args = try std.process.argsAlloc(allocator);
    defer allocator.free(args);

    if (args.len > 1) {
        var arg_str = args[1];
        var stream = std.json.TokenStream.init(arg_str);
        var arg_int = try std.json.parse(u32, &stream, .{});
        if (arg_int >= 0) {
            limit = arg_int;
        }
    }

    if (args.len > 2) {
        var arg_str = args[2];
        var stream = std.json.TokenStream.init(arg_str);
        var arg_int = try std.json.parse(u32, &stream, .{});
        if (arg_int >= 0) {
            num_threads = arg_int;
        }
    }

    const url = try ziget.url.parseUrl(stories_url);

    const options = ziget.request.DownloadOptions{
        .flags = 0,
        .allocator = allocator,
        .maxRedirects = 0,
        .forwardBufferSize = 8192,
        .maxHttpResponseHeaders = 8192,
        .onHttpRequest = no_op,
        .onHttpResponse = no_op,
    };
    var downloadState = ziget.request.DownloadState.init();

    var text = std.ArrayList(u8).init(allocator);
    defer text.deinit();

    try ziget.request.download(url, text.writer(), options, &downloadState);

    // Parse json
    var stream = std.json.TokenStream.init(text.items);
    const ids = try std.json.parse([]u32, &stream, .{ .allocator = allocator });
    defer std.json.parseFree([]u32, ids, .{
        .allocator = allocator,
        .ignore_unknown_fields = true,
    });

    if (limit > ids.len) {
        limit = ids.len;
    }

    if (num_threads > limit) {
        num_threads = limit;
    }

    var threads = std.ArrayList(*std.Thread).init(allocator);
    defer threads.deinit();
    try threads.ensureCapacity(num_threads);

    var sh = &Shared{
        .lock = std.Thread.Mutex.AtomicMutex{},
        .ids = ids[0..limit],
        .cursor_ids = 0,
        .allocator = allocator,
    };
    {
        var i: usize = 0;
        while (i < num_threads) : (i += 1) {
            var thread: *std.Thread = try std.Thread.spawn(fetch_worker, sh);
            try threads.append(thread);
        }
    }
    // wait for threads done
    {
        var i: usize = 0;
        while (i < num_threads) : (i += 1) {
            threads.items[i].*.wait();
        }
    }
    print("end\n", .{});
}
