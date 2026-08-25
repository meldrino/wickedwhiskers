import bpy, bmesh, sys, math
from mathutils import Vector, Matrix

# ---- CLI: blender --background --python paw_gen.py -- --variant <name> --out <png> ----
args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
def arg(name, default=None):
    return args[args.index(name) + 1] if name in args else default
VARIANT = arg('--variant', 'classic')
OUT = arg('--out', r'C:\crypto\wicked whiskers\screenshots\paw_preview.png')
EXPORT = '--export' in args
FLIP = '--flip' in args
SCALE = float(arg('--scale', '1'))
SHARP = '--sharp' in args
SEG = 28 if SHARP else 14
RES = 900 if SHARP else 640

PRESETS = {
    'quenn':   dict(palm_r=0.028, palm_scale=(1.25, 0.8, 0.9), spread=0.016, base_y=0.022,
                    L1=0.014, L2=0.018, r1=0.008, r2=0.006, r3=0.0045, curl=0.004,
                    claw_len=0.010, claw_r=0.0028, thumb_x=0.026, arm_r=0.016, pad_r=0.007),
    'chunky':  dict(palm_r=0.034, palm_scale=(1.25, 0.82, 0.9), spread=0.020, base_y=0.026,
                    L1=0.013, L2=0.016, r1=0.011, r2=0.0085, r3=0.006, curl=0.003,
                    claw_len=0.008, claw_r=0.0035, thumb_x=0.032, arm_r=0.018, pad_r=0.009),
    'sleek':   dict(palm_r=0.024, palm_scale=(1.2, 0.78, 0.9), spread=0.014, base_y=0.019,
                    L1=0.016, L2=0.022, r1=0.006, r2=0.0042, r3=0.0028, curl=0.006,
                    claw_len=0.013, claw_r=0.0022, thumb_x=0.022, arm_r=0.014, pad_r=0.006),
    'kawaii':  dict(palm_r=0.036, palm_scale=(1.3, 0.78, 0.9), spread=0.013, base_y=0.027,
                    L1=0.010, L2=0.011, r1=0.007, r2=0.0052, r3=0.0038, curl=0.002,
                    claw_len=0.006, claw_r=0.0025, thumb_x=0.026, arm_r=0.015, pad_r=0.009),
    'sharp':   dict(palm_r=0.026, palm_scale=(1.2, 0.8, 0.9), spread=0.015, base_y=0.021,
                    L1=0.014, L2=0.020, r1=0.0075, r2=0.005, r3=0.003, curl=0.005,
                    claw_len=0.018, claw_r=0.0024, thumb_x=0.024, arm_r=0.015, pad_r=0.007),
    'stubby':  dict(palm_r=0.032, palm_scale=(1.28, 0.8, 0.9), spread=0.016, base_y=0.024,
                    L1=0.009, L2=0.009, r1=0.010, r2=0.008, r3=0.006, curl=0.002,
                    claw_len=0.006, claw_r=0.0032, thumb_x=0.030, arm_r=0.017, pad_r=0.009),
}

def clear_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()

def new_mat(name, color, rough):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    return m

def seg(a, b, r1, r2, mat):
    a = Vector(a)
    b = Vector(b)
    d = (b - a)
    length = d.length
    me = bmesh.new()
    bmesh.ops.create_cone(me, segments=SEG, radius1=r1, radius2=r2, depth=length, cap_ends=True)
    mesh = bpy.data.meshes.new("m")
    me.to_mesh(mesh)
    o = bpy.data.objects.new("s", mesh)
    bpy.context.collection.objects.link(o)
    me.free()
    o.location = (a + b) * 0.5
    if length > 1e-6:
        q = Vector((0, 0, 1)).rotation_difference((b - a).normalized())
        o.rotation_euler = q.to_euler()
    o.data.materials.append(mat)
    return o

def sphere(loc, r, scale, mat):
    me = bmesh.new()
    bmesh.ops.create_uvsphere(me, u_segments=SEG, v_segments=SEG, radius=r)
    mesh = bpy.data.meshes.new("m")
    me.to_mesh(mesh)
    o = bpy.data.objects.new("s", mesh)
    bpy.context.collection.objects.link(o)
    me.free()
    o.location = loc
    o.scale = scale
    o.data.materials.append(mat)
    return o

def build(P, fur, claw, pad):
    palm_r = P["palm_r"]
    palm_top = palm_r * P["palm_scale"][1]
    sphere((0, 0.0, 0.01), palm_r, P["palm_scale"], fur)
    for i, x in enumerate((-P["spread"], 0.0, P["spread"])):
        digit(x, P, 1.0, fur, claw)
    digit(P["thumb_x"], P, 0.8, fur, claw, thumb=True)
    seg((0, 0.0, 0.008), (0, -0.17, 0.008), P["arm_r"] * 0.85, P["arm_r"], fur)
    for i, x in enumerate((-P["spread"], 0.0, P["spread"], P["thumb_x"])):
        sphere((x, palm_top - 0.004, 0.018), P["pad_r"], (0.85, 0.75, 0.4), pad)

