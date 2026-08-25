import bpy
import bmesh
import math
from mathutils import Matrix

# Clear scene
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()

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

def create_mat(name, color, rough=0.5):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = color
        bsdf.inputs["Roughness"].default_value = rough
    return mat

def create_part(name, mesh_func, mat_name, loc=(0,0,0)):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    mesh_func(bm)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    ob.location = loc
    bpy.context.collection.objects.link(ob)
    if mat_name in bpy.data.materials:
        ob.data.materials.append(bpy.data.materials[mat_name])
    return ob

# Materials
for n, c in PALETTE.items():
    create_mat(n, c, 0.6 if n != "sky" else 0.15)

# Build Tractor Parts
create_part("Bonnet", lambda bm: bmesh.ops.create_cube(bm, size=1.0), "red").scale = (1.2, 0.8, 1.5)
create_part("Grille", lambda bm: bmesh.ops.create_cube(bm, size=1.0), "dark_grey", (0, 0.5, 1.8)).scale = (1.0, 0.6, 0.1)
create_part("Cabin", lambda bm: bmesh.ops.create_cube(bm, size=1.0), "red", (0, 1.2, -0.5)).scale = (1.4, 1.6, 1.2)
create_part("Roof", lambda bm: bmesh.ops.create_cube(bm, size=1.0), "red", (0, 2.1, -0.5)).scale = (1.6, 0.2, 1.4)
create_part("Plate", lambda bm: bmesh.ops.create_cube(bm, size=1.0), "cream", (0, 1.1, -1.8)).scale = (0.5, 0.22, 0.05)

# Wheels
def build_wheel(bm, r, w):
    # Use create_cone; geometry is added directly to the bmesh instance
    ret = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, radius1=r, radius2=r, depth=w, segments=24)
    # Rotate all geometry currently in the bmesh
    bmesh.ops.rotate(bm, cent=(0,0,0), matrix=Matrix.Rotation(math.radians(90), 3, 'Y'), geom=bm.verts[:] + bm.edges[:] + bm.faces[:])

for name, loc in [("Wheel_FL", (1.1, 0.32, 0.8)), ("Wheel_FR", (-1.1, 0.32, 0.8)), 
                  ("Wheel_RL", (1.1, 0.55, -0.8)), ("Wheel_RR", (-1.1, 0.55, -0.8))]:
    r = 0.32 if "F" in name else 0.55
    create_part(name, lambda bm, r=r: build_wheel(bm, r, 0.3), "near_black", loc)

# Export
bpy.ops.wm.save_as_mainfile(filepath="tractor.blend")
bpy.ops.export_scene.gltf(filepath="tractor.glb", export_format='GLB')
print("ASSET_BUILT")


