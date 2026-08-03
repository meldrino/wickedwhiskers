"""Wicked Whiskers — procedural cartoon cat generator (v0.3).

Run headless:
  blender --background --python gen_ww.py

Outputs: <project>/assets/WW.glb  (rigged, glTF/Godot ready, +Y up, forward -Z)

Design: single unioned fur mesh (boolean exact solver) + feature meshes,
armature with stable bone names, procedural materials, subdiv for smoothness.
Topology is display-quality for the prototype; the mesh stays editable/sculptable.
"""

import bpy
import bmesh
import math
import traceback
from mathutils import Vector

OUT_DIR = r"C:\crypto\wicked whiskers\assets"
OUT_FILE = "WW.glb"

FUR = "Fur"
CREAM = "Cream"
DARK = "Dark"
EYE = "Eye"
PUPIL = "Pupil"
SATCHEL = "Satchel"

parts = []  # all meshes that get unioned into the fur body


def log(msg: str) -> None:
    print("WW:", msg, flush=True)


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


def capsule(name: str, p1, p2, r: float) -> list:
    p1v = Vector(p1)
    p2v = Vector(p2)
    direction = p2v - p1v
    length = direction.length
    mid = (p1v + p2v) * 0.5
    bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=r, depth=length, location=mid)
    cyl = bpy.context.active_object
    cyl.name = name
    cyl.rotation_euler = Vector((0.0, 0.0, 1.0)).rotation_difference(direction.normalized()).to_euler()
    s1 = sphere(name + "_cap1", r, p1v)
    s2 = sphere(name + "_cap2", r, p2v)
    return [cyl, s1, s2]


def add_part(obj) -> None:
    if isinstance(obj, (list, tuple)):
        parts.extend(obj)
    else:
        parts.append(obj)


def tapered_tube(name: str, pts, radii, mat, segments: int = 20,
                 flat: float = 1.0, cap_tip: bool = False) -> bpy.types.Object:
    """Smooth tapered tube following a 3D path (closed at the base, optionally at the tip).
    `flat` squashes the cross-section side-to-side (an ear blade)."""
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


def union_fur_body() -> bpy.types.Object:
    """Union all parts into the body; returns the single fur mesh object."""
    body = parts[0]
    bpy.context.view_layer.objects.active = body
    for part in parts[1:]:
        bpy.context.view_layer.objects.active = body
        mod = body.modifiers.new("Union", "BOOLEAN")
        mod.object = part
        mod.operation = "UNION"
        mod.solver = "EXACT"
        try:
            bpy.ops.object.modifier_apply(modifier="Union")
        except RuntimeError:
            # fall back to a fresh boolean modifier pass
            mod = body.modifiers.new("Union2", "BOOLEAN")
            mod.object = part
            mod.operation = "UNION"
            mod.solver = "EXACT"
            bpy.ops.object.modifier_apply(modifier="Union2")
        bpy.data.objects.remove(part, do_unlink=True)
    parts.clear()
    return body


