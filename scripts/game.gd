extends Node3D
## 嘉年华狂欢派对弹珠台 - game controller.
## Owns the rules, score, balls, input, camera and ties the table, decor,
## midway scenery, HUD and sound together.
##
## Luxury scoring ("豪华得分") on top of the basic targets:
##   * Carnival Multiball: ramp jackpots; both ramps light the Super Jackpot
##     at the High Striker; the two ramps back to back score a Double Jackpot.
##   * Double Scoring (双倍积分): from the Wheel of Fortune or 40 spinner turns.
##   * Hurry-up (限时抢分): ringing the High Striker bell starts a countdown
##     value collected on either ramp.
##   * Wheel of Fortune (幸运大转盘): lit by the three Lucky Stars, spun at
##     the Ticket Booth.
##   * Carnival Passport (游园护照): five stamps (bell, ducks, balloons, ring
##     toss, five ramps) light "狂欢之夜" - a timed triple-scoring multiball
##     wizard mode with a champion bonus at the end.

enum State { ATTRACT, PLAYING, BALL_END, GAME_OVER }

const BALLS_PER_GAME := 3
const BALL_SAVE_TIME := 10.0
const COMBO_WINDOW := 4.0
const TICKETS_FOR_MULTIBALL := 3
const RAMPS_FOR_STAMP := 5
const SPINS_FOR_DOUBLE := 40
const HURRY_START := 300000
const HURRY_MIN := 50000
const HURRY_TIME := 20.0
const WIZARD_TIME := 45.0
const SAVE_PATH := "user://carnival_pinball.cfg"
const CAMERAS := [
	[Vector3(0.4, 20.2, 17.6), Vector3(0.4, 0.0, -1.75), 51.0, "街机视角"],
	[Vector3(0.4, 11.0, 19.5), Vector3(0.4, 0.5, -3.0), 58.0, "低角度视角"],
	[Vector3(0.4, 30.0, 4.0), Vector3(0.4, 0.0, -0.6), 50.0, "俯视视角"],
	[Vector3(0.4, 10.5, 14.0), Vector3(0.4, 0.0, 2.5), 52.0, "跟随视角"],
]
const MYSTERY := ["25,000 分", "50,000 分", "奖励倍数 +1", "救球 15 秒", "大力士升级", "免费票券", "棉花糖 10,000"]
const STAMP_NAMES := ["大力士敲钟", "打鸭子全中", "气球全破", "套圈全中", "滑道 5 次"]
const FORTUNE_WEIGHTS := [3.0, 1.0, 2.5, 2.0, 1.2, 1.2, 2.0, 0.4]

var table: Table
var decor: Decor
var midway: Midway
var hud: Hud
var sfx: Sfx
var camera: Camera3D
var env: Environment
var balls: Array[Ball] = []

var state := State.ATTRACT
var paused := false
var score := 0
var high_score := 0
var ball_number := 0
var extra_balls := 0
var bonus_mult := 1
var lanes_lit: Array[bool] = [false, false, false]
var skill_lane := -1
var skill_active := false
var tickets := 0
var mb_ready := false
var multiball := false
var jackpot_value := 50000
var jp_done := {"left": false, "right": false}
var super_lit := false
var _last_jp_side := ""
var _last_jp_time := -100.0
var striker_level := 0
var ducks_down: Array[bool] = [false, false, false]
var stars_lit: Array[bool] = [false, false, false]
var eb_lit := false
var eb_awarded := false
var wheel_lit := false
var kickback_lit := false
var balloons_popped := 0
var bumper_hits := 0
var spins := 0
var carousel_rides := 0
var combo := 0
var last_ramp_time := -100.0
var ball_save := 0.0
var ball_save_running := false
var balls_to_launch := 0
var double_time := 0.0
var hurry_time := 0.0
var hurry_value := 0
var stamps: Array[bool] = [false, false, false, false, false]
var ramps_for_stamp := 0
var wizard_lit := false
var wizard := false
var wizard_time := 0.0
var wizard_earned := 0
var party := 0.0
var lost_balls := 0
var ball_searches := 0

var _bonus := {}
var _launch_timer := 0.0
var _game_time := 0.0
var _end_timer := 0.0
var _shake := 0.0
var _cam_index := 0
var _cam_pos := Vector3.ZERO
var _cam_look := Vector3.ZERO
var _orbit := 0.0
var _mission_timer := 0.0
var _touch: Dictionary = {}
var _touch_plunger := false
var _plunger_lock := false
var _follow := Vector3(0.4, 0.0, 4.0)
var _barrage := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	_setup_input()
	_setup_environment()
	sfx = Sfx.new()
	sfx.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(sfx)
	table = Table.new()
	table.name = "Table"
	table.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(table)
	table.build()
	table.event.connect(_on_event)
	decor = Decor.new()
	decor.name = "Decor"
	decor.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(decor)
	decor.build()
	decor.fortune_tick.connect(func() -> void: sfx.play("tick", randf_range(0.95, 1.05)))
	decor.fortune_done.connect(_on_fortune_done)
	midway = Midway.new()
	midway.name = "Midway"
	midway.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(midway)
	midway.build()
	hud = Hud.new()
	add_child(hud)
	camera = Camera3D.new()
	camera.far = 400.0
	add_child(camera)
	_apply_camera(true)
	_load()
	_reset_ball_bonus()
	_attract()


# ---------------------------------------------------------------- setup

func _bind(action: String, keys: Array, buttons: Array = []) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.2)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
	for b in buttons:
		var jb := InputEventJoypadButton.new()
		jb.button_index = b
		InputMap.action_add_event(action, jb)


