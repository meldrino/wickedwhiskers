import bpy
import bmesh
import math
import mathutils
import os

# Ensure we are saving to the current directory where the script is running
OUTPUT_DIR = os.getcwd()

def clear_scene():
    # Ensure there is an active collection/layer context
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for m in bpy.data.meshes: bpy.data.meshes.remove(m)
    for mat in bpy.data.materials: bpy.data.materials.remove(mat)

def create_material(name, color, roughness=0.5):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    return mat

def create_mesh_obj(name, bm, matrix=None):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(obj)
    if matrix: obj.matrix_world = matrix
    return obj

def create_box(name, size, pos, mat):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bm.transform(mathutils.Matrix.Scale(size[0], 4, (1,0,0)) @ mathutils.Matrix.Scale(size[1], 4, (0,1,0)) @ mathutils.Matrix.Scale(size[2], 4, (0,0,1)))
    bm.transform(mathutils.Matrix.Translation(pos))
    obj = create_mesh_obj(name, bm)
    obj.data.materials.append(mat)
    return obj

def create_wheel(name, radius, width, pos):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=True, segments=24, radius1=radius, radius2=radius, depth=width)
    rot = mathutils.Matrix.Rotation(math.radians(90), 4, 'Y')
    bm.transform(rot)
    bm.transform(mathutils.Matrix.Translation(pos))
    obj = create_mesh_obj(name, bm)
    return obj

# Setup
clear_scene()
m_red = create_material("Red", (0.82, 0.18, 0.13), 0.45)
m_dgrey = create_material("DGrey", (0.2, 0.2, 0.22), 0.5)
m_cream = create_material("Cream", (0.96, 0.95, 0.9), 0.35)

# Build
create_box("Bonnet", (1.2, 0.8, 1.2), (0, 0.8, 0.8), m_red)
create_box("Engine", (1.0, 0.6, 1.0), (0, 0.5, 0.8), m_dgrey)
create_box("Grille", (1.1, 0.7, 0.1), (0, 0.8, 1.45), m_dgrey)
create_box("Cabin", (1.2, 1.0, 1.0), (0, 1.0, -0.5), m_red)
create_box("Roof", (1.4, 0.1, 1.2), (0, 1.6, -0.5), m_red)
create_box("Plate", (0.5, 0.22, 0.05), (0, 1.1, -1.5), m_cream)

# Wheels
w_r = 0.55
w_f = 0.32
create_wheel("Wheel_FL", w_f, 0.2, (-1.1, w_f, 0.8))
create_wheel("Wheel_FR", w_f, 0.2, (1.1, w_f, 0.8))
create_wheel("Wheel_RL", w_r, 0.3, (-1.1, w_r, -0.8))
create_wheel("Wheel_RR", w_r, 0.3, (1.1, w_r, -0.8))

# Export using absolute paths
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUTPUT_DIR, "tractor.blend"))
bpy.ops.export_scene.gltf(filepath=os.path.join(OUTPUT_DIR, "tractor.glb"), export_format='GLB')

# Dims
min_v = mathutils.Vector((99,99,99))
max_v = mathutils.Vector((-99,-99,-99))
for obj in bpy.data.objects:
    for v in obj.bound_box:
        w_v = obj.matrix_world @ mathutils.Vector(v)
        for i in range(3):
            min_v[i] = min(min_v[i], w_v[i])
            max_v[i] = max(max_v[i], w_v[i])
print(f"DIMS {max_v[0]-min_v[0]:.2f} {max_v[1]-min_v[1]:.2f} {max_v[2]-min_v[2]:.2f}")
print("TRACTOR_BUILT")


