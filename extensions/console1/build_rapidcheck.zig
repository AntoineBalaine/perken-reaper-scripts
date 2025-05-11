const std = @import("std");

pub const RapidcheckBuildOptions = struct {
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    enable_rtti: bool = true,
};

/// Compiles RapidCheck and adds object files to the test executable
pub fn compileRapidcheck(
    b: *std.Build,
    test_exe: *std.Build.Step.Compile,
    rapidcheck_dep: *std.Build.Dependency,
    options: RapidcheckBuildOptions,
) !void {
    // Define standard compiler flags
    const std_flags = [_][]const u8{
        if (options.target.result.os.tag == .macos) "clang" else "gcc",
        "-c",
        "-fPIC",
        "-std=c++14",
        b.fmt("-I{s}", .{rapidcheck_dep.path("include").getPath(b)}),
        "-Wall",
        "-Wno-missing-braces",
        "-Wno-unused-command-line-argument",
        if (options.target.result.os.tag == .macos) "-stdlib=libc++" else "",
        if (!options.enable_rtti) "-DRC_DONT_USE_RTTI" else "",
        if (options.target.result.isMinGW()) "-DRC_SEED_SYSTEM_TIME" else "",
        "-O2",
        "-o",
    };

    // Define high-optimization flags for Random.cpp
    const opt_flags = [_][]const u8{
        if (options.target.result.os.tag == .macos) "clang" else "gcc",
        "-c",
        "-fPIC",
        "-std=c++14",
        b.fmt("-I{s}", .{rapidcheck_dep.path("include").getPath(b)}),
        "-Wall",
        "-Wno-missing-braces",
        "-Wno-unused-command-line-argument",
        if (options.target.result.os.tag == .macos) "-stdlib=libc++" else "",
        if (!options.enable_rtti) "-DRC_DONT_USE_RTTI" else "",
        if (options.target.result.isMinGW()) "-DRC_SEED_SYSTEM_TIME" else "",
        "-O3", // Higher optimization for Random.cpp
        "-o",
    };

    // RapidCheck source files list based on CMakeLists.txt
    const rc_source_files = [_][]const u8{
        "src/BeforeMinimalTestCase.cpp",
        "src/Check.cpp",
        "src/Classify.cpp",
        "src/GenerationFailure.cpp",
        "src/Log.cpp",
        "src/Random.cpp", // Will be handled separately for high optimization
        "src/Show.cpp",
        "src/detail/Any.cpp",
        "src/detail/Assertions.cpp",
        "src/detail/Base64.cpp",
        "src/detail/Configuration.cpp",
        "src/detail/DefaultTestListener.cpp",
        "src/detail/FrequencyMap.cpp",
        "src/detail/ImplicitParam.cpp",
        "src/detail/LogTestListener.cpp",
        "src/detail/MapParser.cpp",
        "src/detail/MulticastTestListener.cpp",
        "src/detail/ParseException.cpp",
        "src/detail/Platform.cpp",
        "src/detail/Property.cpp",
        "src/detail/PropertyContext.cpp",
        "src/detail/ReproduceListener.cpp",
        "src/detail/Results.cpp",
        "src/detail/Serialization.cpp",
        "src/detail/StringSerialization.cpp",
        "src/detail/TestMetadata.cpp",
        "src/detail/TestParams.cpp",
        "src/detail/Testing.cpp",
        "src/gen/Numeric.cpp",
        "src/gen/Text.cpp",
        "src/gen/detail/ExecHandler.cpp",
        "src/gen/detail/GenerationHandler.cpp",
        "src/gen/detail/Recipe.cpp",
        "src/gen/detail/ScaleInteger.cpp",
    };

    // Compile RapidCheck files with special handling for Random.cpp
    for (rc_source_files) |rc_src| {
        const rc_src_path = rapidcheck_dep.path(rc_src);
        const basename = std.fs.path.basename(rc_src);
        const filearg = std.fmt.allocPrint(
            b.allocator,
            "rc_{s}.o",
            .{basename},
        ) catch unreachable;

        // Select appropriate flags based on the file
        const flags = if (std.mem.eql(u8, basename, "Random.cpp"))
            &opt_flags
        else
            &std_flags;

        const cxx = b.addSystemCommand(flags);
        test_exe.addObjectFile(cxx.addOutputFileArg(filearg));
        cxx.addFileArg(rc_src_path);
    }

    // Handle external dependencies in ext/
    const catch_include_path = rapidcheck_dep.path("ext/catch/include");
    test_exe.addIncludePath(catch_include_path);
}

/// Add RapidCheck include path to an executable or library
pub fn addRapidcheckInclude(
    artifact: *std.Build.Step.Compile,
    rapidcheck_dep: *std.Build.Dependency,
) void {
    artifact.addIncludePath(rapidcheck_dep.path("include"));
}
