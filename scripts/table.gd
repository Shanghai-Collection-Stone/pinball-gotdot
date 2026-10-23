class_name Table
extends Node3D
## Builds the physical playfield: walls, flippers, ramps, wire rails, targets
## and lamps. Everything that happens to the ball is reported through `event`.
##
## Layout (top view, +z toward the player):
##   top arc + F-U-N lanes, three pop bumpers, balloon targets top-right,
##   left "Roller Coaster" ramp and right "Ferris Wheel" ramp that turn into
##   wire rails feeding the inlanes, High Striker target in the middle,
##   Ticket Booth saucer lower-left, Duck Shoot drop targets lower-right,
##   Ring Toss targets on the left wall, Lucky Star rollovers top-right,
##   a spinning carousel disc in the centre, a kickback cannon in the left
##   outlane, slingshots, inlanes/outlanes, flippers and the shooter lane.

signal event(kind: String, data: Dictionary)

const WALL_H := 0.8
const GUIDE_H := 0.6
const HW := 0.05
const ARC_C := Vector2(0.4, -5.4)
const ARC_R := 5.46
const LANE_X := 5.455
const STOP_Z := 9.5
const BALL_START := Vector3(5.455, 0.26, 9.22)
const DRAIN_Z := 8.85
const FLIP_L := Vector2(-1.95, 7.7)
const FLIP_R := Vector2(1.95, 7.7)
const MOUTH_L := Vector2(-2.75, -1.55)
const MOUTH_W := 0.61
## The ramp trough starts this much wider and narrows over FUNNEL_LEN.
const FUNNEL := 1.6
const FUNNEL_LEN := 1.8
const SAUCER_POS := Vector2(-4.15, 0.55)
const STRIKER_POS := Vector2(0.1, -3.05)
const RING_Z := [1.5, 2.15, 2.8]
const STAR_POS := [Vector2(2.6, -6.5), Vector2(3.35, -6.95), Vector2(4.1, -6.4)]
const DISC_C := Vector2(0.0, 2.6)
const DISC_R := 1.55
const KICK_POS := Vector2(-4.68, 6.6)
const KICK_SPEED := 33.0

## Left ramp centre line (x, floor height, z). The right ramp is its mirror.
const RAMP_CTRL := [
	Vector3(-2.75, 0.004, -1.55), Vector3(-3.05, 0.08, -2.35), Vector3(-3.45, 0.4, -3.45),
	Vector3(-3.8, 0.78, -4.55), Vector3(-4.05, 1.08, -5.45), Vector3(-4.35, 1.22, -6.1),
	Vector3(-4.8, 1.25, -6.38), Vector3(-5.25, 1.23, -6.05), Vector3(-5.35, 1.2, -5.3),
	Vector3(-5.35, 1.12, -3.0), Vector3(-5.32, 1.05, -0.8), Vector3(-5.2, 0.98, 0.8),
	Vector3(-4.55, 0.86, 2.0), Vector3(-3.88, 0.7, 2.7), Vector3(-3.86, 0.64, 3.2),
]
const RAMP_SPLIT := 8 # control point where the plastic ramp becomes a wire rail

var flipper_l: Flipper
var flipper_r: Flipper
var plunger: Plunger
var bumpers: Array[Bumper] = []
var ducks: Array[DropTarget] = []
var balloons: Array[StandupTarget] = []
var balloon_up: Array[bool] = [true, true, true]
var striker: StandupTarget
var saucer: Saucer
var spinner: Spinner
var lamps: Dictionary = {}
var ramp_paths: Dictionary = {}
var ramp_frames: Dictionary = {}
var playfield_mat: ShaderMaterial
var closed_areas: Array[PackedVector2Array] = []
var rings: Array[StandupTarget] = []
var ring_done: Array[bool] = [false, false, false]
## Set by the game when the cannon in the left outlane is loaded.
var kickback_enabled := false
## Carousel disc speed in rad/s (the game speeds it up in modes).
var disc_speed := 2.4

var _gate_flap: Node3D
var _gate_swing := 0.0
var _balloon_vis: Array[Node3D] = []
var _coaster: Node3D
var _coaster_t := -1.0
var _coaster_side := "left"
var _ring_vis: Array[Node3D] = []
var _disc: Node3D
var _disc_last: Dictionary = {}
var _disc_inside: Dictionary = {}
var _cannon: Node3D
var _cannon_flash: MeshInstance3D
var _cannon_smoke: CPUParticles3D
var _cannon_kick := 0.0


func build() -> void:
	_build_floor()
	_build_walls()
	_build_lower(true)
	_build_lower(false)
	_build_top_lanes()
	_build_bumpers()
	_build_balloons()
	_build_striker()
	_build_ramp("left")
	_build_ramp("right")
	_build_saucer()
	_build_ducks()
	_build_gate()
	_build_drain()
	_build_ring_toss()
	_build_stars()
	_build_disc()
	_build_kickback()
	_build_inserts()
	_build_labels()
	_build_coaster()


# ---------------------------------------------------------------- helpers

func _static(name_: String, bounce: float = 0.4, friction: float = 0.15) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name_
	body.collision_layer = 1
	body.collision_mask = 0
	var pm := PhysicsMaterial.new()
	pm.bounce = bounce
	pm.friction = friction
	body.physics_material_override = pm
	add_child(body)
	return body


func _wall(name_: String, pts: PackedVector2Array, height: float, mat: Material, bounce: float = 0.4) -> StaticBody3D:
	var body := _static(name_, bounce)
	Geom.add_wall_collision(body, pts, HW, 0.0, height)
	var mi := MeshInstance3D.new()
	mi.mesh = Geom.wall_mesh(pts, HW, 0.0, height)
	mi.material_override = mat
	body.add_child(mi)
	# a gold cap on top reads nicely from the camera
	var cap := MeshInstance3D.new()
	cap.mesh = Geom.wall_mesh(pts, HW + 0.012, height, height + 0.03)
	cap.material_override = Mats.gold()
	body.add_child(cap)
	return body


