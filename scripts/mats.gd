class_name Mats
extends RefCounted
## Shared materials, colours and fonts for the carnival look.

const RED := Color(0.86, 0.09, 0.16)
const CREAM := Color(1.0, 0.93, 0.78)
const GOLD := Color(1.0, 0.74, 0.22)
const NAVY := Color(0.07, 0.06, 0.2)
const TEAL := Color(0.0, 0.75, 0.78)
const PINK := Color(1.0, 0.32, 0.66)
const PURPLE := Color(0.55, 0.22, 0.85)
const ORANGE := Color(1.0, 0.5, 0.1)
const LIME := Color(0.55, 1.0, 0.25)
const SKY := Color(0.25, 0.65, 1.0)

static var _cache: Dictionary = {}
static var _font: Font
static var _title_font: Font


static func clear_cache() -> void:
	_cache.clear()
	_font = null
	_title_font = null


static func std(key: String, albedo: Color, metallic: float = 0.0, roughness: float = 0.5) -> StandardMaterial3D:
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.metallic = metallic
	m.roughness = roughness
	_cache[key] = m
	return m


static func chrome() -> StandardMaterial3D:
	return std("chrome", Color(0.97, 0.97, 1.0), 0.75, 0.2)


static func gold() -> StandardMaterial3D:
	return std("gold", Color(1.0, 0.74, 0.3), 0.85, 0.26)


static func candy() -> ShaderMaterial:
	if _cache.has("candy"):
		return _cache["candy"]
	var m := stripes(RED, CREAM, 2.6, 2, 0.08)
	_cache["candy"] = m
	return m


static func rubber() -> StandardMaterial3D:
	return std("rubber", Color(0.97, 0.96, 0.93), 0.0, 0.55)


static func rubber_red() -> StandardMaterial3D:
	return std("rubber_red", Color(0.9, 0.08, 0.12), 0.0, 0.5)


static func dark() -> StandardMaterial3D:
	return std("dark", Color(0.05, 0.03, 0.07), 0.0, 0.6)


static func wood() -> StandardMaterial3D:
	return std("wood", Color(0.42, 0.04, 0.08), 0.2, 0.32)


static func ball() -> StandardMaterial3D:
	if _cache.has("ball"):
		return _cache["ball"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.95, 0.95, 1.0)
	m.metallic = 1.0
	m.roughness = 0.06
	m.metallic_specular = 0.8
	m.emission_enabled = true
	m.emission = Color(0.25, 0.22, 0.3)
	m.emission_energy_multiplier = 0.4
	_cache["ball"] = m
	return m


static func plastic(key: String, color: Color, alpha: float = 0.55) -> StandardMaterial3D:
	if _cache.has("pl_" + key):
		return _cache["pl_" + key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.12
	m.metallic_specular = 0.9
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 0.25
	_cache["pl_" + key] = m
	return m


static func solid(key: String, color: Color, roughness: float = 0.35, emission: float = 0.0) -> StandardMaterial3D:
	if _cache.has("so_" + key):
		return _cache["so_" + key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	_cache["so_" + key] = m
	return m


## A fresh (uncached) emissive material, for things that flash individually.
static func glow(color: Color, energy: float = 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.roughness = 0.3
	return m


static func stripes(color_a: Color, color_b: Color, count: float, mode: int = 0, emission: float = 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/stripes.gdshader")
	m.set_shader_parameter("color_a", color_a)
	m.set_shader_parameter("color_b", color_b)
	m.set_shader_parameter("stripes", count)
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("emission_energy", emission)
	return m


const BODY_FONT := "res://fonts/ZCOOLKuaiLe-Regular.ttf"
const SIGN_FONT := "res://fonts/ZCOOLQingKeHuangYou-Subset.ttf"
const CJK_SYSTEM_FONTS := ["Microsoft YaHei", "PingFang SC", "Hiragino Sans GB", "Noto Sans CJK SC", "Source Han Sans SC", "WenQuanYi Micro Hei", "SimHei", "sans-serif"]


## Playful rounded Chinese font (ZCOOL KuaiLe) used for HUD and small text.
static func font() -> Font:
	if _font == null:
		_font = _load_font(BODY_FONT, null)
	return _font


## Chunky sign-painter font (ZCOOL QingKe HuangYou) for titles and banners.
static func title_font() -> Font:
	if _title_font == null:
		_title_font = _load_font(SIGN_FONT, font())
	return _title_font


static func _load_font(path: String, extra: Font) -> Font:
	var sys := SystemFont.new()
	sys.font_names = PackedStringArray(CJK_SYSTEM_FONTS)
	sys.font_weight = 700
	var f: FontFile = load(path) if ResourceLoader.exists(path) else null
	if f == null:
		return sys
	var fb: Array[Font] = []
	if extra:
		fb.append(extra)
	fb.append(sys)
	f.fallbacks = fb
	return f


static func label3d(text: String, size: int, color: Color, outline: Color = Color(0.1, 0.0, 0.05), outline_size: int = 12, sign := false) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = title_font() if sign else font()
	l.font_size = size
	l.outline_size = outline_size
	l.modulate = color
	l.outline_modulate = outline
	l.pixel_size = 0.005
	l.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return l


## Label lying flat on the playfield, readable from the player's side.
static func floor_label(text: String, size: int, color: Color, pos: Vector2, yaw: float = 0.0, outline_size: int = 10, sign := false) -> Label3D:
	var l := label3d(text, size, color, Color(0.08, 0.0, 0.08), outline_size, sign)
	l.position = Vector3(pos.x, 0.012, pos.y)
	l.rotation = Vector3(-PI * 0.5, yaw, 0.0)
	return l
