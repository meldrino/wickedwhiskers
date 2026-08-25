"""Wicked Whiskers — shared style spec for procedural asset generators.

Single source of truth for the WW look: palette + material roughness/metallic
+ the primitive helpers every generator uses (sphere, capsule, tapered tube,
subdivision, glTF export). Match this file if you want an asset to feel like
the cat (gen_ww.py).

Unit convention: generators build in "cat units" (~2 m tall cat); main.gd
scales instances at placement time.
"""

import bpy
import bmesh
import math
import traceback
from mathutils import Vector

OUT_DIR = r"C:\crypto\wicked whiskers\assets"

# --- palette (vibrant, chunky cartoon; matches gen_ww.py materials) ---
FUR = (0.95, 0.42, 0.10)      # cat orange
CREAM = (1.0, 0.93, 0.82)     # belly / muzzle cream
DARK = (0.22, 0.16, 0.11)     # dark brown
EYE = (0.35, 0.75, 0.30)      # green (unused by plants, kept for coherence)
TRUNK = (0.47, 0.30, 0.13)    # woody brown, warmer than DARK
LEAF = (0.30, 0.64, 0.22)     # vibrant leaf green
LEAF_LIGHT = (0.45, 0.74, 0.30)  # highlight green for canopy tips
LEAF_DARK = (0.20, 0.47, 0.16)   # shadow green for under-canopy


def log(tag: str, msg: str) -> None:
    print(f"{tag}:", msg, flush=True)


def new_material(name: str, color, rough: float = 0.65, metal: float = 0.0) -> bpy.types.Material:
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf is None:
        bsdf = mat.node_tree.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Base Color"].default_value = (color[0], color[1], color[2], 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    return mat


def set_mat(obj, mat) -> None:
    if obj.data.materials:
        obj.data.materials[0] = mat
    else:
        obj.data.materials.append(mat)


def sphere(name: str, radius: float, loc, scale=(1.0, 1.0, 1.0), mat=None) -> bpy.types.Object:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=12, radius=radius, location=loc)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = Vector(scale)
    if mat is not None:
        set_mat(obj, mat)
    return obj


def capsule(name: str, p1, p2, r: float, mat=None) -> list:
    p1v = Vector(p1)
    p2v = Vector(p2)
    direction = p2v - p1v
    length = direction.length
    mid = (p1v + p2v) * 0.5
    bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=r, depth=length, location=mid)
    cyl = bpy.context.active_object
    cyl.name = name
    cyl.rotation_euler = Vector((0.0, 0.0, 1.0)).rotation_difference(direction.normalized()).to_euler()
    if mat is not None:
        set_mat(cyl, mat)
    s1 = sphere(name + "_cap1", r, p1v, mat=mat)
    s2 = sphere(name + "_cap2", r, p2v, mat=mat)
    return [cyl, s1, s2]


def tapered_tube(name: str, pts, radii, mat, segments: int = 16,
                 flat: float = 1.0, cap_tip: bool = False) -> bpy.types.Object:
    bm = bmesh.new()

    def tangent(i: int) -> Vector:
        if i == 0:
            return (Vector(pts[1]) - Vector(pts[0])).normalized()
        if i == len(pts) - 1:
            return (Vector(pts[-1]) - Vector(pts[-2])).normalized()
        return (Vector(pts[i + 1]) - Vector(pts[i - 1])).normalized()

    rings = []
    for i in range(len(pts)):
        t = tangent(i)
        ref = Vector((0, 0, 1))
        if abs(t.dot(ref)) > 0.99:
            ref = Vector((1, 0, 0))
        n = t.cross(ref).normalized()
        b = t.cross(n).normalized()
        ring = []
        for k in range(segments):
            ang = 2.0 * math.pi * k / segments
            off = n * (math.cos(ang) * radii[i]) + b * (math.sin(ang) * radii[i])
            off.x *= flat
            ring.append(bm.verts.new(Vector(pts[i]) + off))
        rings.append(ring)

    for i in range(len(pts) - 1):
        for k in range(segments):
            k2 = (k + 1) % segments
            bm.faces.new((rings[i][k], rings[i][k2], rings[i + 1][k2], rings[i + 1][k]))

    center = bm.verts.new(Vector(pts[0]))
    for k in range(segments):
        k2 = (k + 1) % segments
        bm.faces.new((rings[0][k], rings[0][k2], center))

    if cap_tip and len(pts) > 1:
        center_tip = bm.verts.new(Vector(pts[-1]))
        last = rings[-1]
        for k in range(segments):
            k2 = (k + 1) % segments
            bm.faces.new((last[k], last[k2], center_tip))

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    set_mat(obj, mat)
    return obj


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for m in list(bpy.data.meshes):
        bpy.data.meshes.remove(m)
    for m in list(bpy.data.materials):
        bpy.data.materials.remove(m)


def apply_subdivision(obj, level: int = 2) -> None:
    mod = obj.modifiers.new("Smooth", "SUBSURF")
    mod.levels = level
    mod.render_levels = level
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier="Smooth")
    bpy.ops.object.shade_smooth()


def export_glb(out_file: str, apply_scale: bool = False) -> None:
    bpy.ops.object.select_all(action="SELECT")
    if apply_scale:
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.select_all(action="DESELECT")
    out_path = OUT_DIR + "\\" + out_file
    log("STYLE", "exporting " + out_path)
    bpy.ops.export_scene.gltf(filepath=out_path, export_format="GLB", export_apply=False)


def safe_main(run, tag: str) -> None:
    try:
        run()
    except Exception:
        traceback.print_exc()
        raise
