import bpy
import bmesh
import mathutils

def create_material(name, color, roughness=0.7):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    return mat

def create_primitive(name, type='cube', size=1.0, location=(0,0,0), scale=(1,1,1)):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    if type == 'cube':
        bmesh.ops.create_cube(bm, size=size)
    elif type == 'uvsphere':
        bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=12, radius=size/2)
    elif type == 'cone':
        bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=12, radius1=size/2, radius2=0, depth=size)
    
    bm.to_mesh(me)
    bm.free()
    
    # Transform mesh data to avoid object-level scaling
    mat_loc = mathutils.Matrix.Translation(location)
    mat_scale = mathutils.Matrix.Scale(scale[0], 4, (1,0,0)) @ mathutils.Matrix.Scale(scale[1], 4, (0,1,0)) @ mathutils.Matrix.Scale(scale[2], 4, (0,0,1))
    me.transform(mat_loc @ mat_scale)
    
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    return ob

# Materials
mat_grey = create_material("MouseGrey", (0.60, 0.60, 0.63))
mat_pink = create_material("MousePink", (0.85, 0.54, 0.54))
mat_black = create_material("MouseBlack", (0.08, 0.08, 0.09), 0.4)

# Build Mouse
# Body: Pear shape (0.06m long)
body = create_primitive("Body", 'uvsphere', 0.06, (0, 0.04, 0), (0.8, 1.0, 1.2))
body.data.materials.append(mat_grey)

# Head
head = create_primitive("Head", 'uvsphere', 0.04, (0, 0.06, 0.04), (1, 1, 1))
head.data.materials.append(mat_grey)

# Ears
for x in [-0.025, 0.025]:
    ear = create_primitive(f"Ear_{x}", 'uvsphere', 0.025, (x, 0.07, 0.05), (1, 0.2, 1))
    ear.data.materials.append(mat_grey)
    inner = create_primitive(f"InnerEar_{x}", 'uvsphere', 0.015, (x, 0.075, 0.055), (1, 0.2, 1))
    inner.data.materials.append(mat_pink)

# Snout & Nose
snout = create_primitive("Snout", 'cone', 0.02, (0, 0.07, 0.07), (1, 1, 1))
snout.data.materials.append(mat_grey)
nose = create_primitive("Nose", 'uvsphere', 0.005, (0, 0.08, 0.075), (1, 1, 1))
nose.data.materials.append(mat_black)

# Eyes
for x in [-0.015, 0.015]:
    eye = create_primitive(f"Eye_{x}", 'uvsphere', 0.008, (x, 0.07, 0.05), (1, 1, 1))
    eye.data.materials.append(mat_black)

# Legs
for i, pos in enumerate([(-0.02, 0.02, 0.02), (0.02, 0.02, 0.02), (-0.02, 0.02, 0.06), (0.02, 0.02, 0.06)]):
    leg = create_primitive(f"Leg_{i}", 'cube', 0.02, pos, (0.5, 1.5, 0.5))
    leg.data.materials.append(mat_grey)

# Tail
tail = create_primitive("Tail", 'cone', 0.08, (0, 0.02, -0.04), (0.1, 0.1, 1))
tail.data.materials.append(mat_grey)

# Export
bpy.ops.export_scene.gltf(filepath="C:\\crypto\\wicked whiskers\\assetloop\\runs\\20260821_011033\\mouse_1.glb", export_format='GLB')
print("ASSET_BUILT")

# Calculate Dims
min_v = mathutils.Vector((100, 100, 100))
max_v = mathutils.Vector((-100, -100, -100))
for obj in bpy.context.collection.objects:
    for v in obj.data.vertices:
        world_v = obj.matrix_world @ v.co
        min_v = mathutils.Vector(min(min_v[i], world_v[i]) for i in range(3))
        max_v = mathutils.Vector(max(max_v[i], world_v[i]) for i in range(3))
dims = max_v - min_v
print(f"DIMS Vector(({dims.x:.2f}, {dims.y:.2f}, {dims.z:.2f}))")


