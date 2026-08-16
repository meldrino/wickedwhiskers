import bpy, sys
from mathutils import Vector

args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
GLB = args[args.index('--glb') + 1]

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()
bpy.ops.import_scene.gltf(filepath=GLB)
bpy.context.view_layer.update()

print('=== OBJECTS ===')
for o in bpy.context.scene.objects:
    if o.type == 'MESH':
        mesh = o.data
        mat_names = [m.name if m else 'None' for m in mesh.materials]
        print('OBJ %s | verts=%d tris=%d | mats=%s' % (o.name, len(mesh.vertices), len(mesh.polygons), mat_names))

print('=== MATERIALS ===')
for m in bpy.data.materials:
    print('MAT %s' % m.name)
    if m.use_nodes:
        bsdf = m.node_tree.nodes.get('Principled BSDF')
        if bsdf:
            bc = bsdf.inputs['Base Color']
            if bc.links and bc.links[0].from_node.image:
                img = bc.links[0].from_node.image
                print('  base color IMAGE: %s (%dx%d)' % (img.name, img.size[0], img.size[1]))
            else:
                print('  base color VALUE: %s' % (tuple(bc.default_value),))
        else:
            print('  (no Principled BSDF)')

print('=== AABB ===')
corners = []
for o in bpy.context.scene.objects:
    if o.type == 'MESH':
        corners += [o.matrix_world @ Vector(c) for c in o.bound_box]
bb_max = Vector((max(c[i] for c in corners) for i in range(3)))
bb_min = Vector((min(c[i] for c in corners) for i in range(3)))
print('min=%s max=%s size=%s' % (tuple(round(v,4) for v in bb_min), tuple(round(v,4) for v in bb_max), tuple(round(v,4) for v in (bb_max-bb_min))))
print('DONE')
