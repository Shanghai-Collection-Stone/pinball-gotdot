class_name Midway
extends Node3D
## The carnival midway around the pinball machine: food stalls, string
## lights, a big top, a giant Ferris wheel, a carousel, a roller coaster,
## searchlights and fireworks. Pure scenery.

const GROUND_Y := -4.05

var party := 0.0
var bulbs: Array[BulbChain] = []
var _wheel: Node3D
var _wheel_cars: Array[Node3D] = []
var _carousel: Node3D
var _horses: Array[Node3D] = []
var _beams: Array[Node3D] = []
var _fireworks: Array[CPUParticles3D] = []
var _fw_next := 1.0
var _fw_i := 0
var _t := 0.0


func build() -> void:
	_build_ground()
	_build_booths()
	_build_string_lights()
	_build_big_top()
	_build_giant_wheel()
	_build_carousel()
	_build_coaster()
	_build_searchlights()
	_build_fireworks()


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func _sphere(parent: Node3D, r: float, pos: Vector3, mat: Material, scale_v := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 16
	sm.rings = 8
	mi.mesh = sm
	mi.position = pos
	mi.scale = scale_v
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func _cyl(parent: Node3D, r_top: float, r_bot: float, h: float, pos: Vector3, mat: Material, segs := 16) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = segs
	mi.mesh = cm
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi


# ---------------------------------------------------------------- ground

func _build_ground() -> void:
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(260, 260)
	ground.mesh = pm
	ground.position = Vector3(0, GROUND_Y, 0)
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/ground.gdshader")
	ground.material_override = m
	add_child(ground)


# ---------------------------------------------------------------- food stalls

func _build_booths() -> void:
	var specs := [
		[Vector3(-12.5, GROUND_Y, -9.0), 1.0, "爆米花", Mats.RED, "popcorn"],
		[Vector3(-12.8, GROUND_Y, -0.5), 1.0, "棉花糖", Mats.PINK, "cotton"],
		[Vector3(-12.5, GROUND_Y, 8.0), 1.0, "套圈游戏", Mats.PURPLE, "prize"],
		[Vector3(13.3, GROUND_Y, -9.0), -1.0, "热狗", Mats.ORANGE, "hotdog"],
		[Vector3(13.6, GROUND_Y, -0.5), -1.0, "射击游戏", Mats.SKY, "shooting"],
		[Vector3(13.3, GROUND_Y, 8.0), -1.0, "冰淇淋", Mats.TEAL, "icecream"],
	]
	for sp in specs:
		_booth(sp[0], float(sp[1]), sp[2], sp[3], sp[4])


## A striped carnival stall. Its front faces the machine, turned a little
## toward the player so the sign reads from the camera.
func _booth(pos: Vector3, side: float, title: String, col: Color, kind: String) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = deg_to_rad(62.0) * side
	add_child(root)
	_box(root, Vector3(3.4, 0.25, 2.6), Vector3(0, 0.125, 0), Mats.wood())
	_box(root, Vector3(3.1, 1.1, 0.5), Vector3(0, 0.8, 0.9), Mats.stripes(col, Mats.CREAM, 3.0, 1, 0.08))
	_box(root, Vector3(3.2, 0.08, 0.66), Vector3(0, 1.39, 0.9), Mats.gold())
	_box(root, Vector3(3.1, 2.7, 0.12), Vector3(0, 1.6, -1.05), Mats.solid("booth_back_" + kind, col.darkened(0.5), 0.6))
	for sx in [-1.5, 1.5]:
		for sz in [-1.05, 1.1]:
			_cyl(root, 0.06, 0.06, 2.95, Vector3(sx, 1.72, sz), Mats.gold(), 8)
	var roof := _cyl(root, 0.0, 2.45, 1.3, Vector3(0, 3.85, 0.05), Mats.stripes(col, Mats.CREAM, 8.0, 0, 0.12), 4)
	roof.rotation.y = PI * 0.25
	_sphere(root, 0.16, Vector3(0, 4.6, 0.05), Mats.gold())
	var flag := MeshInstance3D.new()
	var fp := PrismMesh.new()
	fp.size = Vector3(0.5, 0.3, 0.02)
	flag.mesh = fp
	flag.rotation.z = -PI * 0.5
	flag.position = Vector3(0.25, 4.95, 0.05)
	flag.material_override = Mats.solid("booth_flag", Mats.GOLD, 0.4, 0.4)
	root.add_child(flag)
	_cyl(root, 0.02, 0.02, 0.7, Vector3(0, 4.85, 0.05), Mats.gold(), 6)
	# sign with bulbs, standing in front of the roof and tilted up so it
	# reads from the high camera
	var sign := Node3D.new()
	sign.position = Vector3(0, 3.75, 1.95)
	sign.rotation.x = -0.55
	root.add_child(sign)
	_box(sign, Vector3(2.7, 0.95, 0.12), Vector3.ZERO, Mats.solid("booth_sign", Color(0.1, 0.02, 0.15), 0.4))
	var l := Mats.label3d(title, 150, Color(2.4, 1.8, 0.6), Color(0.4, 0.0, 0.1), 24, true)
	l.position = Vector3(0, 0, 0.08)
	sign.add_child(l)
	var pts := PackedVector3Array()
	var x := -1.28
	while x <= 1.29:
		pts.append(Vector3(x, 0.52, 0.07))
		pts.append(Vector3(x, -0.52, 0.07))
		x += 0.32
	var chain := BulbChain.new().setup(pts, 0.065, Color(1.0, 0.85, 0.4), col.lightened(0.3), 6.0, 4.5)
	sign.add_child(chain)
	_cyl(root, 0.05, 0.05, 1.2, Vector3(-1.1, 3.3, 1.85), Mats.gold(), 6)
	_cyl(root, 0.05, 0.05, 1.2, Vector3(1.1, 3.3, 1.85), Mats.gold(), 6)
	bulbs.append(chain)
	_goods(root, kind)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 2.3, 0.9)
	light.light_color = Color(1.0, 0.78, 0.5)
	light.light_energy = 1.6
	light.omni_range = 7.0
	root.add_child(light)


