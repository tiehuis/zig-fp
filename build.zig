const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // fp.zig library
    const option_use_legacy_exponent_form = b.option(
        bool,
        "use-legacy-exponent-form",
        "use legacy exponent form for compatibility",
    ) orelse false;
    const option_use_fast_trim_zeros = b.option(
        bool,
        "use-fast-trim-zeros",
        "use fast trim zeros for formatting",
    ) orelse false;
    const option_use_compact_tables = b.option(
        bool,
        "use-compact-tables",
        "use compact tables",
    ) orelse false;

    const build_options = b.addOptions();
    build_options.addOption(bool, "use_legacy_exponent_form", option_use_legacy_exponent_form);
    build_options.addOption(bool, "use_fast_trim_zeros", option_use_fast_trim_zeros);
    build_options.addOption(bool, "use_compact_tables", option_use_compact_tables);

    const fp_mod = b.createModule(.{
        .root_source_file = b.path("fp.zig"),
        .target = target,
        .optimize = optimize,
    });
    fp_mod.addOptions("build_options", build_options);

    // extra/main_perf.zig
    const perf_mod = b.createModule(.{
        .root_source_file = b.path("extra/main_perf.zig"),
        .target = target,
        .optimize = optimize,
    });
    perf_mod.addImport("fp", fp_mod);

    const perf_exe = b.addExecutable(.{
        .name = "perf",
        .root_module = perf_mod,
    });

    const perf_run = b.addRunArtifact(perf_exe);
    if (b.args) |args| perf_run.addArgs(args);

    const perf_step = b.step("perf", "run performance tests");
    perf_step.dependOn(&perf_run.step);

    // extra/main_fuzz.zig
    const fuzz_mod = b.createModule(.{
        .root_source_file = b.path("extra/main_fuzz.zig"),
        .target = target,
        .optimize = optimize,
    });
    fuzz_mod.addImport("fp", fp_mod);

    const fuzz_exe = b.addExecutable(.{
        .name = "fuzz",
        .root_module = fuzz_mod,
    });

    const fuzz_run = b.addRunArtifact(fuzz_exe);
    fuzz_run.addFileArg(b.path("uscale.c"));
    if (b.args) |args| fuzz_run.addArgs(args);

    const fuzz_step = b.step("fuzz", "run fuzzing tests");
    fuzz_step.dependOn(&fuzz_run.step);

    // size command
    const bloaty = b.findProgram(&.{"bloaty"}, &.{}) catch {
        std.debug.print("bloaty not found in PATH", .{});
        return;
    };

    // force x86_64 linux since bloaty does not work with other archs
    const size_target = b.resolveTargetQuery(.{ .cpu_arch = .x86_64, .os_tag = .linux });

    const fp_size_mod = b.createModule(.{
        .root_source_file = b.path("extra/export_zig_fp.zig"),
        .target = size_target,
        .optimize = optimize,
    });
    fp_size_mod.addImport("fp", fp_mod);

    const fp_size_lib = b.addLibrary(.{
        .name = "export_zig_fp",
        .root_module = fp_size_mod,
        .linkage = .static,
    });

    const fp_size_step = b.step("size-fp", "build fp size artifacts and run bloaty");
    const bloaty_fp = b.addSystemCommand(&.{bloaty});
    bloaty_fp.addArtifactArg(fp_size_lib);
    fp_size_step.dependOn(&bloaty_fp.step);

    const std_size_mod = b.createModule(.{
        .root_source_file = b.path("extra/export_zig_std.zig"),
        .target = size_target,
        .optimize = optimize,
    });

    const std_size_lib = b.addLibrary(.{
        .name = "export_zig_std",
        .root_module = std_size_mod,
        .linkage = .static,
    });

    const std_size_step = b.step("size-std", "build std size artifacts and run bloaty");
    const bloaty_std = b.addSystemCommand(&.{bloaty});
    bloaty_std.addArtifactArg(std_size_lib);
    std_size_step.dependOn(&bloaty_std.step);
}
