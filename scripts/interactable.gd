class_name Interactable
extends Area3D

@export var prompt := "Click — interact"
@export var interaction_radius := 2.2
@export var interaction_box := Vector3.ZERO
@export var interaction_center := Vector3.ZERO

var _held_player: Node3D = null


func _ready() -> void:
	add_to_group("interactable")
	var col := CollisionShape3D.new()
	col.position = interaction_center
	if interaction_box != Vector3.ZERO:
		var box := BoxShape3D.new()
		box.size = interaction_box
		col.shape = box
	else:
		var sphere := SphereShape3D.new()
		sphere.radius = interaction_radius
		col.shape = sphere
	add_child(col)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if _held_player == null and body.has_method("set_interactable"):
		_held_player = body
		body.set_interactable(self)


func _on_body_exited(body: Node3D) -> void:
	if body == _held_player:
		body.set_interactable(null)
		_held_player = null


func interact() -> void:
	pass


func get_interaction_point() -> Vector3:
	return to_global(interaction_center)