func _post(p: Vector2, r: float = 0.1, h: float = 0.55) -> void:
	var body := _static("Post", 0.55, 0.2)
	body.position = Geom.v3(p)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = r
	cyl.height = h
	cs.shape = cyl
	cs.position.y = h * 0.5
	body.add_child(cs)
	var ring := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 0.22
	ring.mesh = cm
	ring.position.y = 0.24
	ring.material_override = Mats.rubber()
	body.add_child(ring)
	var core := MeshInstance3D.new()
	var km := CylinderMesh.new()
	km.top_radius = r * 0.6
	km.bottom_radius = r * 0.6
	km.height = h
	core.mesh = km
	core.position.y = h * 0.5
	core.material_override = Mats.chrome()
	body.add_child(core)
	var cap := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r * 0.75
	sm.height = r * 1.5
	cap.mesh = sm
	cap.position.y = h
	cap.material_override = Mats.gold()
	body.add_child(cap)


func _lamp(name_: String, shape: String, pos: Vector2, size: Vector2, col: Color, dir := Vector2(0, -1), text := "", text_size := 40) -> InsertLight:
	var l := InsertLight.new().setup(shape, size, col, text, text_size)
	l.position = Geom.v3(pos)
	l.rotation.y = Geom.yaw_toward(dir)
	add_child(l)
	lamps[name_] = l
	return l


func _mirror(p: Vector2) -> Vector2:
	return Vector2(-p.x, p.y)


func _mouth_corners(m: Vector2, t: Vector2, w: float) -> Array[Vector2]:
	var s := Vector2(t.y, -t.x)
	var a := m + s * w
	var b := m - s * w
	if absf(a.x) > absf(b.x):
		return [a, b]
	return [b, a]


func _mouth_dir(side: String) -> Vector2:
	var a: Vector3 = RAMP_CTRL[0]
	var b: Vector3 = RAMP_CTRL[1]
	var d := Vector2(b.x - a.x, b.z - a.z).normalized()
	return d if side == "left" else Vector2(-d.x, d.y)


# ---------------------------------------------------------------- floor & walls

func _build_floor() -> void:
	var body := _static("Floor", 0.12, 0.25)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(14.0, 1.0, 24.0)
	cs.shape = box
	cs.position = Vector3(0.4, -0.5, -0.4)
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(11.0, 21.6)
	mi.mesh = pm
	mi.position = Vector3(0.4, 0.0, -0.55)
	playfield_mat = ShaderMaterial.new()
	playfield_mat.shader = preload("res://shaders/playfield.gdshader")
	mi.material_override = playfield_mat
	add_child(mi)

	# striped "tent" panels mark the closed areas under the ramps
	var lc := _mouth_corners(MOUTH_L, _mouth_dir("left"), MOUTH_W + HW)
	var left_block := PackedVector2Array([
		Vector2(-5.06, -0.85), lc[0], lc[1], Vector2(-2.62, -5.0), Vector2(-4.2, -8.34), Vector2(-5.06, -5.4),
	])
	var rc := _mouth_corners(_mirror(MOUTH_L), _mouth_dir("right"), MOUTH_W + HW)
	var right_block := PackedVector2Array([
		Vector2(5.05, -0.85), Vector2(5.05, -5.0), Vector2(2.62, -4.4), rc[1], rc[0],
	])
	closed_areas = [left_block, right_block]
	for poly in closed_areas:
		var panel := MeshInstance3D.new()
		panel.mesh = Geom.polygon_mesh(poly, 0.003)
		panel.material_override = Mats.stripes(Color(0.55, 0.05, 0.12), Color(0.85, 0.75, 0.55), 3.0, 2)
		add_child(panel)


func _build_walls() -> void:
	var lc := _mouth_corners(MOUTH_L, _mouth_dir("left"), MOUTH_W + HW)
	var rc := _mouth_corners(_mirror(MOUTH_L), _mouth_dir("right"), MOUTH_W + HW)
	var theta_end := acos((-4.2 - ARC_C.x) / ARC_R)
	var outer := PackedVector2Array([Vector2(ARC_C.x + ARC_R, 10.3)])
	outer.append_array(Geom.arc(ARC_C, ARC_R, 0.0, theta_end, 64))
	outer.append(Vector2(-2.62, -5.0))
	outer.append(lc[1])
	_wall("OuterWall", outer, WALL_H, Mats.candy())
	_wall("LeftWall", PackedVector2Array([lc[0], Vector2(-5.06, -0.85), Vector2(-5.06, 10.3)]), WALL_H, Mats.candy())
	_wall("LaneWall", PackedVector2Array([Vector2(5.05, 9.9), Vector2(5.05, -5.0)]), WALL_H, Mats.candy())
	# the right ramp passes over this one, so it is only guide height
	_wall("RightDeflector", PackedVector2Array([Vector2(5.05, -5.0), Vector2(2.62, -4.4), rc[1]]), GUIDE_H, Mats.chrome())
	_wall("RightBlock", PackedVector2Array([rc[0], Vector2(5.05, -0.85)]), WALL_H, Mats.candy())
	_wall("BottomWall", PackedVector2Array([Vector2(-5.06, 10.3), Vector2(5.86, 10.3)]), WALL_H, Mats.chrome())