func _setup_input() -> void:
	var had_left := InputMap.has_action("flip_left")
	_bind("flip_left", [KEY_LEFT, KEY_A, KEY_Z], [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_DPAD_LEFT])
	_bind("flip_right", [KEY_RIGHT, KEY_D, KEY_SLASH], [JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_B])
	if not had_left:
		var ls := InputEventKey.new()
		ls.physical_keycode = KEY_SHIFT
		ls.location = KEY_LOCATION_LEFT
		InputMap.action_add_event("flip_left", ls)
		var rs := InputEventKey.new()
		rs.physical_keycode = KEY_SHIFT
		rs.location = KEY_LOCATION_RIGHT
		InputMap.action_add_event("flip_right", rs)
	_bind("plunger", [KEY_DOWN, KEY_S, KEY_SPACE], [JOY_BUTTON_A])
	_bind("start", [KEY_ENTER, KEY_KP_ENTER, KEY_1], [JOY_BUTTON_START])
	_bind("pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_BACK])
	_bind("camera", [KEY_C, KEY_V], [JOY_BUTTON_Y])
	_bind("music", [KEY_M], [])
	_bind("fullscreen", [KEY_F11], [])


func _setup_environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color(0.03, 0.02, 0.12)
	psm.sky_horizon_color = Color(0.55, 0.16, 0.42)
	psm.ground_horizon_color = Color(0.32, 0.08, 0.24)
	psm.ground_bottom_color = Color(0.02, 0.01, 0.05)
	psm.sun_angle_max = 1.0
	sky.sky_material = psm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.34, 0.6)
	env.ambient_light_energy = 0.7
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.85
	env.glow_strength = 1.05
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 0.95
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.ssao_enabled = true
	env.ssao_radius = 0.6
	env.fog_enabled = true
	env.fog_light_color = Color(0.25, 0.08, 0.3)
	env.fog_density = 0.004
	env.fog_sky_affect = 0.2
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60.0, 18.0, 0.0)
	sun.light_energy = 1.0
	sun.light_color = Color(1.0, 0.93, 0.86)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 45.0
	sun.shadow_blur = 1.5
	add_child(sun)


func _apply_camera(instant := false) -> void:
	var c: Array = CAMERAS[_cam_index]
	_cam_pos = c[0]
	_cam_look = c[1]
	camera.fov = c[2]
	if instant:
		camera.look_at_from_position(_cam_pos, _cam_look)


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif event.is_action_pressed("camera"):
		_cam_index = (_cam_index + 1) % CAMERAS.size()
		_apply_camera()
		hud.message(CAMERAS[_cam_index][3], "", Mats.TEAL, 0.9)
	elif event.is_action_pressed("music"):
		var on := sfx.toggle_music()
		hud.message("音乐 " + ("开" if on else "关"), "", Mats.TEAL, 0.9)
	elif event.is_action_pressed("pause") and state != State.ATTRACT:
		_set_paused(not paused)
	elif event.is_action_pressed("start") or (event.is_action_pressed("plunger") and (state == State.ATTRACT or state == State.GAME_OVER)):
		if paused:
			_set_paused(false)
		elif state == State.ATTRACT or state == State.GAME_OVER:
			start_game()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		var size := get_viewport().get_visible_rect().size
		if t.pressed:
			if state != State.PLAYING:
				start_game()
				return
			if t.position.x > size.x * 0.82 and t.position.y > size.y * 0.7:
				_touch_plunger = true
				table.plunger.begin_charge()
			else:
				_touch[t.index] = "L" if t.position.x < size.x * 0.5 else "R"
		else:
			if _touch_plunger and not _touch.has(t.index):
				_touch_plunger = false
				table.plunger.release()
			_touch.erase(t.index)


func _set_paused(p: bool) -> void:
	paused = p
	get_tree().paused = p
	if p:
		hud.show_center("暂停", "按 Esc / P 继续")
	else:
		hud.hide_center()


# ---------------------------------------------------------------- game flow

func _attract() -> void:
	state = State.ATTRACT
	hud.set_ball(0, BALLS_PER_GAME)
	hud.set_score(score, true)
	hud.show_center("嘉年华狂欢派对", "欢迎光临！\n按 Enter 或 空格 开始游戏\n\n最高分  " + Hud.fmt(high_score))
	decor.set_bulb_mode(BulbChain.CHASE)
	for l in table.lamps.values():
		(l as InsertLight).state = InsertLight.BLINK


func start_game() -> void:
	for b: Ball in balls.duplicate():
		_remove_ball(b)
	score = 0
	ball_number = 1
	extra_balls = 0
	eb_lit = false
	eb_awarded = false
	tickets = 0
	mb_ready = false
	multiball = false
	jackpot_value = 50000
	super_lit = false
	jp_done = {"left": false, "right": false}
	striker_level = 0
	bumper_hits = 0
	balloons_popped = 0
	spins = 0
	carousel_rides = 0
	balls_to_launch = 0
	double_time = 0.0
	hurry_time = 0.0
	wheel_lit = false
	stamps = [false, false, false, false, false]
	ramps_for_stamp = 0
	wizard_lit = false
	if wizard:
		_end_wizard(false)
	stars_lit = [false, false, false]
	_set_kickback(true)
	decor.set_striker(0)
	table.reset_ducks()
	table.reset_rings()
	ducks_down = [false, false, false]
	for i in 3:
		if not table.balloon_up[i]:
			table.set_balloon(i, true)
	_reset_ball_bonus()
	state = State.PLAYING
	hud.hide_center()
	hud.set_score(0, true)
	hud.set_ball(ball_number, BALLS_PER_GAME)
	hud.shout("欢迎光临！", "按住发射键拉动发射杆", Mats.GOLD, 2.0)
	# the key that started the game must be released before it can plunge
	_plunger_lock = Input.is_action_pressed("plunger")
	sfx.play("start")
	decor.set_bulb_mode(BulbChain.CHASE)
	_apply_camera()
	_serve()


func _reset_ball_bonus() -> void:
	_bonus = {"ramps": 0, "targets": 0, "bumpers": 0, "lanes": 0, "strikes": 0}
	bonus_mult = 1
	lanes_lit = [false, false, false]
	combo = 0
	last_ramp_time = -100.0
	hud.set_bonus_mult(1)


