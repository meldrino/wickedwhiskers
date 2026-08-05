extends Node3D

var fish := []
var swim_t := 0.0

const FISH_COUNT := 5
const SWIM_BASE := 2.0
const SWIM_VARY := 2.6
const MIN_Y := 0.25
const MAX_Y := 0.8


func _ready() -> void:
	for i in range(FISH_COUNT):
		var f := _build_fish(i)
		add_child(f)
		fish.append(f)


func _physics_process(delta: float) -> void:
	swim_t += delta
	var wl := Terrain.water_level
	for i in range(fish.size()):
		var f: Node3D = fish[i]
		var phase := i * 1.7
		var speed := 0.9 + (i % 3) * 0.35
		var radius := SWIM_BASE + (i % FISH_COUNT) * (SWIM_VARY / FISH_COUNT)
		var ang := phase + swim_t * speed
		var px := cos(ang) * radius
		var pz := sin(ang) * radius
		var y := wl - (MIN_Y + (MAX_Y - MIN_Y) * (0.5 + 0.5 * sin(swim_t * 1.3 + phase)))
		f.position = Vector3(px, y, pz)
		f.rotation.y = ang + PI * 0.5
		f.rotation.z = sin(swim_t * 3.0 + phase) * 0.12


func _build_fish(i: int) -> Node3D:
	var orange := StandardMaterial3D.new()
	orange.albedo_color = Color(0.98, 0.72, 0.42)
	orange.metallic = 0.25
	orange.roughness = 0.4
	var fin := StandardMaterial3D.new()
	fin.albedo_color = Color(0.9, 0.55, 0.25)
	fin.metallic = 0.15
	fin.roughness = 0.5

	var f := Node3D.new()
	var body := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.16
	sm.height = 0.42
	sm.material = orange
	body.mesh = sm
	f.add_child(body)

	var tail := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(0.06, 0.2, 0.2)
	tm.material = fin
	tail.mesh = tm
	tail.position = Vector3(0, 0, -0.24)
	f.add_child(tail)

	f.scale = Vector3.ONE * (0.85 + (i % 3) * 0.12)
	return f