func _build_lower(left: bool) -> void:
	var sx := -1.0 if left else 1.0
	var m := func(p: Vector2) -> Vector2: return Vector2(p.x * -sx, p.y)
	# coordinates are written for the left side and mirrored for the right
	# filleted bends so a ball rolls smoothly from the inlane onto the flipper
	var sep_l := PackedVector2Array([Vector2(-4.3, 3.6)])
	sep_l.append_array(Geom.fillet(Vector2(-4.3, 3.6), Vector2(-4.3, 6.06), Vector2(-2.15, 7.31), 0.9, 8))
	sep_l.append(Vector2(-2.15, 7.31))
	var guide_l := PackedVector2Array([Vector2(-3.42, 3.75)])
	guide_l.append_array(Geom.fillet(Vector2(-3.42, 3.75), Vector2(-3.42, 5.763), Vector2(-2.3, 6.41), 0.2, 3))
	guide_l.append(Vector2(-2.3, 6.41))
	var sep := PackedVector2Array()
	for q in sep_l:
		sep.append(m.call(q))
	var guide := PackedVector2Array()
	for q in guide_l:
		guide.append(m.call(q))
	_wall("Separator", sep, GUIDE_H, Mats.chrome())
	_wall("InlaneGuide", guide, GUIDE_H, Mats.chrome())
	_post(m.call(Vector2(-4.3, 3.6)), 0.1, 0.55)
	_post(m.call(Vector2(-3.42, 3.75)), 0.1, 0.55)

	var sling := Slingshot.new()
	add_child(sling)
	sling.setup(left, m.call(Vector2(-3.2, 4.05)), m.call(Vector2(-3.2, 5.7)), m.call(Vector2(-2.42, 6.18)))
	sling.hit.connect(func(s: Slingshot) -> void: event.emit("sling", {"left": s.is_left}))

	var f := Flipper.new()
	f.name = "FlipperL" if left else "FlipperR"
	var pivot: Vector2 = FLIP_L if left else FLIP_R
	f.position = Geom.v3(pivot)
	add_child(f)
	f.setup(left)
	if left:
		flipper_l = f
	else:
		flipper_r = f

	var side := "left" if left else "right"
	var inl := Rollover.new()
	inl.setup("inlane", Vector3(0.5, 1.2, 0.4))
	inl.position = Geom.v3(m.call(Vector2(-3.86, 4.75)), 0.6)
	add_child(inl)
	inl.build_visual()
	inl.triggered.connect(func(b: Ball) -> void: _lane_switch("inlane", side, b))
	var outl := Rollover.new()
	outl.setup("outlane", Vector3(0.5, 1.2, 0.4))
	outl.position = Geom.v3(m.call(Vector2(-4.68, 4.75)), 0.6)
	add_child(outl)
	outl.build_visual()
	outl.triggered.connect(func(b: Ball) -> void: _lane_switch("outlane", side, b))
	if not left:
		plunger = Plunger.new().setup(LANE_X, STOP_Z)
		add_child(plunger)
		plunger.launched.connect(func(power: float) -> void: event.emit("launch", {"power": power}))


func _lane_switch(kind: String, side: String, ball: Ball) -> void:
	if ball.linear_velocity.z > -1.0:
		event.emit(kind, {"side": side})


func _build_top_lanes() -> void:
	for x in [-1.5, -0.5, 0.5, 1.5]:
		_wall("LaneGuide", PackedVector2Array([Vector2(x, -9.2), Vector2(x, -8.1)]), GUIDE_H, Mats.chrome())
		_post(Vector2(x, -9.2), 0.075, 0.55)
	for i in 3:
		var r := Rollover.new()
		r.setup("lane", Vector3(0.6, 0.5, 0.3))
		r.position = Vector3(-1.0 + i, 0.25, -8.6)
		add_child(r)
		r.build_visual(0.4)
		var idx := i
		r.triggered.connect(func(_b: Ball) -> void: event.emit("lane", {"index": idx}))


func _build_bumpers() -> void:
	var spots := [Vector2(-0.95, -6.55), Vector2(1.15, -6.55), Vector2(0.1, -4.95)]
	var cols := [Mats.PINK, Mats.SKY, Mats.RED]
	for i in 3:
		var b := Bumper.new()
		b.position = Geom.v3(spots[i])
		add_child(b)
		b.setup(i, cols[i])
		b.hit.connect(func(x: Bumper) -> void: event.emit("bumper", {"index": x.index}))
		bumpers.append(b)


func _build_balloons() -> void:
	var a := Vector2(5.05, -5.0)
	var b := Vector2(2.62, -4.4)
	var dir := (b - a).normalized()
	var n := Vector2(dir.y, -dir.x)
	if n.y > 0.0:
		n = -n
	var cols := [Mats.PINK, Mats.LIME, Mats.SKY]
	for i in 3:
		# mounted flush with the deflector so balls can roll past them
		var t := 0.27 + 0.2 * i
		var p := a.lerp(b, t)
		var tgt := StandupTarget.new()
		tgt.position = Geom.v3(p)
		add_child(tgt)
		tgt.setup(i, n, Vector3(0.44, 0.5, 0.1), 0.5)
		tgt.min_impact = 2.5
		var plate := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.42, 0.34, 0.08)
		plate.mesh = bm
		plate.position.y = 0.17
		plate.material_override = Mats.stripes(Mats.CREAM, cols[i], 5.0, 2)
		tgt.visual.add_child(plate)
		var balloon := Node3D.new()
		tgt.visual.add_child(balloon)
		var sph := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.17
		sm.height = 0.34
		sph.mesh = sm
		sph.scale = Vector3(1, 1.2, 1)
		sph.position.y = 0.62
		var bmat := Mats.glow(cols[i], 0.5)
		bmat.roughness = 0.15
		bmat.metallic_specular = 1.0
		sph.material_override = bmat
		balloon.add_child(sph)
		var knot := MeshInstance3D.new()
		var km := PrismMesh.new()
		km.size = Vector3(0.06, 0.06, 0.06)
		knot.mesh = km
		knot.position.y = 0.4
		knot.rotation.z = PI
		knot.material_override = bmat
		balloon.add_child(knot)
		_balloon_vis.append(balloon)
		tgt.hit.connect(func(x: StandupTarget, _ball: Ball) -> void: event.emit("balloon", {"index": x.index}))
		balloons.append(tgt)


