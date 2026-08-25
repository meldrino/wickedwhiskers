extends SceneTree
func _initialize() -> void:
	var b1 := Basis.from_euler(Vector3(deg_to_rad(-90.0), deg_to_rad(180.0), 0.0), 0) # XYZ
	var b2 := Basis.from_euler(Vector3(deg_to_rad(-90.0), deg_to_rad(180.0), 0.0), 2) # YXZ
	print("EULER XYZ x-90 y180 cols=", b1.x, " ", b1.y, " ", b1.z)
	print("EULER YXZ x-90 y180 cols=", b2.x, " ", b2.y, " ", b2.z)
	print("  hand(+Z) XYZ -> ", b1 * Vector3(0,0,1))
	print("  arm(-Z)  XYZ -> ", b1 * Vector3(0,0,-1))
	print("  hand(+Z) YXZ -> ", b2 * Vector3(0,0,1))
	print("  arm(-Z)  YXZ -> ", b2 * Vector3(0,0,-1))
	quit(0)