def digit(x, P, s, fur, claw, thumb=False):
    base_y = P["base_y"] * s
    r1 = P["r1"] * (1.15 if thumb else 1.0)
    r2 = P["r2"] * (1.12 if thumb else 1.0)
    r3 = P["r3"] * (1.1 if thumb else 1.0)
    L1 = P["L1"] * s
    L2 = P["L2"] * s
    curl = -P["curl"] if thumb else P["curl"]
    splay = 0.008 if thumb else 0.004
    base = Vector((x, base_y, 0.012))
    knuckle = Vector((x + splay, base_y + L1, 0.012 + 0.002))
    tip = Vector((x + curl, knuckle.y + L2, 0.016))
    seg(base, knuckle, r1, r2, fur)
    seg(knuckle, tip, r2, r3, fur)
    d = (tip - knuckle).normalized()
    claw_tip = tip + d * P["claw_len"] + Vector((0.0, -0.006, 0.010))
    seg(tip, claw_tip, P["claw_r"], P["claw_r"] * 0.7, claw)

clear_scene()
fur = new_mat("Fur", (0.976, 0.678, 0.349), 0.9)
claw = new_mat("Claw", (0.961, 0.902, 0.816), 0.6)
pad = new_mat("Pad", (0.788, 0.553, 0.490), 0.7)
P = PRESETS[VARIANT]
build(P, fur, claw, pad)

# join
bpy.ops.object.select_all(action='DESELECT')
for o in bpy.data.objects:
    if o.type == 'MESH':
        o.select_set(True)
if bpy.context.selected_objects:
    bpy.context.view_layer.objects.active = bpy.context.selected_objects[0]
    bpy.ops.object.join()
    paw = bpy.context.active_object
    paw.name = "Paw"
    if FLIP:
        paw.rotation_euler = (0.0, 0.0, math.radians(180))
    if SCALE != 1:
        paw.scale = (SCALE, SCALE, SCALE)
    bpy.ops.object.transform_apply(location=False, rotation=FLIP, scale=(SCALE != 1))

if EXPORT:
    glb = r'C:\crypto\wicked whiskers\assets\paw_' + VARIANT + '.glb'
    bpy.ops.export_scene.gltf(filepath=glb, export_format='GLB')
    print("GLB:" + glb)

# ---- camera + lights + render (TOP-DOWN) ----
scene = bpy.context.scene
scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x = RES
scene.render.resolution_y = RES
scene.render.film_transparent = False
try:
    scene.eevee.samples = 64 if SHARP else 16
except Exception:
    pass
bpy.context.view_layer.update()
corners = [paw.matrix_world @ Vector(c) for c in paw.bound_box]
bb_max = Vector((max(c[i] for c in corners) for i in range(3)))
bb_min = Vector((min(c[i] for c in corners) for i in range(3)))
bb_center = (bb_max + bb_min) * 0.5
bb_size = bb_max - bb_min
paw_center = Vector((0.0, bb_center.y, bb_center.z))
fov = math.radians(48)
D = (bb_size.y * 1.15) / (2.0 * math.tan(fov / 2.0))
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
scene.collection.objects.link(cam)
scene.camera = cam
cam.data.angle = fov
cam.location = paw_center + Vector((0.0, 0.0, D))
tgt = bpy.data.objects.new("Target", None)
scene.collection.objects.link(tgt)
tgt.location = paw_center
con = cam.constraints.new('TRACK_TO')
con.target = tgt
con.track_axis = 'TRACK_NEGATIVE_Z'
con.up_axis = 'UP_Y'
cam.rotation_euler = (0.0, 0.0, 0.0)
bpy.context.view_layer.update()
key = bpy.data.objects.new("Key", bpy.data.lights.new("Key", 'AREA'))
scene.collection.objects.link(key)
key.location = paw_center + Vector((0.8, 0.8, 1.6))
key.data.energy = 900
fill = bpy.data.objects.new("Fill", bpy.data.lights.new("Fill", 'AREA'))
scene.collection.objects.link(fill)
fill.location = paw_center + Vector((-0.8, 0.9, 1.2))
fill.data.energy = 400
world = bpy.data.worlds.new("W")
scene.world = world
world.node_tree.nodes["Background"].inputs[0].default_value = (0.14, 0.14, 0.16, 1)
scene.render.filepath = OUT
bpy.ops.render.render(write_still=True)
print("RENDERED:" + OUT)
