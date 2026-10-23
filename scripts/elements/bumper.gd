class_name Bumper
extends StaticBody3D
## "Cotton candy" pop bumper: striped dome, gold ring, flashes and kicks.

signal hit(bumper: Bumper)

const RADIUS := 0.48
const KICK := 17.5

var index := 0
var _cap_mat: ShaderMaterial
var _light: OmniLight3D
var _ring: Node3D
var _flash := 0.0
var _cooldown := 0.0


func setup(i: int, col: Color) -> Bumper:
	index = i
	collision_layer = 1
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.6
	pm.friction = 0.1
	physics_material_override = pm
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = RADIUS
	cyl.height = 0.9
	cs.shape = cyl
	cs.position.y = 0.45
	add_child(cs)

	var base := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = RADIUS + 0.12
	bm.bottom_radius = RADIUS + 0.16
	bm.height = 0.08
	base.mesh = bm
	base.position.y = 0.04
	base.material_override = Mats.gold()
	add_child(base)

	var body := MeshInstance3D.new()
	var body_m := CylinderMesh.new()
	body_m.top_radius = RADIUS - 0.04
	body_m.bottom_radius = RADIUS
	body_m.height = 0.62
	body.mesh = body_m
	body.position.y = 0.36
	body.material_override = Mats.stripes(Color(1, 1, 1), col.lightened(0.2), 10.0, 0)
	add_child(body)

	_ring = Node3D.new()
	add_child(_ring)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = RADIUS - 0.02
	tm.outer_radius = RADIUS + 0.06
	tm.rings = 32
	tm.ring_segments = 8
	ring.mesh = tm
	ring.position.y = 0.28
	ring.material_override = Mats.chrome()
	_ring.add_child(ring)

	var cap := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = RADIUS + 0.04
	sm.height = (RADIUS + 0.04) * 2.0
	sm.is_hemisphere = true
	cap.mesh = sm
	cap.scale = Vector3(1, 0.62, 1)
	cap.position.y = 0.66
	_cap_mat = Mats.stripes(col, Color(1, 0.95, 0.9), 8.0, 0, 0.15)
	cap.material_override = _cap_mat
	add_child(cap)

	var top := MeshInstance3D.new()
	var topm := SphereMesh.new()
	topm.radius = 0.09
	topm.height = 0.18
	top.mesh = topm
	top.position.y = 0.98
	top.material_override = Mats.gold()
	add_child(top)

	_light = OmniLight3D.new()
	_light.light_color = col.lightened(0.3)
	_light.omni_range = 2.2
	_light.light_energy = 0.0
	_light.position.y = 1.2
	_light.shadow_enabled = false
	add_child(_light)
	return self


func on_ball_hit(ball: Ball) -> void:
	if _cooldown > 0.0:
		return
	_cooldown = 0.04
	var away := ball.global_position - global_position
	away = away.rotated(Vector3.UP, randf_range(-0.08, 0.08))
	ball.kick(away, KICK * randf_range(0.9, 1.05), 0.35)
	_flash = 1.0
	hit.emit(self)


func _process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 4.0)
	_cap_mat.set_shader_parameter("flash", _flash)
	_light.light_energy = _flash * 3.0
	_ring.position.y = -0.12 * _flash