func _goods(root: Node3D, kind: String) -> void:
	match kind:
		"popcorn":
			var corn := Mats.solid("popcorn_big", Color(1.0, 0.92, 0.55), 0.8, 0.25)
			for k in 3:
				var bx := -0.9 + k * 0.9
				_box(root, Vector3(0.4, 0.5, 0.35), Vector3(bx, 1.68, 0.9), Mats.stripes(Mats.RED, Mats.CREAM, 6.0, 0, 0.1))
				for j in 7:
					_sphere(root, 0.09, Vector3(bx + randf_range(-0.15, 0.15), 1.98 + randf_range(0, 0.12), 0.9 + randf_range(-0.12, 0.12)), corn)
		"cotton":
			var cols := [Mats.PINK, Mats.SKY, Mats.PINK, Color(0.85, 0.6, 1.0)]
			for k in 4:
				var cx := -1.05 + k * 0.7
				_cyl(root, 0.02, 0.02, 0.6, Vector3(cx, 1.75, 0.9), Mats.solid("stick", Color(0.95, 0.9, 0.8), 0.6), 6)
				_sphere(root, 0.26, Vector3(cx, 2.15, 0.9), Mats.solid("cotton%d" % k, cols[k], 0.95, 0.35), Vector3(1, 1.15, 1))
		"hotdog":
			for k in 3:
				var hx := -0.9 + k * 0.9
				_sphere(root, 0.1, Vector3(hx, 1.53, 0.9), Mats.solid("bun", Color(0.95, 0.7, 0.35), 0.8), Vector3(3.2, 0.8, 1.0))
				_sphere(root, 0.07, Vector3(hx, 1.6, 0.9), Mats.solid("sausage", Color(0.75, 0.2, 0.1), 0.4), Vector3(4.2, 1, 1))
			_cyl(root, 0.08, 0.08, 0.3, Vector3(1.3, 1.6, 0.8), Mats.solid("mustard", Color(1.0, 0.85, 0.1), 0.3), 10)
			_cyl(root, 0.08, 0.08, 0.3, Vector3(1.1, 1.6, 0.8), Mats.solid("ketchup", Mats.RED, 0.3), 10)
		"shooting":
			for k in 5:
				var dx := -1.2 + k * 0.6
				_sphere(root, 0.15, Vector3(dx, 2.0, -0.95), Mats.solid("duck_big", Color(1.0, 0.85, 0.1), 0.4, 0.2), Vector3(1.3, 0.9, 0.6))
				_sphere(root, 0.09, Vector3(dx - 0.15, 2.18, -0.95), Mats.solid("duck_big", Color(1.0, 0.85, 0.1), 0.4, 0.2))
			for k in 3:
				var tx := -0.9 + k * 0.9
				for ring in 3:
					var c := _cyl(root, 0.32 - ring * 0.1, 0.32 - ring * 0.1, 0.03, Vector3(tx, 1.2 + 0.0, -0.98 + ring * 0.015), Mats.solid("bull%d" % (ring % 2), Mats.RED if ring % 2 == 0 else Mats.CREAM, 0.5), 20)
					c.rotation.x = PI * 0.5
					c.position.y = 1.15
		"icecream":
			var scoops := [Mats.PINK, Mats.CREAM, Color(0.5, 0.3, 0.15), Mats.LIME]
			for k in 4:
				var ix := -1.05 + k * 0.7
				var cone := _cyl(root, 0.14, 0.0, 0.4, Vector3(ix, 1.65, 0.9), Mats.solid("cone", Color(0.9, 0.65, 0.3), 0.8), 10)
				cone.rotation.x = 0.0
				_sphere(root, 0.15, Vector3(ix, 1.92, 0.9), Mats.solid("scoop%d" % k, scoops[k], 0.7, 0.2))
		_:
			# prize stall: teddy bears and balloons
			var bear := Mats.solid("bear", Color(0.6, 0.38, 0.2), 0.9)
			for k in 4:
				var bx2 := -1.1 + k * 0.73
				_sphere(root, 0.22, Vector3(bx2, 1.9, -0.85), bear)
				_sphere(root, 0.16, Vector3(bx2, 2.25, -0.85), bear)
				_sphere(root, 0.06, Vector3(bx2 - 0.12, 2.38, -0.85), bear)
				_sphere(root, 0.06, Vector3(bx2 + 0.12, 2.38, -0.85), bear)
			for k in 5:
				var col: Color = [Mats.RED, Mats.GOLD, Mats.SKY, Mats.PINK, Mats.LIME][k]
				_sphere(root, 0.25, Vector3(-1.2 + k * 0.6, 4.2 + randf() * 0.4, 1.3), Mats.glow(col, 0.4), Vector3(1, 1.2, 1))


