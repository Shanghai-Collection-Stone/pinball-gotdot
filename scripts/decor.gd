class_name Decor
extends Node3D
## Everything on the machine that makes it look like a carnival but does not
## touch the ball: cabinet with marquee bulbs, the backbox with a spinning
## Ferris wheel, a High Striker tower and the Wheel of Fortune, a topper sign,
## bunting, balloons, confetti, sweeping spotlights and little toys (carousel,
## popcorn cart) on the closed areas of the playfield.

signal fortune_tick
signal fortune_done(index: int)

const BACK_Z := -11.9

var bulbs: Array[BulbChain] = []
var wheel: Node3D
var _gondolas: Array[Node3D] = []
var _wheel_speed := 0.35
var _wheel_boost := 0.0
var _puck: Node3D
var _striker_lamps: Array[StandardMaterial3D] = []
var _bell_mat: StandardMaterial3D
var _bell_flash := 0.0
var _sunburst: ShaderMaterial
var _confetti: Array[CPUParticles3D] = []
var _balloons: Array[Node3D] = []
var _party_lights: Array[OmniLight3D] = []
var _t := 0.0
var party := 0.0

const FORTUNE_LABELS := ["10万", "额外球", "25万", "双倍", "50万", "多球", "大炮", "100万"]
var _fortune: Node3D
var _fortune_from := 0.0
var _fortune_to := 0.0
var _fortune_t := -1.0
var _fortune_index := 0
var _fortune_last_peg := 0
var _toy_carousel: Node3D
var _toy_horses: Array[Node3D] = []
var _spots: Array[SpotLight3D] = []
var _topper_stars: Array[Node3D] = []


func build() -> void:
	_build_cabinet()
	_build_apron()
	_build_backbox()
	_build_wheel()
	_build_striker_tower()
	_build_bunting()
	_build_balloons()
	_build_confetti()
	_build_lights()
	_build_marquee_bulbs()
	_build_toys()
	_build_spotlights()


