"""Builds every model in Sand Rover with Blender, from code.

Run it (from this folder):
    blender -b --python make_models.py -- ../../models

It writes:
    models/*.glb                          what Godot loads
    models/source/sand_rover_models.blend every model in one Blender file, one
                                          collection each: open it, edit, export

Ways of working (pick what you like):
  * Change this script and run it again (good for exact sizes).
  * Or open the .blend, sculpt / model by hand, then File > Export > glTF 2.0
    (.glb) over the file in models/ with the same name. Keep the object
    NAMES the game looks for (e.g. "leg_L0", "wing_L", "claw_R").

Conventions:
  * Metres. The front of every model points along Blender's -Y (that becomes
    +Z in Godot, where the game's "front" is).
  * Every part is coloured by UV-mapping it onto one square of the shared
    palette (textures/models/palette.png, see palette.py). Godot swaps in the
    real palette file, so repainting it recolours all models at once.
  * Vertex colour (red channel) marks the tiny crew's overalls: the game tints
    those per person.
"""

import math
import os
import sys

import bpy
import bmesh

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from palette import uv_of  # noqa: E402

OUT = os.path.abspath(sys.argv[sys.argv.index("--") + 1]) if "--" in sys.argv else os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "models"))
PALETTE_PNG = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../textures/models/palette.png"))

# ---------------------------------------------------------------------------
# Little modelling toolkit
# ---------------------------------------------------------------------------

_materials = {}


def material(name):
    """'palette' (the colour grid) or 'glass' (see-through, for ice)."""
    if name in _materials:
        return _materials[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    tex = m.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(PALETTE_PNG, check_existing=True)
    tex.interpolation = "Closest"
    m.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.7
    if name == "glass":
        bsdf.inputs["Alpha"].default_value = 0.7
        bsdf.inputs["Roughness"].default_value = 0.1
        m.blend_method = "BLEND"
    _materials[name] = m
    return m


def _finish(obj, swatch, bevel=0.0, mat="palette", mask=0.0, smooth=False, wn=False):
    """Bevel, colour (UVs onto a palette square), material, vertex mask.
    wn = "weighted normals": the big flat faces stay flat but the bevelled
    edges shade round, so edges catch a soft highlight like real objects."""
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    if bevel > 0.0:
        mod = obj.modifiers.new("bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 3 if wn else 2
        mod.limit_method = "ANGLE"
        mod.harden_normals = wn
        bpy.ops.object.modifier_apply(modifier=mod.name)
    if wn:
        if hasattr(obj.data, "use_auto_smooth"):
            obj.data.use_auto_smooth = True
        for p in obj.data.polygons:
            p.use_smooth = True
        mod = obj.modifiers.new("wn", "WEIGHTED_NORMAL")
        mod.keep_sharp = True
        bpy.ops.object.modifier_apply(modifier=mod.name)
    paint(obj, swatch)
    obj.data.materials.clear()
    obj.data.materials.append(material(mat))
    set_mask(obj, mask)
    if not wn:
        for p in obj.data.polygons:
            p.use_smooth = smooth
    obj.select_set(False)
    return obj


def paint(obj, swatch):
    """Map every face of obj onto the middle of one palette square."""
    me = obj.data
    if not me.uv_layers:
        me.uv_layers.new(name="UVMap")
    u, v = uv_of(swatch)
    for loop_uv in me.uv_layers.active.data:
        loop_uv.uv = (u, v)


def set_mask(obj, value):
    me = obj.data
    attr = me.color_attributes.get("Col") or me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    for d in attr.data:
        d.color = (value, value, value, 1.0)
    me.color_attributes.active_color = attr


def box(name, size, loc, swatch, bevel=0.01, rot=(0, 0, 0), **kw):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    o.scale = size
    return _finish(o, swatch, bevel, **kw)


def cyl(name, r, depth, loc, swatch, rot=(0, 0, 0), verts=16, bevel=0.0, r2=None, **kw):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=depth, location=loc, rotation=rot, vertices=verts)
    else:
        bpy.ops.mesh.primitive_cone_add(radius1=r, radius2=r2, depth=depth, location=loc, rotation=rot, vertices=verts)
    o = bpy.context.active_object
    o.name = name
    return _finish(o, swatch, bevel, **kw)


def ball(name, r, loc, swatch, scale=(1, 1, 1), seg=14, rings=9, **kw):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=loc, segments=seg, ring_count=rings)
    o = bpy.context.active_object
    o.name = name
    o.scale = scale
    kw.setdefault("smooth", True)
    return _finish(o, swatch, **kw)


def tapered_box(name, size, loc, swatch, top=(0.85, 0.85), shift=0.0, **kw):
    """A box whose top face is smaller (x, depth) than its bottom: cab roofs,
    bonnets. `shift` slides the top backwards (+ = towards the back)."""
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0))
    o = bpy.context.active_object
    o.name = name
    for v in o.data.vertices:
        if v.co.z > 0:
            v.co.x *= top[0]
            v.co.y = v.co.y * top[1] + shift
    o.scale = size
    o.location = loc
    return _finish(o, swatch, **kw)


def arch(name, radius, width, loc, swatch, thickness=0.025, **kw):
    """A wheel arch: the top half of a tube, around the X axis."""
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=width, location=(0, 0, 0),
                                        rotation=(0, math.pi / 2, 0), vertices=24, end_fill_type="NOTHING")
    o = bpy.context.active_object
    o.name = name
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -0.01], context="VERTS")
    bm.to_mesh(o.data)
    bm.free()
    mod = o.modifiers.new("thick", "SOLIDIFY")
    mod.thickness = thickness
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.modifier_apply(modifier=mod.name)
    o.location = loc
    return _finish(o, swatch, **kw)


