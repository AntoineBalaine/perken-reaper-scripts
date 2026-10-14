const std = @import("std");
const reaziglib = @import("reaziglib");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const reazig_dep = b.dependency("reaziglib", .{ .target = target, .optimize = optimize });
    const ini_dep = b.dependency("ini", .{ .target = target, .optimize = optimize });
    const qm_dep = b.dependency("qm_dsp", .{});

    const strip = b.option(bool, "strip", "strip debug info") orelse (optimize != .Debug);
    // The release version, baked into the binary so that it knows which
    // release it came from. CI passes it from the <name>-v<version> tag.
    const version = b.option([]const u8, "version", "Version string baked into the binary") orelse "dev";
    const build_options = b.addOptions();
    build_options.addOption([]const u8, "version", version);

    const lib = b.addSharedLibrary(.{
        .name = "reaper_cajun_extensions",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .strip = strip,
    });
    lib.linkLibC();
    reaziglib.addSharedModules(reazig_dep, lib.root_module);
    reaziglib.addCsurf(b, reazig_dep, lib);
    addBeatTracker(b, qm_dep, lib);
    lib.root_module.addImport("ini", ini_dep.module("ini"));
    lib.root_module.addOptions("build_options", build_options);

    const ext = switch (target.result.os.tag) {
        .macos => "dylib",
        .windows => "dll",
        else => "so",
    };
    const dest = b.fmt("reaper_cajun_extensions.{s}", .{ext});
    const install = b.addInstallArtifact(lib, .{ .dest_dir = .{ .override = .{ .custom = "" } }, .dest_sub_path = dest });
    b.getInstallStep().dependOn(&install.step);

    const test_exe = b.addTest(.{
        .name = "cajun_extensions_tests",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = .Debug,
    });
    test_exe.linkLibC();
    reaziglib.addSharedModules(reazig_dep, test_exe.root_module);
    reaziglib.addCsurf(b, reazig_dep, test_exe);
    addBeatTracker(b, qm_dep, test_exe);
    test_exe.root_module.addImport("ini", ini_dep.module("ini"));
    test_exe.root_module.addOptions("build_options", build_options);

    // Development tool: the beat tracker on a WAV file, outside REAPER
    // (`zig build analyze -- file.wav`).
    const analyze = b.addExecutable(.{
        .name = "analyze",
        .root_source_file = b.path("tools/analyze.zig"),
        .target = target,
        .optimize = .ReleaseSafe,
    });
    analyze.linkLibC();
    analyze.root_module.addImport("beat", b.createModule(.{ .root_source_file = b.path("src/beat/beat.zig") }));
    analyze.root_module.addImport("grid", b.createModule(.{ .root_source_file = b.path("src/beat/grid.zig") }));
    addBeatTracker(b, qm_dep, analyze);
    const run_analyze = b.addRunArtifact(analyze);
    if (b.args) |args| run_analyze.addArgs(args);
    const analyze_step = b.step("analyze", "Run the beat tracker on a WAV file: zig build analyze -- file.wav");
    analyze_step.dependOn(&run_analyze.step);

    const run_test = b.addRunArtifact(test_exe);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_test.step);
}

/// The qm-dsp sources the bar and beat tracker needs: onset detection, the
/// tempo tracker, downbeat detection and their dependencies (kissfft is C).
const qm_sources = [_][]const u8{
    "dsp/onsets/DetectionFunction.cpp",
    "dsp/tempotracking/TempoTrackV2.cpp",
    "dsp/tempotracking/DownBeat.cpp",
    "dsp/phasevocoder/PhaseVocoder.cpp",
    "dsp/transforms/FFT.cpp",
    "maths/MathUtilities.cpp",
    "dsp/rateconversion/Decimator.cpp",
    "ext/kissfft/kiss_fft.c",
    "ext/kissfft/tools/kiss_fftr.c",
};

/// qm-dsp's own build defines kiss_fft_scalar=double. Its warnings are not
/// ours to fix, so they are silenced. On MSVC, M_PI needs
/// _USE_MATH_DEFINES and the standard library needs exception handling.
const qm_flags = reaziglib.CxxFlags{
    .gnu = &.{ "-Dkiss_fft_scalar=double", "-fvisibility=hidden", "-w" },
    .msvc = &.{ "/Dkiss_fft_scalar=double", "/D_USE_MATH_DEFINES", "/EHsc", "/w" },
};

/// Adds the beat tracker to an artifact: the qm-dsp sources and the C bridge
/// (src/beat/qm_bridge.cpp), compiled with REAPER's toolchain like all C++ in
/// this repository, and the matching C++ runtime.
pub fn addBeatTracker(b: *std.Build, qm_dep: *std.Build.Dependency, compile: *std.Build.Step.Compile) void {
    const target = compile.rootModuleTarget();
    const includes = [_]std.Build.LazyPath{
        qm_dep.path(""),
        qm_dep.path("ext/kissfft"),
        qm_dep.path("ext/kissfft/tools"),
        b.path("src/beat"),
    };
    for (qm_sources) |src| {
        const name = b.fmt("qm_{s}", .{std.fs.path.stem(src)});
        compile.addObjectFile(reaziglib.reaperCxxObject(b, target, qm_dep.path(src), &includes, qm_flags, name));
    }
    compile.addObjectFile(reaziglib.reaperCxxObject(b, target, b.path("src/beat/qm_bridge.cpp"), &includes, qm_flags, "qm_bridge"));
    reaziglib.linkReaperCxxRuntime(b, compile);
}
