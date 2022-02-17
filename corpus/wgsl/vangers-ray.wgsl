struct Globals {
    camera_pos: vec4<f32>;
    view_proj: mat4x4<f32>;
    inv_view_proj: mat4x4<f32>;
    light_view_proj: mat4x4<f32>;
    light_pos: vec4<f32>;
    light_color: vec4<f32>; // not used
};

@group(0) @binding(0) var<uniform> u_Globals: Globals;
struct Locals {
    screen_rect: vec4<u32>;      // XY = offset, ZW = size
    params: vec4<u32>;
    cam_origin_dir: vec4<f32>;    // XY = origin, ZW = dir
    sample_range: vec4<f32>;     // XY = X range, ZW = y range
    fog_color: vec4<f32>;
    fog_params: vec4<f32>;       // X=near, Y = far
};
@group(1) @binding(1) var<uniform> u_Locals: Locals;

fn get_frag_ndc(frag_coord: vec2<f32>, z: f32) -> vec4<f32> {
    let normalized = (frag_coord.xy - vec2<f32>(u_Locals.screen_rect.xy)) / vec2<f32>(u_Locals.screen_rect.zw);
    return vec4<f32>(
        // note the Y-flip here
        (normalized * 2.0 - vec2<f32>(1.0)) * vec2<f32>(1.0, -1.0),
        z,
        1.0,
    );
}

fn get_frag_world(frag_coord: vec2<f32>, z: f32) -> vec3<f32> {
    let ndc = get_frag_ndc(frag_coord, z);
    let homogeneous = u_Globals.inv_view_proj * ndc;
    return homogeneous.xyz / homogeneous.w;
}

fn apply_fog(terrain_color: vec4<f32>, world_pos: vec2<f32>) -> vec4<f32> {
    let cam_distance = clamp(length(world_pos - u_Locals.cam_origin_dir.xy), u_Locals.fog_params.x, u_Locals.fog_params.y);
    let fog_amount = smoothStep(u_Locals.fog_params.x, u_Locals.fog_params.y, cam_distance);
    return mix(terrain_color, u_Locals.fog_color, fog_amount);
}
// Common routines for fetching the level surface data.

struct SurfaceConstants {
    texture_scale: vec4<f32>;    // XY = size, Z = height scale, w = number of layers
    terrain_bits: vec4<u32>;     // X_low = shift, X_high = mask
};

@group(1) @binding(0) var<uniform> u_Surface: SurfaceConstants;

@group(1) @binding(2) var t_Height: texture_2d<f32>;
@group(1) @binding(3) var t_Meta: texture_2d<u32>;
@group(1) @binding(7) var s_Main: sampler;

let c_DoubleLevelMask: u32 = 64u;
let c_ShadowMask: u32 = 128u;
let c_DeltaShift: u32 = 0u;
let c_DeltaBits: u32 = 2u;
let c_DeltaScale: f32 = 0.03137254901; //8.0 / 255.0;

struct Surface {
    low_alt: f32;
    high_alt: f32;
    delta: f32;
    low_type: u32;
    high_type: u32;
    tex_coord: vec2<f32>;
    is_shadowed: bool;
};

fn get_terrain_type(meta: u32) -> u32 {
    let bits = u_Surface.terrain_bits.x;
    return (meta >> (bits & 0xFu)) & (bits >> 4u);
}
fn get_delta(meta: u32) -> u32 {
    return (meta >> c_DeltaShift) & ((1u << c_DeltaBits) - 1u);
}

fn modulo(a: i32, b: i32) -> i32 {
    let c = a % b;
    return select(c, c+b, c < 0);
}

fn get_lod_height(ipos: vec2<i32>, lod: u32) -> f32 {
    let x = modulo(ipos.x, i32(u_Surface.texture_scale.x));
    let y = modulo(ipos.y, i32(u_Surface.texture_scale.y));
    let tc = vec2<i32>(x, y) >> vec2<u32>(lod);
    let alt = textureLoad(t_Height, tc, i32(lod)).x;
    return alt * u_Surface.texture_scale.z;
}

