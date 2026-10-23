class_name Rollover
extends Sensor
## Wire rollover switch in a lane, with a little chrome wire you can see.


func build_visual(width: float = 0.34) -> Rollover:
	var wire := MeshInstance3D.new()
	var st := Geom.new_st()
	var pts := PackedVector3Array()
	for i in 13:
		var a := PI * float(i) / 12.0
		pts.append(Vector3(cos(a) * width * 0.5, sin(a) * 0.09 + 0.01, 0.0))
	Geom.add_tube(st, pts, 0.018, 6)
	wire.mesh = st.commit()
	wire.material_override = Mats.chrome()
	wire.position.y = -position.y
	add_child(wire)
	return self
