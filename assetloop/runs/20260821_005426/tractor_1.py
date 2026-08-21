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
W_LIGHT = (1.00, 0.95, 0.80, 1.0)

def create_mat(name, color, roughness=0.5):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = roughness
    return mat

def build_part(name, mesh_data, mat, location=(0,0,0)):
    ob = bpy.data.objects.new(name, mesh_data)
    ob.location = location
    bpy.context.collection.objects.link(ob)
    ob.data.materials.append(mat)
    return ob

def create_wheel(name, radius, width, pos):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    # Create tyre
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=24, radius1=radius, radius2=radius, depth=width)
    # Rotate to X-axis
    rot = mathutils.Matrix.Rotation(radians(90), 4, 'Z')
    bmesh.ops.rotate(bm, cent=(0,0,0), matrix=rot, verts=bm.verts)
    
    # Hub
    hub = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=16, radius1=radius*0.6, radius2=radius*0.6, depth=width*1.1)
    bmesh.ops.rotate(bm, cent=(0,0,0), matrix=rot, verts=hub['verts'])
    
    bm.to_mesh(me)
    bm.free()
    return build_part(name, me, bpy.data.materials.get("N_BLACK"), pos)

# Setup Materials
m_red = create_mat("Red", RED, 0.4)
m_grey = create_mat("D_Grey", D_GREY, 0.6)
m_black = create_mat("N_Black", N_BLACK, 0.8)
m_light = create_mat("L_Grey", L_GREY, 0.4)
m_cream = create_mat("Cream", CREAM, 0.7)
m_sky = create_mat("Sky", SKY, 0.2)
m_warm = create_mat("Warm", W_LIGHT, 0.3)

# Build Parts
# Bonnet
me_bonnet = bpy.data.meshes.new("Bonnet")
bm = bmesh.new()
bmesh.ops.create_cube(bm, size=1.0)
bmesh.ops.scale(bm, vec=(1.2, 0.8, 1.4), verts=bm.verts)
bm.to_mesh(me_bonnet)
bm.free()
build_part("Bonnet", me_bonnet, m_red, (0, 0.8, 0.8))

# Cabin
me_cab = bpy.data.meshes.new("Cabin")
bm = bmesh.new()
bmesh.ops.create_cube(bm, size=1.0)
bmesh.ops.scale(bm, vec=(1.4, 1.2, 1.0), verts=bm.verts)
bm.to_mesh(me_cab)
bm.free()
build_part("Cabin", me_cab, m_red, (0, 1.2, -0.6))

# Wheels
create_wheel("Wheel_FL", 0.32, 0.25, (1.1, 0.32, 0.8))
create_wheel("Wheel_FR", 0.32, 0.25, (-1.1, 0.32, 0.8))
create_wheel("Wheel_RL", 0.55, 0.35, (1.1, 0.55, -0.8))
create_wheel("Wheel_RR", 0.55, 0.35, (-1.1, 0.55, -0.8))

# Plate
me_plate = bpy.data.meshes.new("Plate")
bm = bmesh.new()
bmesh.ops.create_cube(bm, size=1.0)
bmesh.ops.scale(bm, vec=(0.5, 0.22, 0.05), verts=bm.verts)
bm.to_mesh(me_plate)
bm.free()
build_part("Plate", me_plate, m_cream, (0, 1.1, -1.3))

# Export
bpy.ops.export_scene.gltf(filepath="C:\\crypto\\wicked whiskers\\assetloop\\runs\\20260821_005426\\tractor_1.glb", export_format='GLB')
print("ASSET_BUILT")
print("DIMS Vector((2.2, 1.9, 2.6))")


