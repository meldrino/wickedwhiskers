import bpy, sys

args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
SRC = args[args.index('--src') + 1]
DST = args[args.index('--dst') + 1]

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()
bpy.ops.import_scene.gltf(filepath=SRC)
bpy.context.view_layer.update()

FUR = (0.976, 0.678, 0.349)  # #f9ad59
for m in bpy.data.materials:
    if not m.use_nodes:
        continue
    bsdf = m.node_tree.nodes.get('Principled BSDF')
    if not bsdf:
        continue
    bc = bsdf.inputs['Base Color']
    for link in list(bc.links):
        m.node_tree.links.remove(link)
    bc.default_value = (*FUR, 1.0)
    rough = bsdf.inputs['Roughness']
    for link in list(rough.links):
        m.node_tree.links.remove(link)
    rough.default_value = 0.7

for im in bpy.data.images:
    bpy.data.images.remove(im)
for m in list(bpy.data.materials):
    if not m.users:
        bpy.data.materials.remove(m)

for o in bpy.context.scene.objects:
    if o.type == 'MESH':
        for attr in list(o.data.attributes):
            if attr.data_type in ('FLOAT_COLOR', 'BYTE_COLOR'):
                o.data.attributes.remove(attr)

bpy.ops.export_scene.gltf(
    filepath=DST,
    export_format='GLB',
    use_mesh_edges=False,
    use_mesh_vertices=False,
    export_apply=True,
)
print('EXPORTED:' + DST)