func _serve() -> void:
	_spawn_ball()
	skill_lane = randi() % 3
	skill_active = true
	ball_save = BALL_SAVE_TIME
	ball_save_running = false


func _spawn_ball() -> Ball:
	var b := Ball.new()
	b.position = Table.BALL_START
	table.add_child(b)
	balls.append(b)
	return b


func _remove_ball(b: Ball) -> void:
	balls.erase(b)
	if is_instance_valid(b):
		if table.saucer.held == b:
			table.saucer.held = null
		b.queue_free()


func _queue_launch(n: int) -> void:
	balls_to_launch += n
	_launch_timer = minf(_launch_timer, 0.4)


func _lane_clear() -> bool:
	for b in balls:
		if b.global_position.x > 5.08 and b.global_position.z > 6.0:
			return false
	return true


func _live_balls() -> int:
	return balls.size() + balls_to_launch


func _set_kickback(on: bool) -> void:
	kickback_lit = on
	table.kickback_enabled = on


func _start_multiball() -> void:
	multiball = true
	mb_ready = false
	tickets = 0
	super_lit = false
	jp_done = {"left": false, "right": false}
	jackpot_value = maxi(jackpot_value, 50000)
	ball_save = maxf(ball_save, 12.0)
	ball_save_running = true
	_queue_launch(2)
	hud.shout("嘉年华多球！", "射滑道赢大奖", Mats.PINK, 2.6)
	sfx.play("siren")
	sfx.play("jackpot", 1.0, -4.0)
	_celebrate(3, 0.4)
	decor.set_bulb_mode(BulbChain.SPARKLE)


func _end_multiball() -> void:
	multiball = false
	super_lit = false
	hud.message("多球结束", "大奖累计至 " + Hud.fmt(jackpot_value), Mats.TEAL, 1.8)
	decor.set_bulb_mode(BulbChain.CHASE)


func _start_wizard() -> void:
	wizard_lit = false
	wizard = true
	wizard_time = WIZARD_TIME
	wizard_earned = 0
	multiball = false
	mb_ready = false
	ball_save = maxf(ball_save, 15.0)
	ball_save_running = true
	_queue_launch(2)
	table.disc_speed = 6.0
	sfx.music_player.pitch_scale = 1.12
	hud.shout("狂欢之夜！", "全场三倍积分 · 滑道狂欢大奖 · 45 秒", Mats.PURPLE, 3.0)
	sfx.play("fanfare")
	sfx.play("siren", 1.2, -6.0)
	_celebrate(6, 0.5)
	_barrage = WIZARD_TIME
	decor.set_bulb_mode(BulbChain.SPARKLE)


func _end_wizard(completed: bool) -> void:
	wizard = false
	wizard_time = 0.0
	_barrage = 0.0
	table.disc_speed = 2.4
	sfx.music_player.pitch_scale = 1.0
	stamps = [false, false, false, false, false]
	ramps_for_stamp = 0
	if completed:
		var bonus := 1000000 + wizard_earned
		_add(bonus, true)
		hud.shout("狂欢总冠军！", "冠军奖励 " + Hud.fmt(bonus), Mats.GOLD, 3.2)
		sfx.play("fanfare")
		_celebrate(8, 0.5)
	decor.set_bulb_mode(BulbChain.CHASE)


func _end_of_ball() -> void:
	state = State.BALL_END
	table.flipper_l.pressed = false
	table.flipper_r.pressed = false
	if wizard:
		_end_wizard(false)
	if multiball:
		multiball = false
		decor.set_bulb_mode(BulbChain.CHASE)
	double_time = 0.0
	hurry_time = 0.0
	var b := _bonus
	var base: int = b.ramps * 2500 + b.targets * 500 + b.bumpers * 100 + b.lanes * 500 + b.strikes * 1000
	var total := base * bonus_mult
	score += total
	hud.set_score(score)
	hud.show_center("本球结算", "滑道 %d   靶子 %d   弹跳柱 %d\n翻滚道 %d   敲钟 %d\n\n%s  ×%d  =  %s" % [
		b.ramps, b.targets, b.bumpers, b.lanes, b.strikes, Hud.fmt(base), bonus_mult, Hud.fmt(total)])
	sfx.play("drain")
	decor.set_bulb_mode(BulbChain.ALTERNATE)
	_end_timer = 3.2


func _after_bonus() -> void:
	_reset_ball_bonus()
	if extra_balls > 0:
		extra_balls -= 1
		state = State.PLAYING
		hud.hide_center()
		hud.shout("再来一球！", "同一位玩家", Mats.ORANGE, 2.0)
		decor.set_bulb_mode(BulbChain.CHASE)
		_serve()
		return
	ball_number += 1
	if ball_number > BALLS_PER_GAME:
		_game_over()
		return
	state = State.PLAYING
	hud.hide_center()
	hud.set_ball(ball_number, BALLS_PER_GAME)
	hud.shout("第 %d 球" % ball_number, "欢迎光临！", Mats.GOLD, 1.6)
	decor.set_bulb_mode(BulbChain.CHASE)
	_serve()


func _game_over() -> void:
	state = State.GAME_OVER
	var best := score > high_score
	if best:
		high_score = score
		_save()
	hud.set_hiscore(high_score)
	hud.set_ball(0, BALLS_PER_GAME)
	var body := "最终得分  " + Hud.fmt(score)
	if best:
		body += "\n新纪录！"
		_celebrate(5, 0.2)
		sfx.play("jackpot")
	body += "\n\n按 Enter 或 空格 再玩一局"
	hud.show_center("游戏结束", body)
	decor.set_bulb_mode(BulbChain.CHASE)
	for l in table.lamps.values():
		(l as InsertLight).state = InsertLight.BLINK


# ---------------------------------------------------------------- scoring