fn get_map_coordinates(pos: vec2<f32>) -> vec2<i32> {
    return vec2<i32>(pos - floor(pos / u_Surface.texture_scale.xy) * u_Surface.texture_scale.xy);
}

fn get_surface(pos: vec2<f32>) -> Surface {
    var suf: Surface;

    let tc = pos / u_Surface.texture_scale.xy;
    let tci = get_map_coordinates(pos);
    suf.tex_coord = tc;

    let meta = textureLoad(t_Meta, tci, 0).x;
    suf.is_shadowed = (meta & c_ShadowMask) != 0u;
    suf.low_type = get_terrain_type(meta);

    if ((meta & c_DoubleLevelMask) != 0u) {
        //TODO: we need either low or high for the most part
        // so this can be more efficient with a boolean param
        var delta = 0u;
        if (tci.x % 2 == 1) {
            let meta_low = textureLoad(t_Meta, tci + vec2<i32>(-1, 0), 0).x;
            suf.high_type = suf.low_type;
            suf.low_type = get_terrain_type(meta_low);
            delta = (get_delta(meta_low) << c_DeltaBits) + get_delta(meta);
        } else {
            let meta_high = textureLoad(t_Meta, tci + vec2<i32>(1, 0), 0).x;
            suf.tex_coord.x = suf.tex_coord.x + 1.0 / u_Surface.texture_scale.x;
            suf.high_type = get_terrain_type(meta_high);
            delta = (get_delta(meta) << c_DeltaBits) + get_delta(meta_high);
        }

        suf.low_alt = //TODO: the `LodOffset` doesn't appear to work in Metal compute
            //textureLodOffset(sampler2D(t_Height, s_Main), suf.tex_coord, 0.0, ivec2(-1, 0)).x
            textureSampleLevel(t_Height, s_Main, suf.tex_coord - vec2<f32>(1.0 / u_Surface.texture_scale.x, 0.0), 0.0).x
            * u_Surface.texture_scale.z;
        suf.high_alt = textureSampleLevel(t_Height, s_Main, suf.tex_coord, 0.0).x * u_Surface.texture_scale.z;
        suf.delta = f32(delta) * c_DeltaScale * u_Surface.texture_scale.z;
    } else {
        suf.high_type = suf.low_type;

        suf.low_alt = textureSampleLevel(t_Height, s_Main, tc, 0.0).x * u_Surface.texture_scale.z;
        suf.high_alt = suf.low_alt;
        suf.delta = 0.0;
    }

    return suf;
}

struct SurfaceAlt {
    low: f32;
    high: f32;
    delta: f32;
};

fn get_surface_alt(pos: vec2<f32>) -> SurfaceAlt {
    let tci = get_map_coordinates(pos);
    let meta = textureLoad(t_Meta, tci, 0).x;
    let altitude = textureLoad(t_Height, tci, 0).x * u_Surface.texture_scale.z;

    if ((meta & c_DoubleLevelMask) != 0u) {
        let tci_other = tci ^ vec2<i32>(1, 0);
        let meta_other = textureLoad(t_Meta, tci_other, 0).x;
        let alt_other = textureLoad(t_Height, tci_other, 0).x * u_Surface.texture_scale.z;
        let deltas = vec2<u32>(get_delta(meta), get_delta(meta_other));
        let raw = select(
            vec3<f32>(altitude, alt_other, f32((deltas.x << c_DeltaBits) + deltas.y)),
            vec3<f32>(alt_other, altitude, f32((deltas.y << c_DeltaBits) + deltas.x)),
            (tci.x & 1) != 0,
        );
        return SurfaceAlt(raw.x, raw.y, raw.z * c_DeltaScale * u_Surface.texture_scale.z);
    } else {
        return SurfaceAlt(altitude, altitude, 0.0);
    }
}

