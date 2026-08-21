import bpy
import bmesh
from mathutils import Matrix, Vector
import math

def create_material(name, color, roughness=0.5):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    return mat

# Colors
gold_orange = (0.91, 0.53, 0.17)
belly_cream = (0.96, 0.85, 0.66)
fin_orange = (0.79, 0.42, 0.12)
white = (1.0, 1.0, 1.0)
near_black = (0.08, 0.08, 0.09)

def create_part(name, mesh_func, color, roughness=0.5):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    mesh_func(bm)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    ob.data.materials.append(create_material(name + "_mat", color, roughness))
    return ob

# 1. Body (Torpedo shape)
def build_body(bm):
    bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=12, radius=0.06)
    # Elongate to torpedo
    for v in bm.verts:
        v.co.z *= 2.0 
    bmesh.ops.transform(bm, matrix=Matrix.Translation((0, 0.06, 0)), verts=bm.verts)

body = create_part("FishBody", build_body, gold_orange, 0.45)

# 2. Belly (Cream strip)
def build_belly(bm):
    bmesh.ops.create_cube(bm, size=1.0)
    # Squash into a thin strip along bottom
    bmesh.ops.transform(bm, matrix=Matrix.Scale(0.08, 4, (1,0,0)) @ Matrix.Scale(0.1, 4, (0,1,0)) @ Matrix.Scale(0.2, 4, (0,0,1)), verts=bm.verts)
    bmesh.ops.transform(bm, matrix=Matrix.Translation((0, 0.02, 0.06)), verts=bm.verts)

belly = create_part("Belly", build_belly, belly_cream, 0.6)

# 3. Fins (Tail, Dorsal, Side)
def build_fin(bm):
    # Simple triangular prism
    bmesh.ops.create_cone(bm, cap_ends=True, segments=3, radius1=0.04, radius2=0.0, depth=0.06)

tail = create_part("Tail", build_fin, fin_orange, 0.5)
tail.location = (0, 0.06, -0.15)
tail.rotation_euler = (math.pi/2, 0, 0)

dorsal = create_part("Dorsal", build_fin, fin_orange, 0.5)
dorsal.location = (0, 0.12, 0)
dorsal.rotation_euler = (0, 0, 0)

# 4. Eyes
def build_eye(bm):
    bmesh.ops.create_uvsphere(bm, u_segments=8, v_segments=8, radius=0.015)

eye_l = create_part("EyeL", build_eye, white, 0.3)
eye_l.location = (-0.05, 0.08, 0.08)
eye_r = create_part("EyeR", build_eye, white, 0.3)
eye_r.location = (0.05, 0.08, 0.08)

pupil_l = create_part("PupilL", build_eye, near_black, 0.3)
pupil_l.location = (-0.055, 0.09, 0.085)
pupil_l.scale = (0.5, 0.5, 0.5)

pupil_r = create_part("PupilR", build_eye, near_black, 0.3)
pupil_r.location = (0.055, 0.09, 0.085)
pupil_r.scale = (0.5, 0.5, 0.5)

# Export
bpy.ops.export_scene.gltf(filepath="C:\\crypto\\wicked whiskers\\assetloop\\runs\\20260821_011546\\fish_4.glb", export_format='GLB')
print("ASSET_BUILT")

# Calculate Bounding Box
min_v = Vector((100, 100, 100))
max_v = Vector((-100, -100, -100))
for obj in bpy.data.objects:
    for corner in obj.bound_box:
        world_corner = obj.matrix_world @ Vector(corner)
        for i in range(3):
            min_v[i] = min(min_v[i], world_corner[i])
            max_v[i] = max(max_v[i], world_corner[i])
print(f"DIMS Vector({(max_v - min_v).to_tuple()})")


