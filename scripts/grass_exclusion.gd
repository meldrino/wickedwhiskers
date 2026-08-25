class_name GrassExclusion
extends RefCounted

const MAX_SLOPE := 1.2
# Bare ring around every pond: WATER_MARGIN lifts the dry-land cutoff so no
# blade base sits at/below the waterline, WATER_RIM keeps grass a visible
# distance away from the rendered disc edge (which overshoots the true
# shoreline by up to ~0.5 m in receding directions).
const WATER_MARGIN := 0.03
const WATER_RIM := 0.35

const RECTS := [
	{ "x": 0.0, "z": -37.2, "hx": 6.0, "hz": 4.6 },
	{ "x": 16.0, "z": -10.0, "hx": 1.7, "hz": 1.35 },
	{ "x": 0.0, "z": -32.6, "hx": 1.6, "hz": 4.4 },
	{ "x": 0.0, "z": -29.4, "hx": 2.3, "hz": 1.4 },
]


static func is_excluded(wx: float, wz: float, h: float) -> bool:
	if "--bare" in OS.get_cmdline_user_args():
		return false
	if h < Terrain.water_level + WATER_MARGIN:
		return true
	if Terrain.water_radius > 0.0:
		var c: Vector2 = Terrain.lake.center
		if Vector2(wx - c.x, wz - c.y).length() < Terrain.water_radius + WATER_RIM:
			return true
	if TerrainGenerator.slope_at(Terrain.heights, Terrain.config, wx, wz) > MAX_SLOPE:
		return true
	for r in RECTS:
		if absf(wx - r.x) < r.hx and absf(wz - r.z) < r.hz:
			return true
	return false
