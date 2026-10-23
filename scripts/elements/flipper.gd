class_name Flipper
extends AnimatableBody3D
## Kinematic flipper. It is rotated every physics tick; Jolt derives its
## velocity from the motion, so the ball gets a proper hit.

const LENGTH := 1.65
const BASE_R := 0.24
const TIP_R := 0.11
const UP_SPEED := 29.0
const DOWN_SPEED := 15.0
## Solenoid ramp-up: full speed is reached after ~25 ms, so a resting ball
## rolls along the bat a little before it leaves (this is what makes aiming
## depend on where the ball sits).
const ACCEL := 1000.0

var is_left := true
var rest_angle := 0.0
var up_angle := 0.0
var angle := 0.0
var pressed := false
var _omega := 0.0


func setup(left: bool) -> Flipper:
	is_left = left
	if left:
		rest_angle = deg_to_rad(-30.0)
		up_angle = deg_to_rad(28.0)
	else:
		rest_angle = deg_to_rad(210.0)
		up_angle = deg_to_rad(152.0)
	angle = rest_angle
	rotation.y = angle
	collision_layer = 1
	collision_mask = 0
	var pm := PhysicsMaterial.new()
	pm.friction = 0.7
	pm.bounce = 0.32
	physics_material_override = pm

	var outline := Geom.capsule_poly(Vector2.ZERO, BASE_R, Vector2(LENGTH, 0.0), TIP_R, 20)
	var hull := PackedVector3Array()
	for p in outline:
		hull.append(Vector3(p.x, 0.02, p.y))
		hull.append(Vector3(p.x, 0.55, p.y))
	var sh := ConvexPolygonShape3D.new()
	sh.points = hull
	var cs := CollisionShape3D.new()
	cs.shape = sh
	add_child(cs)

	# body: cream plastic, red rubber ring, gold pivot cap
	var body_poly := Geom.capsule_poly(Vector2.ZERO, BASE_R - 0.03, Vector2(LENGTH, 0.0), TIP_R - 0.03, 20)
	var st := Geom.new_st()
	Geom.add_prism(st, body_poly, 0.04, 0.5)
	add_child(Geom.instance(st, Mats.solid("flipper_body", Color(1.0, 0.96, 0.88), 0.25)))
	var rst := Geom.new_st()
	Geom.add_prism(rst, outline, 0.12, 0.4, false)
	add_child(Geom.instance(rst, Mats.rubber_red()))
	var cap := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.11
	cm.bottom_radius = 0.13
	cm.height = 0.08
	cap.mesh = cm
	cap.position = Vector3(0, 0.54, 0)
	cap.material_override = Mats.gold()
	add_child(cap)
	var stripe := MeshInstance3D.new()
	stripe.mesh = Geom.polygon_mesh(Geom.capsule_poly(Vector2(0.35, 0), 0.05, Vector2(LENGTH - 0.2, 0), 0.03, 8), 0.505)
	stripe.material_override = Mats.solid("flipper_stripe", Mats.RED, 0.3, 0.4)
	add_child(stripe)
	return self


func _physics_process(delta: float) -> void:
	var target := up_angle if pressed else rest_angle
	if is_equal_approx(angle, target):
		_omega = 0.0
		return
	var max_spd := UP_SPEED if pressed else DOWN_SPEED
	if pressed:
		_omega = minf(max_spd, _omega + ACCEL * delta)
	else:
		_omega = max_spd
	angle = move_toward(angle, target, _omega * delta)
	rotation.y = angle


func is_up() -> bool:
	return absf(angle - up_angle) < 0.05
