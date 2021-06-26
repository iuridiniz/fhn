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

fn print(comptime fmt: []const u8, args: anytype) void {
    const stdout = std.io.getStdOut().writer();
    stdout.print(fmt, args) catch unreachable;
}

fn no_op(_: []const u8) void {}

const Shared = struct {
    ids: []const u32,
    cursor_ids: u32,
    lock: std.Thread.Mutex.AtomicMutex,
    stories: std.ArrayList(Story),
    cursor_stories: u32,
    allocator: *std.mem.Allocator,
};

fn fetch_worker(sh: *Shared) void {
    // print("Thread {} start\n", .{thread_id});
    // print("Thread {} end\n", .{thread_id});

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

        // push result back to main thread
        defer {
            var lock = sh.lock.acquire();
            defer lock.release();
            sh.stories.append(story) catch unreachable;
            sh.cursor_stories += 1;
        }

        const raw_url = std.fmt.allocPrint(
            sh.allocator,
            "{s}/{d}.json?print=pretty",
            .{ item_base_url, sh.ids[i] },
        ) catch {
            continue;
        };
        defer sh.allocator.free(raw_url);

        const url = ziget.url.parseUrl(raw_url) catch {
            continue;
        };
        var downloadState = ziget.request.DownloadState.init();

        const options = ziget.request.DownloadOptions{
            .flags = 0,
            .allocator = sh.allocator,
            .maxRedirects = 0,
            .forwardBufferSize = 8192,
            .maxHttpResponseHeaders = 8192,
            .onHttpRequest = no_op,
            .onHttpResponse = no_op,
        };

        var text = std.ArrayList(u8).init(sh.allocator);
        defer text.deinit();

        ziget.request.download(url, text.writer(), options, &downloadState) catch {
            continue;
        };

        // print("{s}\n{s}\n ", .{ text.items, url.Http.str });
        // Parse json
        var stream = std.json.TokenStream.init(text.items);
        var fetched_story = std.json.parse(Story, &stream, .{
            .allocator = sh.allocator,
            .ignore_unknown_fields = true,
        }) catch {
            continue;
        };
        // move pointers, remember do free them
        story.title = fetched_story.title;
        story.url = fetched_story.url;
        story.fetched = true;

        // print("{any}\n", .{story});

        // avoid this free, FREE it from main thread
        // defer {
        //     std.json.parseFree(
        //         Story,
        //         fetched_story,
        //         .{
        //             .allocator = sh.allocator,
        //             .ignore_unknown_fields = true,
        //         },
        //     );
        // }
    }
}

pub fn main() anyerror!void {
    // var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    // var arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    // var arena = std.heap.ArenaAllocator.init(ok: {
    //     var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    //     defer std.debug.assert(!gpa.deinit());
    //     break :ok &gpa.allocator;
    // });
    // defer arena.deinit();
    // const allocator = &arena.allocator;

    const allocator = std.heap.c_allocator;
    // const allocator = ok: {
    //     var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    //     defer std.debug.assert(!gpa.deinit());
    //     break :ok &gpa.allocator;
    // };

    // const allocator = ok: {
    //     var buffer: [25 * 1024]u8 = undefined;
    //     var fba = std.heap.FixedBufferAllocator.init(&buffer);
    //     break :ok &fba.allocator;
    // };

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
    // print("{s}\n{s}\n", .{ text.items, url.Http.str });

    // Parse json
    var stream = std.json.TokenStream.init(text.items);
    // print("{}\n", .{stream});
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

    var stories = std.ArrayList(Story).init(allocator);
    defer stories.deinit();
    try stories.ensureCapacity(limit);

    var sh = &Shared{
        .lock = std.Thread.Mutex.AtomicMutex{},
        .ids = ids[0..limit],
        .cursor_ids = 0,
        .stories = stories,
        .cursor_stories = 0,
        .allocator = allocator,
    };
    {
        var i: usize = 0;
        while (i < num_threads) : (i += 1) {
            // print("{any}\n", .{ids[i]});
            var thread: *std.Thread = try std.Thread.spawn(fetch_worker, sh);
            try threads.append(thread);
        }
    }

    // Print from main thread
    {
        var i: usize = 0;

        while (true) {
            if (i >= sh.ids.len) {
                break;
            }

            var stories_done = lock: {
                var hold = sh.lock.acquire();
                defer hold.release();
                var cursor = sh.cursor_stories;
                break :lock cursor;
            };

            var story: Story = undefined;

            if (i < stories_done) {
                var hold = sh.lock.acquire();
                defer hold.release();
                story = sh.stories.items[i];
            } else {
                std.time.sleep(100_000);
                continue;
            }

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
            // free item
            if (story.fetched) {
                std.json.parseFree(Story, story, .{
                    .allocator = sh.allocator,
                    .ignore_unknown_fields = true,
                });
            } else {
                print("------{}--------\n", .{story.number});
            }

            i += 1;
        }
    }
    // wait for threads
    {
        var i: usize = 0;
        while (i < num_threads) : (i += 1) {
            threads.items[i].*.wait();
        }
    }
    print("end\n", .{});
}
