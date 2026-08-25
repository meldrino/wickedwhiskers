"""Wicked Whiskers — procedural cartoon trees (v1.0).

Run headless:
  blender --background --python gen_trees.py

Outputs (to assets/):
  tree_ww_round.glb  — chunky round canopy, curved trunk
  tree_ww_cone.glb   — tall conical fir
  tree_ww_fat.glb    — wide layered canopy, short thick trunk
Each: root at y=0 (y-up), no armature, single-material-per-mesh, subdiv-smoothed.
"""

import importlib.util
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ww_style import (
    OUT_DIR, TRUNK, LEAF, LEAF_LIGHT, LEAF_DARK,
    new_material, sphere, capsule, tapered_tube, clear_scene,
    apply_subdivision, export_glb, safe_main, log,
)

TAG = "TREE"


def round_tree() -> None:
    clear_scene()
    trunk = new_material("Trunk", TRUNK, rough=0.6)
    leaf = new_material("Leaf", LEAF, rough=0.55)
    light = new_material("LeafLight", LEAF_LIGHT, rough=0.5)
    dark = new_material("LeafDark", LEAF_DARK, rough=0.6)

    t = tapered_tube("Trunk", [(0, 0, 0), (0.05, 0, 0.9), (0.02, 0, 1.5)], [0.22, 0.16, 0.10], trunk,
                     segments=16, cap_tip=True)
    apply_subdivision(t, level=2)

    canopy = sphere("Canopy", 1.0, (0, 0.05, 2.0), (0.85, 0.8, 0.85), leaf)
    apply_subdivision(canopy, level=2)

    puff1 = sphere("Puff1", 1.0, (0.35, -0.05, 2.15), (0.45, 0.4, 0.42), light)
    apply_subdivision(puff1, level=2)
    puff2 = sphere("Puff2", 1.0, (-0.3, 0.0, 2.2), (0.38, 0.36, 0.38), dark)
    apply_subdivision(puff2, level=2)
    puff3 = sphere("Puff3", 1.0, (0, 0.12, 2.5), (0.4, 0.38, 0.4), light)
    apply_subdivision(puff3, level=2)

    export_glb("tree_ww_round.glb")


def cone_tree() -> None:
    clear_scene()
    trunk = new_material("Trunk", TRUNK, rough=0.6)
    leaf = new_material("Leaf", LEAF, rough=0.55)
    light = new_material("LeafLight", LEAF_LIGHT, rough=0.5)

    t = tapered_tube("Trunk", [(0, 0, 0), (0.02, 0, 1.1), (0, 0, 1.6)], [0.2, 0.14, 0.08], trunk,
                     segments=16, cap_tip=True)
    apply_subdivision(t, level=2)

    for i in range(4):
        y = 1.7 + i * 0.55
        w = 0.9 - i * 0.18
        tier = sphere("Tier%d" % (i + 1), 1.0, (0, 0.0, y), (w, 0.5, w), leaf if i % 2 else light)
        apply_subdivision(tier, level=2)

    tip = sphere("Tip", 1.0, (0, 0.05, 3.75), (0.28, 0.3, 0.28), leaf)
    apply_subdivision(tip, level=2)

    export_glb("tree_ww_cone.glb")


def fat_tree() -> None:
    clear_scene()
    trunk = new_material("Trunk", TRUNK, rough=0.6)
    leaf = new_material("Leaf", LEAF, rough=0.55)
    light = new_material("LeafLight", LEAF_LIGHT, rough=0.5)

    t = tapered_tube("Trunk", [(0, 0, 0), (0.0, 0, 0.7), (0.0, 0, 1.1)], [0.3, 0.24, 0.18], trunk,
                     segments=16, cap_tip=True)
    apply_subdivision(t, level=2)

    base = sphere("Base", 1.0, (0, 0.0, 1.55), (1.05, 0.65, 1.05), leaf)
    apply_subdivision(base, level=2)
    mid = sphere("Mid", 1.0, (0, 0.08, 2.05), (0.95, 0.62, 0.95), light)
    apply_subdivision(mid, level=2)
    top = sphere("Top", 1.0, (0, 0.15, 2.5), (0.8, 0.6, 0.8), leaf)
    apply_subdivision(top, level=2)
    cap = sphere("Cap", 1.0, (0, 0.2, 2.9), (0.55, 0.5, 0.55), light)
    apply_subdivision(cap, level=2)

    export_glb("tree_ww_fat.glb")


def main() -> None:
    log(TAG, "start")
    round_tree()
    log(TAG, "round done")
    cone_tree()
    log(TAG, "cone done")
    fat_tree()
    log(TAG, "fat done")
    log(TAG, "all done -> " + OUT_DIR)


if __name__ == "__main__":
    safe_main(main, TAG)
