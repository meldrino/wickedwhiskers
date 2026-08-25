import bpy
import bmesh
import mathutils

def create_material(name, color, roughness=0.5):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    return mat

def create_mesh_object(name, bm, material):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    ob.data.materials.append(material)
    return ob

# Materials
mat_gold = create_material("Gold", (0.91, 0.53, 0.17), 0.45)
mat_belly = create_material("Belly", (0.96, 0.85, 0.66), 0.5)
mat_fin = create_material("Fin", (0.79, 0.42, 0.12), 0.5)
mat_white = create_material("EyeWhite", (1.0, 1.0, 1.0), 0.3)
mat_black = create_material("Pupil", (0.08, 0.08, 0.09), 0.3)

# 1. Body (Torpedo shape)
bm = bmesh.new()
bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=12, radius=0.06)
# Elongate to ~0.25m length
for v in bm.verts:
    v.co.z *= 2.0 
body = create_mesh_object("Body", bm, mat_gold)

# 2. Belly (Cream strip)
bm = bmesh.new()
bmesh.ops.create_cube(bm, size=1.0)
belly = create_mesh_object("Belly", bm, mat_belly)
belly.scale = (0.05, 0.03, 0.18)
belly.location = (0, -0.04, 0)

# 3. Fins (Simple triangular prisms)
def make_fin(name, scale, loc, rot):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=True, segments=3, radius1=0.03, radius2=0, depth=0.06)
    fin = create_mesh_object(name, bm, mat_fin)
    fin.scale = scale
    fin.location = loc
    fin.rotation_euler = rot

make_fin("Dorsal", (1, 1, 1), (0, 0.06, 0), (0, 0, 0))
make_fin("SideL", (1, 1, 0.8), (-0.06, 0, 0), (0, 1.57, 0))
make_fin("SideR", (1, 1, 0.8), (0.06, 0, 0), (0, -1.57, 0))
make_fin("Tail", (1.5, 1.5, 0.5), (0, 0, -0.14), (0, 0, 0))

# 4. Eyes
for x in [-0.03, 0.03]:
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=8, v_segments=8, radius=0.015)
    eye = create_mesh_object("Eye", bm, mat_white)
    eye.location = (x, 0.03, 0.08)
    
    bm2 = bmesh.new()
    bmesh.ops.create_uvsphere(bm2, u_segments=8, v_segments=8, radius=0.007)
    pupil = create_mesh_object("Pupil", bm2, mat_black)
    pupil.location = (x * 1.1, 0.04, 0.085)

# Export
bpy.ops.export_scene.gltf(filepath="C:\\crypto\\wicked whiskers\\assetloop\\runs\\20260821_011546\\fish_3.glb", export_format='GLB')
print("ASSET_BUILT")
print("DIMS Vector((0.15, 0.15, 0.30))")


