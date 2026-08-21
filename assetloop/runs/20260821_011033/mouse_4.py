import bpy
import bmesh
import mathutils
from math import radians

# Palette
GREY = (0.60, 0.60, 0.63, 1.0)
PINK = (0.85, 0.54, 0.54, 1.0)
BELLY = (0.79, 0.77, 0.74, 1.0)
BLACK = (0.08, 0.08, 0.09, 1.0)

def create_mat(name, color, roughness=0.7):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = roughness
    return mat

mats = {
    "grey": create_mat("MouseGrey", GREY),
    "pink": create_mat("MousePink", PINK),
    "belly": create_mat("MouseBelly", BELLY),
    "black": create_mat("MouseBlack", BLACK, 0.4)
}

def create_part(name, shape_type, size, loc, rot=(0,0,0), mat=None):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    if shape_type == "uvsphere":
        bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=12, radius=size)
    elif shape_type == "cone":
        bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=12, radius1=size, radius2=0, depth=size*2)
    elif shape_type == "cylinder":
        bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=12, radius1=size, radius2=size, depth=size*2)
    
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    ob.location = loc
    ob.rotation_euler = rot
    if mat: ob.data.materials.append(mat)
    bpy.context.collection.objects.link(ob)
    return ob

# Build Mouse
# Body: Pear shape (uvsphere scaled)
body = create_part("Body", "uvsphere", 0.035, (0, 0.04, 0), mat=mats["grey"])
body.scale = (1, 1, 1.4)

# Head
head = create_part("Head", "uvsphere", 0.025, (0, 0.07, 0.05), mat=mats["grey"])

# Ears
for x in [-0.025, 0.025]:
    ear = create_part("Ear", "uvsphere", 0.015, (x, 0.07, 0.07), mat=mats["grey"])
    ear.scale = (1, 0.2, 1)
    inner = create_part("InnerEar", "uvsphere", 0.01, (x, 0.065, 0.075), mat=mats["pink"])
    inner.scale = (1, 0.2, 1)

# Snout/Nose
snout = create_part("Snout", "cone", 0.01, (0, 0.09, 0.06), rot=(radians(90), 0, 0), mat=mats["grey"])
nose = create_part("Nose", "uvsphere", 0.005, (0, 0.1, 0.065), mat=mats["black"])

# Eyes
for x in [-0.012, 0.012]:
    eye = create_part("Eye", "uvsphere", 0.004, (x, 0.085, 0.06), mat=mats["black"])

# Legs
for x in [-0.02, 0.02]:
    for z in [-0.02, 0.03]:
        leg = create_part("Leg", "cylinder", 0.005, (x, z, 0.02), mat=mats["grey"])

# Tail
tail1 = create_part("Tail1", "cylinder", 0.003, (0, -0.02, 0.02), rot=(radians(45), 0, 0), mat=mats["grey"])
tail2 = create_part("Tail2", "cylinder", 0.002, (0, -0.05, -0.01), rot=(radians(60), 0, 0), mat=mats["grey"])

bpy.ops.export_scene.gltf(filepath="C:\\crypto\\wicked whiskers\\assetloop\\runs\\20260821_011033\\mouse_4.glb", export_format='GLB')
print("ASSET_BUILT")
print("DIMS Vector((0.08, 0.12, 0.15))")


