const std = @import("std");

pub const network = std.build.Pkg{
    .name = "network",
    .path = "3rd/zig-network/network.zig",
    .dependencies = null,
};

pub const http = std.build.Pkg{
    .name = "http",
    .path = "3rd/http/src/main.zig",
    .dependencies = null,
};

var h11_dependencies = [_]std.build.Pkg{
    http,
};

pub const h11 = std.build.Pkg{
    .name = "h11",
    .path = "3rd/h11/src/main.zig",
    .dependencies = &h11_dependencies,
};

var requestz_dependencies = [_]std.build.Pkg{
    network,
    h11,
    http,
};

pub const requestz = std.build.Pkg{
    .name = "requestz",
    .path = "3rd/requestz/src/main.zig",
    .dependencies = &requestz_dependencies,
};

pub fn build(b: *std.build.Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("fhn", "src/main.zig");
    exe.addPackage(requestz);
    // exe.linkSystemLibrary("c");

    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
