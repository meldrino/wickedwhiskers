class_name TerrainGenerator
extends RefCounted


static func generate(cfg: TerrainConfig) -> PackedFloat32Array:
	var size := cfg.size
	var cell := cfg.extent * 2.0 / float(size - 1)
	var heights := PackedFloat32Array()
	heights.resize(size * size)
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = cfg.base_frequency
	n.seed = cfg.seed
	var hill := FastNoiseLite.new()
	hill.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	hill.frequency = cfg.hill_frequency
	hill.seed = cfg.hill_seed
	for iz in range(size):
		var z := -cfg.extent + iz * cell
		for ix in range(size):
			var x := -cfg.extent + ix * cell
			var h := n.get_noise_2d(x, z) * cfg.base_amplitude
			var fr := maxf(absf(x), absf(z))
			if fr > cfg.edge_start:
				h = lerpf(h, 0.0, smoothstep(cfg.edge_start, cfg.edge_end, fr))
			for flat in cfg.flats:
				var pd := Vector2(x, z).distance_to(flat.center)
				if pd < flat.radius:
					h = lerpf(h, 0.0, _pad_factor(pd, flat.radius))
			for lake in cfg.lakes:
				var ld := Vector2(x, z).distance_to(lake.center)
				h -= smoothstep(lake.radius, 0.0, ld) * lake.depth
			if fr > cfg.hill_start:
				var k := smoothstep(cfg.hill_start, cfg.hill_end, fr)
				var roll := smoothstep(cfg.hill_max, cfg.hill_start, fr)
				h += k * hill.get_noise_2d(x, z) * cfg.hill_amplitude * roll
			heights[iz * size + ix] = h
	return heights


static func height_at(heights: PackedFloat32Array, cfg: TerrainConfig, x: float, z: float) -> float:
	var cell := cfg.extent * 2.0 / float(cfg.size - 1)
	var fx := (x + cfg.extent) / cell
	var fz := (z + cfg.extent) / cell
	var ix := clampi(int(floor(fx)), 0, cfg.size - 2)
	var iz := clampi(int(floor(fz)), 0, cfg.size - 2)
	var tx := clampf(fx - ix, 0.0, 1.0)
	var tz := clampf(fz - iz, 0.0, 1.0)
	var a := heights[iz * cfg.size + ix]
	var b := heights[iz * cfg.size + ix + 1]
	var c := heights[(iz + 1) * cfg.size + ix]
	var d := heights[(iz + 1) * cfg.size + ix + 1]
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz)


static func generate_colors(heights: PackedFloat32Array, cfg: TerrainConfig) -> PackedColorArray:
	var size := cfg.size
	var cell := cfg.extent * 2.0 / float(size - 1)
	var colors := PackedColorArray()
	colors.resize(size * size)
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.seed = cfg.color_seed
	n.frequency = cfg.color_frequency
	for iz in range(size):
		for ix in range(size):
			var x := -cfg.extent + ix * cell
			var z := -cfg.extent + iz * cell
			var idx := iz * size + ix
			var h := heights[idx]
			var hx0 := heights[iz * size + maxi(ix - 1, 0)]
			var hx1 := heights[iz * size + mini(ix + 1, size - 1)]
			var hz0 := heights[maxi(iz - 1, 0) * size + ix]
			var hz1 := heights[mini(iz + 1, size - 1) * size + ix]
			var dx := (hx1 - hx0) / (2.0 * cell)
			var dz := (hz1 - hz0) / (2.0 * cell)
			var slope := atan(sqrt(dx * dx + dz * dz))
			var c: Color = cfg.grass_color * (1.0 + n.get_noise_2d(x, z) * cfg.color_variation)
			c = c.lerp(cfg.dirt_color, smoothstep(cfg.slope_dirt_start, cfg.slope_dirt_end, slope))
			c = c.lerp(cfg.rock_color, smoothstep(cfg.rock_start, cfg.rock_end, h))
			for lake in cfg.lakes:
				var ld: float = Vector2(x, z).distance_to(lake.center)
				c = c.lerp(cfg.water_edge_color, 1.0 - smoothstep(0.0, lake.radius * 0.45, ld))
			colors[idx] = c
	return colors


static func slope_at(heights: PackedFloat32Array, cfg: TerrainConfig, x: float, z: float) -> float:
	var cell := cfg.extent * 2.0 / float(cfg.size - 1)
	var fx := (x + cfg.extent) / cell
	var fz := (z + cfg.extent) / cell
	var ix := clampi(int(floor(fx)), 0, cfg.size - 2)
	var iz := clampi(int(floor(fz)), 0, cfg.size - 2)
	var idx := iz * cfg.size + ix
	var hx0 := heights[idx]
	var hx1 := heights[iz * cfg.size + ix + 1]
	var hz0 := heights[idx]
	var hz1 := heights[(iz + 1) * cfg.size + ix]
	var dx := (hx1 - hx0) / cell
	var dz := (hz1 - hz0) / cell
	return atan(sqrt(dx * dx + dz * dz))


static func _pad_factor(pd: float, radius: float) -> float:
	var t := clampf((pd - radius * 0.6) / maxf(radius * 0.4, 0.001), 0.0, 1.0)
	return 1.0 - smoothstep(0.0, 1.0, t)