func _build_striker() -> void:
	striker = StandupTarget.new()
	striker.position = Geom.v3(STRIKER_POS)
	add_child(striker)
	striker.setup(0, Vector2(0, 1), Vector3(0.9, 0.55, 0.16), 0.55)
	var pad := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.88, 0.5, 0.14)
	pad.mesh = bm
	pad.position.y = 0.25
	pad.material_override = Mats.stripes(Mats.RED, Mats.CREAM, 4.0, 2, 0.15)
	striker.visual.add_child(pad)
	var face := Mats.label3d("打我！", 40, Mats.GOLD, Color(0.2, 0, 0.05), 10, true)
	face.position = Vector3(0, 0.28, -0.08)
	face.rotation.y = PI
	striker.visual.add_child(face)
	for s in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.05
		cm.bottom_radius = 0.05
		cm.height = 0.6
		post.mesh = cm
		post.position = Vector3(s * 0.47, 0.3, 0)
		post.material_override = Mats.gold()
		striker.add_child(post)
	striker.hit.connect(_on_striker_hit)


func _on_striker_hit(_x: StandupTarget, ball: Ball) -> void:
	event.emit("striker", {"front": ball.global_position.z > STRIKER_POS.y})


# ---------------------------------------------------------------- ramps

func _build_ramp(side: String) -> void:
	var ctrl: Array = []
	for p in RAMP_CTRL:
		var v: Vector3 = p
		ctrl.append(v if side == "left" else Vector3(-v.x, v.y, v.z))
	var path := Geom.smooth_path(ctrl, 0.12)
	var frames := Geom.path_frames(path)
	var lengths := Geom.path_lengths(path)
	ramp_paths[side] = path
	ramp_frames[side] = frames

	var split := 0
	var split_target: Vector3 = ctrl[RAMP_SPLIT]
	var best := 1e9
	for i in path.size():
		var d := path[i].distance_to(split_target)
		if d < best:
			best = d
			split = i
	var last := path.size() - 1
	var widths := PackedFloat32Array()
	for i in path.size():
		widths.append(lerpf(FUNNEL, 1.0, smoothstep(0.0, FUNNEL_LEN, lengths[i])))

	# physics: one smooth trough for the whole ramp + rail
	var body := _static("Ramp_" + side, 0.1, 0.12)
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(Geom.sweep_faces(frames, Geom.trough_profile(), widths))
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)

	# visuals: translucent plastic ramp, then chrome wire rail
	var col := Mats.RED if side == "left" else Mats.SKY
	var pst := Geom.new_st()
	Geom.add_sweep(pst, frames, Geom.trough_profile(0.4, 0.2, 0.62), 0, split, widths)
	var plastic := Geom.instance(pst, Mats.plastic(side, col, 0.5), false)
	plastic.sorting_offset = 1.0
	body.add_child(plastic)
	var rim := Geom.new_st()
	for uv in [Vector2(-0.41, 0.62), Vector2(0.41, 0.62)]:
		Geom.add_tube(rim, Geom.offset_path(frames, uv, 0, split, widths), 0.035, 6)
	body.add_child(Geom.instance(rim, Mats.gold()))

	var wire := Geom.new_st()
	for uv in [Vector2(-0.13, 0.0), Vector2(0.13, 0.0), Vector2(-0.4, 0.3), Vector2(0.4, 0.3), Vector2(-0.4, 0.6), Vector2(0.4, 0.6)]:
		Geom.add_tube(wire, Geom.offset_path(frames, uv, split, last), 0.028, 6)
	var hoop_profile := Geom.trough_profile(0.43, 0.24, 0.62)
	var next_hoop := lengths[split]
	for i in range(split, last + 1):
		if lengths[i] >= next_hoop:
			next_hoop += 0.55
			var hoop := PackedVector3Array()
			for q in hoop_profile:
				hoop.append(frames[i] * Vector3(q.x, q.y - 0.03, 0.0))
			Geom.add_tube(wire, hoop, 0.022, 5)
	# supports: posts under the plastic part, brackets to the cabinet rail
	var sup := Geom.new_st()
	for frac in [0.35, 0.6, 0.85]:
		var i := int(split * frac)
		var p := path[i] + Vector3(0, -0.02, 0)
		if in_closed_area(Vector2(p.x, p.z)):
			Geom.add_cylinder_between(sup, p, Vector3(p.x, 0.0, p.z), 0.05, 8)
	var sx := -1.0 if side == "left" else 1.0
	var wall_x := 5.4 * sx if side == "left" else 6.2
	for i in range(split + 10, last - 20, 22):
		var p := path[i] + Vector3(0, -0.03, 0)
		if absf(p.x) > 5.0:
			Geom.add_cylinder_between(sup, p, Vector3(wall_x, 0.95, p.z), 0.035, 6)
	body.add_child(Geom.instance(wire, Mats.chrome()))
	body.add_child(Geom.instance(sup, Mats.chrome()))

	# ramp made: sensor right after the U-turn
	var made := Sensor.new().setup("ramp", Vector3(0.9, 0.7, 0.5), 1.0)
	made.transform = Transform3D(frames[split].basis, frames[split].origin + frames[split].basis.y * 0.3)
	add_child(made)
	made.triggered.connect(func(_b: Ball) -> void: _on_ramp_made(side))

	if side == "left":
		var fi := 0
		for i in path.size():
			if lengths[i] > 0.9:
				fi = i
				break
		spinner = Spinner.new().setup(0.76 * widths[fi] - 0.04)
		spinner.transform = Transform3D(frames[fi].basis, frames[fi].origin)
		add_child(spinner)
		spinner.spun.connect(func() -> void: event.emit("spinner", {}))


