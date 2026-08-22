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

def build_stick():
    # Clear scene
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()

    # Materials
    mat_bark = create_material("Bark", (0.42, 0.29, 0.17), 0.85)
    mat_inner = create_material("Inner", (0.79, 0.66, 0.44), 0.85)

    # BMesh setup
    bm = bmesh.new()
    
    # Main shaft: 5 segments, slightly bent
    segments = 5
    length = 0.55
    seg_len = length / segments
    radius = 0.02
    
    for i in range(segments):
        z_pos = -length/2 + (i * seg_len) + (seg_len/2)
        # Gentle bend: offset X based on Z
        x_offset = (z_pos**2) * 0.2
        
        cyl = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=8, radius1=radius, radius2=radius, depth=seg_len)
        bmesh.ops.rotate(bm, cent=Vector((0,0,0)), matrix=Matrix.Rotation(math.radians(i * 5), 4, 'X'), verts=cyl['verts'])
        bmesh.ops.translate(bm, vec=Vector((x_offset, 0, z_pos)), verts=cyl['verts'])

    # Side branch
    branch = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=6, radius1=0.01, radius2=0.01, depth=0.1)
    bmesh.ops.rotate(bm, cent=Vector((0,0,0)), matrix=Matrix.Rotation(math.radians(45), 4, 'Y'), verts=branch['verts'])
    bmesh.ops.translate(bm, vec=Vector((0.02, 0, -0.1)), verts=branch['verts'])
    
    # Forked end
    for side in [-1, 1]:
        fork = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=6, radius1=0.01, radius2=0.01, depth=0.08)
        bmesh.ops.rotate(bm, cent=Vector((0,0,0)), matrix=Matrix.Rotation(math.radians(30 * side), 4, 'X'), verts=fork['verts'])
        bmesh.ops.translate(bm, vec=Vector((0, 0, length/2)), verts=fork['verts'])

    # Bark ridges (thin boxes)
    for i in range(3):
        ridge = bmesh.ops.create_cube(bm, size=1.0)
        bmesh.ops.scale(bm, vec=Vector((0.005, 0.005, 0.3)), verts=ridge['verts'])
        bmesh.ops.translate(bm, vec=Vector((radius + 0.002, 0, 0)), verts=ridge['verts'])
        bmesh.ops.rotate(bm, cent=Vector((0,0,0)), matrix=Matrix.Rotation(math.radians(i * 120), 4, 'Z'), verts=ridge['verts'])

    # Frayed tip (cone)
    tip = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=8, radius1=0.015, radius2=0.0, depth=0.05)
    bmesh.ops.translate(bm, vec=Vector((0, 0, -length/2)), verts=tip['verts'])

    # Finalize mesh
    me = bpy.data.meshes.new("WoodenStick")
    bm.to_mesh(me)
    bm.free()
    
    ob = bpy.data.objects.new("WoodenStick", me)
    bpy.context.collection.objects.link(ob)
    
    # Ensure it sits on ground (Y=0)
    # The current center is at 0,0,0. The lowest point is roughly -length/2.
    ob.location = (0, length/2, 0)
    ob.data.materials.append(mat_bark)
    
    # Export
    bpy.ops.export_scene.gltf(filepath="C:\\crypto\\wicked whiskers\\assetloop\\runs\\20260821_095137\\stick_2.glb", export_format='GLB')
    
    # Output stats
    print("ASSET_BUILT")
    print(f"DIMS {ob.dimensions}")

build_stick()


