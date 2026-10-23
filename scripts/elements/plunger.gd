class_name Plunger
extends Node3D
## Spring plunger in the shooter lane. Hold to pull back, release to fire.

signal launched(power: float)

const MIN_SPEED := 20.0
const MAX_SPEED := 42.0
const CHARGE_TIME := 1.1
const PULL := 0.75

var lane_x := 5.455
var stop_z := 9.5
var charge := 0.0
var charging := false
var _rod: Node3D
var _spring: MeshInstance3D
var _snap := 0.0


func setup(x: float, z: float) -> Plunger:
	lane_x = x
	stop_z = z
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.7, 0.8, 0.4)
	cs.shape = box
	cs.position = Vector3(lane_x, 0.4, stop_z + 0.2)
	body.add_child(cs)
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.05
	pm.friction = 0.8
	body.physics_material_override = pm
	add_child(body)

	_rod = Node3D.new()
	add_child(_rod)
	var tip := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.2
	tm.bottom_radius = 0.2
	tm.height = 0.18
	tip.mesh = tm
	tip.rotation.x = PI * 0.5
	tip.position = Vector3(lane_x, 0.25, stop_z + 0.09)
	tip.material_override = Mats.rubber_red()
	_rod.add_child(tip)
	var rod := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 0.06
	rm.bottom_radius = 0.06
	rm.height = 1.6
	rod.mesh = rm
	rod.rotation.x = PI * 0.5
	rod.position = Vector3(lane_x, 0.25, stop_z + 0.9)
	rod.material_override = Mats.chrome()
	_rod.add_child(rod)
	var knob := MeshInstance3D.new()
	var km := SphereMesh.new()
	km.radius = 0.2
	km.height = 0.4
	knob.mesh = km
	knob.scale = Vector3(1, 1, 0.7)
	knob.position = Vector3(lane_x, 0.25, stop_z + 1.75)
	knob.material_override = Mats.solid("knob", Mats.RED, 0.2, 0.3)
	_rod.add_child(knob)
	_spring = MeshInstance3D.new()
	var st := Geom.new_st()
	var coil := PackedVector3Array()
	for i in 121:
		var t := float(i) / 120.0
		var a := t * TAU * 9.0
		coil.append(Vector3(cos(a) * 0.14, 0.25 + sin(a) * 0.14, t))
	Geom.add_tube(st, coil, 0.02, 6)
	_spring.mesh = st.commit()
	_spring.material_override = Mats.chrome()
	_spring.position = Vector3(lane_x, 0.0, stop_z + 0.2)
	add_child(_spring)
	return self


func _process(delta: float) -> void:
	if charging:
		charge = minf(1.0, charge + delta / CHARGE_TIME)
	if _snap > 0.0:
		_snap = maxf(0.0, _snap - delta * 6.0)
	var pull := charge * PULL if charging else -_snap * 0.2
	_rod.position.z = pull
	_spring.scale.z = maxf(0.2, 0.9 - pull)
	_spring.position.z = stop_z + 0.2 + pull


func begin_charge() -> void:
	charging = true
	charge = 0.0


func release() -> void:
	if not charging:
		return
	charging = false
	fire(charge)
	charge = 0.0
	_snap = 1.0


## Fires every ball resting at the bottom of the shooter lane.
func fire(power: float) -> bool:
	var fired := false
	for b in get_tree().get_nodes_in_group("balls"):
		var ball := b as Ball
		if ball == null or ball.captured:
			continue
		var p := ball.global_position
		if p.x > lane_x - 0.4 and p.z > stop_z - 1.0 and p.y < 0.6:
			ball.linear_velocity = Vector3(0, 0, -lerpf(MIN_SPEED, MAX_SPEED, power))
			fired = true
	if fired:
		launched.emit(power)
	return fired
