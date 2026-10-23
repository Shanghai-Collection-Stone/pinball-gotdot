class_name StandupTarget
extends StaticBody3D
## Fixed target that wobbles when hit (High Striker pad, balloons).

signal hit(target: StandupTarget, ball: Ball)

var index := 0
var visual: Node3D
## Minimum speed along the face normal that counts as a hit, so a ball merely
## rolling along a wall-mounted target does not score.
var min_impact := 0.0
var _normal := Vector3.ZERO
var _wobble := 0.0
var _cooldown := 0.0


func setup(i: int, facing: Vector2, size: Vector3, bounce: float = 0.45) -> StandupTarget:
	index = i
	rotation.y = Geom.yaw_toward(facing)
	_normal = Vector3(facing.x, 0.0, facing.y).normalized()
	var pm := PhysicsMaterial.new()
	pm.bounce = bounce
	physics_material_override = pm
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position.y = size.y * 0.5
	add_child(cs)
	visual = Node3D.new()
	add_child(visual)
	return self


func on_ball_hit(ball: Ball) -> void:
	if _cooldown > 0.0:
		return
	if min_impact > 0.0 and absf(ball.linear_velocity.dot(_normal)) < min_impact:
		return
	_cooldown = 0.15
	_wobble = 1.0
	hit.emit(self, ball)


func _process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if _wobble > 0.0:
		_wobble = maxf(0.0, _wobble - delta * 3.0)
		visual.rotation.x = sin(_wobble * 30.0) * 0.25 * _wobble