func _box(size: Vector3, pos: Vector3, mat: Material, parent: Node = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi


# ---------------------------------------------------------------- cabinet

func _build_cabinet() -> void:
	var wood := Mats.wood()
	_box(Vector3(0.62, 1.05, 22.4), Vector3(-5.43, 0.42, -0.6), wood)
	_box(Vector3(0.62, 1.05, 22.4), Vector3(6.21, 0.42, -0.6), wood)
	_box(Vector3(0.66, 0.05, 22.4), Vector3(-5.43, 0.97, -0.6), Mats.gold())
	_box(Vector3(0.66, 0.05, 22.4), Vector3(6.21, 0.97, -0.6), Mats.gold())
	_box(Vector3(12.3, 0.4, 0.6), Vector3(0.39, 0.85, 10.75), Mats.chrome())
	_box(Vector3(12.3, 1.2, 0.6), Vector3(0.39, 0.4, -11.55), wood)
	# cabinet body under the playfield with carnival stripes, on chrome legs
	var body := _box(Vector3(12.3, 2.0, 22.8), Vector3(0.39, -1.05, -0.6), Mats.stripes(Color(0.5, 0.03, 0.08), Color(0.95, 0.85, 0.65), 1.2, 1))
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_box(Vector3(12.4, 0.12, 22.9), Vector3(0.39, -2.0, -0.6), Mats.gold())
	var legs := Geom.new_st()
	for lx in [-5.3, 6.1]:
		for lz in [-11.5, 10.3]:
			Geom.add_cylinder_between(legs, Vector3(lx, -2.0, lz), Vector3(lx, -4.0, lz), 0.17, 12)
			_box(Vector3(0.6, 0.1, 0.6), Vector3(lx, -4.0, lz), Mats.gold())
	add_child(Geom.instance(legs, Mats.chrome()))
	# coin door on the front of the cabinet
	_box(Vector3(2.8, 1.5, 0.08), Vector3(0.4, -1.0, 10.84), Mats.chrome())
	_box(Vector3(2.5, 1.2, 0.04), Vector3(0.4, -1.0, 10.89), Mats.solid("coin_door", Color(0.12, 0.08, 0.16), 0.3))
	for cx in [-0.5, 1.3]:
		_box(Vector3(0.42, 0.5, 0.05), Vector3(cx, -0.85, 10.92), Mats.glow(Mats.RED, 2.5))
		_box(Vector3(0.04, 0.24, 0.06), Vector3(cx, -0.85, 10.95), Mats.dark())
	var coin := Mats.label3d("投币  免费游戏", 46, Color(2.0, 1.5, 0.5), Color(0.2, 0, 0.05), 10)
	coin.position = Vector3(0.4, -1.45, 10.93)
	add_child(coin)
	# marquee bulbs along both side rails (gaps where the Ring Toss bottles stand)
	for x in [-5.43, 6.21]:
		var pts := PackedVector3Array()
		var z := 10.2
		while z > -11.4:
			var near_bottle := false
			if x < 0.0:
				for rz in Table.RING_Z:
					if absf(z - float(rz)) < 0.32:
						near_bottle = true
			if not near_bottle:
				pts.append(Vector3(x, 1.06, z))
			z -= 0.55
		var chain := BulbChain.new().setup(pts, 0.08, Color(1.0, 0.8, 0.35), Color(1.0, 0.25, 0.35), 7.0, 4.0)
		add_child(chain)
		bulbs.append(chain)


func _build_apron() -> void:
	var poly := PackedVector2Array([
		Vector2(-5.08, 8.95), Vector2(-1.2, 8.95), Vector2(-0.75, 9.15), Vector2(0.75, 9.15),
		Vector2(1.2, 8.95), Vector2(5.07, 8.95), Vector2(5.07, 10.32), Vector2(-5.08, 10.32),
	])
	var st := Geom.new_st()
	Geom.add_prism(st, poly, 0.0, 0.55)
	var apron := Geom.instance(st, Mats.stripes(Color(0.55, 0.04, 0.1), Color(0.98, 0.88, 0.62), 2.0, 2))
	add_child(apron)
	var title := Mats.label3d("嘉年华狂欢派对", 70, Color(2.0, 1.4, 0.4), Color(0.25, 0.0, 0.05), 14, true)
	title.position = Vector3(0, 0.57, 9.75)
	title.rotation.x = -PI * 0.5
	add_child(title)
	var cards := [
		["滑道得票券·集满3张\n射售票亭开启多球\n多球中双滑道点亮超级大奖", Vector3(-3.25, 0.57, 9.68)],
		["盖满游园护照5个章\n开启「狂欢之夜」三倍积分\n幸运星点亮幸运大转盘", Vector3(3.25, 0.57, 9.68)],
	]
	for c in cards:
		var l := Mats.label3d(c[0], 26, Mats.CREAM, Color(0.2, 0, 0.05), 6)
		l.position = c[1]
		l.rotation.x = -PI * 0.5
		add_child(l)


# ---------------------------------------------------------------- backbox

func _build_backbox() -> void:
	var root := Node3D.new()
	root.name = "Backbox"
	root.position = Vector3(0.4, 0.0, BACK_Z)
	root.rotation.x = deg_to_rad(-14.0)
	add_child(root)
	_box(Vector3(12.6, 8.4, 0.6), Vector3(0, 4.2, -0.35), Mats.wood(), root)
	_box(Vector3(12.0, 7.8, 0.05), Vector3(0, 4.2, -0.03), Mats.solid("backglass", Color(0.08, 0.02, 0.18), 0.4), root)
	# rotating sunburst behind the title
	var sun := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(6.4, 6.4)
	sun.mesh = qm
	sun.position = Vector3(0, 5.25, 0.0)
	_sunburst = ShaderMaterial.new()
	_sunburst.shader = preload("res://shaders/sunburst.gdshader")
	_sunburst.set_shader_parameter("energy", 0.75)
	sun.material_override = _sunburst
	root.add_child(sun)
	var title := Mats.label3d("狂欢派对", 300, Color(2.6, 1.8, 0.5), Color(0.55, 0.0, 0.08), 44, true)
	title.position = Vector3(0, 6.1, 0.06)
	root.add_child(title)
	var sub := Mats.label3d("嘉 年 华 弹 珠 台", 120, Color(1.0, 0.5, 1.6), Color(0.12, 0.0, 0.25), 26, true)
	sub.position = Vector3(0, 4.62, 0.06)
	root.add_child(sub)
	var tag := Mats.label3d("★ 史上最欢乐的游乐场 ★", 62, Mats.CREAM, Color(0.2, 0.0, 0.1), 12)
	tag.position = Vector3(0, 3.8, 0.06)
	root.add_child(tag)
	_build_fortune(root)
	_build_topper(root)
	# big-top tents in the lower corners
	for x in [-4.6, 4.6]:
		var tent := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 1.0
		cm.height = 1.2
		cm.radial_segments = 24
		tent.mesh = cm
		tent.position = Vector3(x, 1.2, 0.5)
		tent.material_override = Mats.stripes(Mats.RED, Mats.CREAM, 12.0, 0)
		root.add_child(tent)
		var flag := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(0.3, 0.2, 0.02)
		flag.mesh = pm
		flag.position = Vector3(x + 0.15, 1.95, 0.5)
		flag.rotation.z = -PI * 0.5
		flag.material_override = Mats.solid("flag", Mats.GOLD, 0.4, 0.5)
		root.add_child(flag)
	# bulb border around the backglass
	var pts := PackedVector3Array()
	var w := 5.95
	var h0 := 0.35
	var h1 := 8.05
	var x := -w
	while x < w:
		pts.append(Vector3(x, h1, 0.12))
		x += 0.42
	var y := h1
	while y > h0:
		pts.append(Vector3(w, y, 0.12))
		y -= 0.42
	x = w
	while x > -w:
		pts.append(Vector3(x, h0, 0.12))
		x -= 0.42
	y = h0
	while y < h1:
		pts.append(Vector3(-w, y, 0.12))
		y += 0.42
	var chain := BulbChain.new().setup(pts, 0.1, Color(1.0, 0.85, 0.4), Color(1.0, 0.3, 0.6), 9.0, 5.0)
	root.add_child(chain)
	bulbs.append(chain)


func _build_wheel() -> void:
	var stand := Node3D.new()
	stand.position = Vector3(4.9, 0.0, BACK_Z + 1.25)
	stand.rotation.x = deg_to_rad(-14.0)
	add_child(stand)
	var hub_y := 4.3
	var r := 2.05
	# A-frame legs
	var st := Geom.new_st()
	for s in [-1.0, 1.0]:
		Geom.add_cylinder_between(st, Vector3(s * 1.4, 0.3, -0.25), Vector3(0, hub_y, -0.25), 0.07, 8)
		Geom.add_cylinder_between(st, Vector3(s * 1.4, 0.3, 0.25), Vector3(0, hub_y, 0.25), 0.07, 8)
	stand.add_child(Geom.instance(st, Mats.chrome()))
	wheel = Node3D.new()
	wheel.position = Vector3(0, hub_y, 0)
	stand.add_child(wheel)
	var rim := Geom.new_st()
	for zoff in [-0.18, 0.18]:
		var ring := PackedVector3Array()
		for i in 49:
			var a := TAU * float(i) / 48.0
			ring.append(Vector3(cos(a) * r, sin(a) * r, zoff))
		Geom.add_tube(rim, ring, 0.05, 6)
		var ring2 := PackedVector3Array()
		for i in 49:
			var a := TAU * float(i) / 48.0
			ring2.append(Vector3(cos(a) * r * 0.55, sin(a) * r * 0.55, zoff))
		Geom.add_tube(rim, ring2, 0.03, 6)
		for k in 12:
			var a := TAU * float(k) / 12.0
			Geom.add_cylinder_between(rim, Vector3(0, 0, zoff), Vector3(cos(a) * r, sin(a) * r, zoff), 0.025, 5)
	wheel.add_child(Geom.instance(rim, Mats.solid("wheel_white", Color(0.95, 0.95, 1.0), 0.3, 0.15)))
	var hub := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.22
	hm.bottom_radius = 0.22
	hm.height = 0.5
	hub.mesh = hm
	hub.rotation.x = PI * 0.5
	hub.material_override = Mats.gold()
	wheel.add_child(hub)
	var lights := PackedVector3Array()
	for i in 24:
		var a := TAU * float(i) / 24.0
		lights.append(Vector3(cos(a) * r, sin(a) * r, 0.24))
	var chain := BulbChain.new().setup(lights, 0.07, Color(1.0, 0.3, 0.7), Color(0.3, 0.9, 1.0), 5.0, 5.0)
	wheel.add_child(chain)
	bulbs.append(chain)
	var gcols := [Mats.RED, Mats.GOLD, Mats.SKY, Mats.PINK, Mats.LIME, Mats.ORANGE, Mats.PURPLE, Mats.TEAL]
	for k in 8:
		var a := TAU * float(k) / 8.0
		var pivot := Node3D.new()
		pivot.position = Vector3(cos(a) * r, sin(a) * r, 0)
		wheel.add_child(pivot)
		var car := Node3D.new()
		pivot.add_child(car)
		_box(Vector3(0.42, 0.32, 0.36), Vector3(0, -0.28, 0), Mats.solid("gondola%d" % k, gcols[k], 0.3, 0.3), car)
		_box(Vector3(0.5, 0.05, 0.42), Vector3(0, -0.1, 0), Mats.gold(), car)
		_gondolas.append(pivot)


func _build_striker_tower() -> void:
	var root := Node3D.new()
	root.position = Vector3(-4.3, 0.0, BACK_Z + 1.3)
	root.rotation.x = deg_to_rad(-14.0)
	add_child(root)
	_box(Vector3(1.1, 0.35, 0.8), Vector3(0, 0.6, 0), Mats.wood(), root)
	_box(Vector3(0.36, 5.4, 0.2), Vector3(0, 3.4, 0), Mats.stripes(Mats.RED, Mats.CREAM, 2.2, 1), root)
	_box(Vector3(0.06, 5.4, 0.06), Vector3(0, 3.4, 0.14), Mats.chrome(), root)
	var names := ["弱鸡", "还行", "很强", "超强", "大力神"]
	for i in 5:
		var m := Mats.glow(Mats.RED.lerp(Mats.GOLD, i / 4.0), 0.1)
		_striker_lamps.append(m)
		var lamp := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.13
		sm.height = 0.26
		lamp.mesh = sm
		lamp.position = Vector3(-0.38, 1.4 + i * 0.95, 0.1)
		lamp.material_override = m
		root.add_child(lamp)
		var l := Mats.label3d(names[i], 46, Mats.CREAM, Color(0.15, 0, 0.1), 10)
		l.position = Vector3(0.55, 1.4 + i * 0.95, 0.12)
		root.add_child(l)
	_puck = Node3D.new()
	_puck.position = Vector3(0, 1.0, 0.18)
	root.add_child(_puck)
	_box(Vector3(0.5, 0.18, 0.18), Vector3.ZERO, Mats.solid("puck", Mats.GOLD, 0.2, 0.6), _puck)
	var bell := MeshInstance3D.new()
	var sm2 := SphereMesh.new()
	sm2.radius = 0.4
	sm2.height = 0.8
	sm2.is_hemisphere = true
	bell.mesh = sm2
	bell.position = Vector3(0, 6.15, 0.05)
	_bell_mat = Mats.glow(Mats.GOLD, 0.2)
	_bell_mat.metallic = 1.0
	_bell_mat.roughness = 0.2
	bell.material_override = _bell_mat
	root.add_child(bell)
	var l2 := Mats.label3d("大力士敲钟", 60, Color(2.0, 1.4, 0.4), Color(0.4, 0, 0.05), 12, true)
	l2.position = Vector3(0, 6.9, 0.1)
	root.add_child(l2)


func _build_bunting() -> void:
	var cols := [Mats.RED, Mats.GOLD, Mats.SKY, Mats.CREAM, Mats.PINK]
	var lines := [
		[Vector3(-5.6, 8.6, BACK_Z + 1.6), Vector3(6.4, 8.6, BACK_Z + 1.6), 0.9],
		[Vector3(-5.6, 7.0, BACK_Z + 2.4), Vector3(-1.0, 6.9, BACK_Z + 2.6), 0.6],
		[Vector3(1.8, 6.9, BACK_Z + 2.6), Vector3(6.4, 7.0, BACK_Z + 2.4), 0.6],
	]
	var cord := Geom.new_st()
	var k := 0
	for line in lines:
		var a: Vector3 = line[0]
		var b: Vector3 = line[1]
		var sag: float = line[2]
		var pts := PackedVector3Array()
		var count := int(a.distance_to(b) / 0.45)
		for i in count + 1:
			var t := float(i) / count
			pts.append(a.lerp(b, t) + Vector3(0, -sag * 4.0 * t * (1.0 - t), 0))
		Geom.add_tube(cord, pts, 0.015, 4)
		for i in range(1, count):
			var p := pts[i]
			var flag := MeshInstance3D.new()
			var pm := PrismMesh.new()
			pm.size = Vector3(0.32, 0.4, 0.01)
			flag.mesh = pm
			flag.position = p + Vector3(0, -0.2, 0)
			flag.rotation.z = PI
			var fm := Mats.solid("bunting%d" % (k % cols.size()), cols[k % cols.size()], 0.5, 0.25)
			fm.cull_mode = BaseMaterial3D.CULL_DISABLED
			flag.material_override = fm
			flag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(flag)
			k += 1
	add_child(Geom.instance(cord, Mats.dark(), false))


func _build_balloons() -> void:
	var spots := [
		[Vector3(-6.4, 6.8, BACK_Z + 1.0), Mats.RED], [Vector3(-6.9, 6.1, BACK_Z + 1.5), Mats.SKY],
		[Vector3(-6.1, 5.6, BACK_Z + 2.1), Mats.GOLD], [Vector3(7.2, 6.8, BACK_Z + 1.0), Mats.PINK],
		[Vector3(7.7, 6.0, BACK_Z + 1.6), Mats.LIME], [Vector3(6.9, 5.5, BACK_Z + 2.2), Mats.PURPLE],
	]
	for s in spots:
		var b := Node3D.new()
		b.position = s[0]
		add_child(b)
		var sph := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.45
		sm.height = 0.9
		sph.mesh = sm
		sph.scale = Vector3(1, 1.2, 1)
		var m := Mats.glow(s[1], 0.35)
		m.roughness = 0.12
		sph.material_override = m
		b.add_child(sph)
		var st := Geom.new_st()
		var str_pts := PackedVector3Array()
		for i in 9:
			var t := float(i) / 8.0
			str_pts.append(Vector3(sin(t * 6.0) * 0.08, -0.55 - t * 2.6, 0))
		Geom.add_tube(st, str_pts, 0.01, 4)
		b.add_child(Geom.instance(st, Mats.solid("string", Color(0.9, 0.9, 0.9), 0.8), false))
		b.set_meta("base_y", b.position.y)
		b.set_meta("phase", randf() * TAU)
		_balloons.append(b)


func _build_confetti() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 0.2, 0.3))
	grad.set_color(1, Color(0.3, 0.8, 1.0))
	grad.add_point(0.25, Color(1, 0.85, 0.2))
	grad.add_point(0.5, Color(0.5, 1, 0.3))
	grad.add_point(0.75, Color(1, 0.4, 0.9))
	var qm := QuadMesh.new()
	qm.size = Vector2(0.14, 0.09)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.4, 0.4)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.material = mat
	for x in [-3.5, 0.4, 4.3]:
		var p := CPUParticles3D.new()
		p.emitting = false
		p.one_shot = true
		p.amount = 160
		p.lifetime = 2.8
		p.explosiveness = 0.92
		p.mesh = qm
		p.position = Vector3(x, 4.5, -4.0)
		p.direction = Vector3(0, 1, 0.3)
		p.spread = 55.0
		p.initial_velocity_min = 6.0
		p.initial_velocity_max = 12.0
		p.gravity = Vector3(0, -7.0, 1.5)
		p.damping_min = 1.0
		p.damping_max = 2.5
		p.angular_velocity_min = -720.0
		p.angular_velocity_max = 720.0
		p.particle_flag_rotate_y = true
		p.scale_amount_min = 0.7
		p.scale_amount_max = 1.4
		p.color_initial_ramp = grad
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = 0.6
		add_child(p)
		_confetti.append(p)


