import bpy
import bmesh
import math
from mathutils import Matrix, Vector

def create_material(name, color, roughness):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    return mat

# Materials
mat_bark = create_material("Bark", (0.42, 0.29, 0.17), 0.85)
mat_inner = create_material("InnerWood", (0.79, 0.66, 0.44), 0.85)

def create_part(name, mesh_data, mat):
    ob = bpy.data.objects.new(name, mesh_data)
    bpy.context.collection.objects.link(ob)
    ob.data.materials.append(mat)
    return ob

# Create main shaft segments (5 segments for a gentle bend)
shaft_objs = []
for i in range(5):
    me = bpy.data.meshes.new(f"Shaft_{i}")
    bm = bmesh.new()
    # Create cylinder segment
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=8, radius1=0.02, radius2=0.02, depth=0.11)
    
    # Transform to position along Z
    z_pos = -0.22 + (i * 0.11)
    angle = math.radians(i * 3) # Gentle curve
    mat_trans = Matrix.Translation((0, 0, z_pos))
    mat_rot = Matrix.Rotation(angle, 4, 'X')
    bmesh.ops.transform(bm, matrix=mat_trans @ mat_rot, verts=bm.verts)
    
    bm.to_mesh(me)
    bm.free()
    shaft_objs.append(create_part(f"Shaft_{i}", me, mat_bark))

# Stubby side branch
me_branch = bpy.data.meshes.new("SideBranch")
bm = bmesh.new()
bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=6, radius1=0.01, radius2=0.01, depth=0.08)
bmesh.ops.transform(bm, matrix=Matrix.Rotation(math.radians(45), 4, 'X') @ Matrix.Translation((0, 0.04, 0)), verts=bm.verts)
bm.to_mesh(me_branch)
bm.free()
create_part("SideBranch", me_branch, mat_bark)

# Frayed tip (cone)
me_tip = bpy.data.meshes.new("FrayedTip")
bm = bmesh.new()
bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=8, radius1=0.02, radius2=0.005, depth=0.05)
bmesh.ops.transform(bm, matrix=Matrix.Translation((0, 0, -0.28)) @ Matrix.Rotation(math.radians(180), 4, 'X'), verts=bm.verts)
bm.to_mesh(me_tip)
bm.free()
create_part("FrayedTip", me_tip, mat_inner)

# Export
bpy.ops.export_scene.gltf(filepath="C:\\crypto\\wicked whiskers\\assetloop\\runs\\20260821_095137\\stick_1.glb", export_format='GLB')

# Calculate Bounding Box
min_v = Vector((100, 100, 100))
max_v = Vector((-100, -100, -100))
for obj in bpy.data.objects:
    for corner in obj.bound_box:
        world_corner = obj.matrix_world @ Vector(corner)
        for i in range(3):
            min_v[i] = min(min_v[i], world_corner[i])
            max_v[i] = max(max_v[i], world_corner[i])

dims = max_v - min_v
print("ASSET_BUILT")
print(f"DIMS {dims}")


