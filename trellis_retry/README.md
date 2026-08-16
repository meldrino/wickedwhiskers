# TRELLIS.2 Regeneration Kit (use this instead of the Grok drawing)

## Why this exists
Your first Grok drawing -> TRELLIS.2 attempt produced a lumpy, non-paw blob.
TRELLIS.2 is a single-image generator: given a flat 2D cartoon drawing it collapses
thin features (toe knuckles, digit separations) into one smooth webbed mass.
Both gemini and copilot agree: it needs an *exaggerated 3D render* as the reference
image, not a flat drawing. `paw_v4_back.png` IS such a render — an actual 3D model
that reads as a cat paw (verified: 4 digit bumps + thumb, knuckles, arm).

## Files
- `reference.png`  = copy of the v4 studio render (back of hand, 4 digits + thumb,
                     knuckles, arm hanging down). Feed THIS to TRELLIS.2.
- `prompt.txt`     = exact prompt to paste.

## Steps (HF space, your account, browser)
1. Open https://huggingface.co/spaces/JeffreyXiang/TRELLIS (the free Tier)
   or the TRELLIS.2 space you used before.
2. Image mode. Upload `reference.png` (NOT the Grok drawing).
3. Paste `prompt.txt` content verbatim.
4. Generate. Download the GLB.
5. Hand the GLB to big-pickle: it will strip textures, recolor #f9ad59,
   center the hand, and verify the silhouette (needs >= 4 digit peaks).

## If the result is STILL a blob
Stop. Do not iterate further on TRELLIS. The parametric model
(`assets/paw_ai_v4.glb`) already reads as a paw and is the fallback:
- back view verified: 4 digit peaks (thumb + 3 fingers), symmetric,
  range 0.085 vs TRELLIS's lumpy 0.016.
- studio pose params already tuned (model_rot_x_deg=-90, back to camera,
  arm hanging down) — see screenshots/pawstudio_params.json.
