extends SceneTree
## Headless physics checks. Run with:
##   godot --headless --fixed-fps 240 --path . -s tests/sim.gd -- <scenario>
## Scenarios:
##   plunge  - plunger power sweep
##   aim     - flip a resting ball from points along each flipper
##   inlane  - ball rolls down an inlane, flipped at different moments
##   ramp    - balls fired straight into each ramp at several speeds
##   play    - a simple bot plays for 10 minutes (add "short" for 90 s)
## Extra flags: trace, dense, densetop, noflip

var game: Node
var table: Table
var scenario := "plunge"
var frame := 0
var events: Array = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		scenario = args[0]
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _log_event(kind: String, data: Dictionary) -> void:
	var d := data.duplicate()
	d.erase("ball")
	events.append([kind, d])


var _started := false
var _t := 0.0
var _stage := 0
var _cases: Array = []
var _case_i := -1
var _ball: Ball
var _rec: Dictionary = {}
var _case_t := 0.0


func _physics_process(delta: float) -> bool:
	frame += 1
	if frame == 3:
		table = game.table
		table.event.connect(_log_event)
		game.start_game()
		for b in game.balls.duplicate():
			game._remove_ball(b)
		_setup_cases()
		_started = true
		return false
	if not _started:
		return false
	_t += delta
	return _tick(delta)


func _setup_cases() -> void:
	match scenario:
		"plunge":
			var powers := [0.0, 0.2, 0.35, 0.5, 0.65, 0.8, 1.0]
			if OS.get_cmdline_user_args().has("dense"):
				powers = [1.0]
			for p in powers:
				_cases.append({"power": p})
		"aim":
			for side in ["left", "right"]:
				for d in [0.35, 0.5, 0.65, 0.8, 0.95, 1.1, 1.25, 1.4, 1.55]:
					_cases.append({"side": side, "d": d})
		"ramp":
			for side in ["left", "right"]:
				for v in [10.0, 14.0, 18.0, 22.0, 28.0, 36.0]:
					_cases.append({"side": side, "v": v})
		"inlane":
			for side in ["left", "right"]:
				var times := [0.92, 0.926, 0.932, 0.938, 0.944, 0.95, 0.956, 0.962]
				if OS.get_cmdline_user_args().has("noflip"):
					times = [9.0]
				if OS.get_cmdline_user_args().has("densetop"):
					times = [0.944]
				for t in times:
					_cases.append({"side": side, "flip_t": t})
		"play":
			_cases.append({"play": true})


func _new_ball(pos: Vector3, vel := Vector3.ZERO) -> Ball:
	var b: Ball = game._spawn_ball()
	b.position = pos
	b.linear_velocity = vel
	return b


func _clear_balls() -> void:
	for b in game.balls.duplicate():
		game._remove_ball(b)
	Input.action_release("flip_left")
	Input.action_release("flip_right")


func _tick(delta: float) -> bool:
	if _case_i >= 0 and _case_i < _cases.size():
		_case_t += delta
		if _run_case(_cases[_case_i], delta):
			return false
		_report(_cases[_case_i])
	_case_i += 1
	if _case_i >= _cases.size():
		print("DONE lost=%d searches=%d" % [game.lost_balls, game.ball_searches])
		return true
	_clear_balls()
	events.clear()
	_case_t = 0.0
	_rec = {"min_z": 99.0, "max_y": 0.0, "trace": []}
	_begin_case(_cases[_case_i])
	return false


func _begin_case(c: Dictionary) -> void:
	game.state = game.State.PLAYING
	game.ball_save = 0.0
	if c.has("power"):
		_ball = _new_ball(Table.BALL_START)
		_rec["fire_at"] = 0.3
	elif c.has("d"):
		var left: bool = c.side == "left"
		var pivot: Vector2 = Table.FLIP_L if left else Table.FLIP_R
		var sx := 1.0 if left else -1.0
		var axis := Vector2(0.866 * sx, 0.5)
		var nrm := Vector2(0.5 * sx, -0.866)
		var d: float = c.d
		var half := Flipper.BASE_R - (Flipper.BASE_R - Flipper.TIP_R) * d / Flipper.LENGTH
		var p := pivot + axis * d + nrm * (half + Ball.RADIUS + 0.01)
		_ball = _new_ball(Vector3(p.x, 0.26, p.y))
		_rec["flip_at"] = 0.02
	elif c.has("flip_t"):
		var sx2 := -1.0 if c.side == "left" else 1.0
		_ball = _new_ball(Vector3(3.86 * sx2, 0.26, 4.2), Vector3(0, 0, 3.0))
		_rec["flip_at"] = float(c.flip_t)
	elif c.has("v"):
		var side: String = c.side
		var m := Table.MOUTH_L if side == "left" else Vector2(-Table.MOUTH_L.x, Table.MOUTH_L.y)
		var t: Vector2 = table._mouth_dir(side)
		var p := m - t * 2.0
		_ball = _new_ball(Vector3(p.x, 0.26, p.y), Vector3(t.x, 0, t.y) * float(c.v))
	elif c.has("play"):
		game.start_game()
		_rec["plunge_at"] = 0.5