func _score_mult() -> int:
	var m := 1
	if double_time > 0.0:
		m *= 2
	if wizard:
		m *= 3
	return m


## Adds points (multiplied by Double Scoring / wizard mode unless `raw`) and
## returns what was actually scored, for the banner.
func _add(points: int, raw := false) -> int:
	var p := points if raw else points * _score_mult()
	score += p
	if wizard:
		wizard_earned += p
	hud.set_score(score)
	return p


## Confetti, fireworks, flashing bulbs and a camera bump.
func _celebrate(fireworks: int, shake: float) -> void:
	decor.confetti()
	decor.flash_bulbs(1.2)
	for i in fireworks:
		get_tree().create_timer(i * 0.18, false).timeout.connect(_firework_near)
	party = 1.0
	_shake = maxf(_shake, shake)


func _firework_near() -> void:
	midway.burst(true)
	sfx.play("firework", randf_range(0.85, 1.15), -4.0)


func _end_skill() -> void:
	skill_active = false


func _on_event(kind: String, data: Dictionary) -> void:
	if kind == "drain":
		_on_drain(data["ball"])
		return
	if kind == "saucer" and state != State.PLAYING:
		table.saucer.hold_for(0.5)
		return
	if state != State.PLAYING:
		return
	match kind:
		"bumper":
			bumper_hits += 1
			_bonus.bumpers += 1
			_add(250 + 50 * mini(15, bumper_hits / 10))
			sfx.play("bumper", [1.0, 1.12, 0.9][int(data["index"])])
			_shake = maxf(_shake, 0.06)
			_end_skill()
		"sling":
			_add(50)
			sfx.play("sling", randf_range(0.95, 1.05))
			_end_skill()
		"lane":
			_on_lane(int(data["index"]))
		"inlane":
			_add(1000)
			sfx.play("rollover", 0.9)
			table.flash_lamp("inlane_" + str(data["side"]), 0.8)
		"outlane":
			_add(2500)
			sfx.play("thunk")
			table.flash_lamp("outlane_" + str(data["side"]), 1.2)
			if ball_save <= 0.0 and not multiball and not wizard and not (str(data["side"]) == "left" and kickback_lit):
				hud.message("哎哟！", "外道 +2,500", Mats.RED, 1.2)
		"spinner":
			_on_spinner()
		"ramp":
			_on_ramp(str(data["side"]))
		"striker":
			_on_striker(bool(data["front"]))
		"duck":
			_on_duck(int(data["index"]))
		"balloon":
			_on_balloon(int(data["index"]))
		"ring":
			_on_ring(int(data["index"]))
		"star":
			_on_star(int(data["index"]))
		"carousel":
			_on_carousel()
		"kickback":
			_on_kickback()
		"saucer":
			_on_saucer()
		"launch":
			sfx.play("launch", 0.9 + float(data["power"]) * 0.3)


func _on_lane(i: int) -> void:
	sfx.play("rollover", 1.0 + i * 0.12)
	if skill_active and i == skill_lane:
		var p := _add(25000)
		hud.shout("技巧球！", Hud.fmt(p), Mats.LIME, 1.8)
		sfx.play("jackpot", 1.1, -4.0)
		decor.flash_bulbs(0.8)
	_end_skill()
	if not lanes_lit[i]:
		lanes_lit[i] = true
		_bonus.lanes += 1
		_add(500)
	else:
		_add(100)
	if lanes_lit[0] and lanes_lit[1] and lanes_lit[2]:
		lanes_lit = [false, false, false]
		_add(5000)
		for k in 3:
			table.flash_lamp("lane%d" % k, 1.2)
		if bonus_mult < 5:
			bonus_mult += 1
			hud.set_bonus_mult(bonus_mult)
			hud.message("F-U-N 全亮！", "奖励倍数 %dX" % bonus_mult, Mats.GOLD, 1.5)
		else:
			var p := _add(20000)
			hud.message("F-U-N 全亮！", "满倍奖励 +" + Hud.fmt(p), Mats.GOLD, 1.5)
		sfx.play("cash")


func _rotate_lanes(dir: int) -> void:
	if dir < 0:
		lanes_lit = [lanes_lit[1], lanes_lit[2], lanes_lit[0]]
	else:
		lanes_lit = [lanes_lit[2], lanes_lit[0], lanes_lit[1]]


func _on_spinner() -> void:
	spins += 1
	_add(100)
	sfx.play("spinner", randf_range(0.95, 1.1))
	if spins % SPINS_FOR_DOUBLE == 0:
		double_time = maxf(double_time, 20.0)
		hud.message("双倍积分！", "旋转片 %d 圈 · 20 秒" % spins, Mats.GOLD, 1.6)
		sfx.play("cash", 1.2)


func _on_ramp(side: String) -> void:
	var now := _game_time
	if now - last_ramp_time < COMBO_WINDOW:
		combo += 1
	else:
		combo = 0
	last_ramp_time = now
	_bonus.ramps += 1
	sfx.play("ramp", 1.0 if side == "left" else 1.15)
	if side == "right":
		decor.spin_wheel(5.0)
	_end_skill()
	if not wizard:
		ramps_for_stamp += 1
		if ramps_for_stamp >= RAMPS_FOR_STAMP:
			_stamp(4)
	if hurry_time > 0.0:
		var hp := _add(hurry_value)
		hurry_time = 0.0
		hud.shout("限时大奖！", Hud.fmt(hp), Mats.ORANGE, 2.0)
		sfx.play("jackpot")
		_celebrate(3, 0.3)
		return
	if wizard:
		var wp := _add(300000, true)
		hud.shout("狂欢大奖！", Hud.fmt(wp), Mats.PURPLE, 1.6)
		sfx.play("jackpot")
		_celebrate(2, 0.3)
		return
	if multiball:
		var jp := jackpot_value
		var title := "大奖！"
		if _last_jp_side != "" and _last_jp_side != side and now - _last_jp_time < 4.0:
			jp *= 2
			title = "双倍大奖！"
		var got := _add(jp)
		jackpot_value += 10000
		_last_jp_side = side
		_last_jp_time = now
		jp_done[side] = true
		hud.shout(title, Hud.fmt(got), Mats.PINK, 2.0)
		sfx.play("jackpot")
		_celebrate(2, 0.35)
		if jp_done["left"] and jp_done["right"] and not super_lit:
			super_lit = true
			hud.message("超级大奖已点亮！", "射中大力士 · 大奖 ×3", Mats.GOLD, 2.0)
			sfx.play("siren", 1.3, -6.0)
		return
	var pts := _add(5000 * (combo + 1))
	if combo > 0:
		hud.message("连击 ×%d！" % (combo + 1), Hud.fmt(pts), Mats.PINK, 1.4)
	else:
		hud.message("过山车！" if side == "left" else "摩天轮！", Hud.fmt(pts), Mats.GOLD, 1.3)
	if not mb_ready:
		tickets += 1
		if tickets >= TICKETS_FOR_MULTIBALL:
			mb_ready = true
			hud.message("多球已点亮", "射向售票亭", Mats.PINK, 2.2)
			sfx.play("siren", 1.0, -4.0)


