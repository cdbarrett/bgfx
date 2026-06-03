"""
Rules for bgfx tools.
"""

def _bgfx_shader_impl(ctx):
    args = ctx.actions.args()
    args.add("-f", ctx.file.src)
    args.add("-o", ctx.outputs.out)

    if ctx.attr.only_preprocess:
        args.add("--preprocess")

    if ctx.attr.keep_comments:
        args.add("--keepcomments")

    if ctx.attr.no_preprocess:
        args.add("--raw")

    if ctx.attr.verbose:
        args.add("--verbose")

    if ctx.attr.debug:
        args.add("--debug")

    args.add("--type", ctx.attr.type)
    args.add("--platform", ctx.attr.platform)
    args.add("--profile", ctx.attr.profile)

    if ctx.attr.varying_def:
        args.add("--varyingdef", ctx.file.varying_def.path)

    if ctx.attr.bin2c:
        args.add("--bin2c", ctx.attr.bin2c)

    for define in ctx.attr.defines:
        args.add("--define", define)

    include_dirs = []
    inputs = [ctx.file.src]

    if ctx.attr.varying_def:
        inputs.append(ctx.file.varying_def)

    for f in ctx.files.includes:
        if f.dirname not in include_dirs:
            include_dirs.append(f.dirname)
            args.add("-i", f.dirname)

    ctx.actions.run(
        inputs = inputs + ctx.files.includes,
        outputs = [ctx.outputs.out],
        executable = ctx.executable._tool,
        arguments = [args],
        mnemonic = "Shaderc",
    )
    return [DefaultInfo(files = depset([ctx.outputs.out]))]

bgfx_shader = rule(
    implementation = _bgfx_shader_impl,
    doc = "Rule that generates a given shader using bgfx's shaderc tool.",
    attrs = {
        "src": attr.label(allow_single_file = True, mandatory = True),
        "out": attr.output(mandatory = True),
        "type": attr.string(
            mandatory = True,
            values = [
                "vertex",
                "fragment",
                "compute",
            ],
        ),
        "platform": attr.string(
            mandatory = True,
            values = [
                "android",
                "asm.js",
                "ios",
                "linux",
                "orbis",
                "osx",
                "windows",
            ],
        ),
        "profile": attr.string(
            mandatory = True,
            values = [
                "100_es",
                "300_es",
                "310_es",
                "320_es",
                "s_4_0",
                "s_5_0",
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
                "pssl",
                "spirv",
                "spirv10-10",
                "spirv13-11",
                "spirv14-11",
                "spirv15-12",
                "spirv16-13",
                "120",
                "130",
                "140",
                "150",
                "330",
                "400",
                "410",
                "420",
                "430",
                "440",
                "wgsl",
            ],
        ),
        "includes": attr.label_list(allow_files = True),
        "varying_def": attr.label(allow_single_file = True),
        "bin2c": attr.string(),
        "defines": attr.string_list(),
        "only_preprocess": attr.bool(),
        "keep_comments": attr.bool(),
        "no_preprocess": attr.bool(),
        "verbose": attr.bool(),
        "debug": attr.bool(),
        "_tool": attr.label(
            default = Label("//tools/shaderc:shaderc"),
            executable = True,
            cfg = "target",
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
    return [DefaultInfo(files = depset([ctx.outputs.out]))]

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
            cfg = "target",
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
    return [DefaultInfo(files = depset([ctx.outputs.out]))]

bgfx_texture = rule(
    implementation = _bgfx_texture_impl,
    doc = "Rule that compiles textures using bimg's texturec tool.",
    attrs = {
        "src": attr.label(allow_single_file = True, mandatory = True),
        "out": attr.output(mandatory = True),
        "format": attr.string(
            mandatory = True,
            values = [
                "r1",
                "a8",
                "r8",
                "r8i",
                "r8u",
                "r8s",
                "r16",
                "r16i",
                "r16u",
                "r16f",
                "r16s",
                "r32i",
                "r32u",
                "r32f",
                "rg8",
                "rg8i",
                "rg8u",
                "rg8s",
                "rg16",
                "rg16i",
                "rg16u",
                "rg16f",
                "rg16s",
                "rg32i",
                "rg32u",
                "rg32f",
                "rgb8",
                "rgb8i",
                "rgb8u",
                "rgb8s",
                "rgb9e5",
                "bgra8",
                "rgba8",
                "rgba8i",
                "rgba8u",
                "rgba8s",
                "rgba16",
                "rgba16i",
                "rgba16u",
                "rgba16f",
                "rgba16s",
                "rgba32i",
                "rgba32u",
                "rgba32f",
                "b5g6r5",
                "r5g6b5",
                "bgra4",
                "rgba4",
                "bgr5a1",
                "rgb5a1",
                "rgb10a2",
                "rg11b10f",
                "d16",
                "d24",
                "d24s8",
                "d32",
                "d16f",
                "d24f",
                "d32f",
                "d0s8",
                "bc1",
                "bc2",
                "bc3",
                "bc4",
                "bc5",
                "bc6h",
                "bc7",
                "etc1",
                "etc2",
                "etc2a",
                "etc2a1",
                "eacr11",
                "eacr11s",
                "eacrg11",
                "eacrg11s",
                "ptc12",
                "ptc14",
                "ptc12a",
                "ptc14a",
                "ptc22",
                "ptc24",
                "atc",
                "atce",
                "atci",
                "astc4x4",
                "astc5x4",
                "astc5x5",
                "astc6x5",
                "astc6x6",
                "astc8x5",
                "astc8x6",
                "astc8x8",
                "astc10x5",
                "astc10x6",
                "astc10x8",
                "astc10x10",
                "astc12x10",
                "astc12x12",
            ],
        ),
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
