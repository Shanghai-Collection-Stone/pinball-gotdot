class_name Hud
extends CanvasLayer
## Screen overlay styled like carnival ticket signs.

var score_label: Label
var ball_label: Label
var bonus_label: Label
var hiscore_label: Label
var mission_label: RichTextLabel
var help_label: Label
var msg_box: Control
var msg_title: Label
var msg_sub: Label
var center_overlay: PanelContainer
var center_title: Label
var center_body: Label
var power_bar: ProgressBar
var mode_label: Label

var _shown_score := 0.0
var _target_score := 0
var _msg_queue: Array = []
var _msg_time := 0.0


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# left: score panel
	var left := _panel(Color(0.55, 0.03, 0.1, 0.92), Mats.GOLD)
	left.set_anchors_preset(Control.PRESET_TOP_LEFT)
	left.position = Vector2(22, 22)
	left.custom_minimum_size = Vector2(340, 0)
	root.add_child(left)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 2)
	left.add_child(lv)
	lv.add_child(_label("★ 嘉年华狂欢派对 ★", 32, Mats.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 6, true))
	lv.add_child(_label("弹 珠 游 乐 场", 18, Mats.CREAM, HORIZONTAL_ALIGNMENT_CENTER))
	lv.add_child(_sep())
	lv.add_child(_label("得分", 20, Mats.CREAM))
	score_label = _label("0", 58, Color(1.0, 0.88, 0.35), HORIZONTAL_ALIGNMENT_RIGHT, 8, true)
	lv.add_child(score_label)
	var row := HBoxContainer.new()
	lv.add_child(row)
	ball_label = _label("第 1/3 球", 24, Mats.CREAM)
	ball_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(ball_label)
	bonus_label = _label("奖励 1X", 24, Mats.TEAL, HORIZONTAL_ALIGNMENT_RIGHT)
	row.add_child(bonus_label)
	lv.add_child(_sep())
	hiscore_label = _label("最高分 0", 20, Mats.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	lv.add_child(hiscore_label)
	mode_label = _label("", 22, Mats.PINK, HORIZONTAL_ALIGNMENT_CENTER)
	lv.add_child(mode_label)

	# right: missions + controls
	var right := _panel(Color(0.06, 0.05, 0.22, 0.9), Mats.TEAL)
	right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.offset_left = -372
	right.offset_right = -22
	right.offset_top = 22
	root.add_child(right)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 4)
	right.add_child(rv)
	rv.add_child(_label("游 园 项 目", 30, Mats.TEAL, HORIZONTAL_ALIGNMENT_CENTER, 6, true))
	rv.add_child(_sep(Mats.TEAL))
	mission_label = RichTextLabel.new()
	mission_label.bbcode_enabled = true
	mission_label.fit_content = true
	mission_label.scroll_active = false
	mission_label.custom_minimum_size = Vector2(326, 0)
	mission_label.add_theme_font_override("normal_font", Mats.font())
	mission_label.add_theme_font_size_override("normal_font_size", 19)
	mission_label.add_theme_color_override("default_color", Mats.CREAM)
	rv.add_child(mission_label)
	rv.add_child(_sep(Mats.TEAL))
	help_label = _label("", 16, Color(0.8, 0.85, 1.0))
	help_label.text = "挡板　← / →　A / D　Shift\n发射　按住 ↓ / S / 空格 后松开\n开始 Enter　暂停 Esc / P\n视角 C（4 种）　音乐 M　全屏 F11"
	rv.add_child(help_label)
	rv.add_child(_label("发射力度", 16, Mats.CREAM))
	power_bar = ProgressBar.new()
	power_bar.show_percentage = false
	power_bar.custom_minimum_size = Vector2(326, 16)
	power_bar.max_value = 1.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = Mats.GOLD
	fill.set_corner_radius_all(6)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	bg.set_corner_radius_all(6)
	power_bar.add_theme_stylebox_override("fill", fill)
	power_bar.add_theme_stylebox_override("background", bg)
	rv.add_child(power_bar)

	# message banner (top centre)
	msg_box = VBoxContainer.new()
	msg_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	msg_box.anchor_left = 0.5
	msg_box.anchor_right = 0.5
	msg_box.offset_left = -400
	msg_box.offset_right = 400
	msg_box.offset_top = 110
	msg_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(msg_box)
	msg_title = _label("", 84, Mats.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 18, true)
	msg_box.add_child(msg_title)
	msg_sub = _label("", 32, Mats.CREAM, HORIZONTAL_ALIGNMENT_CENTER, 10)
	msg_box.add_child(msg_sub)
	msg_box.pivot_offset = Vector2(400, 60)
	msg_box.modulate.a = 0.0

	# centre overlay (title / game over / pause / bonus)
	center_overlay = _panel(Color(0.1, 0.02, 0.2, 0.9), Mats.GOLD)
	center_overlay.set_anchors_preset(Control.PRESET_CENTER)
	center_overlay.anchor_left = 0.5
	center_overlay.anchor_right = 0.5
	center_overlay.anchor_top = 0.5
	center_overlay.anchor_bottom = 0.5
	center_overlay.offset_left = -330
	center_overlay.offset_right = 330
	center_overlay.offset_top = -150
	center_overlay.offset_bottom = 150
	root.add_child(center_overlay)
	var cv := VBoxContainer.new()
	cv.alignment = BoxContainer.ALIGNMENT_CENTER
	center_overlay.add_child(cv)
	center_title = _label("", 72, Mats.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 14, true)
	cv.add_child(center_title)
	center_body = _label("", 28, Mats.CREAM, HORIZONTAL_ALIGNMENT_CENTER, 6)
	cv.add_child(center_body)