def flat_ring(name, r_mid, band, loc, swatch, z_thick=0.006, segs=48):
    """A thin flat ring (painted line) lying on the ground."""
    bpy.ops.mesh.primitive_torus_add(major_radius=r_mid, minor_radius=band * 0.5, major_segments=segs,
                                     minor_segments=6, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = (1, 1, z_thick / band)
    return _finish(o, swatch)


def join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    o = bpy.context.active_object
    o.name = name
    o.data.name = name
    bpy.ops.object.select_all(action="DESELECT")
    return o


def set_origin(obj, point):
    """Move an object's pivot (for parts that rotate: legs, wings...)."""
    saved = bpy.context.scene.cursor.location.copy()
    bpy.context.scene.cursor.location = point
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    bpy.context.scene.cursor.location = saved
    obj.select_set(False)


def new_collection(name):
    col = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(col)
    layer = bpy.context.view_layer.layer_collection.children[name]
    bpy.context.view_layer.active_layer_collection = layer
    return col


def bake_ao(col, rays=32):
    """Bake AMBIENT OCCLUSION into the vertex colours: how much each point is
    tucked away in a corner or crevice (1 = open, 0 = hidden). The game
    darkens those spots, which makes models look solid instead of flat.

    How: from every vertex, shoot rays out over the half-sphere above its
    surface; the fraction that escape without hitting the model is its AO.
    (Blender's own vertex-colour bake gave all zeros in background mode, so
    we do it ourselves with a BVH tree: a fast "what does this ray hit?" index.)
    Stored in green and blue; red keeps the crew's overalls mask."""
    import random
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree
    meshes = [o for o in col.all_objects if o.type == "MESH"]
    if not meshes:
        return
    # One combined BVH of the whole model, in world space.
    verts, polys = [], []
    for o in meshes:
        base = len(verts)
        verts += [o.matrix_world @ v.co for v in o.data.vertices]
        polys += [[base + i for i in p.vertices] for p in o.data.polygons]
    tree = BVHTree.FromPolygons(verts, polys)
    size = max(max(o.dimensions) for o in meshes)
    reach = max(0.02, size * 0.25)
    rnd = random.Random(7)
    # Fixed set of directions over a hemisphere around +Z (cosine-weighted).
    dirs = []
    for _ in range(rays):
        u, v = rnd.random(), rnd.random()
        r, a = math.sqrt(u), v * math.tau
        dirs.append(Vector((r * math.cos(a), r * math.sin(a), math.sqrt(max(0.0, 1 - u)))))
    for o in meshes:
        me = o.data
        if "Col" not in me.color_attributes:
            set_mask(o, 0.0)
        colr = me.color_attributes["Col"]
        nm = o.matrix_world.to_3x3().inverted_safe().transposed()
        for vi, v in enumerate(me.vertices):
            p = o.matrix_world @ v.co
            n = (nm @ v.normal).normalized()
            rot = n.to_track_quat("Z", "Y")
            start = p + n * (size * 0.002 + 0.0005)
            hits = 0
            for d in dirs:
                if tree.ray_cast(start, rot @ d, reach)[0] is not None:
                    hits += 1
            ao = 1.0 - hits / rays
            c = colr.data[vi].color
            colr.data[vi].color = (c[0], ao, ao, 1.0)
        me.color_attributes.active_color = colr
        me.color_attributes.render_color_index = me.color_attributes.find("Col")


def export(col, filename):
    bake_ao(col)
    bpy.ops.object.select_all(action="DESELECT")
    for o in col.all_objects:
        o.select_set(True)
    kw = dict(filepath=os.path.join(OUT, filename + ".glb"), export_format="GLB",
              use_selection=True, export_apply=True, export_yup=True)
    try:
        bpy.ops.export_scene.gltf(**kw, export_colors=True)
    except TypeError:
        bpy.ops.export_scene.gltf(**kw, export_vertex_color="ACTIVE")
    bpy.ops.object.select_all(action="DESELECT")
    print("exported", filename)


# Godot (x, y, z) -> Blender (x, -z, y). Handy when copying game sizes.
def G(x, y, z):
    return (x, -z, y)


# ---------------------------------------------------------------------------
# The models
# ---------------------------------------------------------------------------

def truck_body():
    """Chassis + cab (the game adds the bed walls, parts and wheels itself).
    Matches the collision boxes: chassis 1.0 x 0.25 x 1.8, cab 0.8 x 0.3 x 0.5.
    Bevelled with weighted normals, a tapered cab with a raked windscreen, a
    sloped bonnet, wheel arches and a skid plate (Fable's art notes)."""
    col = new_collection("truck_body")
    W = dict(wn=True)
    parts = [
        box("chassis", (1.0, 1.8, 0.25), G(0, 0, 0), "truck_red", bevel=0.035, **W),
        box("skirt", (1.02, 1.82, 0.07), G(0, -0.1, 0), "truck_red_dark", bevel=0.015, **W),
        # Cab: narrower at the top (-15%) and leaning back, so the windscreen rakes.
        tapered_box("cab", (0.8, 0.5, 0.3), G(0, 0.275, 0.55), "truck_red", top=(0.86, 0.8), shift=0.06, bevel=0.035, **W),
        tapered_box("roof", (0.68, 0.38, 0.035), G(0, 0.44, 0.52), "truck_red_dark", top=(0.95, 0.95), bevel=0.012, **W),
        # Windows follow the cab's slopes.
        box("windscreen", (0.6, 0.015, 0.17), G(0, 0.3, 0.785), "glass_dark", rot=(-0.33, 0, 0), bevel=0.006),
        box("back_window", (0.56, 0.015, 0.12), G(0, 0.31, 0.32), "glass_dark", bevel=0.006),
        box("side_window_l", (0.015, 0.3, 0.13), G(-0.375, 0.3, 0.53), "glass_dark", rot=(0, 0.12, 0), bevel=0.006),
        box("side_window_r", (0.015, 0.3, 0.13), G(0.375, 0.3, 0.53), "glass_dark", rot=(0, -0.12, 0), bevel=0.006),
        # Bonnet: a low wedge in front of the cab.
        tapered_box("bonnet", (0.78, 0.13, 0.05), G(0, 0.15, 0.84), "truck_red", top=(0.95, 0.55), shift=0.03, bevel=0.012, **W),
        box("grille", (0.5, 0.02, 0.12), G(0, 0.0, 0.905), "dark_grey", bevel=0.006),
        box("front_bumper", (0.96, 0.08, 0.07), G(0, -0.08, 0.93), "metal_dark", bevel=0.02, **W),
        # Skid plate: angled steel under the nose.
        box("skid", (0.7, 0.16, 0.015), G(0, -0.14, 0.86), "skid_metal", rot=(-0.45, 0, 0), bevel=0.004),
        box("lamp_l", (0.12, 0.02, 0.06), G(-0.36, 0.03, 0.905), "headlight", bevel=0.006),
        box("lamp_r", (0.12, 0.02, 0.06), G(0.36, 0.03, 0.905), "headlight", bevel=0.006),
        box("tail_l", (0.1, 0.02, 0.05), G(-0.38, 0.03, -0.905), "taillight", bevel=0.006),
        box("tail_r", (0.1, 0.02, 0.05), G(0.38, 0.03, -0.905), "taillight", bevel=0.006),
        box("stripe", (0.12, 0.36, 0.004), G(0, 0.459, 0.52), "white", bevel=0.0),
    ]
    # Wheel arches over all four wheels (wheels sit at x +-0.62, z +-0.68).
    for x in (-0.62, 0.62):
        for z in (-0.68, 0.68):
            # Just clear of the tyre (radius 0.32) with room for the suspension.
            parts.append(arch("arch", 0.375, 0.24, G(x, -0.05, z), "truck_red", thickness=0.02, bevel=0.005))
    for k in range(5):   # bed floor ribs
        parts.append(box("rib%d" % k, (0.88, 0.025, 0.012), G(0, 0.131, -0.8 + k * 0.2), "truck_red_dark", bevel=0.0))
    join(parts, "truck_body")
    export(col, "truck_body")


def bed_walls(name, wall_h):
    """The cargo bed's three walls (back, left, right), body red with a dark
    rail along the top and three ribs on each side. Matches rc_car.gd's
    collision boxes: walls 0.05 thick, from y=0.125 up by wall_h."""
    col = new_collection(name)
    y = 0.125 + wall_h * 0.5
    W = dict(wn=True)
    parts = [
        box("back", (1.0, 0.05, wall_h), G(0, y, -0.875), "truck_red", bevel=0.012, **W),
        box("left", (0.05, 1.0, wall_h), G(-0.475, y, -0.4), "truck_red", bevel=0.012, **W),
        box("right", (0.05, 1.0, wall_h), G(0.475, y, -0.4), "truck_red", bevel=0.012, **W),
        box("rail_b", (1.02, 0.07, 0.03), G(0, 0.125 + wall_h, -0.875), "dark_grey", bevel=0.008, **W),
        box("rail_l", (0.07, 1.02, 0.03), G(-0.475, 0.125 + wall_h, -0.4), "dark_grey", bevel=0.008, **W),
        box("rail_r", (0.07, 1.02, 0.03), G(0.475, 0.125 + wall_h, -0.4), "dark_grey", bevel=0.008, **W),
    ]
    for k in range(3):
        z = -0.75 + k * 0.35
        for x in (-0.505, 0.505):
            parts.append(box("rib", (0.015, 0.035, wall_h * 0.8), G(x, y - wall_h * 0.05, z), "truck_red_dark", bevel=0.004))
        parts.append(box("rib_b", (0.035, 0.015, wall_h * 0.8), G(-0.3 + k * 0.3, y - wall_h * 0.05, -0.905), "truck_red_dark", bevel=0.004))
    join(parts, name)
    export(col, name)


def tyre(name, radius, width, paddles=False, blocks=14, rim="yellow", solid=False):
    """A tyre spinning around X, centred on its origin."""
    col = new_collection(name)
    parts = [
        cyl("tyre", radius * (1.0 if solid else 0.92), width, (0, 0, 0), "rubber", rot=(0, math.pi / 2, 0), verts=28, bevel=0.03 if solid else 0.02),
        cyl("rim", radius * 0.55, width + 0.012, (0, 0, 0), rim, rot=(0, math.pi / 2, 0), verts=16, bevel=0.01),
        cyl("hub", radius * 0.2, width + 0.03, (0, 0, 0), "metal", rot=(0, math.pi / 2, 0), verts=10),
    ]
    # Wheel nuts.
    for k in range(5):
        a = k * math.tau / 5
        for side in (-1, 1):
            parts.append(cyl("nut%d%d" % (k, side), 0.018, 0.012,
                             (side * (width / 2 + 0.018), math.cos(a) * radius * 0.32, math.sin(a) * radius * 0.32),
                             "metal_dark", rot=(0, math.pi / 2, 0), verts=6))
    # Tread blocks around the outside (staggered), or big paddles.
    for k in range(blocks):
        a = k * math.tau / blocks
        y, z = math.cos(a), math.sin(a)
        if paddles:
            parts.append(box("paddle%d" % k, (width * 1.02, 0.03, 0.08), (0, y * (radius + 0.02), z * (radius + 0.02)),
                             "rubber", rot=(a, 0, 0), bevel=0.006))
        elif solid:
            # Solid tyres: a smooth band with shallow grooves, no blocks.
            parts.append(box("groove%d" % k, (width * 1.01, 0.012, 0.02), (0, y * radius * 0.995, z * radius * 0.995),
                             "dark_grey", rot=(a, 0, 0), bevel=0.0))
        else:
            off = (k % 2 - 0.5) * width * 0.3
            parts.append(box("block%d" % k, (width * 0.55, radius * 0.11, 0.035), (off, y * radius * 0.95, z * radius * 0.95),
                             "rubber", rot=(a, 0, 0), bevel=0.006))
    join(parts, name)
    export(col, name)


def person():
    """One of the tiny crew: 0.3 m tall, overalls marked for tinting."""
    col = new_collection("person")
    parts = [
        box("boot_l", (0.04, 0.06, 0.03), (-0.025, -0.01, 0.015), "boot", bevel=0.008),
        box("boot_r", (0.04, 0.06, 0.03), (0.025, -0.01, 0.015), "boot", bevel=0.008),
        cyl("leg_l", 0.02, 0.09, (-0.025, 0, 0.075), "overalls", verts=8, mask=1.0),
        cyl("leg_r", 0.02, 0.09, (0.025, 0, 0.075), "overalls", verts=8, mask=1.0),
        ball("torso", 0.055, (0, 0, 0.16), "overalls", scale=(1.0, 0.8, 1.15), seg=10, rings=7, mask=1.0),
        ball("arm_l", 0.017, (-0.065, 0, 0.15), "overalls", scale=(1, 1, 3.2), seg=8, rings=5, mask=1.0),
        ball("arm_r", 0.017, (0.065, 0, 0.15), "overalls", scale=(1, 1, 3.2), seg=8, rings=5, mask=1.0),
        ball("hand_l", 0.015, (-0.067, 0, 0.098), "skin", seg=8, rings=5),
        ball("hand_r", 0.015, (0.067, 0, 0.098), "skin", seg=8, rings=5),
        # Heads and hats 20% bigger than real proportions: they read from
        # far away (a trick from every game with tiny people).
        ball("head", 0.054, (0, 0, 0.255), "skin", seg=12, rings=8),
        ball("eye_l", 0.008, (-0.019, -0.048, 0.26), "eye", seg=6, rings=4),
        ball("eye_r", 0.008, (0.019, -0.048, 0.26), "eye", seg=6, rings=4),
        # A hard hat (they're builders).
        ball("hat", 0.06, (0, 0, 0.276), "hardhat", scale=(1, 1, 0.7), seg=12, rings=6),
        cyl("brim", 0.072, 0.009, (0, -0.01, 0.271), "hardhat", verts=16),
    ]
    join(parts, "person")
    export(col, "person")


def beetle():
    """Dung beetle. Legs are separate objects named leg_L0..leg_R2, with their
    pivot at the hip, so the game can swing them."""
    col = new_collection("beetle")
    body = join([
        ball("shell", 0.35, G(0, 0.02, -0.02), "beetle_shell", scale=(0.85, 1.12, 0.52), seg=18, rings=10),
        ball("thorax", 0.2, G(0, 0.0, 0.3), "beetle_shell", scale=(1.25, 0.9, 0.6), seg=14, rings=8),
        ball("head", 0.13, G(0, -0.02, 0.45), "beetle_dark", scale=(1.2, 0.9, 0.7), seg=12, rings=8),
        cyl("horn", 0.045, 0.2, G(0, 0.07, 0.5), "beetle_dark", rot=(-0.7, 0, 0), r2=0.004, verts=10),
        cyl("horn_l", 0.025, 0.1, G(-0.09, 0.05, 0.47), "beetle_dark", rot=(-0.9, 0.5, 0), r2=0.003, verts=8),
        cyl("horn_r", 0.025, 0.1, G(0.09, 0.05, 0.47), "beetle_dark", rot=(-0.9, -0.5, 0), r2=0.003, verts=8),
        # The seam between the two wing cases: a thin dark slice through the
        # shell, a hair bigger than it, so only a line shows on top.
        ball("seam", 0.35, G(0, 0.022, -0.02), "beetle_dark", scale=(0.03, 1.13, 0.525), seg=18, rings=10),
        cyl("jaw_l", 0.02, 0.1, G(-0.06, -0.06, 0.55), "beetle_dark", rot=(math.pi / 2, 0, 0.4), r2=0.003, verts=6),
        cyl("jaw_r", 0.02, 0.1, G(0.06, -0.06, 0.55), "beetle_dark", rot=(math.pi / 2, 0, -0.4), r2=0.003, verts=6),
    ], "body")
    body.data.materials[0].node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.7
    for side, s in (("L", -1), ("R", 1)):
        for k, z in enumerate((-0.22, 0.0, 0.22)):
            hip = G(0.22 * s, -0.05, z)
            upper = box("u", (0.2, 0.04, 0.04), G(0.32 * s, -0.02, z), "beetle_dark", rot=(0, 0.45 * s, 0), bevel=0.01)
            lower = box("l", (0.04, 0.04, 0.18), G(0.47 * s, -0.12, z), "beetle_dark", rot=(0, -0.6 * s, 0), bevel=0.01)
            foot = ball("f", 0.025, G(0.53 * s, -0.21, z), "beetle_dark", seg=6, rings=4)
            leg = join([upper, lower, foot], "leg_%s%d" % (side, k))
            set_origin(leg, hip)
    export(col, "beetle")


def ant():
    """One ant, 0.2 m long (drawn a bit large so you can see them)."""
    col = new_collection("ant")
    k = 1.7
    parts = [
        ball("head", 0.035 * k, G(0, 0.03 * k, 0.055 * k), "ant_red", scale=(1, 1.15, 0.9), seg=10, rings=6),
        ball("thorax", 0.026 * k, G(0, 0.032 * k, 0), "ant_red", scale=(0.8, 1.6, 0.85), seg=10, rings=6),
        ball("abdomen", 0.045 * k, G(0, 0.04 * k, -0.07 * k), "ant_dark", scale=(0.9, 1.35, 0.85), seg=12, rings=7),
    ]
    for s in (-1, 1):
        for j, z in enumerate((-0.02, 0.0, 0.02)):
            parts.append(box("leg", (0.075 * k, 0.006 * k, 0.006 * k), G(s * 0.04 * k, 0.018 * k, z * k),
                             "ant_dark", rot=(0, (0.5 - j * 0.5) * s, -0.35 * s), bevel=0.0))
        parts.append(box("antenna", (0.004 * k, 0.05 * k, 0.004 * k), G(s * 0.02 * k, 0.06 * k, 0.08 * k),
                         "ant_dark", rot=(0.5, 0, 0.4 * s), bevel=0.0))
    join(parts, "ant")
    export(col, "ant")


def hawk():
    """Hawk. Wings are separate (wing_L, wing_R) with pivots at the shoulders."""
    col = new_collection("hawk")
    join([
        ball("body", 0.12, G(0, 0, 0), "hawk_brown", scale=(0.95, 2.6, 0.95), seg=14, rings=8),
        ball("chest", 0.1, G(0, -0.03, 0.12), "hawk_pale", scale=(0.9, 1.5, 0.9), seg=12, rings=7),
        ball("head", 0.09, G(0, 0.06, 0.33), "hawk_pale", seg=12, rings=8),
        cyl("beak", 0.03, 0.09, G(0, 0.04, 0.43), "beak", rot=(math.pi / 2 + 0.3, 0, 0), r2=0.002, verts=8),
        ball("eye_l", 0.014, G(-0.05, 0.08, 0.37), "eye", seg=6, rings=4),
        ball("eye_r", 0.014, G(0.05, 0.08, 0.37), "eye", seg=6, rings=4),
        box("tail", (0.24, 0.24, 0.02), G(0, 0, -0.4), "hawk_brown", bevel=0.01),
        box("tail_tip", (0.26, 0.05, 0.022), G(0, 0, -0.5), "hawk_pale", bevel=0.005),
        box("talon_l", (0.03, 0.03, 0.09), G(-0.05, -0.14, 0.02), "beak", bevel=0.005),
        box("talon_r", (0.03, 0.03, 0.09), G(0.05, -0.14, 0.02), "beak", bevel=0.005),
    ], "body")
    for side, s in (("L", -1), ("R", 1)):
        inner = box("inner", (0.4, 0.3, 0.025), G(s * 0.3, 0.03, 0.02), "hawk_brown", bevel=0.01)
        outer = box("outer", (0.36, 0.22, 0.02), G(s * 0.66, 0.03, -0.02), "hawk_brown", rot=(0, 0, 0.15 * s), bevel=0.01)
        tip = box("tip", (0.18, 0.18, 0.018), G(s * 0.88, 0.03, -0.05), "hawk_pale", rot=(0, 0, 0.3 * s), bevel=0.008)
        wing = join([inner, outer, tip], "wing_" + side)
        set_origin(wing, G(s * 0.1, 0.03, 0.02))
    export(col, "hawk")


def scorpion():
    """Scorpion. Claws (claw_L, claw_R) and tail are separate, to animate."""
    col = new_collection("scorpion")
    parts = []
    for k in range(4):
        parts.append(ball("seg%d" % k, 0.09 - k * 0.012, G(0, 0.07, 0.12 - k * 0.12), "scorpion_tan",
                          scale=(1.25, 1.1, 0.6), seg=12, rings=7))
    for s in (-1, 1):
        for k in range(4):
            parts.append(box("leg", (0.17, 0.016, 0.02), G(s * 0.12, 0.04, 0.06 - k * 0.07), "scorpion_dark",
                             rot=(0, 0.45 * s, (k - 1.5) * 0.15), bevel=0.0))
        parts.append(ball("eye", 0.012, G(s * 0.03, 0.11, 0.18), "eye", seg=6, rings=4))
    join(parts, "body")
    for side, s in (("L", -1), ("R", 1)):
        arm = box("arm", (0.04, 0.17, 0.035), G(s * 0.12, 0.07, 0.27), "scorpion_tan", rot=(0, 0, 0.4 * s), bevel=0.01)  # box sizes are Blender axes (x, depth, height)
        pincer = ball("pincer", 0.05, G(s * 0.16, 0.07, 0.37), "scorpion_dark", scale=(1.0, 1.4, 0.6), seg=10, rings=6)
        tip_a = cyl("tip_a", 0.015, 0.07, G(s * 0.14, 0.07, 0.43), "scorpion_dark", rot=(math.pi / 2, 0, 0), r2=0.002, verts=6)
        tip_b = cyl("tip_b", 0.015, 0.07, G(s * 0.18, 0.07, 0.43), "scorpion_dark", rot=(math.pi / 2, 0, 0), r2=0.002, verts=6)
        claw = join([arm, pincer, tip_a, tip_b], "claw_" + side)
        set_origin(claw, G(s * 0.08, 0.07, 0.18))
    tail = []
    for k in range(5):
        ang = k * 0.5
        tail.append(ball("t%d" % k, 0.042 - k * 0.003, G(0, 0.08 + math.sin(ang) * 0.13 + k * 0.03, -0.36 - math.cos(ang) * 0.05 + k * 0.025),
                         "scorpion_tan" if k < 4 else "scorpion_dark", seg=10, rings=6))
    tail.append(cyl("sting", 0.02, 0.07, G(0, 0.3, -0.2), "sting", rot=(-0.6, 0, 0), r2=0.002, verts=8))
    t = join(tail, "tail")
    set_origin(t, G(0, 0.08, -0.34))
    export(col, "scorpion")


def crate():
    col = new_collection("crate")
    w, h, d = 0.5, 0.4, 0.5
    parts = [box("core", (w - 0.02, d - 0.02, h - 0.02), (0, 0, 0), "wood_light", bevel=0.005)]
    # Planks round the outside, with metal corners.
    for k in range(4):
        z = -h / 2 + 0.05 + k * 0.1
        parts.append(box("plank_f%d" % k, (w, 0.012, 0.08), (0, -d / 2, z), "wood_light" if k % 2 else "wood_dark", bevel=0.004))
        parts.append(box("plank_b%d" % k, (w, 0.012, 0.08), (0, d / 2, z), "wood_light" if k % 2 else "wood_dark", bevel=0.004))
        parts.append(box("plank_l%d" % k, (0.012, d, 0.08), (-w / 2, 0, z), "wood_dark" if k % 2 else "wood_light", bevel=0.004))
        parts.append(box("plank_r%d" % k, (0.012, d, 0.08), (w / 2, 0, z), "wood_dark" if k % 2 else "wood_light", bevel=0.004))
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(box("corner", (0.05, 0.05, h + 0.01), (sx * w / 2, sy * d / 2, 0), "metal_dark", bevel=0.006))
    join(parts, "crate")
    export(col, "crate")


def barrel():
    col = new_collection("barrel")
    r, h = 0.18, 0.5
    parts = [cyl("drum", r, h, (0, 0, 0), "barrel_blue", verts=20, bevel=0.01)]
    for z in (-0.18, 0.0, 0.18):
        parts.append(cyl("hoop", r + 0.008, 0.025, (0, 0, z), "barrel_rim", verts=20))
    parts.append(cyl("cap", 0.035, 0.03, (0.08, 0, h / 2 + 0.01), "barrel_rim", verts=10))
    join(parts, "barrel")
    export(col, "barrel")


def eggs():
    col = new_collection("eggs")
    parts = [box("tray", (0.55, 0.45, 0.2), (0, 0, -0.025), "egg_tray", bevel=0.01)]
    for i in range(4):
        for j in range(3):
            parts.append(ball("egg", 0.05, (-0.2 + i * 0.133, -0.14 + j * 0.14, 0.1), "egg_white",
                              scale=(1, 1, 1.3), seg=10, rings=7))
    join(parts, "eggs")
    export(col, "eggs")


def engine():
    col = new_collection("engine")
    parts = [
        box("block", (0.4, 0.36, 0.26), (0, 0, -0.03), "engine_grey", bevel=0.015),
        box("head", (0.34, 0.3, 0.06), (0, 0, 0.13), "engine_dark", bevel=0.01),
        cyl("pulley", 0.07, 0.03, (0, -0.2, -0.02), "metal", rot=(math.pi / 2, 0, 0), verts=14),
        cyl("filter", 0.05, 0.1, (0.15, 0.1, 0.12), "orange", verts=12, bevel=0.005),
    ]
    for k in range(4):
        parts.append(cyl("plug", 0.012, 0.05, (-0.12 + k * 0.08, 0, 0.18), "metal", verts=6))
        parts.append(cyl("pipe", 0.016, 0.18, (-0.12 + k * 0.08, -0.12, 0.05), "metal_dark", rot=(0.6, 0, 0), verts=8))
    join(parts, "engine")
    export(col, "engine")


def ice():
    col = new_collection("ice")
    o = box("ice", (0.45, 0.45, 0.45), (0, 0, 0), "ice", bevel=0.04, mat="glass")
    export(col, "ice")


def kit():
    col = new_collection("kit")
    parts = [box("case", (0.6, 0.5, 0.38), (0, 0, 0), "kit_orange", bevel=0.02)]
    for x in (-0.15, 0.15):
        parts.append(box("strap", (0.05, 0.52, 0.39), (x, 0, 0), "dark_grey", bevel=0.004))
    parts.append(box("label", (0.22, 0.01, 0.12), (0, -0.255, 0.04), "kit_white", bevel=0.0))
    parts.append(box("handle", (0.14, 0.03, 0.03), (0, 0, 0.205), "dark_grey", bevel=0.008))
    join(parts, "kit")
    export(col, "kit")


def trailer():
    """Matches trailer.gd: bed 0.9 x 0.12 x 1.1, walls 0.2 high, tow bar to z=1.15."""
    col = new_collection("trailer")
    parts = [
        box("bed", (0.9, 1.1, 0.12), G(0, 0, 0), "truck_red", bevel=0.02),
        box("wall_b", (0.9, 0.04, 0.2), G(0, 0.16, -0.53), "dark_grey", bevel=0.008),
        box("wall_f", (0.9, 0.04, 0.2), G(0, 0.16, 0.53), "dark_grey", bevel=0.008),
        box("wall_l", (0.04, 1.1, 0.2), G(-0.43, 0.16, 0), "dark_grey", bevel=0.008),
        box("wall_r", (0.04, 1.1, 0.2), G(0.43, 0.16, 0), "dark_grey", bevel=0.008),
        box("towbar", (0.06, 0.62, 0.06), G(0, 0.0, 0.85), "metal_dark", bevel=0.01),
        ball("coupler", 0.045, G(0, 0.0, 1.15), "metal", seg=10, rings=6),
        box("tail_l", (0.1, 0.02, 0.05), G(-0.35, 0.03, -0.56), "taillight", bevel=0.005),
        box("tail_r", (0.1, 0.02, 0.05), G(0.35, 0.03, -0.56), "taillight", bevel=0.005),
        box("mud_l", (0.2, 0.36, 0.03), G(-0.55, 0.2, -0.1), "dark_grey", bevel=0.01),
        box("mud_r", (0.2, 0.36, 0.03), G(0.55, 0.2, -0.1), "dark_grey", bevel=0.01),
    ]
    join(parts, "trailer")
    export(col, "trailer")


def dead_tree():
    col = new_collection("dead_tree")
    parts = [cyl("trunk", 0.09, 2.2, (0, 0, 1.1), "bark", r2=0.04, verts=9)]
    for k, (h, yaw, tilt, length) in enumerate([(1.4, 0.3, 0.9, 0.9), (1.8, 2.4, 0.8, 0.7), (1.1, 4.2, 1.0, 0.6), (2.0, 5.3, 0.6, 0.5)]):
        dx, dy = math.cos(yaw) * math.sin(tilt) * length / 2, math.sin(yaw) * math.sin(tilt) * length / 2
        parts.append(cyl("branch%d" % k, 0.04, length, (dx, dy, h + math.cos(tilt) * length / 2), "bark_dark",
                         rot=(math.sin(yaw) * -tilt, math.cos(yaw) * tilt, 0), r2=0.012, verts=7))
    join(parts, "dead_tree")
    export(col, "dead_tree")


def mast():
    col = new_collection("mast")
    parts = []
    for s in ((-1, -1), (1, -1), (-1, 1), (1, 1)):   # a lattice tower
        parts.append(cyl("post", 0.02, 5.0, (s[0] * 0.15, s[1] * 0.15, 2.5), "mast", r2=0.012,
                         rot=(-s[1] * 0.02, s[0] * 0.02, 0), verts=6))
    for k in range(10):
        z = 0.3 + k * 0.48
        parts.append(box("rung", (0.3, 0.015, 0.015), (0, -0.15, z), "mast", bevel=0.0))
        parts.append(box("rung2", (0.015, 0.3, 0.015), (0.15, 0, z), "mast", bevel=0.0))
    parts.append(cyl("dish", 0.3, 0.05, (0.25, -0.2, 4.2), "light_grey", rot=(1.0, 0.4, 0), r2=0.08, verts=16))
    parts.append(ball("beacon", 0.06, (0, 0, 5.05), "red_light", seg=10, rings=6))
    join(parts, "mast")
    export(col, "mast")




# ---------------------------------------------------------------------------
# Glass Desert (Ring 2)
# ---------------------------------------------------------------------------

def lodestone():
    """A magnetic rock: lumpy and black with purple veins, iron filings
    standing up on top like hair. About 1.5 m across. Origin at its base."""
    col = new_collection("lodestone")
    parts = [
        ball("rock", 0.7, G(0, 0.38, 0), "lodestone", scale=(1.1, 0.95, 0.72), seg=10, rings=7, smooth=False),
        ball("lump1", 0.4, G(0.45, 0.25, 0.3), "lodestone", scale=(1, 0.9, 0.8), seg=8, rings=6, smooth=False),
        ball("lump2", 0.35, G(-0.5, 0.2, -0.25), "lodestone", scale=(1, 1.1, 0.8), seg=8, rings=6, smooth=False),
        ball("lump3", 0.3, G(-0.2, 0.75, 0.15), "lodestone", scale=(1, 1, 0.9), seg=8, rings=6, smooth=False),
    ]
    # Veins: thin glowing-purple bands wrapped round the rock.
    for k, (a, tilt) in enumerate(((0.3, 0.4), (1.9, -0.3), (3.6, 0.6))):
        parts.append(box("vein%d" % k, (0.04, 1.5, 0.03), G(math.cos(a) * 0.25, 0.45, math.sin(a) * 0.25),
                         "lodestone_vein", rot=(tilt, 0, a), bevel=0.0))
    # Iron filings, standing up along the field lines.
    for k in range(16):
        a = k * 2.4
        r = 0.15 + (k % 4) * 0.1
        parts.append(cyl("filing%d" % k, 0.012, 0.16, G(math.cos(a) * r, 0.95 - r * 0.4, math.sin(a) * r * 0.8),
                         "metal_dark", rot=(math.sin(a) * 0.4, math.cos(a) * 0.4, 0), r2=0.002, verts=4))
    join(parts, "lodestone")
    export(col, "lodestone")


def shards():
    """A little cluster of broken glass blades (drawn hundreds of times)."""
    col = new_collection("shards")
    parts = []
    for k, (x, z, h, lean, turn) in enumerate(((0, 0, 0.13, 0.25, 0.0), (0.05, 0.03, 0.08, -0.4, 1.2),
                                                 (-0.04, 0.04, 0.1, 0.5, 2.3), (0.01, -0.05, 0.06, -0.3, 4.0))):
        parts.append(cyl("blade%d" % k, 0.03, h, G(x, h * 0.4, z), "glass_shard",
                         rot=(lean, 0, turn), r2=0.001, verts=3, mat="glass"))
    join(parts, "shards")
    export(col, "shards")


# ---------------------------------------------------------------------------
# Build parts (bolted on in the workshop). Each is centred on its origin and
# sized like the part's box in build_parts.gd: (width, height, depth), with
# DEPTH pointing OUT from the truck, i.e. "forward" (-Y in Blender).
# ---------------------------------------------------------------------------

def part(name, objs):
    col = new_collection(name)
    join(objs(), name)
    export(col, name)


def part_ballast():
    part("part_ballast", lambda: [
        box("block", (0.2, 0.18, 0.15), G(0, -0.01, 0), "metal_dark", bevel=0.015),
        cyl("ring", 0.035, 0.012, G(0, 0.075, 0), "metal", verts=12),
        box("label", (0.1, 0.005, 0.05), G(0, 0, 0.09), "yellow", bevel=0.0),
    ])


def part_bumper():
    col = new_collection("part_bumper")
    objs = [box("bar", (0.32, 0.03, 0.1), G(0, 0, 0.008), "yellow", bevel=0.012)]
    for k in range(4):
        objs.append(box("stripe%d" % k, (0.03, 0.002, 0.11), G(-0.12 + k * 0.08, 0, 0.024), "black_stripe",
                        rot=(0, 0.6, 0), bevel=0.0))
    for x in (-0.1, 0.1):
        objs.append(box("bracket", (0.03, 0.03, 0.06), G(x, 0, -0.012), "metal_dark", bevel=0.004))
    join(objs, "part_bumper")
    export(col, "part_bumper")


def part_battery_cell():
    part("part_battery_cell", lambda: [
        box("cell", (0.2, 0.14, 0.15), G(0, -0.005, 0), "battery_green", bevel=0.012),
        box("band", (0.205, 0.04, 0.152), G(0, 0.02, 0), "dark_grey", bevel=0.004),
        cyl("plus", 0.015, 0.02, G(-0.05, 0.08, 0), "taillight", verts=8),
        cyl("minus", 0.015, 0.02, G(0.05, 0.08, 0), "rubber", verts=8),
    ])


def part_solar_tile():
    col = new_collection("part_solar_tile")
    objs = [box("panel", (0.3, 0.018, 0.3), G(0, 0, 0), "solar_blue", bevel=0.004),
            box("frame", (0.31, 0.012, 0.31), G(0, 0, -0.005), "light_grey", bevel=0.002)]
    for k in range(1, 4):
        t = -0.15 + k * 0.075
        objs.append(box("gx%d" % k, (0.004, 0.002, 0.29), G(t, 0, 0.01), "light_grey", bevel=0.0))
        objs.append(box("gy%d" % k, (0.29, 0.002, 0.004), G(0, t, 0.01), "light_grey", bevel=0.0))
    join(objs, "part_solar_tile")
    export(col, "part_solar_tile")


def part_winch():
    part("part_winch", lambda: [
        box("plate", (0.22, 0.04, 0.12), G(0, -0.002, -0.05), "metal_dark", bevel=0.006),
        cyl("drum", 0.05, 0.16, G(0, 0.0, 0.02), "metal", rot=(0, math.pi / 2, 0), verts=14),
        cyl("cable", 0.055, 0.1, G(0, 0.0, 0.02), "rubber", rot=(0, math.pi / 2, 0), verts=14),
        box("end_l", (0.02, 0.13, 0.12), G(-0.1, 0, 0.0), "truck_red_dark", bevel=0.005),
        box("end_r", (0.02, 0.13, 0.12), G(0.1, 0, 0.0), "truck_red_dark", bevel=0.005),
        cyl("hook", 0.018, 0.04, G(0, -0.03, 0.065), "yellow", rot=(math.pi / 2, 0, 0), verts=8),
    ])


def part_headlight():
    part("part_headlight", lambda: [
        box("housing", (0.12, 0.05, 0.08), G(0, 0, -0.005), "dark_grey", bevel=0.012),
        box("bracket", (0.03, 0.03, 0.02), G(0, -0.03, -0.025), "metal_dark", bevel=0.003),
    ])


def part_buzzer():
    part("part_buzzer", lambda: [
        box("case", (0.12, 0.08, 0.08), G(0, -0.008, 0), "yellow", bevel=0.01),
        cyl("coil", 0.028, 0.05, G(0, 0.0, 0.03), "orange", rot=(math.pi / 2, 0, 0), verts=12),
        cyl("prong_l", 0.006, 0.05, G(-0.03, 0.035, 0.03), "metal", verts=6),
        cyl("prong_r", 0.006, 0.05, G(0.03, 0.035, 0.03), "metal", verts=6),
        ball("spark", 0.01, G(0, 0.06, 0.03), "blue_led", seg=6, rings=4),
    ])


def part_hitch():
    part("part_hitch", lambda: [
        box("bar", (0.06, 0.2, 0.06), G(0, 0, 0), "metal_dark", bevel=0.008),
        ball("ball", 0.05, G(0, 0.02, 0.12), "metal", seg=12, rings=8),
        box("plate", (0.12, 0.015, 0.08), G(0, 0, -0.095), "metal_dark", bevel=0.004),
    ])


def part_sandbag():
    part("part_sandbag", lambda: [
        ball("sack", 0.12, G(0, -0.005, 0), "sandbag", scale=(1.0, 0.75, 0.55), seg=12, rings=8),
        box("seam", (0.2, 0.006, 0.01), G(0, 0, 0.085), "sandbag_dark", bevel=0.0),
        cyl("tie", 0.02, 0.04, G(0.11, 0.0, 0.0), "sandbag_dark", rot=(0, math.pi / 2, 0), verts=8),
    ])


def part_spare():
    """A spare wheel, lying flat against the truck (its axle points out)."""
    r, w = 0.15, 0.11
    col = new_collection("part_spare")
    objs = [cyl("tyre", r, w, G(0, 0, 0), "rubber", rot=(math.pi / 2, 0, 0), verts=22, bevel=0.015),
            cyl("rim", r * 0.55, w + 0.01, G(0, 0, 0), "yellow", rot=(math.pi / 2, 0, 0), verts=14),
            box("strap", (0.025, 0.01, 0.32), G(0, 0, w * 0.5 + 0.004), "rubber", bevel=0.0)]
    for k in range(10):
        a = k * math.tau / 10
        objs.append(box("block%d" % k, (0.03, w * 0.9, 0.05), (math.cos(a) * r * 0.97, 0, math.sin(a) * r * 0.97),
                        "rubber", rot=(0, -a, 0), bevel=0.004))
    join(objs, "part_spare")
    export(col, "part_spare")




# ---------------------------------------------------------------------------
# The Drift (Ring 3)
# ---------------------------------------------------------------------------

def ray():
    """A drift ray: a flat diamond that swims in sand, with a fin on its
    back and a whip tail. The wings (wing_L, wing_R) flap, pivoting at the
    body's edge. About 1.4 m across. Front = -Y."""
    col = new_collection("ray")
    join([
        ball("body", 0.32, G(0, 0.03, 0.05), "ray_top", scale=(1.0, 1.35, 0.22), seg=16, rings=8),
        ball("belly", 0.3, G(0, 0.0, 0.05), "ray_belly", scale=(0.95, 1.3, 0.15), seg=14, rings=6),
        box("fin", (0.02, 0.18, 0.14), G(0, 0.11, -0.05), "ray_top", rot=(0.4, 0, 0), bevel=0.008),
        ball("eye_l", 0.025, G(-0.1, 0.07, 0.3), "eye", seg=6, rings=4),
        ball("eye_r", 0.025, G(0.1, 0.07, 0.3), "eye", seg=6, rings=4),
        cyl("tail", 0.025, 0.7, G(0, 0.02, -0.62), "ray_top", rot=(math.pi / 2, 0, 0), r2=0.004, verts=8),
    ], "body")
    for side, s in (("L", -1), ("R", 1)):
        w = join([
            ball("wing", 0.3, G(s * 0.33, 0.02, 0.0), "ray_top", scale=(1.25, 0.85, 0.12), seg=12, rings=6),
            ball("tip", 0.1, G(s * 0.62, 0.02, -0.08), "ray_belly", scale=(1.2, 0.8, 0.12), seg=8, rings=5),
        ], "wing_" + side)
        set_origin(w, G(s * 0.22, 0.02, 0.0))
    export(col, "ray")


def orb():
    """The signal orb: a glowing ball in a metal cage band."""
    col = new_collection("orb")
    join([
        ball("glow", 0.16, (0, 0, 0), "orb_glow", seg=18, rings=12),
        cyl("band_a", 0.172, 0.025, (0, 0, 0), "hull_metal", verts=20),
        cyl("band_b", 0.172, 0.025, (0, 0, 0), "hull_metal", rot=(math.pi / 2, 0, 0), verts=20),
    ], "orb")
    export(col, "orb")


def part_gyro():
    col = new_collection("part_gyro")
    join([
        box("base", (0.2, 0.2, 0.03), G(0, -0.065, 0), "metal_dark", bevel=0.006),
        cyl("ring", 0.09, 0.03, G(0, 0.0, 0), "gyro_blue", rot=(math.pi / 2, 0, 0), verts=20, bevel=0.005),
        cyl("wheel", 0.07, 0.04, G(0, 0.0, 0), "metal", rot=(0, math.pi / 2, 0), verts=18),
        cyl("axle", 0.012, 0.16, G(0, 0.0, 0), "metal_dark", rot=(0, math.pi / 2, 0), verts=8),
        box("post_l", (0.02, 0.02, 0.13), G(-0.08, -0.01, 0), "metal_dark", bevel=0.004),
        box("post_r", (0.02, 0.02, 0.13), G(0.08, -0.01, 0), "metal_dark", bevel=0.004),
        ball("led", 0.012, G(0.06, -0.05, 0.08), "green_led", seg=6, rings=4),
    ], "part_gyro")
    export(col, "part_gyro")


def part_wing():
    """A rear wing / roof spoiler: an airfoil on two struts. Depth points out
    of the truck (up, on the roof), so the struts run along the depth."""
    col = new_collection("part_wing")
    join([
        box("blade", (0.56, 0.1, 0.02), G(0, 0.0, 0.04), "wing_white", rot=(0.12, 0, 0), bevel=0.008),
        box("end_l", (0.012, 0.12, 0.06), G(-0.28, 0.0, 0.035), "truck_red", bevel=0.003),
        box("end_r", (0.012, 0.12, 0.06), G(0.28, 0.0, 0.035), "truck_red", bevel=0.003),
        box("strut_l", (0.02, 0.03, 0.08), G(-0.14, 0.0, -0.01), "metal_dark", bevel=0.004),
        box("strut_r", (0.02, 0.03, 0.08), G(0.14, 0.0, -0.01), "metal_dark", bevel=0.004),
    ], "part_wing")
    export(col, "part_wing")


def hull():
    """The buried ship: a long curved hull with ribs, panels and lights.
    About 13 m long. Only the top half sticks out of the sand."""
    col = new_collection("hull")
    parts = [
        ball("hull", 2.2, G(0, 0.6, 0), "hull_metal", scale=(0.95, 3.0, 0.75), seg=28, rings=14),
        ball("dome", 1.0, G(0, 2.0, -2.0), "hull_dark", scale=(1.0, 1.6, 0.6), seg=18, rings=10),
        box("window", (1.2, 0.05, 0.35), G(0, 2.35, -3.1), "hull_light", bevel=0.02, rot=(0.5, 0, 0)),
    ]
    for k in range(7):
        z = -5.4 + k * 1.8
        r = 2.2 * math.sqrt(max(0.0, 1 - (z / 6.6) ** 2))
        # Ribs: thin oval rings that match the hull's (oval) cross-section.
        parts.append(ball("rib%d" % k, 1.0, G(0, 0.6, z), "hull_dark", scale=(r * 0.95 + 0.06, 0.09, r * 0.75 + 0.06), seg=28, rings=8))
    for k in range(5):
        z = -4.0 + k * 2.0
        parts.append(ball("light%d" % k, 0.09, G(1.95, 1.4, z), "hull_light", seg=8, rings=5))
        parts.append(ball("lightb%d" % k, 0.09, G(-1.95, 1.4, z), "hull_light", seg=8, rings=5))
    parts.append(cyl("antenna", 0.04, 1.6, G(0.4, 3.2, 1.5), "hull_metal", verts=8))
    parts.append(ball("antenna_tip", 0.08, G(0.4, 4.0, 1.5), "hull_light", seg=8, rings=5))
    join(parts, "hull")
    export(col, "hull")




# ---------------------------------------------------------------------------
# Bases
# ---------------------------------------------------------------------------

def landing_pad():
    """The base pad: a concrete disc in 8 slabs, crisp painted rings, a low
    kerb and 4 lamps. Radius 3 m (BASE_RADIUS). Origin at ground level."""
    col = new_collection("landing_pad")
    parts = [cyl("slab", 3.0, 0.06, (0, 0, 0.0), "concrete", verts=64, bevel=0.01)]
    for k in range(8):   # slab seams
        a = k * math.pi / 8
        parts.append(box("seam%d" % k, (6.0, 0.02, 0.004), (0, 0, 0.031), "concrete_dark", rot=(0, 0, a), bevel=0.0))
    parts.append(cyl("centre", 0.5, 0.004, (0, 0, 0.032), "concrete_dark", verts=32))
    parts.append(flat_ring("ring_yellow", 2.55, 0.22, (0, 0, 0.034), "yellow", segs=64))
    parts.append(flat_ring("ring_white", 1.35, 0.1, (0, 0, 0.034), "white", segs=48))
    # The kerb: a low rounded rim.
    bpy.ops.mesh.primitive_torus_add(major_radius=3.03, minor_radius=0.05, major_segments=64, minor_segments=8,
                                     location=(0, 0, 0.02))
    k = bpy.context.active_object
    k.scale = (1, 1, 0.7)
    parts.append(_finish(k, "kerb", smooth=True))
    for n in range(4):   # lamps at the corners
        a = math.pi / 4 + n * math.pi / 2
        x, y = math.cos(a) * 3.35, math.sin(a) * 3.35
        parts.append(cyl("post%d" % n, 0.025, 0.6, (x, y, 0.3), "metal_dark", verts=8))
        parts.append(box("head%d" % n, (0.1, 0.1, 0.06), (x, y, 0.62), "dark_grey", bevel=0.01))
        parts.append(box("glow%d" % n, (0.08, 0.08, 0.01), (x, y, 0.59), "lamp_glow", bevel=0.0))
    join(parts, "landing_pad")
    export(col, "landing_pad")


def prop_tent():
    """A small A-frame crew tent (about 1 m long)."""
    col = new_collection("prop_tent")
    join([
        box("side_l", (0.62, 1.0, 0.012), G(-0.2, 0.22, 0), "tent", rot=(0, 0.95, 0), bevel=0.004),
        box("side_r", (0.62, 1.0, 0.012), G(0.2, 0.22, 0), "tent", rot=(0, -0.95, 0), bevel=0.004),
        cyl("pole_f", 0.012, 0.5, G(0, 0.25, 0.5), "wood_dark", verts=6),
        cyl("pole_b", 0.012, 0.5, G(0, 0.25, -0.5), "wood_dark", verts=6),
        cyl("ridge", 0.01, 1.05, G(0, 0.47, 0), "wood_dark", rot=(math.pi / 2, 0, 0), verts=6),
        box("flap", (0.3, 0.01, 0.36), G(0, 0.15, 0.48), "tent_dark", bevel=0.003),
    ], "prop_tent")
    export(col, "prop_tent")


def prop_toolbox():
    """A crew toolbox."""
    col = new_collection("prop_toolbox")
    join([
        box("box", (0.26, 0.12, 0.12), G(0, 0.06, 0), "toolbox", bevel=0.01, wn=True),
        box("lid", (0.27, 0.13, 0.02), G(0, 0.125, 0), "truck_red_dark", bevel=0.006),
        box("handle", (0.12, 0.015, 0.03), G(0, 0.15, 0), "dark_grey", bevel=0.004),
        box("latch", (0.03, 0.005, 0.03), G(0, 0.1, 0.062), "metal", bevel=0.0),
    ], "prop_toolbox")
    export(col, "prop_toolbox")


# ---------------------------------------------------------------------------

def main():
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(os.path.join(OUT, "source"), exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    truck_body()
    bed_walls("bed_low", 0.2)
    bed_walls("bed_high", 0.42)
    landing_pad()
    prop_tent()
    prop_toolbox()
    tyre("tyre_standard", 0.32, 0.22, blocks=28)
    tyre("tyre_balloon", 0.36, 0.34, blocks=36)
    tyre("tyre_paddle", 0.33, 0.24, paddles=True, blocks=10)
    person()
    beetle()
    ant()
    hawk()
    scorpion()
    crate()
    barrel()
    eggs()
    engine()
    ice()
    kit()
    trailer()
    dead_tree()
    mast()
    tyre("tyre_solid", 0.31, 0.22, blocks=16, rim="mid_grey", solid=True)
    lodestone()
    shards()
    part_ballast()
    part_bumper()
    part_battery_cell()
    part_solar_tile()
    part_winch()
    part_headlight()
    part_buzzer()
    part_hitch()
    part_sandbag()
    part_spare()
    ray()
    orb()
    part_gyro()
    part_wing()
    hull()
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "source", "sand_rover_models.blend"))
    print("ALL MODELS DONE")


main()
