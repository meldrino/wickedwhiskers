import bpy
import os

def main():
    glb_path = r"C:\crypto\wicked whiskers\assets\paw_hv.glb"
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=glb_path)
    for mat in bpy.data.materials:
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        if bsdf:
            bsdf.inputs["Roughness"].default_value = 0.95
            print("RESULT: mat=%s roughness=0.95" % mat.name)
    bpy.ops.export_scene.gltf(
        filepath=glb_path,
        export_format="GLB",
        use_selection=False,
        export_apply=True,
    )
    print("RESULT: exported %s size=%d" % (glb_path, os.path.getsize(glb_path)))

if __name__ == "__main__":
    main()
