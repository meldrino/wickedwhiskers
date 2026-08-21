import bpy
import bmesh
import mathutils
import math

# Constants for Palette
RED = (0.82, 0.18, 0.13, 1.0)
DK_GREY = (0.20, 0.20, 0.22, 1.0)
NR_BLACK = (0.08, 0.08, 0.09, 1.0)
LT_GREY = (0.60, 0.60, 0.63, 1.0)
CREAM = (0.96, 0.95, 0.90, 1.0)
SKY = (0.66, 0.85, 0.91, 1.0)
WARM = (1.00, 0.95, 0.80, 1.0)

def create_mat(name, color, roughness=0.5):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = color
        bsdf.inputs["Roughness"].default_value = roughness
    return mat

def create_part(name, mesh_func, mat, loc=(0,0,0)):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    mesh_func(bm)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    ob.location = loc
    ob.data.materials.append(mat)
    bpy.context.collection.objects.link(ob)
    return ob

# Clear scene
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()

# Materials
m_red = create_mat("Red", RED, 0.4)
m_black = create_mat("Black", NR_BLACK, 0.8)
m_sky = create_mat("Sky", SKY, 0.2)
m_cream = create_mat("Cream", CREAM, 0.7)

# Geometry Builders
def b_bonnet(bm): 
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=(1.0, 0.8, 1.2), verts=bm.verts)

def b_cabin(bm): 
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=(1.2, 1.0, 0.8), verts=bm.verts)

def b_win(bm): 
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=(1.1, 0.9, 0.05), verts=bm.verts)

def b_wheel(bm):
    # Create tyre
    res = bmesh.ops.create_cone(bm, cap_ends=True, radius1=1.0, radius2=1.0, depth=0.3)
    # Rotate to X-axis
    rot = mathutils.Matrix.Rotation(math.radians(90), 4, 'Y')
    bmesh.ops.rotate(bm, cent=(0,0,0), matrix=rot, verts=bm.verts)

def b_plate(bm): 
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=(0.5, 0.22, 0.05), verts=bm.verts)

def b_exh(bm): 
    bmesh.ops.create_cone(bm, cap_ends=True, radius1=0.1, radius2=0.1, depth=1.0)

# Build
create_part("Bonnet", b_bonnet, m_red, (0, 0.8, 0.6))
create_part("Cabin", b_cabin, m_red, (0, 1.2, -0.6))
create_part("Win_F", b_win, m_sky, (0, 1.2, -0.2))
create_part("Plate", b_plate, m_cream, (0, 1.1, -1.4))
create_part("Exhaust", b_exh, m_black, (0.5, 1.5, -0.5))

# Wheels (Scale after creation to keep logic simple)
for name, pos in [("Wheel_FL", (1.1, 0.32, 0.8)), ("Wheel_FR", (-1.1, 0.32, 0.8)), 
                  ("Wheel_RL", (1.1, 0.55, -0.8)), ("Wheel_RR", (-1.1, 0.55, -0.8))]:
    ob = create_part(name, b_wheel, m_black, (pos[0], pos[1], pos[2]))
    ob.scale = (pos[1], pos[1], 1.0) # Scale based on radius

# Export
bpy.ops.wm.save_as_mainfile(filepath="tractor.blend")
bpy.ops.export_scene.gltf(filepath="tractor.glb", export_format='GLB', use_selection=False)
print("ASSET_BUILT")