# ---------------------------------------------------------------- string lights

func _build_string_lights() -> void:
	var poles_l := [Vector3(-8.6, GROUND_Y, -14.0), Vector3(-8.6, GROUND_Y, -5.0), Vector3(-8.6, GROUND_Y, 4.0), Vector3(-8.6, GROUND_Y, 13.0)]
	var poles_r := [Vector3(9.4, GROUND_Y, -14.0), Vector3(9.4, GROUND_Y, -5.0), Vector3(9.4, GROUND_Y, 4.0), Vector3(9.4, GROUND_Y, 13.0)]
	var st := Geom.new_st()
	var tops: Array[Vector3] = []
	for p in poles_l + poles_r:
		var pos: Vector3 = p
		var h := 12.5 if pos.z < -10.0 else 6.6
		Geom.add_cylinder_between(st, pos, pos + Vector3(0, h, 0), 0.09, 8)
		tops.append(pos + Vector3(0, h, 0))
		_sphere(self, 0.22, pos + Vector3(0, h + 0.15, 0), Mats.glow(Color(1.0, 0.85, 0.5), 3.0))
	add_child(Geom.instance(st, Mats.gold()))
	var cord := Geom.new_st()
	var pts := PackedVector3Array()
	var pairs := [[0, 1], [1, 2], [2, 3], [4, 5], [5, 6], [6, 7], [0, 4]]
	for pr in pairs:
		var a: Vector3 = tops[pr[0]]
		var b: Vector3 = tops[pr[1]]
		var sag := 1.4 if pr[0] == 0 and pr[1] == 4 else 0.9
		var line := PackedVector3Array()
		var n := int(a.distance_to(b) / 0.55)
		for i in n + 1:
			var t := float(i) / float(n)
			var q := a.lerp(b, t) + Vector3(0, -sag * 4.0 * t * (1.0 - t), 0)
			line.append(q)
			if i > 0 and i < n:
				pts.append(q + Vector3(0, -0.12, 0))
		Geom.add_tube(cord, line, 0.02, 4)
	add_child(Geom.instance(cord, Mats.dark(), false))
	var chain := BulbChain.new().setup(pts, 0.1, Color(1.0, 0.82, 0.45), Color(1.0, 0.35, 0.45), 3.0, 5.0)
	chain.set_mode(BulbChain.SPARKLE)
	add_child(chain)
	bulbs.append(chain)


