"""Inner Sun bake-off, style C: Blender 5.1 pre-rendered sprites with REAL normal passes.

    blender -b --factory-startup -P pipeline/blender/bake_sprites.py -- <out_dir> [layers] [--samples N]

Builds a simple modeled Reactor room (back wall, reactor prop, ceiling lamp, floor strip) and a crew
stand-in (expedition engineer, side view facing right), then renders for every layer:
  <layer>_alb.png   flat albedo (emission shader, no scene lighting, Standard view transform)
  <layer>_nrm.png   camera-space normals (x right, y UP, z out) = OpenGL tangent space for a camera-facing sprite
  <layer>_ao.png    ambient occlusion (multiplied into the albedo by pipeline/blender_post.py)
  <layer>_emi.png   emissive parts only
at 160 px per meter (orthographic camera looking along +Y, X right, Z up).
Deterministic: fixed seeds for every random choice.
"""
import math
import random
import sys
import os

import bpy
import bmesh
from mathutils import Vector

PPM = 160.0
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = os.path.abspath(argv[0]) if argv else os.path.abspath("blender_raw")
WANT = [a for a in argv[1:] if not a.startswith("--")]
SAMPLES = 48
if "--samples" in argv:
    SAMPLES = int(argv[argv.index("--samples") + 1])
    WANT = [w for w in WANT if w != str(SAMPLES)]
os.makedirs(OUT, exist_ok=True)
rng = random.Random(1977)