func _build_lights() -> void:
	var specs := [
		[Vector3(-4.0, 4.5, -6.0), Color(1.0, 0.3, 0.7), 9.0],
		[Vector3(4.6, 4.5, -6.0), Color(0.3, 0.7, 1.0), 9.0],
		[Vector3(0.4, 4.0, 3.5), Color(1.0, 0.75, 0.45), 10.0],
	]
	for s in specs:
		var l := OmniLight3D.new()
		l.position = s[0]
		l.light_color = s[1]
		l.omni_range = s[2]
		l.light_energy = 1.4
		l.shadow_enabled = false
		add_child(l)
		_party_lights.append(l)


# ---------------------------------------------------------------- luxury extras

## Wheel of Fortune on the backbox. Segment i sits at angle -i*45 degrees
## from the top, so a wheel rotation of i*45 degrees puts it under the pointer.
func _build_fortune(root: Node3D) -> void:
	var centre := Vector3(0, 1.95, 0.14)
	var r := 1.2
	var frame := Node3D.new()
	frame.position = centre
	root.add_child(frame)
	_fortune = Node3D.new()
	frame.add_child(_fortune)
	var cols := [Mats.RED, Mats.GOLD, Mats.SKY, Mats.PINK, Mats.LIME, Mats.ORANGE, Mats.PURPLE, Mats.TEAL]
	var seg := TAU / 8.0
	for i in 8:
		var c := -float(i) * seg
		var st := Geom.new_st()
		for k in 6:
			var a0 := c - seg * 0.5 + seg * float(k) / 6.0
			var a1 := c - seg * 0.5 + seg * float(k + 1) / 6.0
			Geom.tri(st, Vector3.ZERO, Vector3(-sin(a0), cos(a0), 0) * r, Vector3(-sin(a1), cos(a1), 0) * r, Vector3(0, 0, 1))
		var wedge := Geom.instance(st, Mats.solid("fortune%d" % i, cols[i], 0.3, 0.35), false)
		_fortune.add_child(wedge)
		var l := Mats.label3d(FORTUNE_LABELS[i], 44, Color(1, 1, 1), Color(0.15, 0.0, 0.1), 10, true)
		l.position = Vector3(-sin(c), cos(c), 0) * (r * 0.62) + Vector3(0, 0, 0.02)
		l.rotation.z = c
		_fortune.add_child(l)
		var peg := MeshInstance3D.new()
		var pm := SphereMesh.new()
		pm.radius = 0.045
		pm.height = 0.09
		peg.mesh = pm
		var pa := c + seg * 0.5
		peg.position = Vector3(-sin(pa), cos(pa), 0.03) * Vector3(r - 0.06, r - 0.06, 1.0)
		peg.material_override = Mats.gold()
		_fortune.add_child(peg)
	var hub := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.2
	hm.bottom_radius = 0.22
	hm.height = 0.12
	hub.mesh = hm
	hub.rotation.x = PI * 0.5
	hub.position.z = 0.05
	hub.material_override = Mats.gold()
	frame.add_child(hub)
	var rim := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = r
	tm.outer_radius = r + 0.1
	tm.rings = 48
	rim.mesh = tm
	rim.rotation.x = PI * 0.5
	rim.material_override = Mats.gold()
	frame.add_child(rim)
	var pts := PackedVector3Array()
	for i in 24:
		var a := TAU * float(i) / 24.0
		pts.append(Vector3(cos(a), sin(a), 0) * (r + 0.2) + Vector3(0, 0, 0.04))
	var ring_bulbs := BulbChain.new().setup(pts, 0.055, Color(1.0, 0.9, 0.5), Color(1.0, 0.3, 0.6), 10.0, 5.0)
	frame.add_child(ring_bulbs)
	bulbs.append(ring_bulbs)
	var pointer := MeshInstance3D.new()
	var prm := PrismMesh.new()
	prm.size = Vector3(0.3, 0.34, 0.08)
	pointer.mesh = prm
	pointer.rotation.z = PI
	pointer.position = Vector3(0, r + 0.2, 0.1)
	pointer.material_override = Mats.glow(Mats.RED, 1.5)
	frame.add_child(pointer)
	var cap := Mats.label3d("幸运大转盘", 50, Color(2.0, 1.6, 0.5), Color(0.3, 0, 0.05), 10, true)
	cap.position = Vector3(2.15, 2.6, 0.1)
	cap.rotation.z = -0.12
	root.add_child(cap)


