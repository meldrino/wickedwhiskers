class_name TerrainConfig
extends RefCounted

const CAT := 0.5

var size := 121
var extent := 60.0
var seed := 0

var base_frequency := 0.045
var base_amplitude := 0.3

var hill_seed := 0
var hill_frequency := 0.028
var hill_amplitude := 4.0
var hill_start := 30.0
var hill_end := 38.0
var hill_max := 60.0

var edge_start := 26.8
var edge_end := 28.0

var grass_color := Color(0.35, 0.55, 0.2)
var dirt_color := Color(0.45, 0.33, 0.2)
var rock_color := Color(0.52, 0.52, 0.54)
var water_edge_color := Color(0.3, 0.43, 0.21)
var color_seed := 20260809
var color_frequency := 0.09
var color_variation := 0.12
var slope_dirt_start := 0.5
var slope_dirt_end := 1.0
var rock_start := 1.5
var rock_end := 3.0

var grass_spacing := 0.3
var grass_outer_blades := 6
var grass_inner_blades := 3
var grass_min_h := 0.022
var grass_max_h := 0.052

var lakes: Array = []
var flats: Array = []


static func whiskers() -> TerrainConfig:
	var c := TerrainConfig.new()
	c.seed = 20260804
	c.hill_seed = 777
	c.lakes = [
		{ "center": Vector2(-11.0, -16.0), "radius": 6.8, "depth": 5.2 * CAT },
	]
	c.flats = [
		{ "center": Vector2(0.0, -34.0), "radius": 16.0 },
		{ "center": Vector2(10.0, -20.0), "radius": 9.0 },
		{ "center": Vector2(16.0, -10.0), "radius": 8.0 },
	]
	return c
