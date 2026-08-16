import bpy, sys
from mathutils import Matrix, Vector

args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
SRC = args[args.index('--src') + 1]
DST = args[args.index('--dst') + 1]

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()
bpy.ops.import_scene.gltf(filepath=SRC)
bpy.context.view_layer.update()

meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
corners = []
for o in meshes:
    corners += [o.matrix_world @ Vector(c) for c in o.bound_box]
bb_min = Vector((min(c[i] for c in corners) for i in range(3)))
bb_size = Vector((max(c[i] for c in corners) for i in range(3))) - bb_min

hand = []
for o in meshes:
    for v in o.data.vertices:
        wz = (o.matrix_world @ v.co).z
        if wz > bb_min.z + 0.72 * bb_size.z:
            hand.append(o.matrix_world @ v.co)
hand_center = Vector(tuple(sum(v[i] for v in hand) / len(hand) for i in range(3)))

shift = Matrix.Translation(-hand_center)
for o in meshes:
    o.data.transform(shift)
bpy.context.view_layer.update()
print('HAND_CENTER_SHIFT=%s' % (tuple(round(v, 4) for v in hand_center),))

bpy.ops.export_scene.gltf(
    filepath=DST,
    export_format='GLB',
    use_mesh_edges=False,
    use_mesh_vertices=False,
    export_apply=True,
)
print('EXPORTED:' + DST)