fn merge_alt(a: SurfaceAlt, b: SurfaceAlt, ratio: f32) -> SurfaceAlt {
    var suf: SurfaceAlt;
    let mid = 0.5 * (b.low + b.high);
    suf.low = mix(a.low, select(b.low, b.high, a.low >= mid), ratio);
    suf.high = mix(a.high, select(b.low, b.high, a.high >= mid), ratio);
    suf.delta = mix(a.delta, select(0.0, b.delta, a.high >= mid), ratio);
    suf = a;
    return suf;
}

fn get_surface_alt_smooth(pos: vec2<f32>) -> SurfaceAlt {
    let tci = get_map_coordinates(pos);
    let sub_pos = fract(pos);
    let offsets = step(vec2<f32>(0.5), sub_pos) * 2.0 - vec2<f32>(1.0);
    let s00 = get_surface_alt(pos);
    let s10 = get_surface_alt(pos + vec2<f32>(offsets.x, 0.0));
    let s01 = get_surface_alt(pos + vec2<f32>(0.0, offsets.y));
    let s11 = get_surface_alt(pos + offsets);

    let s00_10 = merge_alt(s00, s10, abs(sub_pos.x - 0.5));
    let s01_11 = merge_alt(s01, s11, abs(sub_pos.x - 0.5));
    return merge_alt(s00_10, s01_11, abs(sub_pos.y - 0.5));
}

fn get_surface_smooth(pos: vec2<f32>) -> Surface {
    var suf = get_surface(pos);
    let alt = get_surface_alt_smooth(pos);
    suf.low_alt = alt.low;
    suf.high_alt = alt.high;
    suf.delta = alt.delta;
    return suf;
}
// Shadow sampling.

@group(0) @binding(3) var t_Shadow: texture_depth_2d;
@group(0) @binding(4) var s_Shadow: sampler_comparison;

let c_Ambient: f32 = 0.25;

fn fetch_shadow(pos: vec3<f32>) -> f32 {
    let flip_correction = vec2<f32>(1.0, -1.0);

    if (u_Globals.light_view_proj[3][3] == 0.0) {
        // shadow is disabled
        return 1.0;
    }
    let homogeneous_coords = u_Globals.light_view_proj * vec4<f32>(pos, 1.0);
    if (homogeneous_coords.w <= 0.0) {
        // outside of shadow projection
        return 0.0;
    }

    let light_local = 0.5 * (homogeneous_coords.xy * flip_correction/homogeneous_coords.w + 1.0);
    let shadow = textureSampleCompareLevel(
        t_Shadow, s_Shadow,
        light_local,
        homogeneous_coords.z / homogeneous_coords.w
    );
    return mix(c_Ambient, 1.0, shadow);
}
// Common FS routines for evaluating terrain color.

//uniform sampler2D t_Height;
// Terrain parameters per type: shadow offset, height shift, palette start, palette end
@group(1) @binding(5) var t_Table: texture_1d<u32>;
// corresponds to SDL palette
@group(1) @binding(6) var t_Palette: texture_1d<f32>;

@group(0) @binding(1) var s_Palette: sampler;

let c_HorFactor: f32 = 0.5; //H_CORRECTION
let c_DiffuseScale: f32 = 8.0;
let c_ShadowDepthScale: f32 = 0.6; //~ 2.0 / 3.0;

// see `RenderPrepare` in `land.cpp` for the original game logic

// material coefficients are called "dx", "sd" and "jj" in the original
fn evaluate_light(material: vec3<f32>, height_diff: f32) -> f32 {
    let dx = material.x * c_DiffuseScale;
    let sd = material.y * c_ShadowDepthScale;
    let jj = material.z * height_diff * 256.0;
    let v = (dx * sd - jj) / sqrt((1.0 + sd * sd) * (dx * dx + jj * jj));
    return clamp(v, 0.0, 1.0);
}

fn evaluate_palette(ty: u32, value_in: f32, ycoord: f32) -> f32 {
    var value = clamp(value_in, 0.0, 1.0);
    let terr = vec4<f32>(textureLoad(t_Table, i32(ty), 0));
    //Note: the original game had specific logic here to process water
    return (mix(terr.z, terr.w, value) + 0.5) / 256.0;
}