func _on_ramp_made(side: String) -> void:
	run_coaster(side)
	event.emit("ramp", {"side": side})


func _build_coaster() -> void:
	_coaster = Node3D.new()
	_coaster.visible = false
	add_child(_coaster)
	var car := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.34, 0.16, 0.5)
	car.mesh = bm
	car.position.y = 0.16
	car.material_override = Mats.solid("coaster", Mats.RED, 0.25, 0.4)
	_coaster.add_child(car)
	var trim := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(0.36, 0.04, 0.52)
	trim.mesh = tm
	trim.position.y = 0.25
	trim.material_override = Mats.gold()
	_coaster.add_child(trim)
	for s in [-1.0, 1.0]:
		var rider := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.06
		sm.height = 0.12
		rider.mesh = sm
		rider.position = Vector3(0, 0.32, s * 0.12)
		rider.material_override = Mats.solid("rider", Color(1.0, 0.8, 0.6), 0.6)
		_coaster.add_child(rider)


## Sends the little coaster car racing along a ramp (pure decoration).
func run_coaster(side: String) -> void:
	_coaster_side = side
	_coaster_t = 0.0
	_coaster.visible = true


func _process(delta: float) -> void:
	if _coaster_t >= 0.0:
		_coaster_t += delta / 1.4
		if _coaster_t >= 1.0:
			_coaster_t = -1.0
			_coaster.visible = false
		else:
			var frames: Array[Transform3D] = ramp_frames[_coaster_side]
			var i := clampi(int(_coaster_t * (frames.size() - 1)), 0, frames.size() - 1)
			var f := frames[i]
			_coaster.transform = Transform3D(f.basis, f.origin + f.basis.y * 0.62)
	if _cannon_kick > 0.0:
		_cannon_kick = maxf(0.0, _cannon_kick - delta * 3.0)
		_cannon.position.z = 9.65 + sin(_cannon_kick * PI) * 0.18
		_cannon_flash.scale = Vector3.ONE * (0.3 + _cannon_kick * 1.4)
		_cannon_flash.visible = _cannon_kick > 0.55
	for i in _ring_vis.size():
		if not ring_done[i]:
			_ring_vis[i].rotation.y += delta * 2.0
	if _gate_swing > 0.0:
		_gate_swing = maxf(0.0, _gate_swing - delta * 2.5)
		_gate_flap.rotation.x = -sin(_gate_swing * PI) * 1.2
	for b in get_tree().get_nodes_in_group("balls"):
		var ball := b as Ball
		if ball and ball.gate_open and ball.global_position.z < -4.7 and ball.global_position.z > -5.6:
			_gate_swing = 1.0


# ---------------------------------------------------------------- features

func _build_saucer() -> void:
	saucer = Saucer.new().setup(Vector2(0.42, 0.9))
	saucer.position = Geom.v3(SAUCER_POS)
	add_child(saucer)
	saucer.captured.connect(func(ball: Ball) -> void: event.emit("saucer", {"ball": ball}))
	# ticket booth awning on the wall behind the saucer
	var awning := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(1.3, 0.35, 0.5)
	awning.mesh = pm
	awning.position = Vector3(-4.35, 1.0, -1.05)
	awning.rotation.y = deg_to_rad(-17.0)
	awning.material_override = Mats.stripes(Mats.RED, Mats.CREAM, 7.0, 0, 0.2)
	add_child(awning)
	var sign := Mats.label3d("售票亭", 54, Mats.GOLD, Color(0.3, 0, 0.05), 10, true)
	sign.position = Vector3(-4.35, 0.92, -0.78)
	sign.rotation.y = deg_to_rad(-17.0)
	add_child(sign)


func _build_ducks() -> void:
	for i in 3:
		var d := DropTarget.new()
		d.position = Vector3(4.78, 0.0, -0.2 + i * 0.75)
		add_child(d)
		d.setup(i, Vector2(-1, 0))
		d.dropped.connect(func(x: DropTarget) -> void: event.emit("duck", {"index": x.index}))
		ducks.append(d)
	# backing wall plate the ducks sit in front of
	var plate := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.08, 0.7, 2.5)
	plate.mesh = bm
	plate.position = Vector3(4.99, 0.35, 0.55)
	plate.material_override = Mats.stripes(Color(0.1, 0.3, 0.8), Mats.CREAM, 6.0, 1, 0.1)
	add_child(plate)


func reset_ducks() -> void:
	for d in ducks:
		d.reset()


