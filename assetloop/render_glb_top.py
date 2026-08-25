import bpy, sys, math
from mathutils import Vector

# Forge renderer: imports a GLB and renders a TOP-DOWN view (the judging view for
# paws - user rule: paws are viewed from the top). CYCLES on CPU on purpose: the
# GPU path renders grey/black headless in this environment (worklog 2026-08-16).

args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
def arg(n, d=None):
    return args[args.index(n) + 1] if n in args else d
GLB = arg('--glb')
OUT = arg('--out')
SAMPLES = int(arg('--samples', '48'))

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()
bpy.ops.import_scene.gltf(filepath=GLB)

scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.device = 'CPU'
scene.cycles.samples = SAMPLES
scene.render.resolution_x = 800
scene.render.resolution_y = 800
bpy.context.view_layer.update()

meshes = [o for o in scene.objects if o.type == 'MESH']
corners = []
for o in meshes:
    corners += [o.matrix_world @ Vector(c) for c in o.bound_box]
bb_max = Vector((max(c[i] for c in corners) for i in range(3)))
bb_min = Vector((min(c[i] for c in corners) for i in range(3)))
bb_center = (bb_max + bb_min) * 0.5
bb_size = bb_max - bb_min

# Top-down camera: look straight down at the back of the hand (+Z side up).
fov = math.radians(50)
D = (max(bb_size.x, bb_size.y) * 1.25) / (2.0 * math.tan(fov / 2.0))

cam = bpy.data.objects.new('Cam', bpy.data.cameras.new('Cam'))
scene.collection.objects.link(cam)
scene.camera = cam
cam.data.angle = fov
cam.location = Vector((bb_center.x, bb_center.y, bb_center.z + D))
tgt = bpy.data.objects.new('Tgt', None)
scene.collection.objects.link(tgt)
tgt.location = bb_center
con = cam.constraints.new('TRACK_TO')
con.target = tgt
con.track_axis = 'TRACK_NEGATIVE_Z'
con.up_axis = 'UP_Y'

key = bpy.data.objects.new('Key', bpy.data.lights.new('Key', 'AREA'))
scene.collection.objects.link(key)
key.location = bb_center + Vector((0.8, 0.8, 2.0))
key.data.energy = 900
fill = bpy.data.objects.new('Fill', bpy.data.lights.new('Fill', 'AREA'))
scene.collection.objects.link(fill)
fill.location = bb_center + Vector((-0.8, 0.9, 1.4))
fill.data.energy = 400

world = bpy.data.worlds.new('W')
scene.world = world
world.node_tree.nodes['Background'].inputs[0].default_value = (0.14, 0.14, 0.16, 1)

scene.render.filepath = OUT
bpy.ops.render.render(write_still=True)
print('RENDERED:' + OUT)
