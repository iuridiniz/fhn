const std = @import("std");

pub const iguana = std.build.Pkg{
    .name = "iguana",
    .path = "3rd/iguanaTLS/src/main.zig",
    .dependencies = null,
};

pub const ssl = std.build.Pkg{
    .name = "ssl",
    .path = "3rd/ziget/iguana/ssl.zig",
    .dependencies = &[_]std.build.Pkg{
        iguana,
    },
};

pub const ziget = std.build.Pkg{
    .name = "ziget",
    .path = "3rd/ziget/ziget.zig",
    .dependencies = &[_]std.build.Pkg{
        ssl,
    },
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
    exe.setTarget(target);
    exe.linkSystemLibrary("c");
    exe.setBuildMode(mode);
    exe.addPackage(ziget);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
