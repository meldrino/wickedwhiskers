import bpy
import bmesh
from mathutils import Vector

S = 2.6

def new_mat(name, color, rough):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    return m

def segment(a, b, r1, r2, mat, name="Segment"):
    a = Vector(a); b = Vector(b)
    d = b - a
    if d.length == 0:
        raise ValueError("Segment endpoints must not be identical")
    me = bmesh.new()
    bmesh.ops.create_cone(me, segments=32, radius1=r1, radius2=r2,
                          depth=d.length, cap_ends=True)
    mesh = bpy.data.meshes.new(name + "_Mesh")
    me.to_mesh(mesh); me.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.location = (a + b) * 0.5
    q = Vector((0, 0, 1)).rotation_difference(d.normalized())
    obj.rotation_euler = q.to_euler()
    obj.data.materials.append(mat)
    return obj

def sphere(name, location, scale, mat, segments=32, rings=20):
    me = bmesh.new()
    bmesh.ops.create_uvsphere(me, u_segments=segments, v_segments=rings, radius=1.0)
    mesh = bpy.data.meshes.new(name + "_Mesh")
    me.to_mesh(mesh); me.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.location = Vector(location)
    obj.scale = Vector(scale)
    obj.data.materials.append(mat)
    return obj

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.context.scene.cursor.location = (0.0, 0.0, 0.0)

fur = new_mat("Fur", (0.976, 0.678, 0.349), 0.95)
claw = new_mat("Claw", (0.961, 0.902, 0.816), 0.6)

BODY = []
def s(name, loc, scale, mat=fur):
    BODY.append(sphere(name, tuple(v * S for v in loc), tuple(v * S for v in scale), mat))

def seg(name, a, b, r1, r2, mat=fur):
    BODY.append(segment(tuple(v * S for v in a), tuple(v * S for v in b), r1 * S, r2 * S, mat, name))

# PALM (rounded back-of-hand blob)
s("Palm", (0.0, 0.031, 0.0), (0.030, 0.038, 0.024))
s("PalmBack", (0.0, 0.040, -0.018), (0.028, 0.030, 0.012))

# ARM: wrist -> forearm -> elbow (hangs -Y), chunky cartoon forearm
seg("Arm_Upper", (0.0, 0.012, 0.0), (0.0, -0.160, 0.0), 0.017, 0.030, fur)
seg("Arm_Lower", (0.0, -0.160, 0.0), (0.0, -0.300, 0.0), 0.030, 0.034, fur)
s("Wrist", (0.0, 0.012, 0.0), (0.019, 0.016, 0.019))
s("Elbow", (0.0, -0.310, 0.0), (0.034, 0.030, 0.034))

# LEFT FINGER
left_root = (-0.022, 0.044, 0.000)
left_knuckle = (-0.026, 0.066, 0.001)
left_tip = (-0.024, 0.082, 0.004)
seg("LeftFinger_Base", left_root, left_knuckle, 0.0110, 0.0088)
seg("LeftFinger_Tip", left_knuckle, left_tip, 0.0088, 0.0058)
s("LeftKnuckle", (-0.023, 0.065, -0.024), (0.0130, 0.0130, 0.0120))
s("LeftTip", (-0.024, 0.081, 0.004), (0.0065, 0.0065, 0.0060))

# CENTRE FINGER
centre_root = (0.000, 0.045, 0.000)
centre_knuckle = (0.000, 0.067, 0.001)
centre_tip = (0.000, 0.084, 0.0045)
seg("CentreFinger_Base", centre_root, centre_knuckle, 0.0115, 0.0090)
seg("CentreFinger_Tip", centre_knuckle, centre_tip, 0.0090, 0.0059)
s("CentreKnuckle", (0.000, 0.066, -0.024), (0.0135, 0.0130, 0.0122))
s("CentreTip", (0.000, 0.083, 0.0045), (0.0066, 0.0067, 0.0061))