# ---------------------------------------------------------------- big attractions

func _build_big_top() -> void:
	var root := Node3D.new()
	root.position = Vector3(0.4, GROUND_Y, -40.0)
	add_child(root)
	_cyl(root, 11.0, 11.0, 5.0, Vector3(0, 2.5, 0), Mats.stripes(Mats.RED, Mats.CREAM, 28.0, 0, 0.1), 48)
	_cyl(root, 0.4, 12.0, 9.0, Vector3(0, 9.5, 0), Mats.stripes(Mats.RED, Mats.CREAM, 28.0, 0, 0.1), 48)
	_cyl(root, 0.2, 0.2, 4.0, Vector3(0, 15.5, 0), Mats.gold(), 8)
	var flag := MeshInstance3D.new()
	var fp := PrismMesh.new()
	fp.size = Vector3(1.6, 1.0, 0.05)
	flag.mesh = fp
	flag.rotation.z = -PI * 0.5
	flag.position = Vector3(0.8, 17.0, 0)
	flag.material_override = Mats.solid("bigtop_flag", Mats.GOLD, 0.4, 0.6)
	root.add_child(flag)
	_box(root, Vector3(5.0, 4.2, 0.3), Vector3(0, 2.1, 10.9), Mats.solid("bigtop_door", Color(0.1, 0.02, 0.1), 0.6))
	var l := Mats.label3d("马戏团", 600, Color(3.0, 2.2, 0.7), Color(0.5, 0.0, 0.1), 60, true)
	l.position = Vector3(0, 6.2, 11.2)
	root.add_child(l)
	var pts := PackedVector3Array()
	for i in 64:
		var a := TAU * float(i) / 64.0
		pts.append(Vector3(cos(a) * 11.25, 5.0, sin(a) * 11.25))
	var chain := BulbChain.new().setup(pts, 0.22, Color(1.0, 0.85, 0.4), Color(1.0, 0.3, 0.4), 8.0, 5.0)
	root.add_child(chain)
	bulbs.append(chain)
	for k in 12:
		var a := TAU * float(k) / 12.0
		var pennant := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(0.9, 1.3, 0.03)
		pennant.mesh = pm
		pennant.position = Vector3(cos(a) * 11.4, 4.2, sin(a) * 11.4)
		pennant.rotation = Vector3(0, -a + PI * 0.5, PI)
		pennant.material_override = Mats.solid("pennant%d" % (k % 3), [Mats.GOLD, Mats.SKY, Mats.PINK][k % 3], 0.5, 0.3)
		root.add_child(pennant)