func set_balloon(i: int, up: bool) -> void:
	balloon_up[i] = up
	var v := _balloon_vis[i]
	var tw := create_tween()
	if up:
		tw.tween_property(v, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_property(v, "scale", Vector3(1.6, 1.6, 1.6), 0.06)
		tw.tween_property(v, "scale", Vector3(0.01, 0.01, 0.01), 0.05)


func _build_gate() -> void:
	var a := Vector2(5.08, -5.02)
	var b := Vector2(5.83, -5.3)
	var body := StaticBody3D.new()
	body.name = "OneWayGate"
	body.collision_layer = 4
	body.collision_mask = 0
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.2
	body.physics_material_override = pm
	add_child(body)
	Geom.add_wall_collision(body, PackedVector2Array([a, b]), 0.03, 0.0, 0.7)
	_gate_flap = Node3D.new()
	_gate_flap.position = Geom.v3((a + b) * 0.5, 0.62)
	_gate_flap.rotation.y = Geom.yaw_toward(Vector2((b - a).y, -(b - a).x))
	add_child(_gate_flap)
	var flap := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3((b - a).length(), 0.55, 0.03)
	flap.mesh = bm
	flap.position.y = -0.28
	flap.material_override = Mats.chrome()
	_gate_flap.add_child(flap)


func _build_drain() -> void:
	var drain := Sensor.new().setup("drain", Vector3(10.1, 1.2, 1.5), 0.5)
	drain.position = Vector3(0.0, 0.5, DRAIN_Z + 0.75)
	add_child(drain)
	drain.triggered.connect(func(ball: Ball) -> void: event.emit("drain", {"ball": ball}))


func _build_inserts() -> void:
	var letters := ["F", "U", "N"]
	for i in 3:
		_lamp("lane%d" % i, "circle", Vector2(-1.0 + i, -8.95), Vector2(0.42, 0.42), Mats.GOLD, Vector2(0, -1), letters[i], 52)
	for side in ["left", "right"]:
		var m := MOUTH_L if side == "left" else _mirror(MOUTH_L)
		var t := _mouth_dir(side)
		var col := Mats.ORANGE if side == "left" else Mats.TEAL
		_lamp("ramp_" + side, "arrow", m - t * 1.05, Vector2(0.55, 0.85), col, t)
		_lamp("jackpot_" + side, "rect", m - t * 1.85, Vector2(0.8, 0.34), Mats.PINK, t, "大奖", 30)
	for i in 5:
		_lamp("striker%d" % i, "circle", Vector2(STRIKER_POS.x, -0.7 - i * 0.4), Vector2(0.28, 0.28), Mats.RED.lerp(Mats.GOLD, i / 4.0))
	for i in 3:
		_lamp("duck%d" % i, "tri", Vector2(4.25, -0.2 + i * 0.75), Vector2(0.3, 0.3), Mats.GOLD, Vector2(1, 0))
	for i in 3:
		_lamp("tix%d" % i, "rect", Vector2(-3.7 + i * 0.32, 1.05 + i * 0.36), Vector2(0.42, 0.26), Mats.LIME, Vector2(0.42, -0.9), "票", 26)
	_lamp("mb", "star", Vector2(-3.55, 0.05), Vector2(0.62, 0.62), Mats.PINK, Vector2(0, -1), "多球", 20)
	_lamp("eb", "circle", Vector2(-3.05, 0.6), Vector2(0.44, 0.44), Mats.ORANGE, Vector2(0, -1), "额外", 22)
	_lamp("wheel", "circle", Vector2(-3.0, -0.14), Vector2(0.44, 0.44), Mats.SKY, Vector2(0, -1), "转盘", 22)
	for i in 3:
		_lamp("ring%d" % i, "circle", Vector2(-4.55, RING_Z[i]), Vector2(0.26, 0.26), Mats.PINK)
		_lamp("star%d" % i, "star", STAR_POS[i], Vector2(0.5, 0.5), Mats.GOLD)
	_lamp("kickback", "arrow", Vector2(KICK_POS.x, 5.9), Vector2(0.36, 0.56), Mats.ORANGE, Vector2(0, -1), "炮", 22)
	_lamp("wizard", "rect", Vector2(0, 0.66), Vector2(1.5, 0.34), Mats.PURPLE, Vector2(0, -1), "狂欢之夜", 30)
	var mults := ["2X", "3X", "4X", "5X"]
	for i in 4:
		_lamp("bonus%d" % (i + 2), "rect", Vector2(-0.9 + i * 0.6, 5.5), Vector2(0.48, 0.32), Mats.SKY, Vector2(0, -1), mults[i], 30)
	var stamp_txt := ["钟", "鸭", "球", "圈", "道"]
	for i in 5:
		_lamp("stamp%d" % i, "circle", Vector2(-1.0 + i * 0.5, 6.42), Vector2(0.36, 0.36), Mats.LIME, Vector2(0, -1), stamp_txt[i], 26)
	_lamp("double", "rect", Vector2(0, 7.22), Vector2(0.7, 0.28), Mats.GOLD, Vector2(0, -1), "双倍", 22)
	_lamp("shoot_again", "rect", Vector2(0, 7.95), Vector2(0.95, 0.3), Mats.RED, Vector2(0, -1), "再来一球", 24)
	for side in ["left", "right"]:
		var sx := -1.0 if side == "left" else 1.0
		_lamp("inlane_" + side, "circle", Vector2(3.86 * sx, 5.35), Vector2(0.26, 0.26), Mats.TEAL)
		_lamp("outlane_" + side, "circle", Vector2(4.68 * sx, 5.35), Vector2(0.26, 0.26), Mats.RED)


func _build_labels() -> void:
	add_child(Mats.floor_label("欢迎光临！", 40, Color(2.0, 1.5, 0.5), Vector2(0, 4.5), 0.0, 10, true))
	add_child(Mats.floor_label("奖励倍数", 22, Mats.CREAM, Vector2(0, 5.12), 0.0, 6))
	add_child(Mats.floor_label("游园护照", 22, Mats.CREAM, Vector2(0, 6.03), 0.0, 6))
	add_child(Mats.floor_label("大力士", 30, Mats.CREAM, Vector2(STRIKER_POS.x, -0.3), 0.0, 8, true))
	add_child(Mats.floor_label("打鸭子", 32, Mats.CREAM, Vector2(4.2, 2.05), 0.0, 8, true))
	add_child(Mats.floor_label("套圈", 30, Mats.CREAM, Vector2(-4.5, 3.28), 0.0, 8, true))
	add_child(Mats.floor_label("幸运星", 30, Mats.CREAM, Vector2(3.35, -7.6), 0.0, 8, true))
	var tl := _mouth_dir("left")
	var tr := _mouth_dir("right")
	add_child(Mats.floor_label("过山车", 34, Mats.CREAM, MOUTH_L - tl * 2.4, Geom.yaw_toward(tl), 8, true))
	add_child(Mats.floor_label("摩天轮", 34, Mats.CREAM, _mirror(MOUTH_L) - tr * 2.4, Geom.yaw_toward(tr), 8, true))
	add_child(Mats.floor_label("发射", 34, Mats.GOLD, Vector2(LANE_X, 6.5), 0.0, 8, true))


# ---------------------------------------------------------------- new midway games

## Ring Toss: three targets flush in the left wall. Each has a bottle on the
## cabinet rail; hitting the target drops a ring over its bottle.
func _build_ring_toss() -> void:
	var cols := [Mats.PINK, Mats.GOLD, Mats.SKY]
	var glass := Mats.plastic("bottle", Color(0.2, 0.85, 0.45), 0.7)
	for i in 3:
		var z: float = RING_Z[i]
		var tgt := StandupTarget.new()
		tgt.position = Vector3(-5.06, 0.0, z)
		add_child(tgt)
		tgt.setup(i, Vector2(1, 0), Vector3(0.5, 0.5, 0.1), 0.5)
		tgt.min_impact = 2.5
		var plate := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.48, 0.4, 0.04)
		plate.mesh = bm
		plate.position = Vector3(0, 0.22, -0.055)
		plate.material_override = Mats.stripes(Mats.CREAM, cols[i], 4.0, 2, 0.2)
		tgt.visual.add_child(plate)
		tgt.hit.connect(func(x: StandupTarget, _b: Ball) -> void: event.emit("ring", {"index": x.index}))
		rings.append(tgt)
		# bottle on the cabinet rail
		var base := Vector3(-5.36, 0.995, z)
		var body := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.07
		cm.bottom_radius = 0.085
		cm.height = 0.26
		body.mesh = cm
		body.position = base + Vector3(0, 0.13, 0)
		body.material_override = glass
		add_child(body)
		var neck := MeshInstance3D.new()
		var nm := CylinderMesh.new()
		nm.top_radius = 0.03
		nm.bottom_radius = 0.045
		nm.height = 0.16
		neck.mesh = nm
		neck.position = base + Vector3(0, 0.34, 0)
		neck.material_override = glass
		add_child(neck)
		var cap := MeshInstance3D.new()
		var capm := CylinderMesh.new()
		capm.top_radius = 0.034
		capm.bottom_radius = 0.034
		capm.height = 0.03
		cap.mesh = capm
		cap.position = base + Vector3(0, 0.43, 0)
		cap.material_override = Mats.solid("bottle_cap", Mats.RED, 0.3, 0.5)
		add_child(cap)
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.07
		tm.outer_radius = 0.11
		ring.mesh = tm
		ring.material_override = Mats.glow(cols[i], 1.2)
		var holder := Node3D.new()
		holder.position = base + Vector3(0, 0.62, 0)
		holder.add_child(ring)
		add_child(holder)
		_ring_vis.append(holder)


