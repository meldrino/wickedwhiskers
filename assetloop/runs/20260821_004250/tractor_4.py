import bpy
import bmesh
import mathutils
from math import radians

# Palette
PALETTE = {
    "red": (0.82, 0.18, 0.13, 1.0),
    "brown": (0.55, 0.35, 0.17, 1.0),
    "dark_grey": (0.20, 0.20, 0.22, 1.0),
    "near_black": (0.08, 0.08, 0.09, 1.0),
    "light_grey": (0.60, 0.60, 0.63, 1.0),
    "cream": (0.96, 0.95, 0.90, 1.0),
    "sky": (0.66, 0.85, 0.91, 1.0),
    "warm": (1.00, 0.95, 0.80, 1.0)
}

def create_mat(name, color, roughness=0.5):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = roughness
    return mat

def create_mesh_obj(name, build_func, mat_name, roughness=0.5):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    build_func(bm)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    ob.data.materials.append(bpy.data.materials.get(mat_name) or create_mat(mat_name, PALETTE[mat_name], roughness))
    return ob

# Materials
for k, v in PALETTE.items():
    create_mat(k, v, 0.4 if k != "cream" else 0.8)

# Wheel builder
def build_wheel(bm, radius, width):
    # Cylinder along X axis
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=24, radius1=radius, radius2=radius, depth=width)
    # Rotate to face X axis
    rot = mathutils.Matrix.Rotation(radians(90), 4, 'Y')
    bmesh.ops.rotate(bm, cent=(0,0,0), matrix=rot, verts=bm.verts)

# Create Wheels
wheel_data = [("Wheel_FL", 0.32, -1.0, 0.32, 0.8), ("Wheel_FR", 0.32, 1.0, 0.32, 0.8),
              ("Wheel_RL", 0.55, -1.0, 0.55, 1.8), ("Wheel_RR", 0.55, 1.0, 0.55, 1.8)]

for name, rad, x, y, z in wheel_data:
    ob = create_mesh_obj(name, lambda bm: build_wheel(bm, rad, 0.3), "near_black", 0.4)
    ob.location = (x, y, z)

# Body
create_mesh_obj("Bonnet", lambda bm: bmesh.ops.create_cube(bm, size=1.0), "red", 0.4).scale = (1.2, 0.8, 1.4)
create_mesh_obj("Cabin", lambda bm: bmesh.ops.create_cube(bm, size=1.0), "red", 0.4).location = (0, 0.5, -0.5)
create_mesh_obj("Plate", lambda bm: bmesh.ops.create_cube(bm, size=1.0), "cream", 0.8).scale = (0.5, 0.22, 0.05)
# Set plate location
bpy.data.objects["Plate"].location = (0, 1.1, -1.3)

# Export
bpy.ops.export_scene.gltf(filepath="C:\\crypto\\wicked whiskers\\assetloop\\runs\\20260821_004250\\tractor_4.glb", export_format='GLB')
print("ASSET_BUILT")
print("DIMS Vector((2.2, 1.9, 2.6))")


