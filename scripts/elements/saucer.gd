class_name Saucer
extends Area3D
## "Ticket booth" kickout hole: grabs the ball, holds it, then kicks it out.

signal captured(ball: Ball)

var eject_dir := Vector3(0.45, 0, 0.89)
var eject_speed := 9.5
var held: Ball
var _cooldown := 0.0
var _hold_time := -1.0
var _ring_mat: StandardMaterial3D


func setup(dir: Vector2) -> Saucer:
	eject_dir = Vector3(dir.x, 0, dir.y).normalized()
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.2
	cs.shape = sph
	cs.position.y = 0.25
	add_child(cs)
	body_entered.connect(_on_body_entered)

	var hole := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.34
	hm.bottom_radius = 0.3
	hm.height = 0.02
	hole.mesh = hm
	hole.position.y = 0.006
	hole.material_override = Mats.dark()
	add_child(hole)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.33
	tm.outer_radius = 0.42
	ring.mesh = tm
	ring.scale = Vector3(1, 0.4, 1)
	ring.position.y = 0.02
	_ring_mat = Mats.glow(Mats.GOLD, 0.6)
	_ring_mat.metallic = 0.8
	ring.material_override = _ring_mat
	add_child(ring)
	return self


func _on_body_entered(body: Node3D) -> void:
	var ball := body as Ball
	if ball == null or held != null or _cooldown > 0.0 or ball.captured:
		return
	if ball.linear_velocity.length() > 30.0:
		return
	held = ball
	ball.call_deferred("capture", global_position + Vector3(0, 0.1, 0))
	captured.emit(ball)


## Holds the current ball for `seconds` then ejects it.
func hold_for(seconds: float) -> void:
	_hold_time = seconds


func _process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if held != null:
		_ring_mat.emission_energy_multiplier = 1.5 + sin(Time.get_ticks_msec() * 0.02) * 1.2
		if _hold_time >= 0.0:
			_hold_time -= delta
			if _hold_time < 0.0:
				eject()
	else:
		_ring_mat.emission_energy_multiplier = 0.6


func eject() -> void:
	if held == null:
		return
	var b := held
	held = null
	_cooldown = 0.8
	_hold_time = -1.0
	if is_instance_valid(b):
		b.global_position = global_position + Vector3(0, 0.26, 0) + eject_dir * 0.1
		b.release(eject_dir * eject_speed + Vector3(randf_range(-0.6, 0.6), 0, 0))
