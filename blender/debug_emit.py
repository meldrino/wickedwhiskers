import bpy, math

scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.render.resolution_x = 300
scene.render.resolution_y = 300
scene.cycles.device = 'GPU'
scene.cycles.samples = 32
scene.view_settings.view_transform = 'Standard'
print('VT=%s' % scene.view_settings.view_transform)

world = bpy.data.worlds.new('W')
scene.world = world
world.node_tree.nodes['Background'].inputs[0].default_value = (0.0, 0.0, 0.0, 1)

cam = bpy.data.objects.new('Cam', bpy.data.cameras.new('Cam'))
scene.collection.objects.link(cam)
scene.camera = cam
cam.location = (0, -1.4, 0.5)

bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.5))
cube = bpy.context.active_object

mat = bpy.data.materials.new('OrangeEmit')
mat.use_nodes = True
bsdf = mat.node_tree.nodes.get('Principled BSDF')
bsdf.inputs['Base Color'].default_value = (0.976, 0.678, 0.349, 1.0)
print('BSDF_BC_AFTER_SET=%s' % (tuple(bsdf.inputs['Base Color'].default_value),))
emit = mat.node_tree.nodes.new('ShaderNodeEmission')
emit.inputs['Color'].default_value = (1.0, 0.5, 0.1, 1.0)
emit.inputs['Strength'].default_value = 5.0
mat.node_tree.links.new(emit.outputs['Emission'], mat.node_tree.nodes['Material Output'].inputs['Surface'])
cube.data.materials.append(mat)
print('MAT_SLOTS=%d' % len(cube.data.materials))

scene.render.filepath = r'C:\crypto\wicked whiskers\screenshots\dbg_emit.png'
bpy.ops.render.render(write_still=True)
print('EMIT_DONE')
