import bpy
import bmesh
import mathutils
import math

def create_material(name, color, roughness):
    mat = bpy.data.materials.new(name)
    # In newer Blender versions, nodes are enabled by default, 
    # but we ensure the tree exists.
    if not mat.node_tree:
        mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (*color, 1.0)
        bsdf.inputs["Roughness"].default_value = roughness
    return mat

# Setup materials
mat_bark = create_material("Bark", (0.42, 0.29, 0.17), 0.85)

def create_segment(bm, radius, length, pos, rot):
    # Create cone and transform only the new vertices
    res = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=8, radius1=radius, radius2=radius, depth=length)
    verts = res['verts']
    for v in verts:
        v.co.rotate(rot)
        v.co += pos

# Build the stick
me = bpy.data.meshes.new("WoodenStick")
bm = bmesh.new()

# Main shaft segments
segments = 5
total_len = 0.55
seg_len = total_len / segments
for i in range(segments):
    z_pos = -0.275 + (i * seg_len) + (seg_len/2)
    angle = math.radians(i * 5)
    rot = mathutils.Euler((angle, 0, 0), 'XYZ')
    create_segment(bm, 0.015, seg_len, mathutils.Vector((0, 0, z_pos)), rot)

# Stubby side branch
stub = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=6, radius1=0.008, radius2=0.008, depth=0.08)
for v in stub['verts']:
    v.co.rotate(mathutils.Euler((0, math.radians(45), 0), 'XYZ'))
    v.co += mathutils.Vector((0.02, 0, 0))

# Frayed tip
tip = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=6, radius1=0.012, radius2=0.002, depth=0.03)
for v in tip['verts']:
    v.co += mathutils.Vector((0, 0, -0.29))

bm.to_mesh(me)
bm.free()

ob = bpy.data.objects.new("WoodenStick", me)
bpy.context.collection.objects.link(ob)
ob.data.materials.append(mat_bark)

# Export
bpy.ops.wm.save_as_mainfile(filepath="temp.blend") # Ensure scene is saved/valid
bpy.ops.export_scene.gltf(filepath="C:\\crypto\\wicked whiskers\\assetloop\\runs\\20260821_095903\\stick_1.glb", export_format='GLB')

# Calculate dimensions
dims = ob.dimensions
print("ASSET_BUILT")
print(f"DIMS Vector(({dims.x:.3f}, {dims.y:.3f}, {dims.z:.3f}))")


