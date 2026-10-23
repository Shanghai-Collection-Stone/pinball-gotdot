class_name InsertLight
extends Node3D
## Playfield insert lamp: coloured plastic that glows when lit.

enum { OFF, ON, BLINK, FAST }

var state := OFF
var color := Color.WHITE
var mat: StandardMaterial3D
var label: Label3D
var flash_time := 0.0
var _t := 0.0


func setup(shape: String, size: Vector2, col: Color, text: String = "", text_size: int = 40) -> InsertLight:
	color = col
	_t = randf() * 2.0
	mat = StandardMaterial3D.new()
	mat.albedo_color = col.darkened(0.6)
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 0.05
	mat.roughness = 0.15
	var mi := MeshInstance3D.new()
	mi.mesh = Geom.polygon_mesh(Geom.insert_poly(shape, size), 0.0)
	mi.material_override = mat
	mi.position.y = 0.006
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var rim := MeshInstance3D.new()
	var poly := Geom.insert_poly(shape, size + Vector2(0.08, 0.08))
	rim.mesh = Geom.polygon_mesh(poly, 0.0)
	rim.material_override = Mats.solid("insert_rim", Color(0.05, 0.02, 0.06), 0.4)
	rim.position.y = 0.004
	rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rim)
	if text != "":
		label = Mats.label3d(text, text_size, Color(1, 1, 1), Color(0.1, 0.0, 0.1), 8)
		label.rotation.x = -PI * 0.5
		label.position.y = 0.014
		add_child(label)
	return self


func set_state(s: int) -> void:
	state = s


func flash(seconds: float = 1.0) -> void:
	flash_time = seconds


func _process(delta: float) -> void:
	_t += delta
	var on := 0.0
	match state:
		ON:
			on = 1.0
		BLINK:
			on = 1.0 if fmod(_t, 0.7) < 0.38 else 0.0
		FAST:
			on = 1.0 if fmod(_t, 0.22) < 0.11 else 0.0
	if flash_time > 0.0:
		flash_time -= delta
		on = 1.0 if fmod(flash_time, 0.14) < 0.08 else 0.0
	mat.emission_energy_multiplier = lerpf(0.22, 3.4, on)
	mat.albedo_color = color.darkened(lerpf(0.45, 0.05, on))
