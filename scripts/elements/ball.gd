class_name Ball
extends RigidBody3D
## The pinball. Physics is run by Jolt; playfield parts react through
## `on_ball_hit(ball)` which is called whenever the ball touches them.

const RADIUS := 0.25
const MAX_SPEED := 62.0
## The shooter lane is everything right of this x; while the ball is in it the
## one-way gate at its top is ignored so the ball can be plunged through.
const LANE_X := 5.08
const GATE_Z := -4.95

var gate_open := false
var captured := false
var idle_time := 0.0
var last_hit_time := 0.0


func _init() -> void:
	mass = 1.0
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 8
	can_sleep = false
	collision_layer = 2
	collision_mask = 1 | 2 | 4
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.06
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp = 0.4
	var pm := PhysicsMaterial.new()
	pm.friction = 0.22
	pm.bounce = 0.25
	physics_material_override = pm

	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = RADIUS
	cs.shape = sh
	add_child(cs)

	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = RADIUS
	sm.height = RADIUS * 2.0
	sm.radial_segments = 32
	sm.rings = 16
	mi.mesh = sm
	mi.material_override = Mats.ball()
	add_child(mi)

	add_to_group("balls")
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if body.has_method("on_ball_hit"):
		body.on_ball_hit(self)


func _physics_process(delta: float) -> void:
	var p := global_position
	if p.x > LANE_X and p.z > GATE_Z:
		_set_gate(true)
	elif gate_open and (p.z < GATE_Z - 0.75 or p.x < 4.95):
		_set_gate(false)
	if not captured and linear_velocity.length() < 0.6:
		idle_time += delta
	else:
		idle_time = 0.0


func _set_gate(open: bool) -> void:
	if open == gate_open:
		return
	gate_open = open
	set_collision_mask_value(3, not open)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var v := state.linear_velocity
	if v.length() > MAX_SPEED:
		state.linear_velocity = v.normalized() * MAX_SPEED


func in_shooter_lane() -> bool:
	return global_position.x > LANE_X and global_position.z > GATE_Z


## Hold the ball still (saucer, ball lock).
func capture(at: Vector3) -> void:
	captured = true
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_position = at


func release(velocity: Vector3) -> void:
	freeze = false
	captured = false
	linear_velocity = velocity
	idle_time = 0.0


## Kick used by bumpers and slingshots: push along `dir` with at least `speed`,
## keeping a share of the sideways motion so it still feels physical.
func kick(dir: Vector3, speed: float, keep: float = 0.4) -> void:
	dir.y = 0.0
	dir = dir.normalized()
	var v := linear_velocity
	v.y = 0.0
	var tangential := v - dir * v.dot(dir)
	linear_velocity = dir * speed + tangential * keep
