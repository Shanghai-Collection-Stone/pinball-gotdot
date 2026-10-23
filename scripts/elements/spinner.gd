class_name Spinner
extends Area3D
## Spinning flap. The ball passes through it; its speed sets the spin and
## every half turn scores.

signal spun

var _flap: Node3D
var _spin := 0.0
var _angle := 0.0
var _half_turns := 0


func setup(width: float) -> Spinner:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, 0.6, 0.35)
	cs.shape = box
	cs.position.y = 0.3
	add_child(cs)
	body_entered.connect(_on_body_entered)

	for s in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.035
		cm.bottom_radius = 0.035
		cm.height = 0.75
		post.mesh = cm
		post.position = Vector3(s * width * 0.5, 0.375, 0)
		post.material_override = Mats.chrome()
		add_child(post)
	var bar := MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.top_radius = 0.025
	bc.bottom_radius = 0.025
	bc.height = width
	bar.mesh = bc
	bar.rotation.z = PI * 0.5
	bar.position.y = 0.72
	bar.material_override = Mats.chrome()
	add_child(bar)
	_flap = Node3D.new()
	_flap.position.y = 0.72
	add_child(_flap)
	var plate := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(width - 0.1, 0.4, 0.02)
	plate.mesh = bm
	plate.position.y = -0.2
	plate.material_override = Mats.stripes(Mats.GOLD, Mats.RED, 6.0, 2, 0.2)
	_flap.add_child(plate)
	return self


func _on_body_entered(body: Node3D) -> void:
	var ball := body as Ball
	if ball == null:
		return
	_spin = clampf(absf(ball.linear_velocity.length()) * 2.2, 8.0, 70.0)


func _process(delta: float) -> void:
	if _spin <= 0.0:
		return
	_angle += _spin * delta
	_spin = maxf(0.0, _spin - (6.0 + _spin * 0.9) * delta)
	var turns := int(_angle / PI)
	while _half_turns < turns:
		_half_turns += 1
		spun.emit()
	_flap.rotation.x = _angle
