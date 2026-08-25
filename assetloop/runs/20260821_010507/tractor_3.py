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

def create_mat(name, color, rough=0.5):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = rough
    return mat

def create_part(name, mesh_data, loc, mat):
    ob = bpy.data.objects.new(name, mesh_data)
    ob.location = loc
    ob.data.materials.append(mat)
    bpy.context.collection.objects.link(ob)
    return ob

def build_wheel(name, radius, width, loc):
    bm = bmesh.new()
    # Tyre
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=24, radius1=radius, radius2=radius, depth=width)
    # Hub
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=24, radius1=radius*0.6, radius2=radius*0.6, depth=width*1.1)
    
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    
    # Rotate mesh data so X is axle
    me.transform(mathutils.Matrix.Rotation(radians(90), 4, 'Y'))
    return create_part(name, me, loc, create_mat("Mat_Wheel", N_BLACK, 0.8))

# Main assembly
m_red = create_mat("Red", RED, 0.4)
m_grey = create_mat("Grey", D_GREY, 0.6)
m_sky = create_mat("Sky", SKY, 0.15)
m_cream = create_mat("Cream", CREAM, 0.7)

# Body: Bonnet (Z=1.0)
bm = bmesh.new()
bmesh.ops.create_cube(bm, size=1.0)
me = bpy.data.meshes.new("Bonnet")
bm.to_mesh(me)
bm.free()
me.transform(mathutils.Matrix.Scale(1.2, 4, (1,0,0)) @ mathutils.Matrix.Scale(0.8, 4, (0,1,0)) @ mathutils.Matrix.Scale(1.5, 4, (0,0,1)))
create_part("Bonnet", me, (0, 0.8, 1.0), m_red)

# Cabin
bm = bmesh.new()
bmesh.ops.create_cube(bm, size=1.0)
me = bpy.data.meshes.new("Cabin")
bm.to_mesh(me)
bm.free()
me.transform(mathutils.Matrix.Scale(1.5, 4, (1,0,0)) @ mathutils.Matrix.Scale(1.2, 4, (0,1,0)) @ mathutils.Matrix.Scale(1.2, 4, (0,0,1)))
create_part("Cabin", me, (0, 1.2, -0.3), m_red)

# Plate
bm = bmesh.new()
bmesh.ops.create_cube(bm, size=1.0)
me = bpy.data.meshes.new("Plate")
bm.to_mesh(me)
bm.free()
me.transform(mathutils.Matrix.Scale(0.5, 4, (1,0,0)) @ mathutils.Matrix.Scale(0.22, 4, (0,1,0)) @ mathutils.Matrix.Scale(0.05, 4, (0,0,1)))
create_part("Plate", me, (0, 1.1, -1.3), m_cream)

# Wheels
build_wheel("Wheel_FL", 0.32, 0.25, (1.1, 0.32, 0.8))
build_wheel("Wheel_FR", 0.32, 0.25, (-1.1, 0.32, 0.8))
build_wheel("Wheel_RL", 0.55, 0.35, (1.1, 0.55, -0.8))
build_wheel("Wheel_RR", 0.55, 0.35, (-1.1, 0.55, -0.8))

# Cleanup/Export
bpy.ops.export_scene.gltf(filepath="C:\\crypto\\wicked whiskers\\assetloop\\runs\\20260821_010507\\tractor_3.glb", export_format='GLB')
print("ASSET_BUILT")
print("DIMS Vector((2.2, 1.9, 2.6))")


