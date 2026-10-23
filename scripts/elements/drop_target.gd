class_name DropTarget
extends StaticBody3D
## "Duck shoot" drop target. Drops into the playfield when hit.

signal dropped(target: DropTarget)

var index := 0
var is_down := false
var _visual: Node3D
var _shape: CollisionShape3D
var _tween: Tween


## `facing` is the 2D direction the target face looks toward.
func setup(i: int, facing: Vector2) -> DropTarget:
	index = i
	rotation.y = Geom.yaw_toward(facing)
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.3
	physics_material_override = pm
	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.55, 0.6, 0.14)
	_shape.shape = box
	_shape.position.y = 0.3
	add_child(_shape)

	_visual = Node3D.new()
	add_child(_visual)
	var plate := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.52, 0.42, 0.1)
	plate.mesh = bm
	plate.position.y = 0.21
	plate.material_override = Mats.solid("duck_plate", Color(0.1, 0.45, 0.85), 0.3)
	_visual.add_child(plate)
	# the duck: body, head, beak, eye
	var yellow := Mats.solid("duck_yellow", Color(1.0, 0.85, 0.1), 0.35, 0.15)
	var body := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.16
	sm.height = 0.32
	body.mesh = sm
	body.scale = Vector3(1.35, 0.85, 0.7)
	body.position = Vector3(0.02, 0.5, -0.02)
	body.material_override = yellow
	_visual.add_child(body)
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.1
	hm.height = 0.2
	head.mesh = hm
	head.position = Vector3(-0.13, 0.68, -0.02)
	head.material_override = yellow
	_visual.add_child(head)
	var beak := MeshInstance3D.new()
	var bk := PrismMesh.new()
	bk.size = Vector3(0.08, 0.1, 0.06)
	beak.mesh = bk
	beak.rotation.z = PI * 0.5
	beak.position = Vector3(-0.25, 0.66, -0.02)
	beak.material_override = Mats.solid("duck_beak", Mats.ORANGE, 0.4)
	_visual.add_child(beak)
	var eye := MeshInstance3D.new()
	var em := SphereMesh.new()
	em.radius = 0.025
	em.height = 0.05
	eye.mesh = em
	eye.position = Vector3(-0.16, 0.71, -0.1)
	eye.material_override = Mats.dark()
	_visual.add_child(eye)
	return self


func on_ball_hit(_ball: Ball) -> void:
	if is_down:
		return
	is_down = true
	_shape.set_deferred("disabled", true)
	_animate(-0.85)
	dropped.emit(self)


func reset() -> void:
	if not is_down:
		return
	is_down = false
	_shape.set_deferred("disabled", false)
	_animate(0.0)


func _animate(y: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_visual, "position:y", y, 0.18).set_trans(Tween.TRANS_QUAD)
