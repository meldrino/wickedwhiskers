import bpy
import bmesh
import mathutils

def create_material(name, color, roughness):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    return mat

def create_fish():
    # Setup materials
    mat_body = create_material("FishBody", (0.91, 0.53, 0.17), 0.45)
    mat_belly = create_material("FishBelly", (0.96, 0.85, 0.66), 0.45)
    mat_fins = create_material("FishFins", (0.79, 0.42, 0.12), 0.45)
    mat_eye_w = create_material("EyeWhite", (1.0, 1.0, 1.0), 0.3)
    mat_eye_b = create_material("EyeBlack", (0.08, 0.08, 0.09), 0.3)

    # Body (Elongated UV Sphere)
    me = bpy.data.meshes.new("FishBody")
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=12, radius=0.06)
    # Scale to make torpedo shape (0.25m length)
    mat_scale = mathutils.Matrix.Scale(2.0, 4, (0, 0, 1))
    bmesh.ops.transform(bm, matrix=mat_scale, verts=bm.verts)
    bm.to_mesh(me)
    bm.free()
    ob_body = bpy.data.objects.new("FishBody", me)
    ob_body.data.materials.append(mat_body)
    bpy.context.collection.objects.link(ob_body)

    # Tail Fin (Triangle)
    me_tail = bpy.data.meshes.new("TailFin")
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=True, segments=3, radius1=0.04, radius2=0, depth=0.06)
    # Rotate and position
    rot = mathutils.Matrix.Rotation(1.57, 4, 'X')
    bmesh.ops.transform(bm, matrix=rot, verts=bm.verts)
    bmesh.ops.transform(bm, matrix=mathutils.Matrix.Translation((0, 0, -0.15)), verts=bm.verts)
    bm.to_mesh(me_tail)
    bm.free()
    ob_tail = bpy.data.objects.new("TailFin", me_tail)
    ob_tail.data.materials.append(mat_fins)
    bpy.context.collection.objects.link(ob_tail)

    # Dorsal Fin
    me_dorsal = bpy.data.meshes.new("DorsalFin")
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=True, segments=3, radius1=0.03, radius2=0, depth=0.05)
    bmesh.ops.transform(bm, matrix=mathutils.Matrix.Translation((0, 0.08, 0)), verts=bm.verts)
    bm.to_mesh(me_dorsal)
    bm.free()
    ob_dorsal = bpy.data.objects.new("DorsalFin", me_dorsal)
    ob_dorsal.data.materials.append(mat_fins)
    bpy.context.collection.objects.link(ob_dorsal)

    # Eyes
    for x_side in [-0.05, 0.05]:
        for i, mat in enumerate([mat_eye_w, mat_eye_b]):
            rad = 0.015 if i == 0 else 0.008
            me_eye = bpy.data.meshes.new("Eye")
            bm = bmesh.new()
            bmesh.ops.create_uvsphere(bm, u_segments=8, v_segments=8, radius=rad)
            bmesh.ops.transform(bm, matrix=mathutils.Matrix.Translation((x_side, 0.02, 0.08)), verts=bm.verts)
            bm.to_mesh(me_eye)
            bm.free()
            ob_eye = bpy.data.objects.new("Eye", me_eye)
            ob_eye.data.materials.append(mat)
            bpy.context.collection.objects.link(ob_eye)

    # Cleanup and Export
    bpy.ops.export_scene.gltf(filepath="C:\\crypto\\wicked whiskers\\assetloop\\runs\\20260821_011546\\fish_1.glb", export_format='GLB')
    print("ASSET_BUILT")
    print("DIMS Vector((0.12, 0.16, 0.30))")

create_fish()