def build_geometry() -> None:
    log("building geometry")
    fur = new_material(FUR, (0.95, 0.42, 0.10), rough=0.5)
    cream = new_material(CREAM, (1.0, 0.93, 0.82), rough=0.5)
    dark = new_material(DARK, (0.22, 0.16, 0.11))
    eye = new_material(EYE, (0.35, 0.75, 0.30), rough=0.2)
    pupil = new_material(PUPIL, (0.05, 0.05, 0.05), rough=0.3)
    glint = new_material("Glint", (1.0, 1.0, 1.0), rough=0.1)
    satchel = new_material(SATCHEL, (0.55, 0.33, 0.14))
    whisker = new_material("Whisker", (0.97, 0.96, 0.92), rough=0.4)

    # --- fur parts (unioned) ---
    body = sphere("Body", 1.0, (0, 0, 1.15), (0.62, 0.5, 0.62), fur)
    add_part(body)
    add_part(sphere("Head", 1.0, (0, 0.02, 1.9), (0.46, 0.44, 0.44), fur))

    # ears (curved blade leaning up/back + outward, dark inner cup facing forward)
    inner_ears = []
    for side in (1, -1):
        s = "L" if side > 0 else "R"
        ear_pts, ear_r = [], []
        for i in range(6):
            t = i / 5.0
            ear_pts.append((side * (0.30 + 0.09 * t), -0.06 - 0.05 * t, 2.02 + 0.40 * t))
            ear_r.append(0.22 - 0.20 * t)
        add_part(tapered_tube("Ear." + s, ear_pts, ear_r, fur,
                              segments=18, flat=0.5, cap_tip=True))
        inner_pts = [(p[0] + side * 0.015, p[1] - 0.05, p[2] - 0.01) for p in ear_pts]
        inner_r = [r * 0.72 for r in ear_r]
        inner_ears.append(tapered_tube("InnerEar." + s, inner_pts, inner_r, dark,
                                       segments=14, flat=0.45, cap_tip=False))

    # arms (chunky cartoon limbs, paws forward of the body)
    for side in (1, -1):
        add_part(capsule("UpperArm." + ("L" if side > 0 else "R"),
                         (side * 0.48, 0.12, 1.52), (side * 0.52, 0.06, 1.28), 0.14))
        add_part(capsule("Forearm." + ("L" if side > 0 else "R"),
                         (side * 0.52, 0.06, 1.28), (side * 0.50, -0.06, 1.04), 0.12))
        add_part(sphere("Hand." + ("L" if side > 0 else "R"), 1.0,
                        (side * 0.50, -0.12, 0.92), (0.20, 0.15, 0.18), fur))

    # legs
    for side in (1, -1):
        add_part(capsule("Thigh." + ("L" if side > 0 else "R"),
                         (side * 0.30, 0.04, 0.95), (side * 0.32, 0.05, 0.62), 0.15))
        add_part(capsule("Shin." + ("L" if side > 0 else "R"),
                         (side * 0.32, 0.05, 0.62), (side * 0.34, 0.05, 0.28), 0.13))
        add_part(sphere("Foot." + ("L" if side > 0 else "R"), 1.0,
                        (side * 0.36, 0.02, 0.18), (0.30, 0.40, 0.17), fur))

    # tail (smooth tapered tube curling up over the back)
    tail_pts = [(0.00, 0.26, 0.92, 0.14), (0.00, 0.48, 0.95, 0.125), (0.00, 0.66, 1.05, 0.11),
                (0.00, 0.78, 1.20, 0.09), (0.00, 0.83, 1.38, 0.075), (0.00, 0.78, 1.52, 0.06),
                (0.00, 0.66, 1.60, 0.045), (0.00, 0.52, 1.60, 0.035), (0.00, 0.44, 1.55, 0.028)]
    add_part(tapered_tube("Tail", [p[:3] for p in tail_pts], [p[3] for p in tail_pts], fur))

    # muzzle + belly (unioned, recoloured later by face proximity)
    add_part(sphere("Muzzle", 1.0, (0, -0.32, 1.72), (0.17, 0.16, 0.14), fur))
    add_part(sphere("Belly", 1.0, (0, -0.30, 1.05), (0.5, 0.36, 0.55), fur))

    body = union_fur_body()
    body.name = "WW_Mesh"

    # --- separate feature meshes ---
    nose = sphere("Nose", 0.05, (0, -0.46, 1.78), mat=dark)

    # big cute eyes + pupils + white glints
    eyes = []
    for side in (1, -1):
        eye_obj = sphere("Eye." + ("L" if side > 0 else "R"), 0.11,
                         (side * 0.20, -0.36, 1.94), mat=eye)
        pupil_obj = sphere("Pupil." + ("L" if side > 0 else "R"), 0.05,
                           (side * 0.20, -0.42, 1.97), mat=pupil)
        glint_obj = sphere("Glint." + ("L" if side > 0 else "R"), 0.02,
                           (side * 0.16, -0.46, 1.99), mat=glint)
        eyes += [eye_obj, pupil_obj, glint_obj]

    # satchel box + diagonal strap
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.47, 0.05, 1.12))
    box = bpy.context.active_object
    box.name = "Satchel"
    box.scale = Vector((0.16, 0.11, 0.22))
    set_mat(box, satchel)

    strap_from = Vector((0.38, -0.02, 1.55))
    strap_to = Vector((-0.33, 0.0, 0.98))
    strap_dir = strap_to - strap_from
    strap_mid = (strap_from + strap_to) * 0.5
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=strap_mid)
    strap = bpy.context.active_object
    strap.name = "Strap"
    strap.scale = Vector((0.06, strap_dir.length, 0.03))
    strap.rotation_euler = Vector((0.0, 1.0, 0.0)).rotation_difference(strap_dir.normalized()).to_euler()
    set_mat(strap, satchel)

    # whiskers — thin tapered strands fanning out from each cheek
    whiskers = []
    for side in (1, -1):
        s = "L" if side > 0 else "R"
        starts = [
            (0.24, -0.38, 1.80),
            (0.24, -0.38, 1.86),
            (0.22, -0.36, 1.92),
        ]
        tips = [
            (0.50, -0.64, 1.82),
            (0.56, -0.48, 1.90),
            (0.52, -0.34, 2.02),
        ]
        for k in range(3):
            start = (starts[k][0] * side, starts[k][1], starts[k][2])
            end = (tips[k][0] * side, tips[k][1], tips[k][2])
            whiskers.append(tapered_tube("Whisker.%s%d" % (s, k + 1),
                                         [start, end], [0.018, 0.003], whisker,
                                         segments=10, cap_tip=True))

    feature_meshes = [nose] + inner_ears + eyes + whiskers + [box, strap]
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    return body, feature_meshes