func _run_case(c: Dictionary, _delta: float) -> bool:
	if c.has("play"):
		return _run_play()
	if is_instance_valid(_ball) and _ball.is_inside_tree():
		var p := _ball.global_position
		_rec.min_z = minf(_rec.min_z, p.z)
		_rec.max_y = maxf(_rec.max_y, p.y)
		var dense := OS.get_cmdline_user_args().has("dense") and p.z > 5.5
		if OS.get_cmdline_user_args().has("densetop"):
			dense = p.z < 1.5
		if dense and int(_case_t * 240.0) % (1 if OS.get_cmdline_user_args().has("densetop") else 12) == 0:
			_rec.trace.append("t%.2f(%.2f,%.2f,%.2f v%.1f,%.1f,%.1f)" % [_case_t, p.x, p.y, p.z, _ball.linear_velocity.x, _ball.linear_velocity.y, _ball.linear_velocity.z])
		elif not dense and int(_case_t * 240.0) % 60 == 0:
			_rec.trace.append("(%.1f,%.2f,%.1f)" % [p.x, p.y, p.z])
		_rec["last"] = p
		_rec["speed"] = _ball.linear_velocity.length()
		if (c.has("d") or c.has("flip_t")) and not _rec.has("v0") and not _rec.has("flip_at") and _rec.has("flip_t0") and _case_t > float(_rec.flip_t0) + 0.12:
			_rec["v0"] = _ball.linear_velocity
	if c.has("power") and _rec.has("fire_at") and _case_t >= float(_rec.fire_at):
		_rec.erase("fire_at")
		table.plunger.fire(float(c.power))
	if (c.has("d") or c.has("flip_t")) and _rec.has("flip_at") and _case_t >= float(_rec.flip_at):
		_rec["flip_t0"] = _rec.flip_at
		_rec.erase("flip_at")
		Input.action_press("flip_left" if c.side == "left" else "flip_right")
	if (c.has("d") or c.has("flip_t")) and _rec.has("flip_t0") and _case_t > float(_rec.flip_t0) + 0.5:
		Input.action_release("flip_left")
		Input.action_release("flip_right")
	var limit := 5.0
	if not is_instance_valid(_ball) or not _ball.is_inside_tree():
		return _case_t < 0.1
	return _case_t < limit


func _report(c: Dictionary) -> void:
	var kinds := []
	for e in events:
		if e[0] != "launch":
			kinds.append(e[0] + ("" if not e[1].has("side") else ":" + str(e[1].side)) + ("" if not e[1].has("index") else str(e[1].index)))
	var last: Vector3 = _rec.get("last", Vector3.ZERO)
	var extra := ""
	if _rec.has("v0"):
		var v: Vector3 = _rec.v0
		extra = " v0=%.1f dir=(%.2f,%.2f)" % [v.length(), v.normalized().x, v.normalized().z]
	print("%s -> min_z=%.2f max_y=%.2f end=(%.2f,%.2f,%.2f) spd=%.1f%s events=%s" % [str(c), _rec.min_z, _rec.max_y, last.x, last.y, last.z, _rec.get("speed", 0.0), extra, str(kinds)])
	if OS.get_cmdline_user_args().has("trace"):
		print("   trace: ", " ".join(_rec.trace))


# ---- bot play: flips when a ball approaches a flipper

var _counts := {}
var _hold := {}
var _cool := {}
var _next_report := 10.0


func _run_play() -> bool:
	if _rec.has("plunge_at") and _case_t > float(_rec.plunge_at):
		_rec.erase("plunge_at")
	# auto plunge any ball resting in the lane
	for b in game.balls:
		if b.in_shooter_lane() and b.global_position.z > 8.8 and b.linear_velocity.length() < 0.5:
			table.plunger.fire(randf_range(0.45, 1.0))
	var want_l := false
	var want_r := false
	for b in game.balls:
		var p: Vector3 = b.global_position
		var v: Vector3 = b.linear_velocity
		if p.z > 6.6 and p.z < 8.7 and v.z > -2.0:
			if p.x < 0.2 and p.x > -2.4:
				want_l = true
			if p.x > -0.2 and p.x < 2.4:
				want_r = true
	# don't cradle forever: release after a short hold, like a player would
	for a in ["flip_left", "flip_right"]:
		var want := want_l if a == "flip_left" else want_r
		var held: float = _hold.get(a, 0.0)
		if Input.is_action_pressed(a):
			held += 1.0 / 240.0
		else:
			held = 0.0
		_hold[a] = held
		if held > 0.35:
			want = false
			_cool[a] = 0.25 + randf() * 0.3
		var cool: float = _cool.get(a, 0.0)
		if cool > 0.0:
			_cool[a] = cool - 1.0 / 240.0
			want = false
		_set_flip(a, want)
	for e in events:
		var k: String = e[0]
		_counts[k] = int(_counts.get(k, 0)) + 1
	events.clear()
	if _case_t > _next_report:
		_next_report += float(OS.get_cmdline_user_args()[1]) if OS.get_cmdline_user_args().size() > 1 and OS.get_cmdline_user_args()[1].is_valid_float() else 30.0
		var where := ""
		for b in game.balls:
			where += " pos=(%.2f,%.2f,%.2f) v=(%.1f,%.1f,%.1f)" % [b.global_position.x, b.global_position.y, b.global_position.z, b.linear_velocity.x, b.linear_velocity.y, b.linear_velocity.z]
		print("t=%.0f state=%d ball=%d score=%d balls=%d%s counts=%s" % [_case_t, game.state, game.ball_number, game.score, game.balls.size(), where, str(_counts)])
	if game.state == game.State.GAME_OVER:
		print("GAME OVER at t=%.0f score=%d counts=%s" % [_case_t, game.score, str(_counts)])
		game.start_game()
	return _case_t < (90.0 if OS.get_cmdline_user_args().has("short") else 600.0)


func _set_flip(action: String, on: bool) -> void:
	if on and not Input.is_action_pressed(action):
		Input.action_press(action)
	elif not on and Input.is_action_pressed(action):
		Input.action_release(action)
