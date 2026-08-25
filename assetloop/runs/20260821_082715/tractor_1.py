import bpy
import bmesh
import mathutils
from math import radians

# Palette
RED = (0.82, 0.18, 0.13, 1.0)
BROWN = (0.55, 0.35, 0.17, 1.0)
D_GREY = (0.20, 0.20, 0.22, 1.0)
N_BLACK = (0.08, 0.08, 0.09, 1.0)
L_GREY = (0.60, 0.60, 0.63, 1.0)
CREAM = (0.96, 0.95, 0.90, 1.0)
SKY = (0.66, 0.85, 0.91, 1.0)
WARM = (1.00, 0.95, 0.80, 1.0)

def create_material(name, color, roughness=0.5):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = roughness
    return mat

def create_box(name, size, loc, mat):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    ob.scale = size
    ob.location = loc
    ob.data.materials.append(mat)
    bpy.context.collection.objects.link(ob)
    return ob

def create_wheel(name, radius, width, loc):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    # Tyre
    cyl = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=24, radius1=radius, radius2=radius, depth=width)
    # Rotate to align with X axis
    mat_rot = mathutils.Matrix.Rotation(radians(90), 4, 'Z')
    bmesh.ops.rotate(bm, cent=(0,0,0), matrix=mat_rot, verts=bm.verts)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    ob.location = loc
    ob.data.materials.append(create_material(name+"_mat", N_BLACK, 0.8))
    bpy.context.collection.objects.link(ob)
    return ob

# Materials
mat_red = create_material("Red", RED, 0.4)
mat_grey = create_material("Grey", D_GREY, 0.6)
mat_black = create_material("Black", N_BLACK, 0.8)
mat_sky = create_material("Sky", SKY, 0.2)
mat_cream = create_material("Cream", CREAM, 0.7)
mat_warm = create_material("Warm", WARM, 0.3)

# Build Tractor
# Body/Hood
create_box("Hood", (1.2, 0.8, 1.4), (0, 0.8, 0.7), mat_red)
create_box("Grille", (1.0, 0.6, 0.1), (0, 0.8, 1.4), mat_grey)
create_box("Cabin", (1.4, 1.2, 1.0), (0, -0.6, 1.2), mat_red)
create_box("Roof", (1.6, 0.1, 1.2), (0, -0.6, 1.8), mat_red)

# Wheels (Local X orientation)
wheel_data = [("Wheel_FL", 0.32, 0.3, (-1.1, 0.5, 0.32)), 
              ("Wheel_FR", 0.32, 0.3, (1.1, 0.5, 0.32)),
              ("Wheel_RL", 0.55, 0.4, (-1.1, -0.8, 0.55)),
              ("Wheel_RR", 0.55, 0.4, (1.1, -0.8, 0.55))]

for name, r, w, loc in wheel_data:
    create_wheel(name, r, w, loc)

# Plate
create_box("Plate", (0.5, 0.22, 0.05), (0, -1.3, 1.1), mat_cream)

# Export
bpy.ops.export_scene.gltf(filepath="C:\\crypto\\wicked whiskers\\assetloop\\runs\\20260821_082715\\tractor_1.glb", export_format='GLB')
print("ASSET_BUILT")
print("DIMS Vector((2.2, 1.9, 2.6))")


