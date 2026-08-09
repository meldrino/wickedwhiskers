class_name GrassExclusion
extends RefCounted

const MAX_SLOPE := 1.2

const RECTS := [
	{ "x": 0.0, "z": -37.2, "hx": 6.0, "hz": 4.6 },
	{ "x": 16.0, "z": -10.0, "hx": 3.2, "hz": 2.6 },
	{ "x": 0.0, "z": -32.6, "hx": 1.6, "hz": 4.4 },
	{ "x": 0.0, "z": -29.4, "hx": 2.3, "hz": 1.4 },
]


static func is_excluded(wx: float, wz: float, h: float) -> bool:
	if h < Terrain.water_level:
		return true
	if TerrainGenerator.slope_at(Terrain.heights, Terrain.config, wx, wz) > MAX_SLOPE:
		return true
	for r in RECTS:
		if absf(wx - r.x) < r.hx and absf(wz - r.z) < r.hz:
			return true
	return false
