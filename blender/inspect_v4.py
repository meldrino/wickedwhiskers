import bpy
import sys

def main():
    glb_path = sys.argv[sys.argv.index("--") + 1]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=glb_path)
    for o in bpy.data.objects:
        if o.type == "MESH":
            coords = [o.matrix_world @ v.co for v in o.data.vertices]
            xs = [c.x for c in coords]; ys = [c.y for c in coords]; zs = [c.z for c in coords]
            print("MESH %s verts=%d x[%.3f,%.3f] y[%.3f,%.3f] z[%.3f,%.3f]" % (
                o.name, len(coords), min(xs), max(xs), min(ys), max(ys), min(zs), max(zs)))
            mats = [o.material_slots[i].name for i in range(len(o.material_slots))]
            print("MESH materials=%s" % mats)
    print("INSPECT_DONE")

if __name__ == "__main__":
    main()