func _on_striker(front: bool) -> void:
	if not front:
		_add(10)
		return
	_end_skill()
	if wizard:
		var wp := _add(150000, true)
		hud.shout("大力神！", Hud.fmt(wp), Mats.PURPLE, 1.4)
		sfx.play("bell")
		decor.ring_bell()
		return
	if multiball and super_lit:
		var sp := _add(jackpot_value * 3)
		super_lit = false
		jp_done = {"left": false, "right": false}
		hud.shout("超级大奖！", Hud.fmt(sp), Mats.GOLD, 2.6)
		sfx.play("bell")
		sfx.play("jackpot")
		decor.ring_bell()
		_celebrate(6, 0.5)
		return
	striker_level += 1
	_bonus.strikes += 1
	sfx.play("thunk", 0.8 + striker_level * 0.12)
	if striker_level >= 5:
		var p := _add(100000 if multiball else 50000)
		hud.shout("当当当！", "大力士敲钟 " + Hud.fmt(p), Mats.GOLD, 2.2)
		sfx.play("bell")
		decor.ring_bell()
		_celebrate(3, 0.3)
		striker_level = 0
		get_tree().create_timer(1.6).timeout.connect(func() -> void: decor.set_striker(striker_level))
		_stamp(0)
		if not multiball and not wizard:
			hurry_value = HURRY_START
			hurry_time = HURRY_TIME
			hud.message("限时抢分！", "20 秒内射滑道", Mats.ORANGE, 2.0)
	else:
		_add(1000 * striker_level)
		decor.set_striker(striker_level)
		var names := ["", "弱鸡！", "还行！", "很强！", "超强！"]
		hud.message("大力士", names[striker_level], Mats.ORANGE, 1.0)


func _on_duck(i: int) -> void:
	ducks_down[i] = true
	_bonus.targets += 1
	_add(750)
	sfx.play("quack", randf_range(0.9, 1.2))
	sfx.play("drop", 1.0, -6.0)
	_end_skill()
	if ducks_down[0] and ducks_down[1] and ducks_down[2]:
		_add(10000)
		sfx.play("cash")
		if not eb_awarded and not eb_lit:
			eb_lit = true
			hud.message("打鸭子全中！", "额外球已点亮", Mats.ORANGE, 2.0)
		else:
			var p := _add(15000)
			hud.message("打鸭子全中！", "+" + Hud.fmt(p), Mats.ORANGE, 1.6)
		_stamp(1)
		get_tree().create_timer(1.4).timeout.connect(_reset_ducks)


func _reset_ducks() -> void:
	ducks_down = [false, false, false]
	table.reset_ducks()


func _on_balloon(i: int) -> void:
	_end_skill()
	if not table.balloon_up[i]:
		_add(100)
		return
	table.set_balloon(i, false)
	balloons_popped += 1
	_bonus.targets += 1
	_add(1500)
	sfx.play("pop", randf_range(0.9, 1.15))
	if not (table.balloon_up[0] or table.balloon_up[1] or table.balloon_up[2]):
		_add(10000)
		if bonus_mult < 5:
			bonus_mult += 1
			hud.set_bonus_mult(bonus_mult)
		hud.message("气球大丰收！", "10,000 + 奖励倍数", Mats.LIME, 1.8)
		sfx.play("cash")
		_stamp(2)
		get_tree().create_timer(2.0).timeout.connect(_reinflate_balloons)


func _reinflate_balloons() -> void:
	for k in 3:
		table.set_balloon(k, true)


func _on_ring(i: int) -> void:
	_end_skill()
	if table.ring_done[i]:
		_add(300)
		sfx.play("clink", 0.8)
		return
	table.set_ring(i, true)
	_bonus.targets += 1
	_add(2000)
	sfx.play("clink", 1.0 + i * 0.1)
	if table.ring_done[0] and table.ring_done[1] and table.ring_done[2]:
		var p := _add(20000)
		_set_kickback(true)
		hud.message("套圈全中！", "+" + Hud.fmt(p) + " · 大炮已装填", Mats.PINK, 2.0)
		sfx.play("cash")
		_stamp(3)
		get_tree().create_timer(1.6).timeout.connect(table.reset_rings)


func _on_star(i: int) -> void:
	_end_skill()
	if stars_lit[i]:
		_add(250)
		sfx.play("chime", 0.8)
		return
	stars_lit[i] = true
	_bonus.targets += 1
	_add(1000)
	sfx.play("chime", 1.0 + i * 0.15)
	if stars_lit[0] and stars_lit[1] and stars_lit[2]:
		stars_lit = [false, false, false]
		var p := _add(15000)
		for k in 3:
			table.flash_lamp("star%d" % k, 1.4)
		if not wheel_lit:
			wheel_lit = true
			hud.message("幸运星全亮！", "幸运大转盘已点亮 · 射售票亭", Mats.SKY, 2.2)
		else:
			hud.message("幸运星全亮！", "+" + Hud.fmt(p), Mats.SKY, 1.6)
		sfx.play("cash")


