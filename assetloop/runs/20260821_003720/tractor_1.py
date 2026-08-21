import bpy
import bmesh
import mathutils
from mathutils import Vector, Matrix, Euler
import math

# Clear existing objects
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

# -----------------------------------------------------------------------------
# MATERIALS
# -----------------------------------------------------------------------------
def get_material(name, color, roughness=0.5):
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        if bsdf:
            bsdf.inputs["Base Color"].default_value = (color[0], color[1], color[2], 1.0)
            bsdf.inputs["Roughness"].default_value = roughness
    return mat

mat_red         = get_material("TractorRed",   (0.82, 0.18, 0.13), 0.40)
mat_dark_grey   = get_material("DarkGrey",     (0.20, 0.20, 0.22), 0.60)
mat_near_black  = get_material("NearBlack",    (0.08, 0.08, 0.09), 0.80)
mat_light_grey  = get_material("LightGrey",    (0.60, 0.60, 0.63), 0.40)

# -----------------------------------------------------------------------------
# MESH HELPERS
# -----------------------------------------------------------------------------
def create_box(name, size, loc, mat):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    ob.location = Vector(loc)
    ob.data.materials.append(mat)
    bpy.context.collection.objects.link(ob)
    return ob

def create_cylinder(name, radius, depth, loc, rot=(0, 0, 0), mat=mat_dark_grey):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=24, radius1=radius, radius2=radius, depth=depth)
    rot_mat = Euler(rot, 'XYZ').to_matrix().to_4x4()
    bmesh.ops.transform(bm, matrix=rot_mat, verts=bm.verts)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    ob.location = Vector(loc)
    ob.data.materials.append(mat)
    bpy.context.collection.objects.link(ob)
    return ob

# -----------------------------------------------------------------------------
# WHEEL BUILDER
# -----------------------------------------------------------------------------
def build_wheel(name, radius, width, loc, is_left=True):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    
    me.materials.append(mat_near_black) # 0
    me.materials.append(mat_light_grey) # 1
    me.materials.append(mat_dark_grey)  # 2

    rot_to_x = Euler((0, math.radians(90), 0), 'XYZ').to_matrix().to_4x4()

    def add_part(r, d, mat_idx, offset=0):
        geom = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=28, radius1=r, radius2=r, depth=d)
        verts = geom['verts']
        bmesh.ops.transform(bm, matrix=Matrix.Translation((0, 0, offset)), verts=verts)
        bmesh.ops.transform(bm, matrix=rot_to_x, verts=verts)
        for f in bm.faces:
            if f.material_index == 0: f.material_index = mat_idx
        return verts

    add_part(radius, width, 0)
    add_part(radius * 1.035, width * 0.42, 0)
    add_part(radius * 0.58, width * 1.04, 1)
    lug_offset = (width * 0.53) if not is_left else (-width * 0.53)
    add_part(radius * 0.58 * 0.35, width * 0.16, 2, offset=lug_offset)

    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    ob.location = Vector(loc)
    bpy.context.collection.objects.link(ob)
    return ob

# Build
build_wheel("Wheel_FL", 0.32, 0.22, (-0.80, 0.32, 0.75), True)
build_wheel("Wheel_FR", 0.32, 0.22, ( 0.80, 0.32, 0.75), False)
build_wheel("Wheel_RL", 0.55, 0.36, (-0.92, 0.55, -0.65), True)
build_wheel("Wheel_RR", 0.55, 0.36, ( 0.92, 0.55, -0.65), False)

create_box("Chassis_Main", (0.72, 0.22, 1.95), (0.0, 0.44, 0.05), mat_dark_grey)
create_cylinder("Front_Axle", 0.045, 1.56, (0.0, 0.32, 0.75), (0, math.radians(90), 0))
create_cylinder("Rear_Axle", 0.065, 1.76, (0.0, 0.55, -0.65), (0, math.radians(90), 0))
create_box("Front_Bumper", (0.84, 0.26, 0.20), (0.0, 0.36, 1.18), mat_red)


