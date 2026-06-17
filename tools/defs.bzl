"""
Rules for compiling shaders, geometry, and textures using bgfx's shaderc, geometryc, and texturec tools.
"""

load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")

def _bgfx_shader_suffix_for_profile(profile):
    """Returns the embedded shader array name suffix for a given shaderc profile.

    Args:
        profile: A shaderc --profile value (e.g. "spirv", "120", "s_5_0").

    Returns:
        The suffix string used in generated bin.h arrays (e.g. "_spv", "_glsl").
    """
    essl_profiles = ["100_es", "300_es", "310_es", "320_es"]
    dxbc_profiles = ["s_4_0", "s_5_0"]
    dxil_profiles = [
        "s_6_0",
        "s_6_1",
        "s_6_2",
        "s_6_3",
        "s_6_4",
        "s_6_5",
        "s_6_6",
        "s_6_7",
        "s_6_8",
        "s_6_9",
    ]
    glsl_profiles = ["120", "130", "140", "150", "330", "400", "410", "420", "430", "440"]
    metal_profiles = [
        "metal",
        "metal10-10",
        "metal11-10",
        "metal12-10",
        "metal20-11",
        "metal21-11",
        "metal22-11",
        "metal23-14",
        "metal24-14",
        "metal30-14",
        "metal31-14",
    ]
    spirv_profiles = [
        "spirv",
        "spirv10-10",
        "spirv13-11",
        "spirv14-11",
        "spirv15-12",
        "spirv16-13",
    ]
    wgsl_profiles = ["wgsl"]
    pssl_profiles = ["pssl"]

    if profile in essl_profiles:
        return "_essl"
    elif profile in dxbc_profiles:
        return "_dxbc"
    elif profile in dxil_profiles:
        return "_dxil"
    elif profile in glsl_profiles:
        return "_glsl"
    elif profile in metal_profiles:
        return "_mtl"
    elif profile in spirv_profiles:
        return "_spv"
    elif profile in wgsl_profiles:
        return "_wgsl"
    elif profile in pssl_profiles:
        return "_pssl"
    else:
        fail("Unknown shaderc profile: " + profile)

def _bgfx_embedded_shader_impl(ctx):
    # set up the base arguments that are common across all platform/profile combinations
    base_args = ctx.actions.args()
    base_args.add("--type", ctx.attr.type)
    base_args.add_all(ctx.attr.opts)

    if ctx.attr.defines:
        base_args.add("--define", ";".join(ctx.attr.defines))

    header_dirs = []

    for hdr in ctx.files.hdrs + ctx.files._internal_hdrs:
        dirname = hdr.dirname
        if dirname not in header_dirs:
            header_dirs.append(dirname)

    for path in header_dirs:
        base_args.add("-i", path)

    base_args.add("--varyingdef", ctx.file.varying_def)

    inputs = ctx.files.srcs + [ctx.file.varying_def] + ctx.files.hdrs + ctx.files._internal_hdrs
    outputs = []

    # compile the shader for each platform/profile pair, generating intermediate bin.h files for each, then concatenate them into a single output header.
    for src in ctx.files.srcs:
        if src.extension:
            stem = src.basename.removesuffix("." + src.extension)
        else:
            stem = src.basename

        compiled_shaders = []

        for platform, profiles in ctx.attr.targets.items():
            for profile in profiles:
                suffix = _bgfx_shader_suffix_for_profile(profile)

                input_file = src
                output_file = ctx.actions.declare_file(stem + suffix + ".bin.h")

                per_file_args = ctx.actions.args()
                per_file_args.add("--platform", platform)
                per_file_args.add("--profile", profile)
                per_file_args.add("-f", input_file)
                per_file_args.add("-o", output_file)
                per_file_args.add("--bin2c", stem + suffix)

                ctx.actions.run(
                    inputs = inputs,
                    outputs = [output_file],
                    executable = ctx.executable._tool,
                    arguments = [base_args, per_file_args],
                    mnemonic = "BgfxCompileShader",
                )

                compiled_shaders.append(output_file)

        merged_output_file = ctx.actions.declare_file(stem + ".bin.h")

        ctx.actions.run_shell(
            inputs = compiled_shaders,
            outputs = [merged_output_file],
            command = "cat {} > {}".format(
                " ".join([f.path for f in compiled_shaders]),
                merged_output_file.path,
            ),
            mnemonic = "BgfxConcatenateShader",
        )

        outputs.append(merged_output_file)

    compilation_context = cc_common.create_compilation_context(
        headers = depset(outputs),
        quote_includes = depset([f.dirname for f in outputs]),
    )

    return [
        DefaultInfo(
            files = depset(outputs),
            default_runfiles = ctx.runfiles(files = []),
        ),
        CcInfo(compilation_context = compilation_context),
    ]