func _on_carousel() -> void:
	carousel_rides += 1
	_add(2500)
	sfx.play("carousel", randf_range(0.95, 1.08), -4.0)
	if carousel_rides % 5 == 0:
		var p := _add(25000)
		hud.message("旋转木马狂欢！", "第 %d 圈 +%s" % [carousel_rides, Hud.fmt(p)], Mats.PINK, 1.5)


func _on_kickback() -> void:
	_set_kickback(false)
	var p := _add(5000)
	hud.message("大炮发射！", "轰！+" + Hud.fmt(p), Mats.ORANGE, 1.4)
	sfx.play("boom")
	_shake = maxf(_shake, 0.35)


## Carnival Passport: five stamps light the wizard mode.
func _stamp(i: int) -> void:
	if wizard:
		return
	if i == 4:
		ramps_for_stamp = 0
	if stamps[i]:
		return
	stamps[i] = true
	var p := _add(50000)
	table.flash_lamp("stamp%d" % i, 1.5)
	sfx.play("stamp")
	var done := 0
	for s in stamps:
		if s:
			done += 1
	if done == stamps.size():
		wizard_lit = true
		hud.shout("狂欢之夜已点亮！", "护照集满 · 射向售票亭", Mats.PURPLE, 2.6)
		sfx.play("siren", 0.9, -4.0)
	else:
		hud.message("护照盖章！", "%s +%s (%d/5)" % [STAMP_NAMES[i], Hud.fmt(p), done], Mats.LIME, 1.6)


func _on_saucer() -> void:
	_add(3000)
	sfx.play("cash")
	_end_skill()
	var hold := 1.5
	if wizard:
		var wp := _add(100000, true)
		hud.message("售票亭狂欢！", Hud.fmt(wp), Mats.PURPLE, 1.2)
	elif multiball:
		var p := _add(25000)
		hud.message("售票大奖", Hud.fmt(p), Mats.PINK, 1.4)
	elif wizard_lit:
		_start_wizard()
		hold = 2.8
	elif mb_ready:
		_start_multiball()
		hold = 2.4
	elif wheel_lit and not decor.fortune_busy():
		wheel_lit = false
		decor.spin_fortune(_pick_fortune())
		hud.message("幸运大转盘", "转呀转……", Mats.SKY, 3.4)
		hold = 4.3
	elif eb_lit:
		eb_lit = false
		eb_awarded = true
		extra_balls += 1
		hud.shout("额外球！", "", Mats.ORANGE, 2.2)
		sfx.play("jackpot")
		decor.flash_bulbs(1.0)
		hold = 2.0
	else:
		var prize: String = MYSTERY[randi() % MYSTERY.size()]
		match prize:
			"25,000 分":
				_add(25000)
			"50,000 分":
				_add(50000)
			"奖励倍数 +1":
				bonus_mult = mini(5, bonus_mult + 1)
				hud.set_bonus_mult(bonus_mult)
			"救球 15 秒":
				ball_save = maxf(ball_save, 15.0)
				ball_save_running = true
			"大力士升级":
				striker_level = mini(4, striker_level + 1)
				decor.set_striker(striker_level)
			"免费票券":
				if not mb_ready:
					tickets += 1
					if tickets >= TICKETS_FOR_MULTIBALL:
						mb_ready = true
			_:
				_add(10000)
		hud.message("售票亭", prize, Mats.LIME, 1.6)
	table.saucer.hold_for(hold)


func _pick_fortune() -> int:
	var total := 0.0
	for w in FORTUNE_WEIGHTS:
		total += float(w)
	var r := randf() * total
	for i in FORTUNE_WEIGHTS.size():
		r -= float(FORTUNE_WEIGHTS[i])
		if r <= 0.0:
			return i
	return 0


func _on_fortune_done(index: int) -> void:
	if state != State.PLAYING:
		return
	var label: String = Decor.FORTUNE_LABELS[index]
	var sub := ""
	match index:
		0:
			sub = Hud.fmt(_add(100000))
		1:
			extra_balls += 1
			sub = "额外球 +1"
		2:
			sub = Hud.fmt(_add(250000))
		3:
			double_time = maxf(double_time, 30.0)
			sub = "双倍积分 30 秒"
		4:
			sub = Hud.fmt(_add(500000))
		5:
			if multiball or wizard:
				sub = Hud.fmt(_add(250000))
			else:
				_start_multiball()
				sub = "开启多球"
		6:
			_set_kickback(true)
			sub = "大炮已装填 +" + Hud.fmt(_add(50000))
		_:
			sub = Hud.fmt(_add(1000000))
	hud.shout("转盘：" + label + "！", sub, Mats.SKY, 2.4)
	sfx.play("jackpot")
	_celebrate(4 if index == 7 else 2, 0.3)


func _on_drain(ball: Ball) -> void:
	_remove_ball(ball)
	if state != State.PLAYING:
		return
	if ball_save > 0.0:
		_queue_launch(1)
		hud.message("救球！", "", Mats.TEAL, 1.4)
		if not multiball and not wizard:
			ball_save = 0.0
		return
	if multiball:
		if _live_balls() <= 1:
			_end_multiball()
		return
	if _live_balls() > 0:
		return
	_end_of_ball()


# ---------------------------------------------------------------- per frame

