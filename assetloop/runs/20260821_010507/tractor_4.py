import bpy
import bmesh
import mathutils
from math import radians

# Palette
RED = (0.82, 0.18, 0.13, 1.0)
WOOD = (0.55, 0.35, 0.17, 1.0)
DK_GREY = (0.20, 0.20, 0.22, 1.0)
NR_BLACK = (0.08, 0.08, 0.09, 1.0)
LT_GREY = (0.60, 0.60, 0.63, 1.0)
CREAM = (0.96, 0.95, 0.90, 1.0)
SKY = (0.66, 0.85, 0.91, 1.0)
WARM = (1.00, 0.95, 0.80, 1.0)

def create_mat(name, color, rough=0.5):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = rough
    return mat

mats = {
    "red": create_mat("Red", RED, 0.4),
    "dk": create_mat("DkGrey", DK_GREY, 0.7),
    "black": create_mat("Black", NR_BLACK, 0.8),
    "lt": create_mat("LtGrey", LT_GREY, 0.4),
    "cream": create_mat("Cream", CREAM, 0.6),
    "sky": create_mat("Sky", SKY, 0.2),
    "warm": create_mat("Warm", WARM, 0.3)
}

def build_part(name, shape_func, mat_key, loc=(0,0,0), scale=(1,1,1)):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    shape_func(bm)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    ob.location = loc
    ob.scale = scale
    ob.data.materials.append(mats[mat_key])
    return ob

# Wheel builder
def create_wheel(name, radius, width, loc):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    # Tyre
    bmesh.ops.create_cone(bm, cap_ends=True, radius1=radius, radius2=radius, depth=width, segments=24)
    # Hub
    bmesh.ops.create_cone(bm, cap_ends=True, radius1=radius*0.6, radius2=radius*0.6, depth=width*1.2, segments=16)
    # Rotate to X-axis
    rot = mathutils.Matrix.Rotation(radians(90), 4, 'Z')
    bmesh.ops.rotate(bm, cent=(0,0,0), matrix=rot, verts=bm.verts)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    ob.location = loc
    ob.data.materials.append(mats["black"])
    return ob

# Main Assembly
# Bonnet
build_part("Bonnet", lambda bm: bmesh.ops.create_cube(bm, size=1), "red", (0, 1.1, 0.8), (1.4, 0.8, 1.8))
# Cabin
build_part("Cabin", lambda bm: bmesh.ops.create_cube(bm, size=1), "red", (0, 1.2, -0.6), (1.6, 1.8, 1.2))
# Roof
build_part("Roof", lambda bm: bmesh.ops.create_cube(bm, size=1), "red", (0, 2.1, -0.6), (1.8, 0.2, 1.4))
# Grille
build_part("Grille", lambda bm: bmesh.ops.create_cube(bm, size=1), "dk", (0, 1.1, 1.7), (1.2, 0.6, 0.1))
# Plate
plate = build_part("Plate", lambda bm: bmesh.ops.create_cube(bm, size=1), "cream", (0, 1.1, -1.3), (0.5, 0.22, 0.05))

# Wheels
create_wheel("Wheel_FL", 0.32, 0.25, (1.1, 0.32, 0.8))
create_wheel("Wheel_FR", 0.32, 0.25, (-1.1, 0.32, 0.8))
create_wheel("Wheel_RL", 0.55, 0.4, (1.1, 0.55, -0.8))
create_wheel("Wheel_RR", 0.55, 0.4, (-1.1, 0.55, -0.8))

# Exhaust
build_part("Exhaust", lambda bm: bmesh.ops.create_cone(bm, cap_ends=True, radius1=0.1, radius2=0.1, depth=1.5, segments=8), "black", (0.7, 1.8, -0.2))

bpy.ops.export_scene.gltf(filepath="C:\\crypto\\wicked whiskers\\assetloop\\runs\\20260821_010507\\tractor_4.glb", export_format='GLB')
print("ASSET_BUILT")
print("DIMS Vector((2.2, 1.9, 2.6))")


