"""Wicked Whiskers — procedural cartoon rocks (v1.0).

Run headless:
  blender --background --python gen_rocks.py

Outputs (to assets/):
  rock_ww_a.glb  — chunky irregular boulder
  rock_ww_b.glb  — flatter paddy rock
  rock_ww_c.glb  — small rounded pebble stack
Root at y=0 (y-up), subdiv-smoothed, single material.
"""

import importlib.util
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ww_style import (
    OUT_DIR,
    new_material, sphere, clear_scene,
    apply_subdivision, export_glb, safe_main, log,
)

TAG = "ROCK"

ROCK_GREY = (0.52, 0.5, 0.47)
ROCK_DARK = (0.4, 0.38, 0.36)
ROCK_LIGHT = (0.6, 0.58, 0.54)


def rock_a() -> None:
    clear_scene()
    mat = new_material("Rock", ROCK_GREY, rough=0.85)
    dark = new_material("RockDark", ROCK_DARK, rough=0.9)
    light = new_material("RockLight", ROCK_LIGHT, rough=0.8)

    main = sphere("Main", 1.0, (0, 0.35, 0), (0.7, 0.6, 0.6), mat)
    apply_subdivision(main, level=2)
    top = sphere("Top", 1.0, (0.1, 0.7, -0.1), (0.42, 0.35, 0.38), light)
    apply_subdivision(top, level=2)
    facet = sphere("Facet", 1.0, (-0.25, 0.3, 0.3), (0.3, 0.22, 0.3), dark)
    apply_subdivision(facet, level=2)

    export_glb("rock_ww_a.glb")


def rock_b() -> None:
    clear_scene()
    mat = new_material("Rock", ROCK_GREY, rough=0.85)
    dark = new_material("RockDark", ROCK_DARK, rough=0.9)

    base = sphere("Base", 1.0, (0, 0.12, 0), (0.9, 0.28, 0.7), mat)
    apply_subdivision(base, level=2)
    hump = sphere("Hump", 1.0, (0.05, 0.32, -0.05), (0.5, 0.3, 0.4), dark)
    apply_subdivision(hump, level=2)

    export_glb("rock_ww_b.glb")


def rock_c() -> None:
    clear_scene()
    mat = new_material("Rock", ROCK_LIGHT, rough=0.8)
    dark = new_material("RockDark", ROCK_DARK, rough=0.9)

    b1 = sphere("B1", 1.0, (0, 0.12, 0), (0.45, 0.3, 0.4), mat)
    apply_subdivision(b1, level=2)
    b2 = sphere("B2", 1.0, (0.3, 0.16, 0.15), (0.32, 0.26, 0.3), mat)
    apply_subdivision(b2, level=2)
    b3 = sphere("B3", 1.0, (0.05, 0.36, -0.05), (0.28, 0.24, 0.26), dark)
    apply_subdivision(b3, level=2)

    export_glb("rock_ww_c.glb")


def main() -> None:
    log(TAG, "start")
    rock_a()
    log(TAG, "a done")
    rock_b()
    log(TAG, "b done")
    rock_c()
    log(TAG, "c done")
    log(TAG, "all done -> " + OUT_DIR)


if __name__ == "__main__":
    safe_main(main, TAG)