fn evaluate_color_id(ty: u32, tex_coord: vec2<f32>, height_normalized: f32, lit_factor: f32) -> f32 {
    // See the original code in "land.cpp": `LINE_render()`
    //Note: we could have a different code path for double level here
    let diff =
        textureSampleLevel(t_Height, s_Main, tex_coord, 0.0, vec2<i32>(0, 0)).x -
        textureSampleLevel(t_Height, s_Main, tex_coord, 0.0, vec2<i32>(-2, 0)).x;
    // See the original code in "land.cpp": `TERRAIN_MATERIAL` etc
    let material = select(vec3<f32>(1.0), vec3<f32>(5.0, 1.25, 0.5), ty == 0u);
    let light_clr = evaluate_light(material, diff);
    let tmp = light_clr - c_HorFactor * (1.0 - height_normalized);
    return evaluate_palette(ty, lit_factor * tmp, tex_coord.y);
}

fn evaluate_color(ty: u32, tex_coord: vec2<f32>, height_normalized: f32, lit_factor: f32) -> vec4<f32> {
    let color_id = evaluate_color_id(ty, tex_coord, height_normalized, lit_factor);
    return textureSample(t_Palette, s_Palette, color_id);
}
//!include globals.inc terrain/locals.inc surface.inc shadow.inc color.inc

@stage(vertex)
fn main(@location(0) pos: vec4<i32>) -> @builtin(position) vec4<f32> {
    // orhto projections don't like infinite values
    return select(
        u_Globals.view_proj * vec4<f32>(pos),
        // the expected geometry is 4 trianges meeting in the center
        vec4<f32>(vec2<f32>(pos.xy), 0.0, 0.5),
        u_Globals.view_proj[2][3] == 0.0
    );
}

//imported: Surface, u_Surface, get_surface, evaluate_color

fn cast_ray_to_plane(level: f32, base: vec3<f32>, dir: vec3<f32>) -> vec3<f32> {
    let t = (level - base.z) / dir.z;
    return t * dir + base;
}

struct CastResult {
    surface: Surface;
    a: vec3<f32>;
    b: vec3<f32>;
};

fn cast_ray_impl(
    a_in: vec3<f32>, b_in: vec3<f32>,
    high_in: bool, num_forward: i32, num_binary: i32
) -> CastResult {
    let step = (1.0 / f32(num_forward + 1)) * (b_in - a_in);
    var a = a_in;
    var b = b_in;
    var high = high_in;

    for (var i = 0; i < num_forward; i = i + 1) {
        let c = a + step;
        let suf = get_surface_alt(c.xy);

        if (c.z > suf.high) {
            high = true; // re-appear on the surface
            a = c;
        } else {
            let height = select(suf.low, suf.high, high);
            if (c.z <= height) {
                b = c;
                break;
            } else {
                a = c;
            }
        }
    }

    for (var i = 0; i < num_binary; i = i+1) {
        let c = mix(a, b, 0.5);
        let suf = get_surface_alt(c.xy);

        let height = select(suf.low, suf.high, high);
        if (c.z <= height) {
            b = c;
        } else {
            a = c;
        }
    }

    let result = get_surface(b.xy);
    return CastResult(result, a, b);
}

fn cast_ray_impl_smooth(
    a_in: vec3<f32>, b_in: vec3<f32>,
    high_in: bool, num_forward: i32, num_binary: i32
) -> CastResult {
    let step = (1.0 / f32(num_forward + 1)) * (b_in - a_in);
    var a = a_in;
    var b = b_in;
    var high = high_in;

    for (var i = 0; i < num_forward; i = i + 1) {
        let c = a + step;
        let suf = get_surface_alt_smooth(c.xy);

        if (c.z > suf.high) {
            high = true; // re-appear on the surface
            a = c;
        } else {
            let height = select(suf.low, suf.high, high);
            if (c.z <= height) {
                b = c;
                break;
            } else {
                a = c;
            }
        }
    }

    for (var i = 0; i < num_binary; i = i+1) {
        let c = mix(a, b, 0.5);
        let suf = get_surface_alt_smooth(c.xy);

        let height = select(suf.low, suf.high, high);
        if (c.z <= height) {
            b = c;
        } else {
            a = c;
        }
    }

    let result = get_surface_smooth(b.xy);
    return CastResult(result, a, b);
}