func _physics_process(delta: float) -> void:
	if paused:
		return
	_game_time += delta
	var playing := state == State.PLAYING
	var l := playing and (Input.is_action_pressed("flip_left") or _touch.values().has("L"))
	var r := playing and (Input.is_action_pressed("flip_right") or _touch.values().has("R"))
	if l != table.flipper_l.pressed:
		table.flipper_l.pressed = l
		sfx.play("flipper" if l else "flipper_down", 1.0)
		if l:
			_rotate_lanes(-1)
	if r != table.flipper_r.pressed:
		table.flipper_r.pressed = r
		sfx.play("flipper" if r else "flipper_down", 1.08)
		if r:
			_rotate_lanes(1)
	if _plunger_lock and not Input.is_action_pressed("plunger"):
		_plunger_lock = false
	if playing and not _plunger_lock:
		if Input.is_action_just_pressed("plunger"):
			table.plunger.begin_charge()
		elif Input.is_action_just_released("plunger"):
			table.plunger.release()
	hud.set_power(table.plunger.charge)

	if playing and not ball_save_running:
		for b in balls:
			if not b.in_shooter_lane():
				ball_save_running = true
				break
	if ball_save_running and ball_save > 0.0:
		ball_save = maxf(0.0, ball_save - delta)
	if playing:
		double_time = maxf(0.0, double_time - delta)
		if hurry_time > 0.0:
			hurry_time = maxf(0.0, hurry_time - delta)
			hurry_value = maxi(HURRY_MIN, int(HURRY_START - (HURRY_TIME - hurry_time) / HURRY_TIME * (HURRY_START - HURRY_MIN)))
			if hurry_time <= 0.0:
				hud.message("限时抢分结束", "", Mats.TEAL, 1.0)
		if wizard:
			wizard_time = maxf(0.0, wizard_time - delta)
			if wizard_time <= 0.0:
				_end_wizard(true)

	if balls_to_launch > 0 and playing:
		_launch_timer -= delta
		if _launch_timer <= 0.0 and _lane_clear():
			balls_to_launch -= 1
			_spawn_ball()
			_launch_timer = 1.2
			get_tree().create_timer(0.45, false).timeout.connect(_auto_fire)

	_check_balls()
	if state == State.BALL_END:
		_end_timer -= delta
		if _end_timer <= 0.0:
			_after_bonus()


func _auto_fire() -> void:
	table.plunger.fire(randf_range(0.8, 0.92))


func _check_balls() -> void:
	for b: Ball in balls.duplicate():
		if not is_instance_valid(b):
			balls.erase(b)
			continue
		var p := b.global_position
		var lost := p.y < -2.0 or p.y > 6.0 or absf(p.x - 0.4) > 6.6 or p.z > 11.5 or p.z < -12.5
		if not lost and b.idle_time > 1.5 and table.in_closed_area(Vector2(p.x, p.z)):
			lost = true
		if lost:
			lost_balls += 1
			_remove_ball(b)
			if state == State.PLAYING:
				_queue_launch(1)
			continue
		var near_flippers := p.z > 6.4 and absf(p.x) < 2.8
		if b.idle_time > 4.0 and not b.in_shooter_lane() and not near_flippers:
			# "ball search": real machines pulse their coils when a ball sits still
			b.idle_time = 0.0
			ball_searches += 1
			b.apply_central_impulse(Vector3(randf_range(-4.0, 4.0), 1.0, randf_range(-8.0, -4.0)))


func _process(delta: float) -> void:
	var floor_party := 0.0
	if wizard:
		floor_party = 1.0
	elif multiball:
		floor_party = 0.6
	elif double_time > 0.0:
		floor_party = 0.35
	party = maxf(floor_party, party - delta * 0.5)
	decor.party = party
	midway.party = party
	table.playfield_mat.set_shader_parameter("party", party)
	if _barrage > 0.0:
		_barrage -= delta
		if randf() < delta * 2.5:
			midway.burst(true)
	_shake = maxf(0.0, _shake - delta * 1.6)
	var attract := state == State.ATTRACT or state == State.GAME_OVER
	if attract:
		# slow sweep across the front of the machine to show off the midway
		_orbit += delta * 0.16
		var a := sin(_orbit) * 1.05
		_cam_pos = Vector3(0.4 + sin(a) * 27.0, 12.0 + sin(_orbit * 0.7) * 3.0, -2.0 + cos(a) * 27.0)
		_cam_look = Vector3(0.4, 1.0, -3.0)
	elif _cam_index == 3:
		_update_follow(delta)
	var target := _cam_pos + Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.4
	camera.position = camera.position.lerp(target, minf(1.0, delta * (1.5 if attract else 6.0)))
	camera.look_at(_cam_look)
	if state == State.PLAYING or state == State.BALL_END:
		_update_lamps()
	_mission_timer -= delta
	if _mission_timer <= 0.0:
		_mission_timer = 0.2
		_update_missions()


## Follow view: keeps the lowest ball (the one about to need a flipper) framed.
func _update_follow(delta: float) -> void:
	var focus := Vector3(0.4, 0.0, 4.0)
	var best := -100.0
	for b in balls:
		var p := b.global_position
		if not b.in_shooter_lane() and p.z > best:
			best = p.z
			focus = p
	_follow = _follow.lerp(focus, minf(1.0, delta * 2.5))
	var z := clampf(_follow.z, -5.5, 5.0)
	var x := 0.4 + (_follow.x - 0.4) * 0.3
	_cam_pos = Vector3(x, 10.5, z + 10.0)
	_cam_look = Vector3(0.4 + (_follow.x - 0.4) * 0.5, 0.0, z - 1.8)