# RIGHT FINGER
right_root = (0.022, 0.044, 0.000)
right_knuckle = (0.026, 0.066, 0.001)
right_tip = (0.024, 0.082, 0.004)
seg("RightFinger_Base", right_root, right_knuckle, 0.0110, 0.0088)
seg("RightFinger_Tip", right_knuckle, right_tip, 0.0088, 0.0058)
s("RightKnuckle", (0.023, 0.065, -0.024), (0.0130, 0.0130, 0.0120))
s("RightTip", (0.024, 0.081, 0.004), (0.0065, 0.0065, 0.0060))

# WEBBING (fill gaps between finger roots, pulled into palm)
s("LeftWeb", (-0.012, 0.050, 0.000), (0.0125, 0.0140, 0.0110))
s("CentreWeb", (0.000, 0.051, 0.000), (0.0130, 0.0145, 0.0110))
s("RightWeb", (0.012, 0.050, 0.000), (0.0125, 0.0140, 0.0110))
s("WebBack", (0.000, 0.056, -0.006), (0.0190, 0.0120, 0.0080))

# THUMB (left side, chunky)
thumb_root = (-0.028, 0.030, 0.000)
thumb_joint = (-0.040, 0.040, 0.003)
thumb_tip = (-0.043, 0.052, 0.006)
seg("Thumb_Base", thumb_root, thumb_joint, 0.0130, 0.0100)
seg("Thumb_Tip", thumb_joint, thumb_tip, 0.0100, 0.0060)
s("ThumbShoulder", (-0.028, 0.032, 0.000), (0.0160, 0.0170, 0.0130))
s("ThumbJoint", (-0.039, 0.041, -0.024), (0.0115, 0.0120, 0.0110))
s("ThumbTip", (-0.043, 0.052, 0.006), (0.0065, 0.0070, 0.0065))

# CLAWS (sharp, longer, on +Z so they rise off the finger tops toward the dial)
seg("LeftClaw", (-0.024, 0.080, 0.006), (-0.022, 0.076, 0.022), 0.0040, 0.0005, claw)
seg("CentreClaw", (0.000, 0.082, 0.0065), (0.000, 0.078, 0.024), 0.0041, 0.0005, claw)
seg("RightClaw", (0.024, 0.080, 0.006), (0.022, 0.076, 0.022), 0.0040, 0.0005, claw)
seg("ThumbClaw", (-0.043, 0.051, 0.008), (-0.040, 0.047, 0.024), 0.0042, 0.0005, claw)

# ---- REMESH BODY (merge everything except claws into one smooth volume) ----
claw_objs = [o for o in BODY if o.data.materials[0].name == "Claw"]
fur_objs = [o for o in BODY if o.data.materials[0].name == "Fur"]
for o in fur_objs:
    o.select_set(True)
bpy.context.view_layer.objects.active = fur_objs[0]
bpy.ops.object.join()
body = bpy.context.active_object
body.name = "PawBody"
mod = body.modifiers.new("rem", "REMESH")
mod.mode = 'VOXEL'
mod.voxel_size = 0.006 * S
bpy.ops.object.modifier_apply(modifier=mod.name)
bpy.ops.object.shade_smooth()

# ---- RE-ADD CLAWS (sharp detail must survive) ----
for o in claw_objs:
    o.select_set(True)
body.select_set(True)
bpy.context.view_layer.objects.active = body
bpy.ops.object.join()
paw = bpy.context.active_object
paw.name = "Paw"

# ---- ROTATE into paw_hv convention: back(-Z)->+Y, arm(-Y)->-Z, fingers(+Y)->+Z ----
bpy.context.scene.cursor.location = (0.0, 0.0, 0.0)
bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
paw.rotation_euler = (1.5707963, 0.0, 0.0)
bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
bpy.ops.object.origin_set(type="ORIGIN_CURSOR")

bpy.ops.export_scene.gltf(
    filepath=r"C:\crypto\wicked whiskers\assets\paw_ai_v4.glb",
    export_format="GLB",
    export_texcoords=False,
    export_materials="EXPORT",
)
print("PAW_V4_BUILT")
print("DIMS", paw.dimensions)