struct CastPoint {
    pos: vec3<f32>;
    ty: u32;
    tex_coord: vec2<f32>;
    is_underground: bool;
    //is_shadowed: bool;
};

fn cast_ray_to_map(base: vec3<f32>, dir: vec3<f32>) -> CastPoint {
    var pt: CastPoint;

    let a_in = select(
        base,
        cast_ray_to_plane(u_Surface.texture_scale.z, base, dir),
        base.z > u_Surface.texture_scale.z,
    );
    var c = cast_ray_to_plane(0.0, base, dir);

    let cast_result = cast_ray_impl(a_in, c, true, 8, 4);
    var a = cast_result.a;
    var b = cast_result.b;
    var suf = cast_result.surface;
    pt.ty = suf.high_type;
    pt.is_underground = false;

    if (suf.delta != 0.0 && b.z < suf.low_alt + suf.delta) {
        // continue the cast underground, but reserve
        // the right to re-appear above the surface.
        let cr = cast_ray_impl(b, c, false, 6, 3);
        a = cr.a;
        b = cr.b;
        suf = cr.surface;
        if (b.z >= suf.low_alt + suf.delta) {
            pt.ty = suf.high_type;
        } else {
            pt.ty = suf.low_type;
            // underground is better indicated by a real shadow
            //pt.is_underground = true;
        }
    }

    pt.pos = b;
    pt.tex_coord = suf.tex_coord;
    //pt.is_shadowed = suf.is_shadowed;

    return pt;
}

fn color_point(pt: CastPoint, lit_factor: f32) -> vec4<f32> {
    return evaluate_color(pt.ty, pt.tex_coord, pt.pos.z / u_Surface.texture_scale.z, lit_factor);
}

let c_DepthBias: f32 = 0.01;

struct RayInput {
    @builtin(position) frag_coord: vec4<f32>;
};

@stage(fragment)
fn fs_main(in: RayInput) -> @builtin(frag_depth) f32 {
    let sp_near_world = get_frag_world(in.frag_coord.xy, 0.0);
    let sp_far_world = get_frag_world(in.frag_coord.xy, 1.0);
    let view = normalize(sp_far_world - sp_near_world);
    let pt = cast_ray_to_map(sp_near_world, view);

    let target_ndc = u_Globals.view_proj * vec4<f32>(pt.pos, 1.0);
    return target_ndc.z / target_ndc.w + c_DepthBias;
}

struct FragOutput {
    @location(0) color: vec4<f32>;
    @builtin(frag_depth) depth: f32;
};

@stage(fragment)
fn ray_color_debug(in: RayInput) -> FragOutput {
    let sp_near_world = get_frag_world(in.frag_coord.xy, 0.0);
    let sp_far_world = get_frag_world(in.frag_coord.xy, 1.0);
    let view = normalize(sp_far_world - sp_near_world);

    var point = cast_ray_to_plane(0.0, sp_near_world, view);
    let surface = get_surface(point.xy);
    let color = vec4<f32>(surface.low_alt, surface.high_alt, surface.delta, 0.0) / 255.0;
    return FragOutput(color, 1.0);
}

@stage(fragment)
fn ray_color(in: RayInput) -> FragOutput {
    let sp_near_world = get_frag_world(in.frag_coord.xy, 0.0);
    let sp_far_world = get_frag_world(in.frag_coord.xy, 1.0);
    let view = normalize(sp_far_world - sp_near_world);
    let pt = cast_ray_to_map(sp_near_world, view);

    let lit_factor = fetch_shadow(pt.pos);
    var frag_color = color_point(pt, lit_factor);

    let target_ndc = u_Globals.view_proj * vec4<f32>(pt.pos, 1.0);
    let depth = target_ndc.z / target_ndc.w;
    return FragOutput(frag_color, depth);
}

