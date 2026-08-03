# Wicked Whiskers — AI Cat Prompts
# Paste the relevant prompt into Meshy / Tripo (free tiers).
# Generate the cat FIRST, keep its render, then reuse that render as the
# style reference for every later asset so the whole game stays consistent.

# -----------------------------------------------------------------------------
# STATUS: BLENDER PIPELINE CHOSEN AND WORKING
# -----------------------------------------------------------------------------
# The procedural Blender pipeline (tools/blender/gen_ww.py) was selected as the
# hero-cat path and IS WORKING (verified: WW.glb renders, rigged, textured).
# It won because:
#   - No credits/API accounts (Meshy/Tripo need interactive web sessions)
#   - The user cannot view AI images, so AI style iteration is blind
#   - 100% style consistency, no license headaches, fully re-runnable
# Run it:  "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --python gen_ww.py
# Output:  assets\WW.glb  +  WW.blend saved OUTSIDE the project
#          (C:\crypto\wicked-whiskers-blender-out\WW.blend - a .blend inside
#          res:// breaks Godot's importer without a configured Blender path)
# After re-running gen_ww.py, reimport in the Godot editor (delete .godot\imported
# to force a full reimport).
# Keep this file: the Meshy/Tripo prompts below remain the fallback if we ever
# want AI-generated variants or art for other assets.

# -----------------------------------------------------------------------------
# STYLE BLOCK — reuse this on EVERY asset for consistency
# -----------------------------------------------------------------------------
STYLE = "Stylized cartoon, game-ready 3D asset. Soft rounded shapes, hand-painted PBR textures, vibrant warm colors, Pixar/Disney-inspired cartoon style, clean topology, centered, no background."

# -----------------------------------------------------------------------------
# MESHY (recommended first try)
# https://www.meshy.ai  ->  Text to 3D  (Meshy 5, 10 credits)
# -----------------------------------------------------------------------------
MESHY_PROMPT = """Stylized cartoon cat, game-ready 3D character. Plump rounded body, large expressive eyes, big triangular ears with tufted tips, long curling tail. Orange tabby with cream muzzle, chest and paws, subtle darker orange stripes. Friendly cheeky smirk, adventurous farm-cat personality. Soft rounded shapes, hand-painted PBR textures, vibrant warm colors, Pixar/Disney-inspired cartoon style, clean topology, front-facing, full body, centered, no background. 4K textures."""

# Meshy negative prompt (optional field):
MESHY_NEGATIVE = "low poly, flat shading, realistic fur, photorealistic, malformed limbs, extra legs, text, watermark, background"

# -----------------------------------------------------------------------------
# TRIPO (second candidate, for comparison)
# https://www.tripo3d.ai  ->  Text to 3D (or better: Image to 3D later)
# -----------------------------------------------------------------------------
TRIPO_PROMPT = """A cute mischievous cartoon tabby cat, plump rounded body, large expressive eyes, big triangular ears, long curling tail. Orange fur with cream muzzle, chest and paws. Friendly cheeky smile. Stylized cartoon game character, soft rounded shapes, hand-painted texture, vibrant colors, Pixar-inspired. Full body, front facing, centered on a plain background."""

# -----------------------------------------------------------------------------
# WORKFLOW
# -----------------------------------------------------------------------------
# 1. Paste the prompt into each tool, generate.
# 2. Download the best result as GLB/GLTF.
# 3. Drop it into C:\crypto\wicked whiskers\assets\  (e.g. cat_wicked.glb)
# 4. Compare the two renders, pick the winner (or refine the prompt).
# 5. Keep the winning render as the STYLE REFERENCE image for all other assets
#    (farmhouse, shed, birds, mice, Dumbleclaw, etc.) so styles stay consistent.
# 6. Licensing note: free-tier outputs are CC BY 4.0 (public + attribution).
#    Upgrade to Pro when we run the full asset batch for clean commercial rights.
# 7. Can't view the GLB? No viewer needed — drop the file anywhere and I'll render
#    turntable screenshots: godot --path "C:\crypto\wicked whiskers" res://scenes/viewer.tscn -- --view="path\to\model.glb"
#    This writes view_1.png .. view_4.png in the project root for eyeballing.

# -----------------------------------------------------------------------------
# OTHER GENERATORS (Grok's suggestions + Blender option, evaluated)
# Blender + Python (bpy) — SELECTED (see STATUS at top); script is
#   tools/blender/gen_ww.py and produces the working hero cat WW.glb.
# The rest are fallback-only:
# -----------------------------------------------------------------------------
# CSM (Tripo? No - CSM.ai, common/cloud models by Modelabs)
#   - Good at game-ready stylized characters, has an animation/retargeting suite.
#   - Prompt the same MESHY_PROMPT; free tier has limited credits.
# Stable Doodle
#   - Text+sketch-to-image; good for a CONCEPT/STYLE SHEET to feed as image input
#     (image-to-3D) into Tripo/Meshy rather than generating the mesh itself.
# Blender + Python (bpy) — ChatGPT suggestion, worth a shot
#   - Generate assets procedurally in code (rounded primitives + subdivision/bevel
#     modifiers + shader-node materials). 100% style-consistent, no credits, no
#     license headaches, exportable GLB via Blender. Great fallback if the AI
#     generators give inconsistent styles. Scripts can live in C:\crypto\wicked whiskers\tools\blender\.
#   - Need Blender installed first (blender.org). I can write the .py scripts.

