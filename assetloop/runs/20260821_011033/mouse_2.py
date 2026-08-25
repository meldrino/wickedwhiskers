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

# Palette
grey = (0.60, 0.60, 0.63)
light_grey = (0.79, 0.77, 0.74)
pink = (0.85, 0.54, 0.54)
black = (0.08, 0.08, 0.09)

# Materials
mat_body = create_material("MouseGrey", grey, 0.7)
mat_belly = create_material("MouseLight", light_grey, 0.7)
mat_pink = create_material("MousePink", pink, 0.6)
mat_eye = create_material("MouseEye", black, 0.3)

def create_part(name, mesh_func, mat, loc=(0,0,0), scale=(1,1,1)):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    mesh_func(bm)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    ob.location = loc
    ob.scale = scale
    ob.data.materials.append(mat)
    bpy.context.collection.objects.link(ob)
    return ob

# Create Mouse Parts
# Body: Pear shape (sphere scaled)
create_part("Body", lambda bm: bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=12, radius=0.03), mat_body, (0, 0.03, 0), (1, 1.2, 1.5))
# Head
create_part("Head", lambda bm: bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=12, radius=0.025), mat_body, (0, 0.05, 0.03))
# Snout
create_part("Snout", lambda bm: bmesh.ops.create_cone(bm, cap_ends=True, radius1=0.01, radius2=0.005, depth=0.02), mat_pink, (0, 0.05, 0.06), (1, 1, 1))
# Ears
create_part("EarL", lambda bm: bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=8, radius=0.015), mat_body, (-0.02, 0.06, 0.04), (1, 0.2, 1))
create_part("EarR", lambda bm: bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=8, radius=0.015), mat_body, (0.02, 0.06, 0.04), (1, 0.2, 1))
# Eyes
create_part("EyeL", lambda bm: bmesh.ops.create_uvsphere(bm, u_segments=8, v_segments=8, radius=0.005), mat_eye, (-0.01, 0.065, 0.04))
create_part("EyeR", lambda bm: bmesh.ops.create_uvsphere(bm, u_segments=8, v_segments=8, radius=0.005), mat_eye, (0.01, 0.065, 0.04))
# Legs
for i in range(4):
    x = 0.02 if i % 2 else -0.02
    z = 0.04 if i < 2 else -0.02
    create_part(f"Leg{i}", lambda bm: bmesh.ops.create_cone(bm, cap_ends=True, radius1=0.008, radius2=0.008, depth=0.02), mat_body, (x, 0.01, z))

# Tail
create_part("Tail", lambda bm: bmesh.ops.create_cone(bm, cap_ends=True, radius1=0.005, radius2=0.001, depth=0.08), mat_body, (0, 0.02, -0.05), (1, 1, 1))

# Export
bpy.ops.export_scene.gltf(filepath="C:\\crypto\\wicked whiskers\\assetloop\\runs\\20260821_011033\\mouse_2.glb", export_format='GLB')

# Bounds
min_v = mathutils.Vector((999,999,999))
max_v = mathutils.Vector((-999,-999,-999))
for ob in bpy.context.collection.objects:
    for v in ob.bound_box:
        world_v = ob.matrix_world @ mathutils.Vector(v)
        for i in range(3):
            min_v[i] = min(min_v[i], world_v[i])
            max_v[i] = max(max_v[i], world_v[i])

print("ASSET_BUILT")
print(f"DIMS Vector({(max_v - min_v)})")