func _panel(bg: Color, border: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(16)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 10
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _label(text: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, outline := 6, sign := false) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_override("font", Mats.title_font() if sign else Mats.font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.12, 0.0, 0.08))
	l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _sep(col: Color = Mats.GOLD) -> HSeparator:
	var s := HSeparator.new()
	var sb := StyleBoxLine.new()
	sb.color = col
	sb.thickness = 2
	s.add_theme_stylebox_override("separator", sb)
	return s


static func fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


func set_score(v: int, instant := false) -> void:
	_target_score = v
	if instant:
		_shown_score = v


func set_ball(n: int, total: int) -> void:
	ball_label.text = "第 %d/%d 球" % [n, total] if n > 0 else "免费游戏"


func set_bonus_mult(m: int) -> void:
	bonus_label.text = "奖励 %dX" % m


func set_hiscore(v: int) -> void:
	hiscore_label.text = "最高分 " + fmt(v)


func set_mode(text: String) -> void:
	mode_label.text = text


func set_missions(bbcode: String) -> void:
	mission_label.text = bbcode


func set_power(v: float) -> void:
	power_bar.value = v


## Queues a big banner message.
func message(title: String, sub: String = "", col: Color = Mats.GOLD, seconds: float = 1.6) -> void:
	if _msg_queue.size() > 3:
		_msg_queue.pop_front()
	_msg_queue.append([title, sub, col, seconds])
	if _msg_time <= 0.0:
		_next_message()


## Shows a message immediately, replacing whatever is on screen.
func shout(title: String, sub: String = "", col: Color = Mats.GOLD, seconds: float = 1.8) -> void:
	_msg_queue.clear()
	_msg_queue.append([title, sub, col, seconds])
	_next_message()


func _next_message() -> void:
	if _msg_queue.is_empty():
		return
	var m: Array = _msg_queue.pop_front()
	msg_title.text = m[0]
	msg_sub.text = m[1]
	msg_title.add_theme_color_override("font_color", m[2])
	_msg_time = m[3]
	msg_box.modulate.a = 1.0
	msg_box.scale = Vector2(0.3, 0.3)
	var tw := create_tween()
	tw.tween_property(msg_box, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func show_center(title: String, body: String) -> void:
	center_title.text = title
	center_body.text = body
	center_overlay.visible = true


func hide_center() -> void:
	center_overlay.visible = false


func _process(delta: float) -> void:
	if _shown_score < _target_score:
		_shown_score = minf(_target_score, _shown_score + maxf(40.0, (_target_score - _shown_score) * 8.0) * delta)
	else:
		_shown_score = _target_score
	score_label.text = fmt(int(_shown_score))
	if _msg_time > 0.0:
		_msg_time -= delta
		if _msg_time <= 0.0:
			if _msg_queue.is_empty():
				var tw := create_tween()
				tw.tween_property(msg_box, "modulate:a", 0.0, 0.25)
			else:
				_next_message()