bgfx_embedded_shader = rule(
    implementation = _bgfx_embedded_shader_impl,
    attrs = {
        "srcs": attr.label_list(
            doc = "Source file to compile.",
            mandatory = True,
            allow_files = True,
        ),
        "hdrs": attr.label_list(
            doc = "List of headers to make available as includes during shader compilation.",
            allow_files = True,
        ),
        "type": attr.string(
            doc = "Type of shader to compile.",
            values = ["vertex", "fragment", "compute"],
            mandatory = True,
        ),
        "targets": attr.string_list_dict(
            doc = "Shader platforms and their corresponding default profiles to use for compilation.",
            default = {
                "linux": ["120", "spirv", "wgsl"],
                "windows": ["s_5_0", "s_6_0"],
                "android": ["100_es"],
                "ios": ["metal"],
            },
        ),
        "varying_def": attr.label(
            doc = "Varying definition file to use during shader compilation.",
            mandatory = True,
            allow_single_file = True,
        ),
        "defines": attr.string_list(
            doc = "List of preprocessor definitions to pass to the shader compiler.",
        ),
        "opts": attr.string_list(
            doc = "List of additional options to pass to the shader compiler.",
        ),
        "_internal_hdrs": attr.label_list(
            default = [
                "//examples/common:common.sh",
                "//examples/common:shaderlib.sh",
                "//:src/bgfx_compute.sh",
                "//:src/bgfx_shader.sh",
            ],
            allow_files = True,
        ),
        "_tool": attr.label(
            default = Label("//tools/shaderc:shaderc"),
            executable = True,
            cfg = "exec",
        ),
    },
)

# ==========================================================================

def _bgfx_geometry_impl(ctx):
    args = ctx.actions.args()
    args.add("-f", ctx.file.src)
    args.add("-o", ctx.outputs.out)

    if ctx.attr.front_face_ccw:
        args.add("--ccw")

    if ctx.attr.flip_texture_v:
        args.add("--flipv")

    if ctx.attr.calc_tangents:
        args.add("--tangent")

    if ctx.attr.calc_barycentric:
        args.add("--barycentric")

    if ctx.attr.compress_indices:
        args.add("--compress")

    if ctx.attr.coordinate_system:
        args.add("--" + ctx.attr.coordinate_system)

    if ctx.attr.scale_factor:
        args.add("--scale", ctx.attr.scale_factor)

    if ctx.attr.obb_steps:
        args.add("--obb", ctx.attr.obb_steps)

    if ctx.attr.pack_normals:
        args.add("--packnormal", "1")

    if ctx.attr.pack_uvs:
        args.add("--packuv", "1")

    ctx.actions.run(
        inputs = [ctx.file.src],
        outputs = [ctx.outputs.out],
        executable = ctx.executable._tool,
        arguments = [args],
        mnemonic = "Geometryc",
    )
    return [DefaultInfo(
        files = depset([ctx.outputs.out]),
        default_runfiles = ctx.runfiles(files = [ctx.outputs.out]),
    )]