## Spins the Wheel of Fortune so that it stops on `index`; emits
## fortune_done(index) when it settles.
func spin_fortune(index: int) -> void:
	_fortune_index = index
	var seg := TAU / 8.0
	var base := _fortune.rotation.z
	var target := float(index) * seg + randf_range(-0.3, 0.3) * seg
	var turns := ceilf((base - target) / TAU) + 4.0
	_fortune_from = base
	_fortune_to = target + turns * TAU
	_fortune_t = 0.0
	_fortune_last_peg = int(floor((base + seg * 0.5) / seg))


func fortune_busy() -> bool:
	return _fortune_t >= 0.0


## Topper sign above the backbox.
func _build_topper(root: Node3D) -> void:
	var top := Node3D.new()
	top.position = Vector3(0, 9.35, -0.25)
	root.add_child(top)
	_box(Vector3(8.2, 1.9, 0.4), Vector3.ZERO, Mats.wood(), top)
	_box(Vector3(7.8, 1.55, 0.05), Vector3(0, 0, 0.21), Mats.solid("topper_glass", Color(0.12, 0.02, 0.22), 0.4), top)
	var l := Mats.label3d("★ 嘉年华 ★", 240, Color(2.8, 2.0, 0.6), Color(0.5, 0.0, 0.1), 40, true)
	l.position = Vector3(0, 0.02, 0.26)
	top.add_child(l)
	var pts := PackedVector3Array()
	var x := -3.95
	while x <= 3.95:
		pts.append(Vector3(x, 0.86, 0.24))
		pts.append(Vector3(x, -0.86, 0.24))
		x += 0.38
	for y in [-0.5, 0.0, 0.5]:
		pts.append(Vector3(-3.95, y, 0.24))
		pts.append(Vector3(3.95, y, 0.24))
	var chain := BulbChain.new().setup(pts, 0.085, Color(1.0, 0.85, 0.4), Color(1.0, 0.3, 0.5), 8.0, 5.0)
	top.add_child(chain)
	bulbs.append(chain)
	for sx in [-1.0, 1.0]:
		var star := Node3D.new()
		star.position = Vector3(sx * 4.8, 0.25, 0.1)
		top.add_child(star)
		var st := Geom.new_st()
		var poly := Geom.star_poly(0.75, 0.32)
		var rotated := PackedVector2Array()
		for p in poly:
			rotated.append(Vector2(p.x, p.y))
		Geom.add_prism(st, rotated, -0.08, 0.08)
		var mi := Geom.instance(st, Mats.glow(Mats.GOLD, 1.6))
		mi.rotation.x = PI * 0.5
		star.add_child(mi)
		_topper_stars.append(star)