func set_ring(i: int, done: bool) -> void:
	ring_done[i] = done
	var v := _ring_vis[i]
	var y := 0.995 + (0.3 if done else 0.62)
	var tw := create_tween()
	if done:
		tw.tween_property(v, "position:y", y, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_property(v, "position:y", y, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func reset_rings() -> void:
	for i in 3:
		if ring_done[i]:
			set_ring(i, false)


## Lucky Stars: three star rollovers in the top-right pocket.
func _build_stars() -> void:
	for i in 3:
		var r := Rollover.new()
		r.setup("star", Vector3(0.5, 0.5, 0.5), 0.8)
		r.position = Geom.v3(STAR_POS[i], 0.25)
		add_child(r)
		r.build_visual(0.36)
		var idx := i
		r.triggered.connect(func(_b: Ball) -> void: event.emit("star", {"index": idx}))


## Carousel: a spinning disc set into the floor. A ball rolling over it is
## dragged around and flung off at an angle.
func _build_disc() -> void:
	_disc = Node3D.new()
	_disc.position = Geom.v3(DISC_C)
	add_child(_disc)
	var plate := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = DISC_R
	cm.bottom_radius = DISC_R
	cm.height = 0.01
	cm.radial_segments = 48
	plate.mesh = cm
	plate.position.y = 0.004
	plate.material_override = Mats.stripes(Color(0.75, 0.06, 0.14), Color(1.0, 0.75, 0.25), 12.0, 0, 0.12)
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_disc.add_child(plate)
	var hub := MeshInstance3D.new()
	hub.mesh = Geom.polygon_mesh(Geom.star_poly(0.42, 0.2), 0.0)
	hub.position.y = 0.012
	hub.material_override = Mats.glow(Mats.GOLD, 1.0)
	_disc.add_child(hub)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = DISC_R - 0.02
	tm.outer_radius = DISC_R + 0.08
	tm.rings = 64
	ring.mesh = tm
	ring.scale = Vector3(1, 0.12, 1)
	ring.material_override = Mats.gold()
	add_child(ring)
	ring.position = Geom.v3(DISC_C, 0.005)
	var title := Mats.label3d("旋转木马", 76, Color(2.2, 2.0, 2.2), Color(0.35, 0.0, 0.12), 16, true)
	title.rotation.x = -PI * 0.5
	title.position = Vector3(0, 0.016, 0.62)
	_disc.add_child(title)
	var title2 := Mats.label3d("狂欢派对", 76, Color(2.2, 1.6, 0.4), Color(0.35, 0.0, 0.12), 16, true)
	title2.rotation = Vector3(-PI * 0.5, PI, 0)
	title2.position = Vector3(0, 0.016, -0.62)
	_disc.add_child(title2)
	var pts := PackedVector3Array()
	for i in 24:
		var a := TAU * float(i) / 24.0
		pts.append(Vector3(cos(a) * (DISC_R - 0.12), 0.0, sin(a) * (DISC_R - 0.12)))
	var bulbs := BulbChain.new().setup(pts, 0.05, Color(1.0, 0.9, 0.5), Color(1.0, 0.3, 0.7), 8.0, 4.0)
	bulbs.scale = Vector3(1, 0.3, 1)
	_disc.add_child(bulbs)


func _physics_process(delta: float) -> void:
	_disc.rotation.y += disc_speed * delta
	var now := float(Engine.get_physics_frames()) / float(Engine.physics_ticks_per_second)
	for b in get_tree().get_nodes_in_group("balls"):
		var ball := b as Ball
		if ball == null or ball.captured:
			continue
		var p := ball.global_position
		var r := Vector2(p.x - DISC_C.x, p.z - DISC_C.y)
		var d := r.length()
		var id := ball.get_instance_id()
		var inside := d < DISC_R and p.y < 0.4
		if inside:
			# friction between disc and ball: pull the ball toward the disc's
			# surface speed along the direction of rotation
			# (bounded, and weaker for fast balls so it carries slow rollers
			# without spoiling flipper shots that cross it)
			var t := Vector3(r.y, 0.0, -r.x).normalized()
			var vt := ball.linear_velocity.dot(t)
			var pull := clampf((disc_speed * d - vt) * 2.6, -10.0, 10.0)
			ball.apply_central_force(t * pull / (1.0 + ball.linear_velocity.length() * 0.08))
			if not _disc_inside.get(id, false) and now - float(_disc_last.get(id, -9.0)) > 1.2:
				_disc_last[id] = now
				event.emit("carousel", {})
		_disc_inside[id] = inside


## Kickback: when loaded, a ball dropping into the left outlane is fired back
## up by the cannon.
func _build_kickback() -> void:
	var sensor := Sensor.new().setup("kickback", Vector3(0.62, 1.0, 0.5), 0.5)
	sensor.position = Geom.v3(KICK_POS, 0.5)
	add_child(sensor)
	sensor.triggered.connect(_on_kickback)
	# the cannon sits on the apron and points up the outlane
	_cannon = Node3D.new()
	_cannon.position = Vector3(KICK_POS.x + 0.05, 0.78, 9.65)
	add_child(_cannon)
	var barrel := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.13
	bm.bottom_radius = 0.19
	bm.height = 0.95
	barrel.mesh = bm
	barrel.rotation.x = PI * 0.5 - 0.18
	barrel.material_override = Mats.solid("cannon", Color(0.75, 0.08, 0.12), 0.25, 0.15)
	_cannon.add_child(barrel)
	for k in 3:
		var band := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.13 + k * 0.025
		tm.outer_radius = 0.17 + k * 0.025
		band.mesh = tm
		band.rotation.x = PI * 0.5 - 0.18
		band.position = Vector3(0, 0.07 - k * 0.07, -0.4 + k * 0.38)
		band.material_override = Mats.gold()
		_cannon.add_child(band)
	for sx in [-1.0, 1.0]:
		var wheel := MeshInstance3D.new()
		var wm := CylinderMesh.new()
		wm.top_radius = 0.17
		wm.bottom_radius = 0.17
		wm.height = 0.06
		wheel.mesh = wm
		wheel.rotation.z = PI * 0.5
		wheel.position = Vector3(sx * 0.2, -0.1, 0.12)
		wheel.material_override = Mats.wood()
		_cannon.add_child(wheel)
	_cannon_flash = MeshInstance3D.new()
	var fm := SphereMesh.new()
	fm.radius = 0.2
	fm.height = 0.4
	_cannon_flash.mesh = fm
	_cannon_flash.position = Vector3(0, 0.1, -0.55)
	_cannon_flash.material_override = Mats.glow(Color(1.0, 0.7, 0.2), 6.0)
	_cannon_flash.visible = false
	_cannon.add_child(_cannon_flash)
	_cannon_smoke = CPUParticles3D.new()
	_cannon_smoke.emitting = false
	_cannon_smoke.one_shot = true
	_cannon_smoke.amount = 26
	_cannon_smoke.lifetime = 1.1
	_cannon_smoke.explosiveness = 0.9
	var sm := SphereMesh.new()
	sm.radius = 0.09
	sm.height = 0.18
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.85, 0.85, 0.9, 0.6)
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.material = smat
	_cannon_smoke.mesh = sm
	_cannon_smoke.direction = Vector3(0, 0.4, -1)
	_cannon_smoke.spread = 30.0
	_cannon_smoke.initial_velocity_min = 1.0
	_cannon_smoke.initial_velocity_max = 3.0
	_cannon_smoke.gravity = Vector3(0, 0.8, 0)
	_cannon_smoke.scale_amount_min = 0.6
	_cannon_smoke.scale_amount_max = 2.2
	_cannon_smoke.position = Vector3(0, 0.1, -0.55)
	_cannon.add_child(_cannon_smoke)


func _on_kickback(ball: Ball) -> void:
	if not kickback_enabled or ball.linear_velocity.z < 0.0:
		return
	kickback_enabled = false
	var dx := KICK_POS.x - ball.global_position.x
	ball.linear_velocity = Vector3(dx * 5.0, 0.0, -KICK_SPEED)
	_cannon_kick = 1.0
	_cannon_flash.visible = true
	_cannon_smoke.restart()
	event.emit("kickback", {})


## True inside the walled-off areas under the ramps, where a ball that fell
## off a ramp would be stuck forever.
func in_closed_area(p: Vector2) -> bool:
	for poly in closed_areas:
		if Geometry2D.is_point_in_polygon(p, poly):
			return true
	return false


func set_lamp(name_: String, state: int) -> void:
	var l: InsertLight = lamps.get(name_)
	if l:
		l.state = state


func flash_lamp(name_: String, seconds: float = 1.0) -> void:
	var l: InsertLight = lamps.get(name_)
	if l:
		l.flash(seconds)
