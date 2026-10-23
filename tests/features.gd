extends SceneTree
## Headless checks for the midway games and the luxury scoring rules.
##   godot --headless --fixed-fps 240 --path . -s tests/features.gd

var game: Node
var table: Table
var events: Array[String] = []
var failures := 0


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	_run()


func _wait(sec: float) -> void:
	for i in int(sec * 240.0):
		await physics_frame


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failures += 1


func _fresh() -> void:
	game.start_game()
	for b in game.balls.duplicate():
		game._remove_ball(b)
	game.ball_save = 0.0
	events.clear()


func _ball(pos: Vector3, vel: Vector3) -> Ball:
	var b: Ball = game._spawn_ball()
	b.position = pos
	b.linear_velocity = vel
	return b


func _run() -> void:
	await _wait(0.2)
	table = game.table
	table.event.connect(func(k: String, _d: Dictionary) -> void: events.append(k))

	print("kickback cannon")
	_fresh()
	_check(game.kickback_lit, "cannon is loaded at game start")
	var b := _ball(Vector3(-4.68, 0.26, 4.2), Vector3(0, 0, 6))
	var min_z := 99.0
	for i in 240:
		await physics_frame
		if is_instance_valid(b):
			min_z = minf(min_z, b.global_position.z)
	_check(events.has("kickback"), "outlane ball triggers the cannon")
	_check(min_z < 0.0, "ball fired back up the table (min z %.1f)" % min_z)
	_check(not game.kickback_lit, "cannon is spent after firing")
	events.clear()
	var b2 := _ball(Vector3(-4.68, 0.26, 4.2), Vector3(0, 0, 6))
	await _wait(1.5)
	_check(not events.has("kickback") and events.has("drain"), "unloaded cannon lets the ball drain")
	if is_instance_valid(b2):
		game._remove_ball(b2)

	print("ring toss")
	_fresh()
	for i in 3:
		_ball(Vector3(-3.2, 0.26, float(Table.RING_Z[i])), Vector3(-16, 0, 0))
		await _wait(0.5)
		for bb in game.balls.duplicate():
			game._remove_ball(bb)
	_check(events.count("ring") >= 3, "three ring targets hit (%d)" % events.count("ring"))
	_check(game.stamps[3], "ring toss complete stamps the passport")
	_check(game.kickback_lit, "ring toss reloads the cannon")

	print("carousel disc")
	_fresh()
	var d := _ball(Vector3(0.6, 0.26, 2.6), Vector3(0, 0, 0.5))
	var start_x := d.global_position.x
	await _wait(0.6)
	_check(events.has("carousel"), "riding the disc scores")
	_check(absf(d.global_position.x - start_x) > 0.05 or d.global_position.z < 2.55, "disc drags the ball around")
	game._remove_ball(d)

	print("lucky stars -> wheel of fortune")
	_fresh()
	for i in 3:
		game._on_star(i)
	_check(game.wheel_lit, "three stars light the wheel")
	var fortune := [-1]
	game.decor.fortune_done.connect(func(i: int) -> void: fortune[0] = i)
	var score0: int = game.score
	_ball(Vector3(Table.SAUCER_POS.x, 0.26, Table.SAUCER_POS.y - 0.6), Vector3(0, 0, 2))
	await _wait(5.0)
	_check(fortune[0] >= 0, "wheel spun and stopped on %s" % (Decor.FORTUNE_LABELS[fortune[0]] if fortune[0] >= 0 else "?"))
	_check(game.score > score0, "prize awarded (score %d -> %d)" % [score0, game.score])
	_check(not game.wheel_lit, "wheel is used up")

	print("multiball jackpots")
	_fresh()
	game._start_multiball()
	var s0: int = game.score
	game._on_ramp("left")
	var jp1: int = game.score - s0
	game._game_time += 1.0
	s0 = game.score
	game._on_ramp("right")
	var jp2: int = game.score - s0
	_check(jp2 >= jp1 * 2, "back-to-back ramps give a double jackpot (%d then %d)" % [jp1, jp2])
	_check(game.super_lit, "both ramps light the super jackpot")
	s0 = game.score
	game._on_striker(true)
	_check(game.score - s0 >= game.jackpot_value * 3 - 1, "super jackpot pays 3x (%d)" % (game.score - s0))
	_check(not game.super_lit, "super jackpot resets")
	await _wait(3.0)

	print("hurry-up and double scoring")
	_fresh()
	game.striker_level = 4
	game._on_striker(true)
	_check(game.hurry_time > 0.0 and game.stamps[0], "bell starts the hurry-up and stamps the passport")
	await _wait(4.0)
	var hv: int = game.hurry_value
	_check(hv < Game_HURRY_START() and hv > 50000, "hurry-up counts down (%d)" % hv)
	s0 = game.score
	game._on_ramp("left")
	_check(game.score - s0 >= hv - 20000, "ramp collects the hurry-up (%d)" % (game.score - s0))
	game.double_time = 10.0
	s0 = game.score
	game._on_carousel()
	_check(game.score - s0 == 5000, "double scoring doubles points (%d)" % (game.score - s0))

	print("passport -> 狂欢之夜")
	_fresh()
	for i in 5:
		game._stamp(i)
	_check(game.wizard_lit, "five stamps light the wizard mode")
	_ball(Vector3(Table.SAUCER_POS.x, 0.26, Table.SAUCER_POS.y - 0.6), Vector3(0, 0, 2))
	await _wait(1.0)
	_check(game.wizard, "booth starts 狂欢之夜")
	s0 = game.score
	game._on_carousel()
	_check(game.score - s0 == 7500, "wizard mode triples points (%d)" % (game.score - s0))
	await _wait(4.0)
	_check(game.balls.size() + game.balls_to_launch >= 2, "wizard mode is a multiball (%d balls)" % game.balls.size())
	game.wizard_time = 0.2
	s0 = game.score
	await _wait(0.5)
	_check(not game.wizard and game.score - s0 >= 1000000, "champion bonus at the end (%d)" % (game.score - s0))
	_check(not game.stamps[0], "passport resets after the wizard mode")

	print("lost=%d searches=%d" % [game.lost_balls, game.ball_searches])
	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures else 0)


func Game_HURRY_START() -> int:
	return 300000