let c_Step: f32 = 0.6;

// Algorithm is based on "http://www.tevs.eu/project_i3d08.html"
//"Maximum Mipmaps for Fast, Accurate, and Scalable Dynamic Height Field Rendering"
fn cast_ray_mip(base_point: vec3<f32>, dir: vec3<f32>) -> vec3<f32> {
    var point = base_point;
    var lod = u_Locals.params.x;
    var ipos = vec2<i32>(floor(point.xy)); // integer coordinate of the cell
    var num_jumps = u_Locals.params.y;
    var num_steps = u_Locals.params.z;
    loop {
        // step 0: at lowest LOD, just advance
        if (lod == 0u) {
            let surface = get_surface(point.xy);
            if (point.z < surface.low_alt || (point.z < surface.high_alt && point.z >= surface.low_alt + surface.delta)) {
                break;
            }
            if (surface.low_alt == surface.high_alt) {
                lod = lod + 1u; //try to escape the low level and LOD
            }
            point = point + c_Step * dir;
            ipos = vec2<i32>(floor(point.xy));
            num_steps = num_steps - 1u;
            if (num_steps == 0u) {
                break;
            }
            continue;
        }

        // step 1: get the LOD height and early out
        let height = get_lod_height(ipos, lod);
        if (point.z <= height) {
            lod = lod - 1u;
            continue;
        }
        // assumption: point.z >= height

        // step 2: figure out the closest intersection with the cell
        // it can be X axis, Y axis, or the depth
        let cell_id = floor(vec2<f32>(ipos) / f32(1 << lod)); // careful!
        let cell_tl = vec2<i32>(cell_id) << vec2<u32>(lod);
        let cell_offset = vec2<f32>(cell_tl) + f32(1 << lod) * step(vec2<f32>(0.0), dir.xy) - point.xy;
        let units = vec3<f32>(cell_offset, height - point.z) / dir;
        let min_side_unit = min(units.x, units.y);

        // advance the point
        point = point + min(units.z, min_side_unit) * dir;
        ipos = vec2<i32>(floor(point.xy));
        num_jumps = num_jumps - 1u;

        if (units.z < min_side_unit) {
            lod = lod - 1u;
        } else {
            // adjust the integer position on cell boundary
            // figure out if we hit the higher LOD bound and switch to it
            var affinity = 0.0;
            let proximity = abs(cell_id % vec2<f32>(2.0)) - vec2<f32>(0.5);

            if (units.x <= units.y) {
                ipos.x = select(cell_tl.x - 1, cell_tl.x + (1 << lod), dir.x >= 0.0);
                affinity = dir.x * proximity.x;
            }
            if (units.y <= units.x) {
                ipos.y = select(cell_tl.y - 1, cell_tl.y + (1 << lod), dir.y >= 0.0);
                affinity = dir.y * proximity.y;
            }
            if (lod < u_Locals.params.x && affinity > 0.0) {
                lod = lod + 1u;
            }
        }
        if (num_jumps == 0u) {
            break;
        }
    }

    return point;
}

@stage(fragment)
fn ray_mip_color(in: RayInput) -> FragOutput {
    let sp_near_world = get_frag_world(in.frag_coord.xy, 0.0);
    let sp_far_world = get_frag_world(in.frag_coord.xy, 1.0);
    let view = normalize(sp_far_world - sp_near_world);
    let point = cast_ray_mip(sp_near_world, view);

    let lit_factor = fetch_shadow(point);
    let surface = get_surface(point.xy);
    let ty = select(surface.low_type, surface.high_type, point.z > surface.low_alt);
    let frag_color = evaluate_color(ty, surface.tex_coord, point.z / u_Surface.texture_scale.z, lit_factor);

    let target_ndc = u_Globals.view_proj * vec4<f32>(point, 1.0);
    let depth = target_ndc.z / target_ndc.w;
    return FragOutput(frag_color, depth);
}