func _build_giant_wheel() -> void:
	var root := Node3D.new()
	root.position = Vector3(27.0, GROUND_Y, -30.0)
	root.rotation.y = -0.55
	add_child(root)
	var r := 11.0
	var hub_y := 13.0
	var st := Geom.new_st()
	for s in [-1.0, 1.0]:
		for zz in [-1.2, 1.2]:
			Geom.add_cylinder_between(st, Vector3(s * 7.0, 0, zz), Vector3(0, hub_y, zz * 0.4), 0.3, 8)
	root.add_child(Geom.instance(st, Mats.chrome()))
	_wheel = Node3D.new()
	_wheel.position = Vector3(0, hub_y, 0)
	root.add_child(_wheel)
	var rim := Geom.new_st()
	for zoff in [-0.6, 0.6]:
		var ring := PackedVector3Array()
		for i in 97:
			var a := TAU * float(i) / 96.0
			ring.append(Vector3(cos(a) * r, sin(a) * r, zoff))
		Geom.add_tube(rim, ring, 0.18, 6)
		for k in 16:
			var a := TAU * float(k) / 16.0
			Geom.add_cylinder_between(rim, Vector3(0, 0, zoff), Vector3(cos(a) * r, sin(a) * r, zoff), 0.08, 5)
	_wheel.add_child(Geom.instance(rim, Mats.solid("giant_wheel", Color(0.95, 0.95, 1.0), 0.3, 0.2)))
	var lights := PackedVector3Array()
	for i in 64:
		var a := TAU * float(i) / 64.0
		lights.append(Vector3(cos(a) * r, sin(a) * r, 0.75))
	for k in 16:
		var a := TAU * float(k) / 16.0
		for j in range(1, 6):
			lights.append(Vector3(cos(a), sin(a), 0) * (r * j / 6.0) + Vector3(0, 0, 0.7))
	var chain := BulbChain.new().setup(lights, 0.2, Color(1.0, 0.3, 0.7), Color(0.3, 0.9, 1.0), 4.0, 5.0)
	_wheel.add_child(chain)
	bulbs.append(chain)
	var cols := [Mats.RED, Mats.GOLD, Mats.SKY, Mats.PINK, Mats.LIME, Mats.ORANGE, Mats.PURPLE, Mats.TEAL]
	for k in 16:
		var a := TAU * float(k) / 16.0
		var pivot := Node3D.new()
		pivot.position = Vector3(cos(a) * r, sin(a) * r, 0)
		_wheel.add_child(pivot)
		_box(pivot, Vector3(1.4, 1.1, 1.1), Vector3(0, -1.0, 0), Mats.solid("gcar%d" % (k % 8), cols[k % 8], 0.3, 0.25))
		_box(pivot, Vector3(1.6, 0.15, 1.3), Vector3(0, -0.4, 0), Mats.gold())
		_wheel_cars.append(pivot)


func _build_carousel() -> void:
	_carousel = Node3D.new()
	_carousel.position = Vector3(-25.0, GROUND_Y, -24.0)
	add_child(_carousel)
	_cyl(_carousel, 5.2, 5.4, 0.6, Vector3(0, 0.3, 0), Mats.stripes(Mats.GOLD, Mats.RED, 32.0, 0, 0.2), 40)
	_cyl(_carousel, 0.5, 0.5, 5.0, Vector3(0, 3.0, 0), Mats.stripes(Mats.CREAM, Mats.PINK, 4.0, 1, 0.3), 16)
	_cyl(_carousel, 0.3, 5.6, 1.8, Vector3(0, 6.3, 0), Mats.stripes(Mats.RED, Mats.CREAM, 20.0, 0, 0.2), 40)
	_sphere(_carousel, 0.5, Vector3(0, 7.4, 0), Mats.gold())
	var cols := [Color(1, 1, 1), Mats.PINK, Mats.SKY, Mats.GOLD, Mats.LIME, Mats.CREAM, Mats.ORANGE, Mats.PURPLE]
	for k in 10:
		var a := TAU * float(k) / 10.0
		var holder := Node3D.new()
		holder.position = Vector3(cos(a) * 3.8, 0, sin(a) * 3.8)
		holder.rotation.y = -a
		_carousel.add_child(holder)
		_cyl(holder, 0.06, 0.06, 4.8, Vector3(0, 3.0, 0), Mats.gold(), 6)
		var horse := Node3D.new()
		holder.add_child(horse)
		var hm := Mats.solid("bighorse%d" % (k % 8), cols[k % 8], 0.3, 0.2)
		_sphere(horse, 0.5, Vector3(0, 2.2, 0), hm, Vector3(0.7, 0.75, 1.6))
		_sphere(horse, 0.3, Vector3(0, 2.75, 0.75), hm)
		_horses.append(horse)
	var pts := PackedVector3Array()
	for i in 40:
		var a := TAU * float(i) / 40.0
		pts.append(Vector3(cos(a) * 5.65, 5.4, sin(a) * 5.65))
	var chain := BulbChain.new().setup(pts, 0.16, Color(1.0, 0.85, 0.4), Color(1.0, 0.4, 0.8), 7.0, 5.0)
	_carousel.add_child(chain)
	bulbs.append(chain)