def lin(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple((x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4) for x in c) + (1.0,)


# ---------------------------------------------------------------- materials
_mats = {}


def mat(name, base, wear=None, grime=0.35, nscale=22.0, stripes=None, glow=None, wear_amt=1.0):
    """Emission-only albedo material: base colour, procedural grime, edge wear from pointiness."""
    if name in _mats:
        return _mats[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(em.outputs[0], out.inputs[0])
    if stripes:
        tc = nt.nodes.new("ShaderNodeTexCoord")
        sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        nt.links.new(tc.outputs["Object"], sep.inputs[0])
        add = nt.nodes.new("ShaderNodeMath")
        add.operation = "ADD"
        nt.links.new(sep.outputs[0], add.inputs[0])
        nt.links.new(sep.outputs[2], add.inputs[1])
        mul = nt.nodes.new("ShaderNodeMath")
        mul.operation = "MULTIPLY"
        mul.inputs[1].default_value = stripes
        nt.links.new(add.outputs[0], mul.inputs[0])
        fr = nt.nodes.new("ShaderNodeMath")
        fr.operation = "FRACT"
        nt.links.new(mul.outputs[0], fr.inputs[0])
        gt = nt.nodes.new("ShaderNodeMath")
        gt.operation = "GREATER_THAN"
        gt.inputs[1].default_value = 0.5
        nt.links.new(fr.outputs[0], gt.inputs[0])
        base_n = nt.nodes.new("ShaderNodeMix")
        base_n.data_type = "RGBA"
        base_n.inputs[6].default_value = lin(base)
        base_n.inputs[7].default_value = lin("14161a")
        nt.links.new(gt.outputs[0], base_n.inputs[0])
        base_sock = base_n.outputs[2]
    else:
        base_n = nt.nodes.new("ShaderNodeRGB")
        base_n.outputs[0].default_value = lin(base)
        base_sock = base_n.outputs[0]
    # grime: darkening noise
    tc2 = nt.nodes.new("ShaderNodeTexCoord")
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = nscale
    noise.inputs["Detail"].default_value = 5.0
    nt.links.new(tc2.outputs["Object"], noise.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.35
    ramp.color_ramp.elements[1].position = 0.75
    nt.links.new(noise.outputs["Fac"], ramp.inputs[0])
    dark = nt.nodes.new("ShaderNodeMix")
    dark.data_type = "RGBA"
    dark.blend_type = "MULTIPLY"
    dark.inputs[0].default_value = grime
    nt.links.new(base_sock, dark.inputs[6])
    nt.links.new(ramp.outputs[0], dark.inputs[7])
    last = dark.outputs[2]
    if wear:
        geo = nt.nodes.new("ShaderNodeNewGeometry")
        pr = nt.nodes.new("ShaderNodeValToRGB")
        pr.color_ramp.elements[0].position = 0.50
        pr.color_ramp.elements[1].position = 0.60
        nt.links.new(geo.outputs["Pointiness"], pr.inputs[0])
        wmix = nt.nodes.new("ShaderNodeMix")
        wmix.data_type = "RGBA"
        wmix.inputs[7].default_value = lin(wear)
        nt.links.new(last, wmix.inputs[6])
        scale = nt.nodes.new("ShaderNodeMath")
        scale.operation = "MULTIPLY"
        scale.inputs[1].default_value = wear_amt
        nt.links.new(pr.outputs[0], scale.inputs[0])
        nt.links.new(scale.outputs[0], wmix.inputs[0])
        last = wmix.outputs[2]
    nt.links.new(last, em.inputs["Color"])
    em.inputs["Strength"].default_value = 1.0
    _mats[name] = m
    return m


def glowmat(name, inner, outer, strength=1.0):
    """Emissive material with a facing gradient (bright centre) for bulbs and core windows."""
    if name in _mats:
        return _mats[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    lw = nt.nodes.new("ShaderNodeLayerWeight")
    lw.inputs["Blend"].default_value = 0.5
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = lin(inner)
    ramp.color_ramp.elements[1].color = lin(outer)
    ramp.color_ramp.elements[0].position = 0.35
    ramp.color_ramp.elements[1].position = 0.9
    nt.links.new(lw.outputs["Facing"], ramp.inputs[0])
    nt.links.new(ramp.outputs[0], em.inputs["Color"])
    em.inputs["Strength"].default_value = strength
    nt.links.new(em.outputs[0], out.inputs[0])
    _mats[name] = m
    return m


def override_mat(kind, ao_dist=0.3):
    nm = "ov_" + kind
    m = bpy.data.materials.get(nm)
    if m:
        bpy.data.materials.remove(m)
    m = bpy.data.materials.new(nm)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(em.outputs[0], out.inputs[0])
    if kind == "nrm":
        geo = nt.nodes.new("ShaderNodeNewGeometry")
        vt = nt.nodes.new("ShaderNodeVectorTransform")
        vt.vector_type = "NORMAL"
        vt.convert_from = "WORLD"
        vt.convert_to = "CAMERA"
        nt.links.new(geo.outputs["Normal"], vt.inputs[0])
        flip = nt.nodes.new("ShaderNodeVectorMath")   # Cycles camera space looks along +Z; sprite space has z out
        flip.operation = "MULTIPLY"
        flip.inputs[1].default_value = (1.0, 1.0, -1.0)
        nt.links.new(vt.outputs[0], flip.inputs[0])
        vm = nt.nodes.new("ShaderNodeVectorMath")
        vm.operation = "MULTIPLY_ADD"
        vm.inputs[1].default_value = (0.5, 0.5, 0.5)
        vm.inputs[2].default_value = (0.5, 0.5, 0.5)
        nt.links.new(flip.outputs[0], vm.inputs[0])
        nt.links.new(vm.outputs[0], em.inputs["Color"])
    else:
        ao = nt.nodes.new("ShaderNodeAmbientOcclusion")
        ao.inputs["Distance"].default_value = ao_dist
        ao.samples = 16
        nt.links.new(ao.outputs["Color"] if False else ao.outputs["AO"], em.inputs["Color"])
    return m


# ---------------------------------------------------------------- geometry helpers
LAYERS = {}
_cur = [None]


def layer(name):
    _cur[0] = name
    LAYERS.setdefault(name, {"all": [], "glow": []})


def _register(o, glow=False):
    LAYERS[_cur[0]]["all"].append(o)
    if glow:
        LAYERS[_cur[0]]["glow"].append(o)
    return o


def finish(o, m, bevel=0.0, glow=False, seg=3, smooth=True):
    o.data.materials.clear()
    o.data.materials.append(m)
    if smooth:
        bm = bmesh.new()
        bm.from_mesh(o.data)
        for e in bm.edges:
            if len(e.link_faces) == 2:
                e.smooth = e.calc_face_angle(0.0) < math.radians(35)
        for f in bm.faces:
            f.smooth = True
        bm.to_mesh(o.data)
        bm.free()
    if bevel > 0:
        b = o.modifiers.new("bev", "BEVEL")
        b.width = bevel
        b.segments = seg
        b.limit_method = "ANGLE"
        b.angle_limit = math.radians(35)
        b.harden_normals = True
    return _register(o, glow)


def box(size, loc, m, bevel=0.012, rot=(0, 0, 0), glow=False):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    return finish(o, m, bevel, glow)


def cyl(r, depth, loc, m, axis="Z", bevel=0.01, verts=40, glow=False, r2=None, scale=None):
    rot = {"Z": (0, 0, 0), "Y": (math.pi / 2, 0, 0), "X": (0, math.pi / 2, 0)}[axis]
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc, rotation=rot)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=depth, location=loc, rotation=rot)
    o = bpy.context.active_object
    if scale:
        o.scale = scale
        bpy.ops.object.transform_apply(scale=True)
    return finish(o, m, bevel, glow)


def sphere(r, loc, m, scale=(1, 1, 1), glow=False, seg=32, twin=False):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=seg // 2, radius=r, location=loc)
    o = bpy.context.active_object
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    if twin:
        o["hide_alb"] = True       # emissive twin of a dark glass object: only drawn in the emission pass
    return finish(o, m, 0.0, glow)


def limb(p0, p1, r0, r1, m, verts=20):
    """Tapered cylinder between two points (cone with matching axis)."""
    a, b = Vector(p0), Vector(p1)
    d = b - a
    L = d.length
    mid = (a + b) / 2
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r0, radius2=r1, depth=L, location=mid)
    o = bpy.context.active_object
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
    bpy.ops.object.transform_apply(rotation=True)
    return finish(o, m, 0.0)


def polyprism(pts, y0, y1, m, glow=False):
    """Extrude a polygon in the X-Z plane between y0 and y1 (flat, no bevel)."""
    me = bpy.data.meshes.new("pp")
    verts = [(x, y0, z) for x, z in pts] + [(x, y1, z) for x, z in pts]
    n = len(pts)
    faces = [list(range(n)), list(range(2 * n - 1, n - 1, -1))]
    for i in range(n):
        faces.append([i, (i + 1) % n, n + (i + 1) % n, n + i])
    me.from_pydata(verts, [], faces)
    me.update()
    o = bpy.data.objects.new("pp", me)
    bpy.context.collection.objects.link(o)
    bpy.context.view_layer.objects.active = o
    return finish(o, m, 0.0, glow, smooth=False)


def gauge(cx, cz, r, y, brass, face, needle, ang):
    cyl(r, 0.07, (cx, y, cz), brass, "Y", bevel=0.012)
    cyl(r * 0.82, 0.02, (cx, y - 0.04, cz), face, "Y", bevel=0.004)
    for i in range(11):
        a = math.radians(-120 + i * 24)
        tx = cx + math.sin(a) * r * 0.66
        tz = cz + math.cos(a) * r * 0.66
        box((r * 0.05, 0.012, r * 0.16 if i % 5 == 0 else r * 0.10), (tx, y - 0.052, tz), needle, bevel=0.0,
            rot=(0, -a, 0))
    na = math.radians(ang)
    box((r * 0.06, 0.012, r * 0.62), (cx + math.sin(na) * r * 0.28, y - 0.062, cz + math.cos(na) * r * 0.28),
        needle, bevel=0.0, rot=(0, -na, 0))
    cyl(r * 0.1, 0.03, (cx, y - 0.068, cz), brass, "Y", bevel=0.004, verts=16)


def rivet(x, z, y, m, r=0.017):
    sphere(r, (x, y, z), m, scale=(1, 0.55, 1), seg=12)


# ---------------------------------------------------------------- palette
def palette():
    P = {}
    P["steel_d"] = mat("steel_d", "3a424b", "7d8791", 0.5, 18, wear_amt=0.7)
    P["steel_m"] = mat("steel_m", "566370", "9aa6b1", 0.45, 22, wear_amt=0.8)
    P["steel_l"] = mat("steel_l", "76828e", "b5c0ca", 0.35, 26, wear_amt=0.8)
    P["panel_a"] = mat("panel_a", "444d56", "86919b", 0.55, 16, wear_amt=0.6)
    P["panel_b"] = mat("panel_b", "3c464f", "7a858f", 0.6, 14, wear_amt=0.6)
    P["panel_c"] = mat("panel_c", "4b4f4a", "8b8f84", 0.6, 13, wear_amt=0.6)
    P["brass"] = mat("brass", "b48a3a", "f0d38a", 0.35, 30, wear_amt=1.0)
    P["brass_d"] = mat("brass_d", "7c5c22", "d0a85a", 0.4, 30)
    P["haz"] = mat("haz", "dcaa1c", None, 0.35, 20, stripes=5.5)
    P["yellow"] = mat("yellow", "dcaa1c", "f0d060", 0.3, 20)
    P["black"] = mat("black", "17191d", "50555c", 0.2, 20)
    P["cream"] = mat("cream", "e6dcbc", None, 0.25, 40)
    P["red"] = mat("red", "b8332a", "e8806a", 0.3, 20)
    P["dark_glass"] = mat("dark_glass", "0b2218", "2f6a4a", 0.1, 10)
    P["cable_r"] = mat("cable_r", "9c2b22", None, 0.3, 30)
    P["cable_b"] = mat("cable_b", "2a4f86", None, 0.3, 30)
    P["cable_k"] = mat("cable_k", "1c1c20", "4a4d55", 0.2, 30)
    P["rubber"] = mat("rubber", "1f1f22", "55585e", 0.3, 30)
    P["olive"] = mat("olive", "5e5d3a", "8a885a", 0.55, 14, wear_amt=0.5)
    P["olive_d"] = mat("olive_d", "46452c", "6e6c44", 0.55, 14, wear_amt=0.4)
    P["hat"] = mat("hat", "e0b020", "f6dc70", 0.4, 24, wear_amt=0.8)
    P["leather"] = mat("leather", "5c3a22", "8c6240", 0.5, 26, wear_amt=0.8)
    P["skin"] = mat("skin", "c79d7c", None, 0.25, 40)
    P["glove"] = mat("glove", "2c2723", "5a524a", 0.3, 30)
    P["boot"] = mat("boot", "2b2420", "5c5048", 0.4, 30, wear_amt=0.8)
    P["hair"] = mat("hair", "3a2c22", None, 0.2, 40)
    P["wood"] = mat("wood", "7a5634", "a88256", 0.4, 40)
    P["lens"] = mat("lens", "d8ecff", None, 0.0, 40)
    P["glow_core"] = glowmat("glow_core", "6df08a", "0a7430", 1.0)
    P["glow_bulb"] = glowmat("glow_bulb", "fff4d8", "ffc060", 1.0)
    P["glow_lens"] = glowmat("glow_lens", "ffffff", "cfe8ff", 1.0)
    return P


# ---------------------------------------------------------------- layers
def build_wall(P):
    layer("wall")
    box((4.0, 0.10, 3.0), (0, 0.05, 1.5), P["steel_d"], bevel=0.0)
    cols = [-1.5, -0.5, 0.5, 1.5]
    rows = [0.5, 1.5, 2.5]
    pm = [P["panel_a"], P["panel_b"], P["panel_c"]]
    for xi, x in enumerate(cols):
        for zi, z in enumerate(rows):
            rec = rng.random() < 0.3
            y = -0.012 + (0.012 if rec else 0.0)
            box((0.95, 0.045, 0.95), (x, y, z), pm[rng.randrange(3)], bevel=0.016)
            ins = 0.075
            for sx in (-1, 1):
                for sz in (-1, 1):
                    rivet(x + sx * (0.5 - ins), z + sz * (0.5 - ins), y - 0.028, P["steel_l"])
            for t in (-0.27, 0.0, 0.27):
                for sz in (-1, 1):
                    rivet(x + t, z + sz * (0.5 - ins), y - 0.028, P["steel_l"], 0.013)
                    rivet(x + sz * (0.5 - ins), z + t, y - 0.028, P["steel_l"], 0.013)
    # vertical conduits with brackets
    for x in (-1.78, 1.78):
        cyl(0.065, 3.0, (x, -0.09, 1.5), P["steel_l"], "Z", bevel=0.01, verts=28)
        for z in (0.35, 1.1, 1.85, 2.6):
            box((0.17, 0.05, 0.05), (x, -0.075, z), P["steel_m"], bevel=0.01)
            cyl(0.085, 0.05, (x, -0.09, z + 0.07), P["brass_d"], "Z", bevel=0.01, verts=28)
    # horizontal conduit and elbow stubs
    cyl(0.045, 3.4, (0.0, -0.075, 0.21), P["steel_m"], "X", bevel=0.008, verts=24)
    for x in (-1.2, -0.3, 0.9):
        cyl(0.062, 0.05, (x, -0.075, 0.21), P["brass_d"], "X", bevel=0.008, verts=24)
    # cable tray
    box((3.5, 0.13, 0.07), (0.0, -0.075, 2.32), P["steel_m"], bevel=0.01)
    box((3.5, 0.02, 0.2), (0.0, -0.01, 2.40), P["steel_d"], bevel=0.005)
    for i in range(30):
        box((0.02, 0.13, 0.22), (-1.7 + i * 0.117, -0.075, 2.43), P["steel_m"], bevel=0.004)
    for k, (mm, dz) in enumerate([(P["cable_r"], 0.0), (P["cable_b"], 0.03), (P["cable_k"], 0.06)]):
        cyl(0.021, 3.4, (0.0, -0.085, 2.40 + dz + 0.03), mm, "X", bevel=0.0, verts=14)
    # gauges
    gauge(-1.05, 1.85, 0.17, -0.06, P["brass"], P["cream"], P["black"], 40)
    gauge(-0.62, 1.85, 0.17, -0.06, P["brass"], P["cream"], P["black"], -35)
    gauge(1.0, 1.95, 0.27, -0.06, P["brass"], P["cream"], P["black"], 15)
    # hazard panel
    box((0.9, 0.04, 0.2), (1.3, -0.05, 0.58), P["haz"], bevel=0.008)
    for sx in (-1, 1):
        rivet(1.3 + sx * 0.42, 0.58, -0.075, P["steel_l"])
    # red alarm fixture (unlit red glass), upper right
    cyl(0.09, 0.05, (1.55, -0.07, 2.78), P["steel_m"], "Y", bevel=0.01, verts=28)
    sphere(0.075, (1.55, -0.1, 2.78), P["red"], scale=(1, 0.7, 1))
    # junction box with switches
    box((0.46, 0.09, 0.34), (-1.2, -0.07, 1.0), P["steel_l"], bevel=0.012)
    for i in range(3):
        box((0.045, 0.06, 0.09), (-1.31 + i * 0.11, -0.13, 1.03), P["black"], bevel=0.008)
        box((0.02, 0.07, 0.05), (-1.31 + i * 0.11, -0.16, 1.05 if i != 1 else 1.0), P["red"] if i == 2 else P["cream"],
            bevel=0.006)
    cyl(0.03, 0.05, (-1.05, -0.13, 0.93), P["red"], "Y", bevel=0.006, verts=16)
    # vent grille
    box((0.6, 0.05, 0.4), (0.25, -0.05, 1.07), P["steel_d"], bevel=0.01)
    for i in range(7):
        box((0.52, 0.03, 0.022), (0.25, -0.085, 0.92 + i * 0.05), P["black"], bevel=0.004)


def build_reactor(P):
    layer("reactor")
    cyl(0.74, 0.20, (0, 0, 0.10), P["haz"], "Z", bevel=0.018, verts=64)
    cyl(0.62, 0.05, (0, 0, 0.225), P["steel_m"], "Z", bevel=0.01, verts=64)
    cyl(0.52, 1.08, (0, 0, 0.77), P["steel_d"], "Z", bevel=0.014, verts=64)
    for z, w in ((0.36, 0.07), (0.74, 0.05), (1.17, 0.07)):
        cyl(0.545, w, (0, 0, z), P["brass"], "Z", bevel=0.012, verts=64)
    for a in range(0, 360, 30):
        r = math.radians(a)
        if math.cos(r) > -0.2:
            pass
    # core window bezel, glass (separate glow object), bolts
    cyl(0.285, 0.13, (0, -0.50, 0.80), P["brass"], "Y", bevel=0.02, verts=48)
    sphere(0.205, (0, -0.545, 0.80), P["dark_glass"], scale=(1, 0.35, 1), glow=False)
    sphere(0.205, (0, -0.545, 0.80), P["glow_core"], scale=(1, 0.35, 1), glow=True, twin=True)
    for i in range(8):
        a = math.radians(i * 45 + 22.5)
        cyl(0.022, 0.03, (math.sin(a) * 0.245, -0.572, 0.80 + math.cos(a) * 0.245), P["steel_l"], "Y", bevel=0.005,
            verts=12)
    # shoulder, cap, stack
    cyl(0.46, 0.14, (0, 0, 1.38), P["steel_m"], "Z", bevel=0.02, verts=64)
    sphere(0.44, (0, 0, 1.44), P["steel_l"], scale=(1, 1, 0.38), seg=48)
    cyl(0.12, 0.20, (0, 0, 1.60), P["steel_d"], "Z", bevel=0.01, verts=32)
    cyl(0.17, 0.045, (0, 0, 1.675), P["brass"], "Z", bevel=0.01, verts=40)
    # side pipes with flanges
    cyl(0.085, 0.50, (-0.65, 0.0, 1.08), P["steel_l"], "X", bevel=0.01, verts=28)
    cyl(0.12, 0.05, (-0.40, 0.0, 1.08), P["brass_d"], "X", bevel=0.01, verts=28)
    cyl(0.12, 0.05, (-0.86, 0.0, 1.08), P["brass_d"], "X", bevel=0.01, verts=28)
    cyl(0.085, 0.46, (0.66, 0.0, 0.52), P["steel_l"], "X", bevel=0.01, verts=28)
    cyl(0.12, 0.05, (0.42, 0.0, 0.52), P["brass_d"], "X", bevel=0.01, verts=28)
    cyl(0.12, 0.05, (0.87, 0.0, 0.52), P["brass_d"], "X", bevel=0.01, verts=28)
    # small gauge and valve wheel on body
    gauge(0.33, 1.08, 0.095, -0.50, P["brass"], P["cream"], P["black"], 30)
    cyl(0.07, 0.03, (-0.33, -0.52, 1.12), P["red"], "Y", bevel=0.008, verts=24)
    cyl(0.018, 0.08, (-0.33, -0.50, 1.12), P["steel_l"], "Y", bevel=0.004, verts=12)
    # control box on the plinth
    box((0.34, 0.12, 0.22), (0.36, -0.62, 0.30), P["steel_l"], bevel=0.014)
    for i in range(3):
        cyl(0.022, 0.03, (0.27 + i * 0.09, -0.69, 0.33), [P["red"], P["yellow"], P["cream"]][i], "Y", bevel=0.004,
            verts=14)
    # vertical ribs behind
    for a in (-0.38, 0.38):
        box((0.04, 0.05, 1.0), (a, -0.46, 0.77), P["steel_m"], bevel=0.008)


def build_lamp(P):
    layer("lamp")
    box((0.05, 0.05, 0.12), (0, 0, 0.44), P["steel_l"], bevel=0.008)
    cyl(0.07, 0.04, (0, 0, 0.48), P["brass_d"], "Z", bevel=0.008, verts=24)
    cyl(0.07, 0.16, (0, 0, 0.36), P["steel_m"], "Z", bevel=0.012, verts=32, r2=0.26)
    cyl(0.26, 0.02, (0, 0, 0.275), P["steel_d"], "Z", bevel=0.008, verts=40)
    sphere(0.07, (0, 0, 0.22), P["lens"], scale=(1, 1, 1.15))
    sphere(0.07, (0, 0, 0.22), P["glow_bulb"], scale=(1, 1, 1.15), glow=True, twin=True)
    cyl(0.06, 0.05, (0, 0, 0.285), P["brass"], "Z", bevel=0.006, verts=20)
    for i in range(10):
        a = math.radians(i * 36)
        x = math.cos(a) * 0.14
        y = math.sin(a) * 0.14
        limb((x * 1.05, y * 1.05, 0.27), (x * 0.5, y * 0.5, 0.115), 0.007, 0.007, P["steel_m"], verts=8)
    cyl(0.09, 0.02, (0, 0, 0.11), P["steel_d"], "Z", bevel=0.006, verts=24)
    sphere(0.02, (0, 0, 0.095), P["steel_l"], seg=12)


def build_floor(P):
    layer("floor")
    box((4.0, 0.34, 0.035), (0, -0.05, 0.22), P["steel_l"], bevel=0.008)           # top tread plate
    box((4.0, 0.30, 0.03), (0, -0.05, 0.015), P["steel_m"], bevel=0.008)            # bottom flange
    web = box((4.0, 0.035, 0.175), (0, -0.19, 0.115), P["steel_d"], bevel=0.0)       # web
    for i in range(16):
        x = -1.875 + i * 0.25
        cyl(0.04, 0.05, (x, -0.19, 0.115), P["black"], "Y", bevel=0.0, verts=20)    # lightening holes
    for i in range(33):
        x = -1.99 + i * 0.1244
        rivet(x, 0.205, -0.215, P["steel_l"], 0.011)
    for i in range(32):                                                             # grating bars (visible nosing)
        box((0.022, 0.34, 0.05), (-1.95 + i * 0.1244, -0.05, 0.18), P["steel_m"], bevel=0.004)
    box((4.0, 0.03, 0.03), (0, -0.215, 0.245), P["yellow"], bevel=0.006)             # safety nosing


def build_crew(P, ph=0.0):
    """Expedition engineer facing +X. ph is the idle phase in [0,1)."""
    layer("crew")
    br = math.sin(ph * 2 * math.pi)
    up = 0.010 * br
    sw = 0.012 * br
    yn, yf = -0.07, 0.07                                      # near / far leg depth
    # boots
    box((0.30, 0.12, 0.12), (0.075, yn, 0.06), P["boot"], bevel=0.03)
    box((0.30, 0.12, 0.12), (-0.04, yf, 0.06), P["boot"], bevel=0.03)
    box((0.12, 0.125, 0.04), (0.19, yn, 0.02), P["rubber"], bevel=0.01)
    # legs
    limb((0.02, yn, 0.13), (0.05, yn, 0.52), 0.065, 0.08, P["olive"])
    limb((0.05, yn, 0.52), (0.03, yn, 0.93), 0.082, 0.095, P["olive"])
    limb((-0.03, yf, 0.13), (-0.04, yf, 0.52), 0.065, 0.08, P["olive_d"])
    limb((-0.04, yf, 0.52), (-0.01, yf, 0.93), 0.082, 0.095, P["olive_d"])
    sphere(0.085, (0.05, yn, 0.52), P["olive"])
    # pelvis & torso (slightly forward lean)
    sphere(0.16, (0.0, 0.0, 0.97), P["olive"], scale=(0.95, 1.1, 0.75))
    sphere(0.18, (0.015, 0.0, 1.2 + up), P["olive"], scale=(0.85, 1.12, 1.55))
    sphere(0.17, (0.025, 0.0, 1.42 + up), P["olive"], scale=(0.8, 1.15, 0.85))
    # belt, pouches, hammer
    cyl(0.155, 0.075, (0.0, 0.0, 1.0), P["leather"], "Z", bevel=0.01, verts=36, scale=(0.95, 1.2, 1.0))
    box((0.07, 0.05, 0.05), (0.075, -0.2, 1.0), P["brass"], bevel=0.008)
    box((0.09, 0.06, 0.12), (-0.07, -0.19, 0.93), P["leather"], bevel=0.015)
    box((0.07, 0.05, 0.09), (0.11, -0.19, 0.93), P["leather"], bevel=0.012)
    limb((0.03, -0.21, 0.97), (0.03, -0.22, 0.72), 0.014, 0.014, P["wood"], verts=10)
    box((0.1, 0.045, 0.05), (0.03, -0.22, 0.97 + 0.0), P["steel_l"], bevel=0.008)
    cyl(0.04, 0.05, (-0.12, -0.2, 0.84), P["black"], "Y", bevel=0.006, verts=16)     # coiled line
    # near arm hangs and forearm bends forward holding a wrench
    sh = (0.0, -0.2, 1.5 + up)
    el = (-0.03, -0.235, 1.22 + up * 0.5 + sw)
    wr = (0.17, -0.22, 1.1 + sw)
    limb(sh, el, 0.058, 0.05, P["olive"])
    limb(el, wr, 0.05, 0.04, P["olive"])
    sphere(0.057, el, P["olive"])
    sphere(0.052, wr, P["glove"])
    limb((wr[0], wr[1], wr[2] + 0.02), (wr[0] + 0.15, wr[1], wr[2] - 0.17), 0.016, 0.016, P["steel_l"], verts=10)
    cyl(0.04, 0.03, (wr[0] + 0.155, wr[1], wr[2] - 0.185), P["steel_l"], "Y", bevel=0.004, verts=16)
    # far arm, mostly hidden
    limb((0.0, 0.2, 1.5 + up), (0.02, 0.23, 1.2 + up * 0.5), 0.056, 0.048, P["olive_d"])
    limb((0.02, 0.23, 1.2 + up * 0.5), (0.0, 0.23, 0.98 - sw), 0.048, 0.04, P["olive_d"])
    sphere(0.05, (0.0, 0.23, 0.96 - sw), P["glove"])
    sphere(0.075, (0.0, -0.2, 1.5 + up), P["olive"])
    # chest strap / pocket
    box((0.05, 0.06, 0.12), (0.145, -0.1, 1.33 + up), P["olive_d"], bevel=0.012)
    box((0.03, 0.34, 0.05), (0.095, 0.0, 1.46 + up), P["leather"], bevel=0.008)
    # neck, head, face, hat, headlamp
    limb((0.02, 0, 1.55 + up), (0.03, 0, 1.62 + up), 0.058, 0.055, P["skin"])
    sphere(0.1, (0.045, 0, 1.68 + up), P["skin"], scale=(1.0, 0.9, 1.12))
    sphere(0.025, (0.145, 0, 1.665 + up), P["skin"], scale=(1.1, 0.9, 1.0))            # nose
    sphere(0.045, (0.0, 0, 1.66 + up), P["hair"], scale=(1.1, 1.8, 1.0))               # hair behind hat
    sphere(0.14, (0.04, 0, 1.73 + up), P["hat"], scale=(1.0, 0.95, 0.85))              # hat dome
    cyl(0.145, 0.03, (0.07, 0, 1.715 + up), P["hat"], "Z", bevel=0.01, verts=36, scale=(1.35, 1.0, 1.0))
    box((0.22, 0.04, 0.03), (0.03, 0, 1.845 + up), P["hat"], bevel=0.008)               # hat ridge
    cyl(0.032, 0.05, (0.18, 0, 1.775 + up), P["steel_l"], "X", bevel=0.006, verts=18)    # headlamp body
    cyl(0.026, 0.02, (0.215, 0, 1.775 + up), P["glow_lens"], "X", bevel=0.0, verts=18, glow=True)
    sphere(0.012, (0.1, -0.075, 1.69 + up), P["black"], seg=8)                          # eye


# ---------------------------------------------------------------- render
def setup_render():
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = SAMPLES
    sc.cycles.use_denoising = False
    sc.cycles.filter_width = 1.2
    sc.render.film_transparent = True
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    sc.display_settings.display_device = "sRGB"
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.render.image_settings.color_depth = "8"
    sc.render.resolution_percentage = 100
    cam = bpy.data.cameras.new("cam")
    cam.type = "ORTHO"
    co = bpy.data.objects.new("cam", cam)
    bpy.context.collection.objects.link(co)
    co.rotation_euler = (math.pi / 2, 0, 0)
    sc.camera = co
    # a world with no light: everything is emission
    w = bpy.data.worlds.new("w")
    w.use_nodes = True
    sc.world = w
    return co, cam


def render_layer(name, cx, cz, wm, hm, co, cam, ao_dist, tag=""):
    sc = bpy.context.scene
    vl = bpy.context.view_layer
    sc.render.resolution_x = int(round(wm * PPM))
    sc.render.resolution_y = int(round(hm * PPM))
    cam.ortho_scale = max(wm, hm)
    co.location = (cx, -10.0, cz)
    allobjs = [o for L in LAYERS.values() for o in L["all"]]
    for o in allobjs:
        o.hide_render = True
    for o in LAYERS[name]["all"]:
        o.hide_render = False
    for kind, ov in (("alb", None), ("nrm", override_mat("nrm")), ("ao", override_mat("ao", ao_dist))):
        vl.material_override = ov
        for o in LAYERS[name]["all"]:
            o.hide_render = bool(o.get("hide_alb"))
        sc.view_settings.view_transform = "Standard" if kind == "alb" else "Raw"
        sc.cycles.samples = SAMPLES if kind != "nrm" else max(16, SAMPLES // 2)
        sc.render.filepath = os.path.join(OUT, f"{name}{tag}_{kind}.png")
        bpy.ops.render.render(write_still=True)
    glow = LAYERS[name]["glow"]
    if glow:
        for o in LAYERS[name]["all"]:
            o.hide_render = o not in glow
        vl.material_override = None
        sc.view_settings.view_transform = "Standard"
        sc.render.filepath = os.path.join(OUT, f"{name}{tag}_emi.png")
        bpy.ops.render.render(write_still=True)
    vl.material_override = None
    print("rendered", name, tag, sc.render.resolution_x, "x", sc.render.resolution_y)


def clear_layer(name):
    for o in LAYERS[name]["all"]:
        bpy.data.objects.remove(o, do_unlink=True)
    LAYERS.pop(name, None)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    co, cam = setup_render()
    P = palette()
    want = WANT or ["wall", "reactor", "lamp", "floor", "crew"]
    if "wall" in want:
        build_wall(P)
        render_layer("wall", 0, 1.5, 4.0, 3.0, co, cam, 0.35)
    if "reactor" in want:
        build_reactor(P)
        render_layer("reactor", 0, 0.875, 1.8, 1.75, co, cam, 0.3)
    if "lamp" in want:
        build_lamp(P)
        render_layer("lamp", 0, 0.25, 0.6, 0.5, co, cam, 0.12)
    if "floor" in want:
        build_floor(P)
        render_layer("floor", 0, 0.125, 4.0, 0.25, co, cam, 0.1)
    if "crew" in want:
        for f in range(4):
            if "crew" in LAYERS:
                clear_layer("crew")
            build_crew(P, f / 4.0)
            render_layer("crew", 0, 0.95, 1.1, 1.9, co, cam, 0.2, tag=f"_f{f}")


main()
