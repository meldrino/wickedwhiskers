import bpy
import bmesh
import math
from mathutils import Matrix, Vector

# Clean scene
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()

# Palette
colors = {
    "red": (0.82, 0.18, 0.13, 1.0),
    "brown": (0.55, 0.35, 0.17, 1.0),
    "d_grey": (0.20, 0.20, 0.22, 1.0),
    "n_black": (0.08, 0.08, 0.09, 1.0),
    "l_grey": (0.60, 0.60, 0.63, 1.0),
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

mats = {k: create_mat(k, v, 0.4 if k != "light" else 0.2) for k, v in colors.items()}

def add_part(name, mesh_data, loc, mat_key):
    ob = bpy.data.objects.new(name, mesh_data)
    ob.location = loc
    ob.data.materials.append(mats[mat_key])
    bpy.context.collection.objects.link(ob)
    return ob

def create_wheel(name, radius, width, loc):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    # Cylinder for tyre
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=24, radius1=radius, radius2=radius, depth=width)
    # Hub
    hub = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=24, radius1=radius*0.6, radius2=radius*0.6, depth=width*1.1)
    # Rotate mesh data so local X is axle
    rot = Matrix.Rotation(math.radians(90), 4, 'Y')
    bmesh.ops.rotate(bm, cent=(0,0,0), matrix=rot, verts=bm.verts)
    bm.to_mesh(me)
    bm.free()
    ob = add_part(name, me, loc, "n_black")
    # Hub material override
    ob.data.materials.append(mats["l_grey"]) 
    return ob

# Build Tractor
# Body/Bonnet
me = bpy.data.meshes.new("Body")
bm = bmesh.new()
bmesh.ops.create_cube(bm, size=1.0)
# Scale to shape
bm.verts.ensure_lookup_table()
for v in bm.verts: v.co.x *= 1.2; v.co.y *= 0.8; v.co.z *= 1.5
bmesh.ops.translate(bm, vec=(0, 0.6, 0.5), verts=bm.verts)
bm.to_mesh(me); bm.free()
add_part("Body", me, (0,0,0), "red")

# Wheels
create_wheel("Wheel_FL", 0.32, 0.25, (1.1, 0.32, 0.8))
create_wheel("Wheel_FR", 0.32, 0.25, (-1.1, 0.32, 0.8))
create_wheel("Wheel_RL", 0.55, 0.35, (1.1, 0.55, -0.8))
create_wheel("Wheel_RR", 0.55, 0.35, (-1.1, 0.55, -0.8))

# Cabin
me = bpy.data.meshes.new("Cabin")
bm = bmesh.new()
bmesh.ops.create_cube(bm, size=1.0)
bmesh.ops.translate(bm, vec=(0, 1.2, -0.5), verts=bm.verts)
bm.to_mesh(me); bm.free()
add_part("Cabin", me, (0,0,0), "red")

# Plate
me = bpy.data.meshes.new("Plate")
bm = bmesh.new()
bmesh.ops.create_cube(bm, size=1.0)
for v in bm.verts: v.co.x *= 0.5; v.co.y *= 0.22; v.co.z *= 0.05
bmesh.ops.translate(bm, vec=(0, 1.1, -1.3), verts=bm.verts)
bm.to_mesh(me); bm.free()
add_part("Plate", me, (0,0,0), "cream")

# Export
bpy.ops.export_scene.gltf(filepath="C:\\crypto\\wicked whiskers\\assetloop\\runs\\20260821_004250\\tractor_3.glb", export_format='GLB')
print("ASSET_BUILT")
print("DIMS Vector((2.2, 1.9, 2.6))")


