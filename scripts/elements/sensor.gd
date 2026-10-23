class_name Sensor
extends Area3D
## Invisible trigger volume (rollovers, ramp exits, drain...).

signal triggered(ball: Ball)

var tag := ""
var cooldown := 0.0
var _last: Dictionary = {}


func setup(t: String, size: Vector3, cool: float = 0.3) -> Sensor:
	tag = t
	cooldown = cool
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	add_child(cs)
	body_entered.connect(_on_body_entered)
	return self


func _on_body_entered(body: Node3D) -> void:
	var ball := body as Ball
	if ball == null:
		return
	var now := float(Engine.get_physics_frames()) / float(Engine.physics_ticks_per_second)
	var id := ball.get_instance_id()
	if _last.has(id) and now - float(_last[id]) < cooldown:
		return
	_last[id] = now
	triggered.emit(ball)