def build_armature() -> bpy.types.Object:
    log("building armature")
    bpy.ops.object.add(type="ARMATURE", location=(0, 0, 0))
    arm = bpy.context.active_object
    arm.name = "WW_Armature"
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.data.edit_bones

    def bone(name, head, tail, parent=None):
        b = eb.new(name)
        b.head = Vector(head)
        b.tail = Vector(tail)
        if parent:
            b.parent = eb[parent]
        return b

    bone("Root", (0, 0, 0.0), (0, 0, 0.15))
    bone("Pelvis", (0, 0, 0.90), (0, 0, 1.05), "Root")
    bone("Spine", (0, 0, 1.05), (0, 0, 1.35), "Pelvis")
    bone("Chest", (0, 0, 1.35), (0, 0, 1.60), "Spine")
    bone("Neck", (0, 0, 1.60), (0, 0, 1.78), "Chest")
    bone("Head", (0, 0, 1.78), (0, 0, 2.05), "Neck")
    for side in (1, -1):
        s = "L" if side > 0 else "R"
        bone("UpperArm." + s, (side * 0.48, 0.12, 1.52), (side * 0.52, 0.06, 1.28), "Chest")
        bone("Forearm." + s, (side * 0.52, 0.06, 1.28), (side * 0.50, -0.06, 1.04), "UpperArm." + s)
        bone("Hand." + s, (side * 0.50, -0.06, 1.04), (side * 0.50, -0.12, 0.92), "Forearm." + s)
        bone("Thigh." + s, (side * 0.30, 0.05, 0.92), (side * 0.33, 0.05, 0.62), "Pelvis")
        bone("Shin." + s, (side * 0.33, 0.05, 0.62), (side * 0.34, 0.05, 0.28), "Thigh." + s)
        bone("Foot." + s, (side * 0.34, 0.05, 0.28), (side * 0.40, 0.10, 0.18), "Shin." + s)
        bone("Toe." + s, (side * 0.40, 0.10, 0.18), (side * 0.45, 0.14, 0.16), "Foot." + s)
        bone("Ear." + s, (side * 0.30, -0.06, 2.02), (side * 0.39, -0.11, 2.42), "Head")
    bone("Tail01", (0, 0.05, 0.92), (0, 0.35, 0.96), "Pelvis")
    bone("Tail02", (0, 0.35, 0.96), (0, 0.60, 1.15), "Tail01")
    bone("Tail03", (0, 0.60, 1.15), (0, 0.74, 1.40), "Tail02")
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


def apply_armature(all_meshes, arm) -> None:
    log("automatic weights")
    bpy.ops.object.select_all(action="DESELECT")
    for obj in all_meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    bpy.ops.object.select_all(action="DESELECT")


def apply_subdivision(obj, level: int = 2) -> None:
    mod = obj.modifiers.new("Smooth", "SUBSURF")
    mod.levels = level
    mod.render_levels = level
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier="Smooth")
    bpy.ops.object.shade_smooth()


def paint_cream_faces(obj, ref_points) -> None:
    """Assign the CREAM material to faces near reference points (post-subdiv)."""
    cream = bpy.data.materials[CREAM]
    if CREAM not in obj.data.materials:
        obj.data.materials.append(cream)
    cream_idx = obj.data.materials.find(CREAM)
    mesh = obj.data
    bm = bmesh.new()
    bm.from_mesh(mesh)
    for face in bm.faces:
        c = face.calc_center_median()
        for ref, d in ref_points:
            if (c - Vector(ref)).length <= d:
                face.material_index = cream_idx
                break
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()


def enable_gltf() -> None:
    try:
        bpy.ops.preferences.addon_enable(module="io_scene_gltf2")
    except Exception:
        pass
    if not hasattr(bpy.ops.export_scene, "gltf"):
        raise RuntimeError("glTF exporter operator not found")


def main() -> None:
    log("start")
    clear_scene()
    enable_gltf()
    body, feature_meshes = build_geometry()
    arm = build_armature()

    all_meshes = [body] + feature_meshes
    apply_armature(all_meshes, arm)

    apply_subdivision(body, level=3)
    log("painting cream faces")
    paint_cream_faces(body, [
        ((0, -0.34, 1.75), 0.20),   # muzzle
        ((0, -0.34, 1.02), 0.38),   # belly / chest
        ((0.36, -0.16, 0.20), 0.16),   # left foot toes
        ((-0.36, -0.16, 0.20), 0.16),  # right foot toes
    ])

    out_path = OUT_DIR + "\\" + OUT_FILE
    log("exporting " + out_path)
    bpy.ops.export_scene.gltf(filepath=out_path, export_format="GLB", export_apply=False)
    blend_path = r"C:\crypto\wicked-whiskers-blender-out\WW.blend"
    log("saving " + blend_path)
    bpy.ops.wm.save_as_mainfile(filepath=blend_path)
    log("done: " + out_path)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        traceback.print_exc()
        raise
