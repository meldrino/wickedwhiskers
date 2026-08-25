import bpy, sys, math
from mathutils import Vector

args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
GLB = args[args.index('--glb') + 1]
OUT = args[args.index('--out') + 1]

scene = bpy.context.scene
scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x = 400
scene.render.resolution_y = 400

world = bpy.data.worlds.new('W')
scene.world = world
world.node_tree.nodes['Background'].inputs[0].default_value = (0.18, 0.18, 0.21, 1)

cam = bpy.data.objects.new('Cam', bpy.data.cameras.new('Cam'))
scene.collection.objects.link(cam)
scene.camera = cam
cam.location = (0, -4, 1.5)
cam.rotation_euler = (math.radians(10), 0, 0)

key = bpy.data.objects.new('Key', bpy.data.lights.new('Key', 'AREA'))
scene.collection.objects.link(key)
key.location = (1.2, -1.5, 2.2)
key.data.energy = 1800

bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.5))
cube = bpy.context.active_object
mat = bpy.data.materials.new('Orange')
mat.use_nodes = True
bsdf = mat.node_tree.nodes.get('Principled BSDF')
bsdf.inputs['Base Color'].default_value = (0.976, 0.678, 0.349, 1.0)
cube.data.materials.append(mat)

scene.render.filepath = OUT.replace('.png', '_cube.png')
bpy.ops.render.render(write_still=True)
print('CUBE_RENDERED')

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()
bpy.ops.import_scene.gltf(filepath=GLB)
bpy.context.view_layer.update()

print('=== MESH ATTRIBUTES ===')
for o in bpy.context.scene.objects:
    if o.type == 'MESH':
        for a in o.data.attributes:
            print('ATTR %s domain=%s type=%s' % (a.name, a.domain, a.data_type))

print('=== MATERIAL NODES ===')
for m in bpy.data.materials:
    print('MAT %s' % m.name)
    if m.use_nodes:
        for n in m.node_tree.nodes:
            desc = []
            for inp in n.inputs:
                if inp.links:
                    desc.append('%s<-%s' % (inp.name, inp.links[0].from_node.name))
            if desc:
                print('  node %s (%s) %s' % (n.name, n.type, '; '.join(desc)))

scene.render.filepath = OUT.replace('.png', '_paw.png')
bpy.ops.render.render(write_still=True)
print('PAW_RENDERED')
