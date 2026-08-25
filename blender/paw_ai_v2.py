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


def segment(a, b, r1, r2, mat, name="Segment"):
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

    mesh = bpy.data.meshes.new(name + "_Mesh")
    me.to_mesh(mesh)
    me.free()

    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)

    obj.location = (a + b) * 0.5

    if d.length > 0.0:
        q = Vector((0, 0, 1)).rotation_difference(d.normalized())
        obj.rotation_euler = q.to_euler()

    obj.data.materials.append(mat)
    return obj


def sphere(name, location, scale, mat, segments=24, rings=16):
    me = bmesh.new()

    bmesh.ops.create_uvsphere(
        me,
        u_segments=segments,
        v_segments=rings,
        radius=1.0
    )

    mesh = bpy.data.meshes.new(name + "_Mesh")
    me.to_mesh(mesh)
    me.free()

    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)

    obj.location = Vector(location)
    obj.scale = Vector(scale)
    obj.data.materials.append(mat)

    return obj


bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

bpy.context.scene.cursor.location = (0.0, 0.0, 0.0)

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
    (0.0, 0.031, 0.0),
    (0.0305, 0.035, 0.0215),
    fur,
    28,
    18
)

arm = segment(
    (0.0, 0.010, 0.0),
    (0.0, -0.150, 0.0),
    0.016,
    0.010,
    fur,
    "Arm"
)

# LEFT FINGER
left_base = (-0.016, 0.046, 0.000)
left_knuckle = (-0.018, 0.065, 0.000)
left_tip = (-0.014, 0.081, 0.003)

segment(
    left_base,
    left_knuckle,
    0.0090,
    0.0062,
    fur,
    "LeftFinger_Base"
)

segment(
    left_knuckle,
    left_tip,
    0.0062,
    0.0045,
    fur,
    "LeftFinger_Tip"
)

# LEFT CLAW
left_claw_end = (-0.010, 0.073, 0.011)

segment(
    left_tip,
    left_claw_end,
    0.0038,
    0.00035,
    claw,
    "LeftClaw"
)

# CENTRE FINGER
centre_base = (0.000, 0.048, 0.000)
centre_knuckle = (0.000, 0.068, 0.000)
centre_tip = (0.000, 0.084, 0.0035)

segment(
    centre_base,
    centre_knuckle,
    0.0092,
    0.0064,
    fur,
    "CentreFinger_Base"
)

segment(
    centre_knuckle,
    centre_tip,
    0.0064,
    0.0045,
    fur,
    "CentreFinger_Tip"
)

# CENTRE CLAW
centre_claw_end = (0.000, 0.076, 0.012)

segment(
    centre_tip,
    centre_claw_end,
    0.0038,
    0.00035,
    claw,
    "CentreClaw"
)

# RIGHT FINGER
right_base = (0.016, 0.046, 0.000)
right_knuckle = (0.018, 0.065, 0.000)
right_tip = (0.014, 0.081, 0.003)

segment(
    right_base,
    right_knuckle,
    0.0090,
    0.0062,
    fur,
    "RightFinger_Base"
)

segment(
    right_knuckle,
    right_tip,
    0.0062,
    0.0045,
    fur,
    "RightFinger_Tip"
)

# RIGHT CLAW
right_claw_end = (0.010, 0.073, 0.011)

segment(
    right_tip,
    right_claw_end,
    0.0038,
    0.00035,
    claw,
    "RightClaw"
)

thumb_base = (-0.023, 0.031, 0.000)
thumb_joint = (-0.035, 0.040, 0.002)
thumb_tip = (-0.039, 0.052, 0.006)

segment(
    thumb_base,
    thumb_joint,
    0.0110,
    0.0080,
    fur,
    "Thumb_Base"
)

segment(
    thumb_joint,
    thumb_tip,
    0.0080,
    0.0050,
    fur,
    "Thumb_Tip"
)

thumb_claw_end = (-0.036, 0.044, 0.014)

segment(
    thumb_tip,
    thumb_claw_end,
    0.0040,
    0.00035,
    claw,
    "ThumbClaw"
)

sphere(
    "LeftFingerRoot",
    (-0.014, 0.049, 0.000),
    (0.011, 0.012, 0.010),
    fur,
    24,
    16
)

sphere(
    "CentreFingerRoot",
    (0.000, 0.050, 0.000),
    (0.011, 0.013, 0.010),
    fur,
    24,
    16
)

sphere(
    "RightFingerRoot",
    (0.014, 0.049, 0.000),
    (0.011, 0.012, 0.010),
    fur,
    24,
    16
)

sphere(
    "ThumbShoulder",
    (-0.024, 0.035, 0.000),
    (0.014, 0.014, 0.011),
    fur,
    24,
    16
)

sphere(
    "LeftToePad",
    (-0.014, 0.052, 0.0205),
    (0.0070, 0.0065, 0.0025),
    pad,
    24,
    16
)

sphere(
    "CentreToePad",
    (0.000, 0.055, 0.0210),
    (0.0070, 0.0065, 0.0025),
    pad,
    24,
    16
)

sphere(
    "RightToePad",
    (0.014, 0.052, 0.0205),
    (0.0070, 0.0065, 0.0025),
    pad,
    24,
    16
)

sphere(
    "ThumbPad",
    (-0.024, 0.041, 0.0195),
    (0.0065, 0.0070, 0.0024),
    pad,
    24,
    16
)

sphere(
    "PalmPad",
    (0.0, 0.031, 0.0215),
    (0.012, 0.0105, 0.0028),
    pad,
    28,
    18
)

bpy.ops.object.select_all(action='DESELECT')

mesh_objects = [
    obj for obj in bpy.context.scene.objects
    if obj.type == 'MESH'
]

for obj in mesh_objects:
    obj.select_set(True)

bpy.context.view_layer.objects.active = mesh_objects[0]

bpy.ops.object.join()

paw = bpy.context.active_object
paw.name = "Paw"

bpy.context.scene.cursor.location = (0.0, 0.0, 0.0)

bpy.ops.object.origin_set(type='ORIGIN_CURSOR')

bpy.ops.export_scene.gltf(
    filepath=r"C:\crypto\wicked whiskers\assets\paw_ai_v1.glb",
    export_format='GLB'
)

print("PAW_BUILT")
print("DIMS", bpy.context.active_object.dimensions)