## Chasing bulbs along the top arch of the playfield and the apron edge.
func _build_marquee_bulbs() -> void:
	var theta_end := acos((-4.2 - Table.ARC_C.x) / Table.ARC_R)
	var pts := PackedVector3Array()
	var n := 34
	for i in n:
		var a := lerpf(0.05, theta_end - 0.04, float(i) / float(n - 1))
		var p := Table.ARC_C + Vector2(cos(a), -sin(a)) * Table.ARC_R
		pts.append(Vector3(p.x, 0.9, p.y))
	var arch := BulbChain.new().setup(pts, 0.06, Color(1.0, 0.85, 0.35), Color(0.4, 0.9, 1.0), 9.0, 4.5)
	add_child(arch)
	bulbs.append(arch)
	var apron := PackedVector3Array()
	var x := -4.9
	while x <= 4.95:
		if absf(x) > 1.35:
			apron.append(Vector3(x, 0.6, 8.93))
		x += 0.38
	var chain := BulbChain.new().setup(apron, 0.055, Color(1.0, 0.3, 0.5), Color(1.0, 0.85, 0.4), 7.0, 4.0)
	add_child(chain)
	bulbs.append(chain)


## Little toys standing in the walled-off areas under the ramps.
func _build_toys() -> void:
	# carousel (merry-go-round)
	_toy_carousel = Node3D.new()
	_toy_carousel.position = Vector3(-4.4, 0.0, -3.0)
	add_child(_toy_carousel)
	var base := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.48
	bm.bottom_radius = 0.5
	bm.height = 0.08
	base.mesh = bm
	base.position.y = 0.04
	base.material_override = Mats.stripes(Mats.GOLD, Mats.RED, 16.0, 0, 0.2)
	_toy_carousel.add_child(base)
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.06
	pm.bottom_radius = 0.06
	pm.height = 0.8
	pole.mesh = pm
	pole.position.y = 0.45
	pole.material_override = Mats.gold()
	_toy_carousel.add_child(pole)
	var canopy := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.02
	cm.bottom_radius = 0.5
	cm.height = 0.24
	cm.radial_segments = 16
	canopy.mesh = cm
	canopy.position.y = 0.86
	canopy.material_override = Mats.stripes(Mats.RED, Mats.CREAM, 8.0, 0, 0.2)
	_toy_carousel.add_child(canopy)
	var hcols := [Color(1, 1, 1), Mats.PINK, Mats.SKY, Mats.GOLD, Mats.LIME, Mats.CREAM]
	for k in 6:
		var a := TAU * float(k) / 6.0
		var holder := Node3D.new()
		holder.position = Vector3(cos(a) * 0.34, 0.0, sin(a) * 0.34)
		holder.rotation.y = -a
		_toy_carousel.add_child(holder)
		var rod := MeshInstance3D.new()
		var rm := CylinderMesh.new()
		rm.top_radius = 0.012
		rm.bottom_radius = 0.012
		rm.height = 0.66
		rod.mesh = rm
		rod.position.y = 0.42
		rod.material_override = Mats.gold()
		holder.add_child(rod)
		var horse := Node3D.new()
		holder.add_child(horse)
		var hm := Mats.solid("horse%d" % k, hcols[k], 0.3, 0.2)
		var body := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.07
		sm.height = 0.14
		body.mesh = sm
		body.scale = Vector3(0.7, 0.75, 1.5)
		body.position.y = 0.36
		body.material_override = hm
		horse.add_child(body)
		var head := MeshInstance3D.new()
		var hd := SphereMesh.new()
		hd.radius = 0.045
		hd.height = 0.09
		head.mesh = hd
		head.position = Vector3(0, 0.45, 0.1)
		head.material_override = hm
		horse.add_child(head)
		_toy_horses.append(horse)
	var cb := PackedVector3Array()
	for k in 12:
		var a := TAU * float(k) / 12.0
		cb.append(Vector3(cos(a) * 0.5, 0.74, sin(a) * 0.5))
	var cbulbs := BulbChain.new().setup(cb, 0.035, Color(1.0, 0.85, 0.4), Color(1.0, 0.4, 0.7), 6.0, 4.0)
	_toy_carousel.add_child(cbulbs)
	# popcorn cart
	var cart := Node3D.new()
	cart.position = Vector3(4.45, 0.0, -2.9)
	cart.rotation.y = -0.35
	add_child(cart)
	_box(Vector3(0.72, 0.34, 0.46), Vector3(0, 0.33, 0), Mats.stripes(Mats.RED, Mats.CREAM, 6.0, 2, 0.1), cart)
	for wx in [-0.28, 0.28]:
		var wheel_mi := MeshInstance3D.new()
		var wm := CylinderMesh.new()
		wm.top_radius = 0.14
		wm.bottom_radius = 0.14
		wm.height = 0.05
		wheel_mi.mesh = wm
		wheel_mi.rotation.x = PI * 0.5
		wheel_mi.position = Vector3(wx, 0.14, 0.25)
		wheel_mi.material_override = Mats.gold()
		cart.add_child(wheel_mi)
	_box(Vector3(0.62, 0.34, 0.4), Vector3(0, 0.67, 0), Mats.plastic("cart_glass", Color(0.8, 0.9, 1.0), 0.25), cart)
	var corn := Mats.solid("popcorn", Color(1.0, 0.92, 0.55), 0.8, 0.25)
	for k in 14:
		var c := MeshInstance3D.new()
		var csm := SphereMesh.new()
		csm.radius = 0.055
		csm.height = 0.11
		c.mesh = csm
		c.position = Vector3(randf_range(-0.25, 0.25), 0.55 + randf_range(0.0, 0.14), randf_range(-0.15, 0.15))
		c.material_override = corn
		cart.add_child(c)
	var roof := MeshInstance3D.new()
	var rp := PrismMesh.new()
	rp.size = Vector3(0.8, 0.2, 0.52)
	roof.mesh = rp
	roof.position.y = 0.94
	roof.material_override = Mats.stripes(Mats.RED, Mats.CREAM, 9.0, 0, 0.2)
	cart.add_child(roof)
	var sign := Mats.label3d("爆米花", 40, Mats.GOLD, Color(0.3, 0, 0.05), 8, true)
	sign.position = Vector3(0, 0.34, 0.24)
	cart.add_child(sign)


