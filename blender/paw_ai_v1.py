import bpy
import bmesh
from mathutils import Vector

def new_mat(name, color, rough):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    return m


def segment(a, b, r1, r2, mat):
    a = Vector(a)
    b = Vector(b)
    d = b - a

    me = bmesh.new()
    bmesh.ops.create_cone(
        me,
        segments=24,
        radius1=r1,
        radius2=r2,
        depth=d.length,
        cap_ends=True
    )

    mesh = bpy.data.meshes.new("m")
    me.to_mesh(mesh)
    me.free()

    o = bpy.data.objects.new("s", mesh)
    bpy.context.collection.objects.link(o)

    o.location = (a + b) * 0.5
    o.rotation_euler = Vector((0, 0, 1)).rotation_difference(
        d.normalized()
    ).to_euler()

    o.data.materials.append(mat)
    return o


def sphere(name, location, scale, mat, segments=24, rings=16):
    me = bmesh.new()

    bmesh.ops.create_uvsphere(
        me,
        u_segments=segments,
        v_segments=rings,
        radius=1.0
    )

    mesh = bpy.data.meshes.new(name)
    me.to_mesh(mesh)
    me.free()

    o = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(o)

    o.location = Vector(location)
    o.scale = Vector(scale)
    o.data.materials.append(mat)

    return o


bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

bpy.context.scene.cursor.location = (0, 0, 0)

fur = new_mat(
    "Fur",
    (0.976, 0.678, 0.349),
    0.9
)

claw = new_mat(
    "Claw",
    (0.961, 0.902, 0.816),
    0.6
)

pad = new_mat(
    "Pad",
    (0.788, 0.553, 0.490),
    0.7
)

palm = sphere(
    "Palm",
    (0.0, 0.025, 0.0),
    (0.031, 0.030, 0.022),
    fur,
    segments=24,
    rings=16
)

arm = segment(
    (0.0, 0.0, 0.0),
    (0.0, -0.15, 0.0),
    0.016,
    0.010,
    fur
)

finger_data = [
    (-0.024, 0.045, -0.023, 0.061, -0.019, 0.073),
    (-0.008, 0.047, -0.007, 0.064, -0.005, 0.078),
    ( 0.008, 0.047,  0.007, 0.064,  0.005, 0.078),
    ( 0.024, 0.045,  0.023, 0.061,  0.019, 0.073),
]

for i, (bx, by, kx, ky, tx, ty) in enumerate(finger_data):
    segment(
        (bx, by, 0.0),
        (kx, ky, 0.0),
        0.008,
        0.006,
        fur
    )

    segment(
        (kx, ky, 0.0),
        (tx, ty, 0.0035),
        0.006,
        0.0045,
        fur
    )

    claw_start = Vector((tx, ty, 0.0035))
    claw_end = Vector((tx * 0.92, ty - 0.007, 0.0095))

    segment(
        claw_start,
        claw_end,
        0.0038,
        0.0004,
        claw
    )

thumb_base = (-0.030, 0.031, 0.003)
thumb_knuckle = (-0.038, 0.043, 0.005)
thumb_tip = (-0.034, 0.054, 0.008)

segment(
    thumb_base,
    thumb_knuckle,
    0.009,
    0.0065,
    fur
)

segment(
    thumb_knuckle,
    thumb_tip,
    0.0065,
    0.0048,
    fur
)

segment(
    thumb_tip,
    (-0.0305, 0.047, 0.014),
    0.0040,
    0.0004,
    claw
)

toe_pad_positions = [
    (-0.022, 0.047, 0.0195),
    (-0.0075, 0.050, 0.0210),
    ( 0.0075, 0.050, 0.0210),
    ( 0.022, 0.047, 0.0195),
]

for i, position in enumerate(toe_pad_positions):
    sphere(
        "ToePad_%d" % (i + 1),
        position,
        (0.007, 0.006, 0.0022),
        pad,
        segments=24,
        rings=16
    )

sphere(
    "PalmPad",
    (0.0, 0.027, 0.0220),
    (0.012, 0.010, 0.0028),
    pad,
    segments=24,
    rings=16
)

bpy.ops.object.select_all(action='DESELECT')

mesh_objects = [
    o for o in bpy.context.scene.objects
    if o.type == 'MESH'
]

for o in mesh_objects:
    o.select_set(True)

bpy.context.view_layer.objects.active = mesh_objects[0]

bpy.ops.object.join()

paw = bpy.context.active_object
paw.name = "Paw"

bpy.context.scene.cursor.location = (0, 0, 0)

bpy.ops.object.origin_set(type='ORIGIN_CURSOR')

bpy.ops.export_scene.gltf(
    filepath=r"C:\crypto\wicked whiskers\assets\paw_ai_v1.glb",
    export_format='GLB'
)

print("PAW_BUILT")
print("DIMS", bpy.context.active_object.dimensions)
