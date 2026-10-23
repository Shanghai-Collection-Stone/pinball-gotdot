class_name Geom
extends RefCounted
## Procedural geometry helpers. The whole table is generated in code, so no
## imported models are needed.
##
## Convention: 2D points are (x, z) on the playfield plane, y is the height
## above the playfield. +z points toward the player (bottom of the table).


static func v3(p: Vector2, y: float = 0.0) -> Vector3:
	return Vector3(p.x, y, p.y)


## Points on a circular arc. Angle 0 points to +x, angles grow toward -z
## (counter-clockwise when looking down at the table).
static func arc(center: Vector2, radius: float, a0: float, a1: float, segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments + 1:
		var a := lerpf(a0, a1, float(i) / float(segments))
		pts.append(center + Vector2(cos(a), -sin(a)) * radius)
	return pts


## Rounded corner: replaces `corner` (between prev and next) with an arc of
## radius r tangent to both segments.
static func fillet(prev: Vector2, corner: Vector2, next: Vector2, r: float, steps: int = 6) -> PackedVector2Array:
	var d1 := (corner - prev).normalized()
	var d2 := (next - corner).normalized()
	var turn := d1.angle_to(d2)
	var t := r * tan(absf(turn) * 0.5)
	var p1 := corner - d1 * t
	var c := p1 + Vector2(-d1.y, d1.x) * signf(turn) * r
	var a0 := (p1 - c).angle()
	var out := PackedVector2Array()
	for i in steps + 1:
		out.append(c + Vector2.from_angle(a0 + turn * float(i) / float(steps)) * r)
	return out


## Offsets an open polyline sideways with mitred joints. Positive d moves the
## line toward the left normal (-t.y, t.x) of each segment.
static func offset_polyline(pts: PackedVector2Array, d: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := pts.size()
	for i in n:
		var n0 := Vector2.ZERO
		var n1 := Vector2.ZERO
		if i > 0:
			var t0 := (pts[i] - pts[i - 1]).normalized()
			n0 = Vector2(-t0.y, t0.x)
		if i < n - 1:
			var t1 := (pts[i + 1] - pts[i]).normalized()
			n1 = Vector2(-t1.y, t1.x)
		var nn: Vector2
		if i == 0:
			nn = n1
		elif i == n - 1:
			nn = n0
		else:
			nn = (n0 + n1).normalized()
			nn = nn / maxf(nn.dot(n1), 0.35)
		out.append(pts[i] + nn * d)
	return out


## Adds a triangle, fixing the winding so the front face points along `n`.
static func tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	if (b - a).cross(c - a).dot(n) > 0.0:
		var tmp := b
		b = c
		c = tmp
	st.set_normal(n)
	st.add_vertex(a)
	st.set_normal(n)
	st.add_vertex(b)
	st.set_normal(n)
	st.add_vertex(c)


## Triangle with per-vertex normals (smooth shading).
static func tri_n(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3) -> void:
	if (b - a).cross(c - a).dot(na + nb + nc) > 0.0:
		var tmp := b
		b = c
		c = tmp
		var tn := nb
		nb = nc
		nc = tn
	st.set_normal(na)
	st.add_vertex(a)
	st.set_normal(nb)
	st.add_vertex(b)
	st.set_normal(nc)
	st.add_vertex(c)


static func quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	tri(st, a, b, c, n)
	tri(st, a, c, d, n)


## Visual mesh of a wall following a polyline.
static func wall_mesh(pts: PackedVector2Array, half_w: float, y0: float, y1: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	add_wall(st, pts, half_w, y0, y1)
	return st.commit()


static func add_wall(st: SurfaceTool, pts: PackedVector2Array, half_w: float, y0: float, y1: float) -> void:
	var l := offset_polyline(pts, half_w)
	var r := offset_polyline(pts, -half_w)
	var n := pts.size()
	for i in n - 1:
		var seg := pts[i + 1] - pts[i]
		var side := Vector2(-seg.y, seg.x).normalized()
		var nl := Vector3(side.x, 0.0, side.y)
		quad(st, v3(l[i], y0), v3(l[i + 1], y0), v3(l[i + 1], y1), v3(l[i], y1), nl)
		quad(st, v3(r[i], y0), v3(r[i + 1], y0), v3(r[i + 1], y1), v3(r[i], y1), -nl)
		quad(st, v3(l[i], y1), v3(l[i + 1], y1), v3(r[i + 1], y1), v3(r[i], y1), Vector3.UP)
	var d0 := (pts[1] - pts[0]).normalized()
	quad(st, v3(l[0], y0), v3(r[0], y0), v3(r[0], y1), v3(l[0], y1), Vector3(-d0.x, 0.0, -d0.y))
	var d1 := (pts[n - 1] - pts[n - 2]).normalized()
	quad(st, v3(l[n - 1], y0), v3(r[n - 1], y0), v3(r[n - 1], y1), v3(l[n - 1], y1), Vector3(d1.x, 0.0, d1.y))


## Adds one convex hull per wall segment. Neighbouring hulls share their mitred
## faces, so a ball can slide along curved walls without catching on seams.
static func add_wall_collision(body: CollisionObject3D, pts: PackedVector2Array, half_w: float, y0: float, y1: float) -> void:
	var l := offset_polyline(pts, half_w)
	var r := offset_polyline(pts, -half_w)
	for i in pts.size() - 1:
		var hull := PackedVector3Array([
			v3(l[i], y0), v3(l[i + 1], y0), v3(r[i], y0), v3(r[i + 1], y0),
			v3(l[i], y1), v3(l[i + 1], y1), v3(r[i], y1), v3(r[i + 1], y1),
		])
		var sh := ConvexPolygonShape3D.new()
		sh.points = hull
		var cs := CollisionShape3D.new()
		cs.shape = sh
		body.add_child(cs)


## Flat polygon facing up.
static func add_polygon(st: SurfaceTool, poly: PackedVector2Array, y: float) -> void:
	var idx := Geometry2D.triangulate_polygon(poly)
	for i in range(0, idx.size(), 3):
		tri(st, v3(poly[idx[i]], y), v3(poly[idx[i + 1]], y), v3(poly[idx[i + 2]], y), Vector3.UP)


static func polygon_mesh(poly: PackedVector2Array, y: float = 0.0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	add_polygon(st, poly, y)
	return st.commit()


## Polygon extruded between y0 and y1 (sides + top cap).
static func add_prism(st: SurfaceTool, poly: PackedVector2Array, y0: float, y1: float, top := true) -> void:
	var n := poly.size()
	for i in n:
		var a := poly[i]
		var b := poly[(i + 1) % n]
		var e := (b - a).normalized()
		var nrm := Vector2(e.y, -e.x)
		if Geometry2D.is_point_in_polygon((a + b) * 0.5 + nrm * 0.01, poly):
			nrm = -nrm
		quad(st, v3(a, y0), v3(b, y0), v3(b, y1), v3(a, y1), Vector3(nrm.x, 0.0, nrm.y))
	if top:
		add_polygon(st, poly, y1)


static func prism_mesh(poly: PackedVector2Array, y0: float, y1: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	add_prism(st, poly, y0, y1)
	return st.commit()


static func circle_poly(center: Vector2, r: float, segments: int = 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		var a := TAU * float(i) / float(segments)
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	return pts


## Outline of two circles joined by tangents (flipper / stadium shape).
static func capsule_poly(a: Vector2, ra: float, b: Vector2, rb: float, segments: int = 20) -> PackedVector2Array:
	var pts := circle_poly(a, ra, segments)
	pts.append_array(circle_poly(b, rb, segments))
	var hull := Geometry2D.convex_hull(pts)
	hull.remove_at(hull.size() - 1)
	return hull


static func star_poly(r_out: float, r_in: float, points: int = 5) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in points * 2:
		var a := -PI * 0.5 + PI * float(i) / float(points)
		var r := r_out if i % 2 == 0 else r_in
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts


## Shapes for playfield insert lamps. Arrows and triangles point toward -z.
static func insert_poly(shape: String, size: Vector2) -> PackedVector2Array:
	var w := size.x * 0.5
	var h := size.y * 0.5
	match shape:
		"arrow":
			return PackedVector2Array([
				Vector2(0, -h), Vector2(w, -h + w), Vector2(w * 0.42, -h + w),
				Vector2(w * 0.42, h), Vector2(-w * 0.42, h), Vector2(-w * 0.42, -h + w), Vector2(-w, -h + w),
			])
		"tri":
			return PackedVector2Array([Vector2(0, -h), Vector2(w, h), Vector2(-w, h)])
		"rect":
			return PackedVector2Array([Vector2(-w, -h), Vector2(w, -h), Vector2(w, h), Vector2(-w, h)])
		"star":
			return star_poly(w, w * 0.45)
		_:
			return circle_poly(Vector2.ZERO, w, 28)


## Smooth Catmull-Rom path through control points, resampled at even spacing.
static func smooth_path(ctrl: Array, ds: float) -> PackedVector3Array:
	var dense := PackedVector3Array()
	var n := ctrl.size()
	for i in n - 1:
		var p0: Vector3 = ctrl[maxi(i - 1, 0)]
		var p1: Vector3 = ctrl[i]
		var p2: Vector3 = ctrl[i + 1]
		var p3: Vector3 = ctrl[mini(i + 2, n - 1)]
		for s in 24:
			dense.append(p1.cubic_interpolate(p2, p0, p3, float(s) / 24.0))
	dense.append(ctrl[n - 1])
	return resample(dense, ds)


static func resample(pts: PackedVector3Array, ds: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	out.append(pts[0])
	var next_d := ds
	var total := 0.0
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var b := pts[i]
		var seg := a.distance_to(b)
		while seg > 0.0 and total + seg >= next_d:
			out.append(a.lerp(b, (next_d - total) / seg))
			next_d += ds
		total += seg
	var last := pts[pts.size() - 1]
	if out[out.size() - 1].distance_to(last) > ds * 0.35:
		out.append(last)
	else:
		out[out.size() - 1] = last
	return out


static func path_lengths(path: PackedVector3Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var acc := 0.0
	out.append(0.0)
	for i in range(1, path.size()):
		acc += path[i - 1].distance_to(path[i])
		out.append(acc)
	return out


## One frame per path point. basis.x = side (left), basis.y = local up,
## basis.z = forward tangent.
static func path_frames(path: PackedVector3Array) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	var n := path.size()
	for i in n:
		var a := path[maxi(i - 1, 0)]
		var b := path[mini(i + 1, n - 1)]
		var t := (b - a).normalized()
		var s := Vector3.UP.cross(t).normalized()
		var nn := t.cross(s).normalized()
		out.append(Transform3D(Basis(s, nn, t), path[i]))
	return out


## Cross-section of the ball channel shared by plastic ramps and wire rails:
## flat floor, filleted corners, vertical side walls. (u = side, v = up)
static func trough_profile(half_w: float = 0.38, fillet: float = 0.2, top: float = 0.62) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(Vector2(-half_w, top))
	pts.append(Vector2(-half_w, fillet))
	for i in range(1, 6):
		var a := PI + PI * 0.5 * float(i) / 6.0
		pts.append(Vector2(-half_w + fillet + cos(a) * fillet, fillet + sin(a) * fillet))
	pts.append(Vector2(-half_w + fillet, 0.0))
	pts.append(Vector2(half_w - fillet, 0.0))
	for i in range(1, 6):
		var a := PI * 1.5 + PI * 0.5 * float(i) / 6.0
		pts.append(Vector2(half_w - fillet + cos(a) * fillet, fillet + sin(a) * fillet))
	pts.append(Vector2(half_w, fillet))
	pts.append(Vector2(half_w, top))
	return pts


static func _fp(f: Transform3D, p: Vector2, w: float = 1.0) -> Vector3:
	return f * Vector3(p.x * w, p.y, 0.0)


static func _w(widths: PackedFloat32Array, i: int) -> float:
	return widths[i] if i < widths.size() else 1.0


## Triangle soup for a ConcavePolygonShape3D swept along frames [i0, i1].
## `widths` optionally scales the profile sideways per frame (entry funnels).
static func sweep_faces(frames: Array[Transform3D], profile: PackedVector2Array, widths := PackedFloat32Array(), i0: int = 0, i1: int = -1) -> PackedVector3Array:
	if i1 < 0:
		i1 = frames.size() - 1
	var faces := PackedVector3Array()
	for i in range(i0, i1):
		var fa := frames[i]
		var fb := frames[i + 1]
		var wa := _w(widths, i)
		var wb := _w(widths, i + 1)
		for j in profile.size() - 1:
			var a := _fp(fa, profile[j], wa)
			var b := _fp(fa, profile[j + 1], wa)
			var c := _fp(fb, profile[j + 1], wb)
			var d := _fp(fb, profile[j], wb)
			faces.append_array(PackedVector3Array([a, b, c, a, c, d]))
	return faces


## Smooth-shaded visual surface swept along frames [i0, i1]. Normals point to
## the inside of the channel.
static func add_sweep(st: SurfaceTool, frames: Array[Transform3D], profile: PackedVector2Array, i0: int, i1: int, widths := PackedFloat32Array()) -> void:
	var pn := PackedVector2Array()
	var m := profile.size()
	for j in m:
		var acc := Vector2.ZERO
		if j > 0:
			var e0 := profile[j] - profile[j - 1]
			acc += Vector2(-e0.y, e0.x).normalized()
		if j < m - 1:
			var e1 := profile[j + 1] - profile[j]
			acc += Vector2(-e1.y, e1.x).normalized()
		pn.append(acc.normalized())
	for i in range(i0, i1):
		var fa := frames[i]
		var fb := frames[i + 1]
		var wa := _w(widths, i)
		var wb := _w(widths, i + 1)
		for j in m - 1:
			var a := _fp(fa, profile[j], wa)
			var b := _fp(fa, profile[j + 1], wa)
			var c := _fp(fb, profile[j + 1], wb)
			var d := _fp(fb, profile[j], wb)
			var na := (fa.basis.x * pn[j].x + fa.basis.y * pn[j].y).normalized()
			var nb := (fa.basis.x * pn[j + 1].x + fa.basis.y * pn[j + 1].y).normalized()
			var nc := (fb.basis.x * pn[j + 1].x + fb.basis.y * pn[j + 1].y).normalized()
			var nd := (fb.basis.x * pn[j].x + fb.basis.y * pn[j].y).normalized()
			tri_n(st, a, b, c, na, nb, nc)
			tri_n(st, a, c, d, na, nc, nd)


## Path traced by a fixed (u, v) offset in every frame (used for wires/rims).
static func offset_path(frames: Array[Transform3D], uv: Vector2, i0: int, i1: int, widths := PackedFloat32Array()) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in range(i0, i1 + 1):
		out.append(_fp(frames[i], uv, _w(widths, i)))
	return out


## Round tube along a 3D polyline (parallel-transport frames, no end caps).
static func add_tube(st: SurfaceTool, path: PackedVector3Array, radius: float, sides: int = 8) -> void:
	var n := path.size()
	if n < 2:
		return
	var t0 := (path[1] - path[0]).normalized()
	var ref := Vector3.UP if absf(t0.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
	var nrm := ref.cross(t0).normalized()
	var prev_t := t0
	var rings_p: Array[PackedVector3Array] = []
	var rings_n: Array[PackedVector3Array] = []
	for i in n:
		var t: Vector3
		if i == 0:
			t = t0
		elif i == n - 1:
			t = (path[i] - path[i - 1]).normalized()
		else:
			t = (path[i + 1] - path[i - 1]).normalized()
		var axis := prev_t.cross(t)
		if axis.length() > 0.000001:
			nrm = nrm.rotated(axis.normalized(), prev_t.angle_to(t))
		prev_t = t
		var bin := t.cross(nrm).normalized()
		var rp := PackedVector3Array()
		var rn := PackedVector3Array()
		for k in sides:
			var a := TAU * float(k) / float(sides)
			var dir := nrm * cos(a) + bin * sin(a)
			rp.append(path[i] + dir * radius)
			rn.append(dir)
		rings_p.append(rp)
		rings_n.append(rn)
	for i in n - 1:
		for k in sides:
			var k2 := (k + 1) % sides
			tri_n(st, rings_p[i][k], rings_p[i][k2], rings_p[i + 1][k2], rings_n[i][k], rings_n[i][k2], rings_n[i + 1][k2])
			tri_n(st, rings_p[i][k], rings_p[i + 1][k2], rings_p[i + 1][k], rings_n[i][k], rings_n[i + 1][k2], rings_n[i + 1][k])


static func add_cylinder_between(st: SurfaceTool, a: Vector3, b: Vector3, radius: float, sides: int = 8) -> void:
	add_tube(st, PackedVector3Array([a, b]), radius, sides)


## Builds a MeshInstance3D from a SurfaceTool, with a material.
static func instance(st: SurfaceTool, mat: Material, shadows := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func new_st() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


## Rotation around Y that makes local -Z point along the 2D direction d.
static func yaw_toward(d: Vector2) -> float:
	return atan2(-d.x, -d.y)
