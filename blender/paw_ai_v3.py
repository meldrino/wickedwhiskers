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

    if d.length == 0:
        raise ValueError("Segment endpoints must not be identical")

    me = bmesh.new()
    bmesh.ops.create_cone(
        me,
        segments=32,
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
    q = Vector((0, 0, 1)).rotation_difference(d.normalized())
    obj.rotation_euler = q.to_euler()
    obj.data.materials.append(mat)

    return obj


def sphere(name, location, scale, mat, segments=32, rings=20):
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


bpy.ops.object.select_all(action="SELECT")
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

sphere(
    "Palm",
    (0.0, 0.031, 0.0),
    (0.033, 0.037, 0.023),
    fur,
    32,
    20
)

segment(
    (0.0, 0.010, 0.0),
    (0.0, -0.150, 0.0),
    0.016,
    0.010,
    fur,
    "Arm"
)

# LEFT FINGER
left_root = (-0.014, 0.044, 0.000)
left_knuckle = (-0.016, 0.058, 0.001)
left_tip = (-0.012, 0.074, 0.004)

segment(
    left_root,
    left_knuckle,
    0.0100,
    0.0080,
    fur,
    "LeftFinger_Base"
)

segment(
    left_knuckle,
    left_tip,
    0.0080,
    0.0052,
    fur,
    "LeftFinger_Tip"
)

sphere(
    "LeftKnuckle",
    (-0.0145, 0.057, 0.000),
    (0.0100, 0.0100, 0.0090),
    fur,
    28,
    18
)

sphere(
    "LeftTip",
    (-0.012, 0.0735, 0.004),
    (0.0060, 0.0060, 0.0055),
    fur,
    28,
    18
)

# CENTRE FINGER
centre_root = (0.000, 0.045, 0.000)
centre_knuckle = (0.000, 0.059, 0.001)
centre_tip = (0.000, 0.076, 0.0045)

segment(
    centre_root,
    centre_knuckle,
    0.0105,
    0.0082,
    fur,
    "CentreFinger_Base"
)

segment(
    centre_knuckle,
    centre_tip,
    0.0082,
    0.0053,
    fur,
    "CentreFinger_Tip"
)

sphere(
    "CentreKnuckle",
    (0.000, 0.058, 0.000),
    (0.0105, 0.0100, 0.0092),
    fur,
    28,
    18
)

sphere(
    "CentreTip",
    (0.000, 0.0755, 0.0045),
    (0.0061, 0.0062, 0.0056),
    fur,
    28,
    18
)

# RIGHT FINGER
right_root = (0.014, 0.044, 0.000)
right_knuckle = (0.016, 0.058, 0.001)
right_tip = (0.012, 0.074, 0.004)

segment(
    right_root,
    right_knuckle,
    0.0100,
    0.0080,
    fur,
    "RightFinger_Base"
)

segment(
    right_knuckle,
    right_tip,
    0.0080,
    0.0052,
    fur,
    "RightFinger_Tip"
)

sphere(
    "RightKnuckle",
    (0.0145, 0.057, 0.000),
    (0.0100, 0.0100, 0.0090),
    fur,
    28,
    18
)

sphere(
    "RightTip",
    (0.012, 0.0735, 0.004),
    (0.0060, 0.0060, 0.0055),
    fur,
    28,
    18
)

# WEBBING
sphere(
    "LeftWeb",
    (-0.009, 0.050, 0.000),
    (0.0115, 0.0130, 0.0105),
    fur,
    28,
    18
)

sphere(
    "CentreWeb",
    (0.000, 0.051, 0.000),
    (0.0120, 0.0135, 0.0105),
    fur,
    28,
    18
)

sphere(
    "RightWeb",
    (0.009, 0.050, 0.000),
    (0.0115, 0.0130, 0.0105),
    fur,
    28,
    18
)

# CLAWS
segment(
    (-0.012, 0.073, 0.006),
    (-0.010, 0.069, 0.017),
    0.0040,
    0.00012,
    claw,
    "LeftClaw"
)

segment(
    (0.000, 0.075, 0.0065),
    (0.000, 0.071, 0.019),
    0.0041,
    0.00012,
    claw,
    "CentreClaw"
)

segment(
    (0.012, 0.073, 0.006),
    (0.010, 0.069, 0.017),
    0.0040,
    0.00012,
    claw,
    "RightClaw"
)

# THUMB
thumb_root = (-0.025, 0.030, 0.000)
thumb_joint = (-0.035, 0.037, 0.002)
thumb_tip = (-0.038, 0.049, 0.006)

segment(
    thumb_root,
    thumb_joint,
    0.0120,
    0.0090,
    fur,
    "Thumb_Base"
)

segment(
    thumb_joint,
    thumb_tip,
    0.0090,
    0.0055,
    fur,
    "Thumb_Tip"
)

sphere(
    "ThumbShoulder",
    (-0.025, 0.032, 0.000),
    (0.0150, 0.0160, 0.0120),
    fur,
    32,
    20
)

sphere(
    "ThumbJoint",
    (-0.034, 0.039, 0.002),
    (0.0095, 0.0100, 0.0090),
    fur,
    28,
    18
)

sphere(
    "ThumbTip",
    (-0.038, 0.049, 0.006),
    (0.0060, 0.0065, 0.0060),
    fur,
    28,
    18
)

segment(
    (-0.038, 0.048, 0.008),
    (-0.035, 0.044, 0.020),
    0.0042,
    0.00012,
    claw,
    "ThumbClaw"
)

# TOE PADS
sphere(
    "LeftToePad",
    (-0.014, 0.052, 0.0215),
    (0.0075, 0.0068, 0.0027),
    pad,
    28,
    18
)

sphere(
    "CentreToePad",
    (0.000, 0.054, 0.0220),
    (0.0075, 0.0068, 0.0027),
    pad,
    28,
    18
)

sphere(
    "RightToePad",
    (0.014, 0.052, 0.0215),
    (0.0075, 0.0068, 0.0027),
    pad,
    28,
    18
)

sphere(
    "ThumbPad",
    (-0.027, 0.039, 0.0200),
    (0.0068, 0.0075, 0.0027),
    pad,
    28,
    18
)

sphere(
    "PalmPad",
    (0.0, 0.030, 0.0220),
    (0.0125, 0.0110, 0.0030),
    pad,
    32,
    20
)

bpy.ops.object.select_all(action="DESELECT")

mesh_objects = [
    obj for obj in bpy.context.scene.objects
    if obj.type == "MESH"
]

for obj in mesh_objects:
    obj.select_set(True)

bpy.context.view_layer.objects.active = mesh_objects[0]

bpy.ops.object.join()

paw = bpy.context.active_object
paw.name = "Paw"

bpy.context.scene.cursor.location = (0.0, 0.0, 0.0)

bpy.ops.object.origin_set(type="ORIGIN_CURSOR")

bpy.ops.export_scene.gltf(
    filepath=r"C:\crypto\wicked whiskers\assets\paw_ai_v1.glb",
    export_format="GLB"
)

print("PAW_BUILT")
print("DIMS", bpy.context.active_object.dimensions)
