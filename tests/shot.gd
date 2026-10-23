extends SceneTree
## Renders screenshots of the table for visual checks.
## Usage: godot --path . -s tests/shot.gd -- out_dir [camera_index] [start]

var game: Node
var frames := 0
var out_dir := "user://"
var cam := 0
var do_start := false
var custom := PackedFloat32Array()
var settle := 40
var tag := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 1:
		cam = int(args[1])
	if args.size() > 2:
		do_start = args[2] == "start"
	if args.size() > 3 and args[3] != "-":
		for v in args[3].split(","):
			custom.append(float(v))
	if args.size() > 4:
		settle = int(args[4])
	if args.size() > 5:
		tag = args[5]
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5:
		game._cam_index = cam
		game._apply_camera(true)
		if do_start:
			game.start_game()
			game.hud.hide_center()
	if custom.size() == 7:
		game._cam_pos = Vector3(custom[0], custom[1], custom[2])
		game._cam_look = Vector3(custom[3], custom[4], custom[5])
		game.camera.fov = custom[6]
		game.camera.look_at_from_position(game._cam_pos, game._cam_look)
	if frames == settle - 30 and tag == "_party":
		game._start_multiball()
		game._on_ramp("right")
	if frames == settle - 40 and tag == "_wizard":
		for i in 5:
			game._stamp(i)
		game._start_wizard()
	if frames == settle - 60 and tag == "_wheel":
		game.decor.spin_fortune(7)
	if frames == settle:
		var img := root.get_texture().get_image()
		img.save_png(out_dir.path_join("shot_cam%d%s%s.png" % [cam, "_play" if do_start else "", tag]))
		return true
	return false
