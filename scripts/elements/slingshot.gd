class_name Slingshot
extends StaticBody3D
## Triangular slingshot above each flipper. Only the long rubber face kicks.

signal hit(sling: Slingshot)

const KICK := 14.5

var is_left := true
var _a := Vector2.ZERO
var _c := Vector2.ZERO
var _n := Vector2.ZERO
var _band: MeshInstance3D
var _plastic_mat: StandardMaterial3D
var _flash := 0.0


## a = top corner, b = corner on the inlane guide, c = bottom corner.
## The kicking face is a -> c.
func setup(left: bool, a: Vector2, b: Vector2, c: Vector2) -> Slingshot:
	is_left = left
	_a = a
	_c = c
	var e := (c - a).normalized()
	_n = Vector2(e.y, -e.x)
	if _n.dot(b - a) > 0.0:
		_n = -_n
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.5
	pm.friction = 0.2
	physics_material_override = pm

	var poly := PackedVector2Array([a + _n * 0.06, b, c + _n * 0.06])
	var hull := PackedVector3Array()
	for p in poly:
		hull.append(Geom.v3(p, 0.0))
		hull.append(Geom.v3(p, 0.6))
	var sh := ConvexPolygonShape3D.new()
	sh.points = hull
	var cs := CollisionShape3D.new()
	cs.shape = sh
	add_child(cs)

	var inner := PackedVector2Array([a - _n * 0.02 + e * 0.05, b, c - _n * 0.02 - e * 0.05])
	var st := Geom.new_st()
	Geom.add_prism(st, inner, 0.0, 0.42)
	add_child(Geom.instance(st, Mats.solid("sling_base", Color(0.12, 0.05, 0.2), 0.5)))
	var pst := Geom.new_st()
	Geom.add_prism(pst, inner, 0.5, 0.56)
	_plastic_mat = Mats.glow(Mats.GOLD, 0.25)
	add_child(Geom.instance(pst, _plastic_mat))

	_band = MeshInstance3D.new()
	var bst := Geom.new_st()
	Geom.add_wall(bst, PackedVector2Array([a + _n * 0.03, c + _n * 0.03]), 0.04, 0.12, 0.42)
	_band.mesh = bst.commit()
	_band.material_override = Mats.rubber()
	add_child(_band)
	for p in [a, b, c]:
		_add_post(p)
	return self


func _add_post(p: Vector2) -> void:
	var post := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.07
	cm.bottom_radius = 0.07
	cm.height = 0.62
	post.mesh = cm
	post.position = Geom.v3(p, 0.31)
	post.material_override = Mats.chrome()
	add_child(post)


func on_ball_hit(ball: Ball) -> void:
	var p := Vector2(ball.global_position.x, ball.global_position.z)
	var ac := _c - _a
	var t := clampf((p - _a).dot(ac) / ac.length_squared(), 0.0, 1.0)
	var closest := _a + ac * t
	var rel := p - closest
	if t < 0.1 or t > 0.9 or rel.dot(_n) <= 0.0 or rel.length() > Ball.RADIUS + 0.14:
		return
	# a little randomness, like a real coil, so the ball can't settle into an
	# endless sling-to-sling ping-pong
	var dir := _n.rotated(randf_range(-0.14, 0.14))
	ball.kick(Vector3(dir.x, 0.0, dir.y), KICK * randf_range(0.82, 1.05), 0.5)
	_flash = 1.0
	hit.emit(self)


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 5.0)
		_band.position = Vector3(_n.x, 0, _n.y) * 0.06 * _flash
		_plastic_mat.emission_energy_multiplier = 0.25 + _flash * 3.0
