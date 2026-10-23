class_name BulbChain
extends MultiMeshInstance3D
## Row of marquee light bulbs animated on the GPU (see bulb.gdshader).

enum { CHASE, ALTERNATE, ALL_ON, SPARKLE, OFF }

var mat: ShaderMaterial
var _flash := 0.0


func setup(points: PackedVector3Array, radius: float, col_a: Color, col_b: Color, speed: float = 6.0, energy: float = 4.0) -> BulbChain:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 10
	sm.rings = 6
	mm.mesh = sm
	mm.instance_count = points.size()
	for i in points.size():
		mm.set_instance_transform(i, Transform3D(Basis(), points[i]))
		mm.set_instance_custom_data(i, Color(float(i), 0, 0, 0))
	multimesh = mm
	mat = ShaderMaterial.new()
	mat.shader = preload("res://shaders/bulb.gdshader")
	mat.set_shader_parameter("color_a", col_a)
	mat.set_shader_parameter("color_b", col_b)
	mat.set_shader_parameter("speed", speed)
	mat.set_shader_parameter("energy", energy)
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return self


func set_mode(m: int) -> void:
	mat.set_shader_parameter("mode", float(m))


func flash(seconds: float = 0.6) -> void:
	_flash = seconds


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash -= delta
		mat.set_shader_parameter("flash", 1.0 if fmod(_flash, 0.16) < 0.09 else 0.0)
		if _flash <= 0.0:
			mat.set_shader_parameter("flash", 0.0)
