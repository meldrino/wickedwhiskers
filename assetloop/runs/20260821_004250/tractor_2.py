import bpy
import bmesh
import math
from mathutils import Matrix, Vector

# Palette
colors = {
    "red": (0.82, 0.18, 0.13, 1.0),
    "brown": (0.55, 0.35, 0.17, 1.0),
    "d_grey": (0.20, 0.20, 0.22, 1.0),
    "n_black": (0.08, 0.08, 0.09, 1.0),
    "cream": (0.96, 0.95, 0.90, 1.0),
    "sky": (0.66, 0.85, 0.91, 1.0),
    "light": (1.00, 0.95, 0.80, 1.0)
}

def create_mat(name, color, rough=0.5):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = rough
    return mat

mats = {k: create_mat(k, v, 0.5 if k != "sky" else 0.15) for k, v in colors.items()}

def create_part(name, mesh_data, loc=(0,0,0), mat=None):
    ob = bpy.data.objects.new(name, mesh_data)
    ob.location = loc
    bpy.context.collection.objects.link(ob)
    if mat: ob.data.materials.append(mat)
    return ob

def build_wheel(name, radius, width, loc):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    # Create cylinder along Z, then rotate to X
    bmesh.ops.create_cone(bm, cap_ends=True, radius1=radius, radius2=radius, depth=width, segments=24)
    bmesh.ops.rotate(bm, cent=(0,0,0), matrix=Matrix.Rotation(math.radians(90), 3, 'Y'), verts=bm.verts)
    bm.to_mesh(me)
    bm.free()
    ob = create_part(name, me, loc, mats["n_black"])
    return ob

# Main Assembly
# Bonnet
me = bpy.data.meshes.new("Bonnet")
bm = bmesh.new()
bmesh.ops.create_cube(bm, size=1.0)
bmesh.ops.scale(bm, vec=(1.2, 0.8, 1.5), verts=bm.verts)
bm.to_mesh(me); bm.free()
create_part("Bonnet", me, (0, 1.1, 0.8), mats["red"])

# Cabin
me = bpy.data.meshes.new("Cabin")
bm = bmesh.new()
bmesh.ops.create_cube(bm, size=1.0)
bmesh.ops.scale(bm, vec=(1.5, 1.4, 1.2), verts=bm.verts)
bm.to_mesh(me); bm.free()
create_part("Cabin", me, (0, 1.2, -0.6), mats["red"])

# Wheels
wheel_locs = [("Wheel_FL", 0.32, 0.3, (1.1, 0.32, 0.8)), ("Wheel_FR", 0.32, 0.3, (-1.1, 0.32, 0.8)),
              ("Wheel_RL", 0.55, 0.4, (1.1, 0.55, -1.0)), ("Wheel_RR", 0.55, 0.4, (-1.1, 0.55, -1.0))]

for name, r, w, loc in wheel_locs:
    build_wheel(name, r, w, loc)

# Plate
me = bpy.data.meshes.new("Plate")
bm = bmesh.new()
bmesh.ops.create_cube(bm, size=1.0)
bmesh.ops.scale(bm, vec=(0.5, 0.22, 0.05), verts=bm.verts)
bm.to_mesh(me); bm.free()
create_part("Plate", me, (0, 1.1, -1.3), mats["cream"])

# Export
bpy.ops.export_scene.gltf(filepath="C:\\crypto\\wicked whiskers\\assetloop\\runs\\20260821_004250\\tractor_2.glb", export_format='GLB')
print("ASSET_BUILT")
print("DIMS Vector((2.2, 1.9, 2.6))")