## Two coloured spotlights that sweep across the playfield.
func _build_spotlights() -> void:
	var specs := [[Vector3(-8.0, 11.0, 9.0), Color(1.0, 0.35, 0.75)], [Vector3(8.8, 11.0, 9.0), Color(0.35, 0.85, 1.0)]]
	for sp in specs:
		var l := SpotLight3D.new()
		l.position = sp[0]
		l.light_color = sp[1]
		l.light_energy = 2.5
		l.spot_range = 40.0
		l.spot_angle = 11.0
		l.spot_attenuation = 0.6
		l.shadow_enabled = false
		add_child(l)
		l.look_at(Vector3(0.4, 0, 0))
		_spots.append(l)


# ---------------------------------------------------------------- actions

func spin_wheel(boost: float = 4.0) -> void:
	_wheel_boost = maxf(_wheel_boost, boost)


func set_striker(level: int) -> void:
	for i in _striker_lamps.size():
		_striker_lamps[i].emission_energy_multiplier = 3.0 if i < level else 0.1
	var tw := create_tween()
	var y := 1.0 + level * 0.95
	tw.tween_property(_puck, "position:y", y + 0.6, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_puck, "position:y", y, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func ring_bell() -> void:
	_bell_flash = 2.0
	var tw := create_tween()
	tw.tween_property(_puck, "position:y", 5.95, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.6)
	tw.tween_property(_puck, "position:y", 1.0, 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	for m in _striker_lamps:
		m.emission_energy_multiplier = 4.0


func confetti() -> void:
	for p in _confetti:
		p.restart()
		p.emitting = true


func set_bulb_mode(mode: int) -> void:
	for b in bulbs:
		b.set_mode(mode)


func flash_bulbs(seconds: float = 0.8) -> void:
	for b in bulbs:
		b.flash(seconds)


func _process(delta: float) -> void:
	_t += delta
	_wheel_boost = maxf(0.0, _wheel_boost - delta * 1.2)
	wheel.rotation.z += (_wheel_speed + _wheel_boost) * delta
	for g in _gondolas:
		g.rotation.z = -wheel.rotation.z
	for b in _balloons:
		var ph: float = b.get_meta("phase")
		b.position.y = float(b.get_meta("base_y")) + sin(_t * 1.3 + ph) * 0.18
		b.rotation.z = sin(_t * 0.9 + ph) * 0.12
	if _bell_flash > 0.0:
		_bell_flash = maxf(0.0, _bell_flash - delta)
		_bell_mat.emission_energy_multiplier = 0.2 + (5.0 if fmod(_bell_flash, 0.2) < 0.1 else 1.0) * minf(1.0, _bell_flash)
	_sunburst.set_shader_parameter("flash", party)
	for i in _party_lights.size():
		var l := _party_lights[i]
		l.light_energy = 1.3 + party * (0.9 + 0.9 * sin(_t * 9.0 + i * 2.1))
	_toy_carousel.rotation.y += delta * (0.8 + party * 2.0)
	for k in _toy_horses.size():
		_toy_horses[k].position.y = sin(_t * 3.0 + k * 1.3) * 0.06
	for st in _topper_stars:
		st.rotation.z += delta * 1.2
	var sweep := 0.6 + party * 1.4
	for i in _spots.size():
		var sp := _spots[i]
		var ph := float(i) * 2.4
		sp.look_at(Vector3(0.4 + sin(_t * 0.7 * sweep + ph) * 4.2, 0.0, -1.5 + cos(_t * 0.53 * sweep + ph) * 7.5))
		sp.light_energy = 2.2 + party * 2.0
	if _fortune_t >= 0.0:
		_fortune_t = minf(1.0, _fortune_t + delta / 3.6)
		var e := 1.0 - pow(1.0 - _fortune_t, 4.0)
		_fortune.rotation.z = lerpf(_fortune_from, _fortune_to, e)
		var seg := TAU / 8.0
		var peg := int(floor((_fortune.rotation.z + seg * 0.5) / seg))
		if peg != _fortune_last_peg:
			_fortune_last_peg = peg
			fortune_tick.emit()
		if _fortune_t >= 1.0:
			_fortune_t = -1.0
			_fortune.rotation.z = fmod(_fortune.rotation.z, TAU)
			flash_bulbs(1.2)
			fortune_done.emit(_fortune_index)
