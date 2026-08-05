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