func _update_lamps() -> void:
	for i in 3:
		var s := InsertLight.ON if lanes_lit[i] else InsertLight.OFF
		if skill_active and i == skill_lane:
			s = InsertLight.FAST
		table.set_lamp("lane%d" % i, s)
	var combo_live := _game_time - last_ramp_time < COMBO_WINDOW
	for side in ["left", "right"]:
		var s := InsertLight.OFF
		if wizard or hurry_time > 0.0:
			s = InsertLight.FAST
		elif multiball:
			s = InsertLight.ON if jp_done[side] else InsertLight.FAST
		elif combo_live:
			s = InsertLight.BLINK
		elif not mb_ready:
			s = InsertLight.ON
		table.set_lamp("ramp_" + side, s)
		var js := InsertLight.OFF
		if wizard:
			js = InsertLight.FAST
		elif multiball:
			js = InsertLight.ON if jp_done[side] else InsertLight.BLINK
		table.set_lamp("jackpot_" + side, js)
	for i in 5:
		var s := InsertLight.OFF
		if super_lit or wizard:
			s = InsertLight.FAST
		elif i < striker_level:
			s = InsertLight.ON
		elif i == striker_level:
			s = InsertLight.BLINK
		table.set_lamp("striker%d" % i, s)
	for i in 3:
		table.set_lamp("duck%d" % i, InsertLight.OFF if ducks_down[i] else InsertLight.ON)
		var ts := InsertLight.OFF
		if mb_ready:
			ts = InsertLight.FAST
		elif i < tickets:
			ts = InsertLight.ON
		table.set_lamp("tix%d" % i, ts)
		table.set_lamp("ring%d" % i, InsertLight.ON if table.ring_done[i] else InsertLight.OFF)
		table.set_lamp("star%d" % i, InsertLight.ON if stars_lit[i] else InsertLight.OFF)
	table.set_lamp("mb", InsertLight.FAST if mb_ready else (InsertLight.ON if multiball else InsertLight.OFF))
	table.set_lamp("eb", InsertLight.BLINK if eb_lit else InsertLight.OFF)
	table.set_lamp("wheel", InsertLight.BLINK if wheel_lit else InsertLight.OFF)
	table.set_lamp("kickback", InsertLight.ON if kickback_lit else InsertLight.OFF)
	table.set_lamp("wizard", InsertLight.FAST if wizard_lit else (InsertLight.ON if wizard else InsertLight.OFF))
	table.set_lamp("double", InsertLight.BLINK if double_time > 0.0 else InsertLight.OFF)
	for i in 5:
		table.set_lamp("stamp%d" % i, InsertLight.FAST if wizard else (InsertLight.ON if stamps[i] else InsertLight.OFF))
	for m in range(2, 6):
		table.set_lamp("bonus%d" % m, InsertLight.ON if bonus_mult >= m else InsertLight.OFF)
	var sa := InsertLight.OFF
	if extra_balls > 0:
		sa = InsertLight.ON
	if ball_save > 0.0:
		sa = InsertLight.BLINK if ball_save_running else InsertLight.ON
	table.set_lamp("shoot_again", sa)
	for side in ["left", "right"]:
		table.set_lamp("inlane_" + side, InsertLight.OFF)
		table.set_lamp("outlane_" + side, InsertLight.OFF)


func _bar(n: int, total: int) -> String:
	var s := ""
	for i in total:
		s += "[color=#ffcc33]■[/color]" if i < n else "[color=#554466]■[/color]"
	return s


func _count(arr: Array) -> int:
	var n := 0
	for v in arr:
		if v:
			n += 1
	return n


func _update_missions() -> void:
	var lines: Array[String] = []
	if wizard:
		lines.append("[color=#cc77ff]狂欢之夜！[/color] 剩余 %d 秒" % ceili(wizard_time))
	elif multiball:
		lines.append("[color=#ff66cc]多球进行中[/color]  大奖 " + Hud.fmt(jackpot_value))
		if super_lit:
			lines.append("[color=#ffcc33]超级大奖已点亮 → 大力士[/color]")
	elif mb_ready:
		lines.append("[color=#ff66cc]多球已点亮[/color] → 射售票亭")
	else:
		lines.append("票券  %s  （上滑道得票）" % _bar(tickets, TICKETS_FOR_MULTIBALL))
	lines.append("大力士  " + _bar(striker_level, 5))
	lines.append("打鸭子  " + _bar(_count(ducks_down), 3) + ("  [color=#ff9933]额外球已点亮[/color]" if eb_lit else ""))
	var popped := 0
	for u in table.balloon_up:
		if not u:
			popped += 1
	lines.append("戳气球  " + _bar(popped, 3))
	lines.append("套圈    " + _bar(_count(table.ring_done), 3) + ("  [color=#ff9933]大炮已装填[/color]" if kickback_lit else ""))
	lines.append("幸运星  " + _bar(_count(stars_lit), 3) + ("  [color=#66ccff]转盘已点亮[/color]" if wheel_lit else ""))
	var fun := ""
	var letters := ["F", "U", "N"]
	for i in 3:
		fun += ("[color=#ffcc33]%s[/color]" if lanes_lit[i] else "[color=#554466]%s[/color]") % letters[i]
	lines.append("翻滚道  " + fun)
	var pass_line := "游园护照 "
	for i in 5:
		pass_line += "[color=#88ff55]★[/color]" if stamps[i] else "[color=#554466]☆[/color]"
	if wizard_lit:
		pass_line += "  [color=#cc77ff]狂欢之夜已点亮[/color]"
	lines.append(pass_line)
	hud.set_missions("\n".join(lines))
	var modes: Array[String] = []
	if state == State.PLAYING:
		if wizard:
			modes.append("狂欢之夜 ×3  %d秒" % ceili(wizard_time))
		if double_time > 0.0:
			modes.append("双倍积分 %d秒" % ceili(double_time))
		if hurry_time > 0.0:
			modes.append("限时抢分 " + Hud.fmt(hurry_value))
		if ball_save > 0.0 and ball_save_running:
			modes.append("救球 %d" % ceili(ball_save))
		if extra_balls > 0:
			modes.append("额外球 ×%d" % extra_balls)
	hud.set_mode("\n".join(modes))


# ---------------------------------------------------------------- save

func _exit_tree() -> void:
	Mats.clear_cache()


func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) == OK:
		high_score = int(cf.get_value("scores", "high", 0))
	hud.set_hiscore(high_score)


func _save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("scores", "high", high_score)
	cf.save(SAVE_PATH)