bgfx_geometry = rule(
    implementation = _bgfx_geometry_impl,
    doc = "Rule that compiles 3D geometry using bgfx's geometryc tool.",
    attrs = {
        "src": attr.label(allow_single_file = True, mandatory = True),
        "out": attr.output(mandatory = True),
        "scale_factor": attr.string(),
        "front_face_ccw": attr.bool(),
        "flip_texture_v": attr.bool(),
        "coordinate_system": attr.string(
            values = [
                "lh-up+y",
                "lh-up+z",
                "rh-up+y",
                "rh-up+z",
            ],
        ),
        "obb_steps": attr.string(),
        "pack_normals": attr.bool(),
        "pack_uvs": attr.bool(),
        "calc_tangents": attr.bool(),
        "calc_barycentric": attr.bool(),
        "compress_indices": attr.bool(),
        "_tool": attr.label(
            default = Label("//tools/geometryc:geometryc"),
            executable = True,
            cfg = "exec",
        ),
    },
)

# ==========================================================================

def _bgfx_texture_impl(ctx):
    args = ctx.actions.args()
    args.add("-f", ctx.file.src)
    args.add("-o", ctx.outputs.out)
    args.add("-t", ctx.attr.format)

    if ctx.attr.quality:
        args.add("-q", ctx.attr.quality)

    if ctx.attr.num_mips:
        args.add("--mips", ctx.attr.num_mips)

    if ctx.attr.skip_mips:
        args.add("--mipskip", ctx.attr.skip_mips)

    if ctx.attr.normal_map:
        args.add("--normalmap")

    if ctx.attr.equirectangular:
        args.add("--equirect")

    if ctx.attr.strip:
        args.add("--strip")

    if ctx.attr.sdf:
        args.add("--sdf")

    if ctx.attr.alpha_ref:
        args.add("--ref", ctx.attr.alpha_ref)

    if ctx.attr.iqa:
        args.add("--iqa")

    if ctx.attr.premultiply_alpha:
        args.add("--pma")

    if ctx.attr.linear:
        args.add("--linear")

    if ctx.attr.max_size:
        args.add("--max", ctx.attr.max_size)

    if ctx.attr.radiance:
        args.add("--radiance", ctx.attr.radiance)

    if ctx.attr.save_as:
        args.add("--as", ctx.attr.save_as)

    ctx.actions.run(
        inputs = [ctx.file.src],
        outputs = [ctx.outputs.out],
        executable = ctx.executable._tool,
        arguments = [args],
        mnemonic = "Texturec",
    )

    return [DefaultInfo(
        files = depset([ctx.outputs.out]),
        default_runfiles = ctx.runfiles(files = [ctx.outputs.out]),
    )]

bgfx_texture = rule(
    implementation = _bgfx_texture_impl,
    doc = "Rule that compiles textures using bimg's texturec tool.",
    attrs = {
        "src": attr.label(allow_single_file = True, mandatory = True),
        "out": attr.output(mandatory = True),
        "format": attr.string(mandatory = True),
        "quality": attr.string(
            values = [
                "default",
                "fastest",
                "highest",
            ],
        ),
        "num_mips": attr.string(),
        "skip_mips": attr.string(),
        "normal_map": attr.bool(),
        "equirectangular": attr.bool(),
        "strip": attr.bool(),
        "sdf": attr.bool(),
        "alpha_ref": attr.string(),
        "iqa": attr.bool(),
        "premultiply_alpha": attr.bool(),
        "linear": attr.bool(),
        "max_size": attr.string(),
        "radiance": attr.string(
            values = [
                "phong",
                "phongbrdf",
                "blinn",
                "blinnbrdf",
                "ggx",
            ],
        ),
        "save_as": attr.string(),
        "_tool": attr.label(
            default = Label("@bimg//tools/texturec:texturec"),
            executable = True,
            cfg = "exec",
        ),
    },
)