func _build_coaster() -> void:
	var st := Geom.new_st()
	var rail_a := PackedVector3Array()
	var rail_b := PackedVector3Array()
	var sup := Geom.new_st()
	var n := 160
	for i in n + 1:
		var t := float(i) / float(n)
		var x := lerpf(-70.0, -18.0, t)
		var z := -58.0 + sin(t * 9.0) * 4.0
		var y := GROUND_Y + 6.0 + sin(t * 14.0) * 4.0 + sin(t * 5.0) * 3.0 + 3.0
		rail_a.append(Vector3(x, y, z - 0.6))
		rail_b.append(Vector3(x, y, z + 0.6))
		if i % 6 == 0:
			Geom.add_cylinder_between(sup, Vector3(x, y - 0.1, z), Vector3(x, GROUND_Y, z), 0.15, 6)
	Geom.add_tube(st, rail_a, 0.18, 6)
	Geom.add_tube(st, rail_b, 0.18, 6)
	add_child(Geom.instance(st, Mats.solid("coaster_rail", Mats.RED, 0.3, 0.4), false))
	add_child(Geom.instance(sup, Mats.solid("coaster_sup", Color(0.9, 0.9, 0.95), 0.4), false))


func _build_searchlights() -> void:
	var beam_mat := StandardMaterial3D.new()
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam_mat.albedo_color = Color(0.6, 0.6, 0.9, 0.09)
	for spot in [Vector3(-34.0, GROUND_Y, -55.0), Vector3(38.0, GROUND_Y, -58.0), Vector3(-6.0, GROUND_Y, -70.0)]:
		var pivot := Node3D.new()
		pivot.position = spot
		add_child(pivot)
		var cone := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 4.5
		cm.bottom_radius = 0.4
		cm.height = 70.0
		cm.radial_segments = 16
		cm.cap_top = false
		cm.cap_bottom = false
		cone.mesh = cm
		cone.position.y = 35.0
		cone.material_override = beam_mat
		cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(cone)
		_beams.append(pivot)


# ---------------------------------------------------------------- fireworks

func _build_fireworks() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	grad.add_point(0.7, Color(1, 1, 1, 0.8))
	for i in 10:
		var p := CPUParticles3D.new()
		p.emitting = false
		p.one_shot = true
		p.amount = 140
		p.lifetime = 1.9
		p.explosiveness = 1.0
		var sm := SphereMesh.new()
		sm.radius = 0.12
		sm.height = 0.24
		sm.radial_segments = 6
		sm.rings = 3
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.material = m
		p.mesh = sm
		p.direction = Vector3(0, 1, 0)
		p.spread = 180.0
		p.initial_velocity_min = 9.0
		p.initial_velocity_max = 12.0
		p.gravity = Vector3(0, -4.0, 0)
		p.damping_min = 2.0
		p.damping_max = 3.0
		p.scale_amount_min = 0.6
		p.scale_amount_max = 1.2
		p.color_ramp = grad
		p.local_coords = false
		add_child(p)
		_fireworks.append(p)


## Launches one firework burst. Near bursts go off above the playfield.
func burst(near: bool = false) -> void:
	var p := _fireworks[_fw_i]
	_fw_i = (_fw_i + 1) % _fireworks.size()
	var hue := randf()
	p.color = Color.from_hsv(hue, 0.75, 1.0) * 3.0
	if near:
		p.position = Vector3(randf_range(-4.0, 5.0), randf_range(6.0, 8.5), randf_range(-9.0, -4.0))
		p.initial_velocity_min = 3.5
		p.initial_velocity_max = 5.0
		p.scale_amount_max = 0.6
	else:
		p.position = Vector3(randf_range(-40.0, 40.0), randf_range(20.0, 34.0), randf_range(-75.0, -45.0))
		p.initial_velocity_min = 10.0
		p.initial_velocity_max = 14.0
		p.scale_amount_max = 1.4
	p.restart()


func _process(delta: float) -> void:
	_t += delta
	_wheel.rotation.z += delta * (0.12 + party * 0.3)
	for c in _wheel_cars:
		c.rotation.z = -_wheel.rotation.z
	_carousel.rotation.y += delta * (0.35 + party * 0.6)
	for k in _horses.size():
		_horses[k].position.y = sin(_t * 2.2 + k * 1.1) * 0.5
	for i in _beams.size():
		var b := _beams[i]
		b.rotation.z = sin(_t * 0.35 + i * 2.0) * 0.45
		b.rotation.x = -0.25 + cos(_t * 0.27 + i * 1.3) * 0.2
	_fw_next -= delta * (1.0 + party * 3.0)
	if _fw_next <= 0.0:
		_fw_next = randf_range(1.2, 3.2)
		burst(false)
