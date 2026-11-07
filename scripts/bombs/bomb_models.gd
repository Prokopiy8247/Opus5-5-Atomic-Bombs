extends RefCounted
## Procedural bomb models, the generic booster missile and parachutes.
##
## Everything is built in code (surfaces of revolution, extruded polygons,
## boxes and tubes merged into one ArrayMesh per part), at real metre scale
## from data/bombs.json (length_m, diameter_m, colors).
##
## Bomb convention: long axis along +X (nose at +X), the model is centred on
## its bounding box along X, the body axis lies on the X axis (y = z = 0).
## Missile convention: long axis along +Y (nose up), nozzle exit at y = 0.
## Parachute convention: attach point (line confluence) at the origin,
## canopy above it (+Y).
##
## Usage: const BombModels = preload("res://scripts/bombs/bomb_models.gd")
##        var node := BombModels.build(Game.bombs[i])

const SEGS := 28          # radial segments of bomb bodies
const SEGS_SMALL := 8     # radial segments of tubes / rings

static var _mat_cache: Dictionary = {}


## Drops the static material cache at exit.
static func release() -> void:
	_mat_cache.clear()


# =========================================================== mesh builder ===

## One surface (one material) of a mesh under construction.
class Surf:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var idx := PackedInt32Array()
	var mat: Material = null

	func vert(p: Vector3, nn: Vector3) -> int:
		v.append(p)
		n.append(nn)
		return v.size() - 1

	## Adds a triangle; the winding is chosen from the vertex normals so that
	## the face is front-facing for Godot (clockwise front faces).
	func tri(a: int, b: int, c: int) -> void:
		var pa: Vector3 = v[a]
		var cr: Vector3 = (v[b] - pa).cross(v[c] - pa)
		if cr.length_squared() < 1e-16:
			return
		var nn: Vector3 = n[a] + n[b] + n[c]
		if cr.dot(nn) > 0.0:
			idx.append(a)
			idx.append(c)
			idx.append(b)
		else:
			idx.append(a)
			idx.append(b)
			idx.append(c)


## Accumulates geometry per material key and builds one MeshInstance3D.
class Geo:
	var surfs: Dictionary = {}
	var order: Array = []
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)

	func mat(key: String, m: Material) -> void:
		if not surfs.has(key):
			surfs[key] = Surf.new()
			order.append(key)
		(surfs[key] as Surf).mat = m

	func surf(key: String) -> Surf:
		if not surfs.has(key):
			push_error("bomb_models: unknown surface key " + key)
			mat(key, StandardMaterial3D.new())
		return surfs[key]

	func vert(s: Surf, p: Vector3, nn: Vector3) -> int:
		lo = lo.min(p)
		hi = hi.max(p)
		return s.vert(p, nn)

	func aabb() -> AABB:
		if lo.x > hi.x:
			return AABB()
		return AABB(lo, hi - lo)

	func tri_count() -> int:
		var t := 0
		for k in order:
			t += int((surfs[k] as Surf).idx.size() / 3.0)
		return t

	static func basis_x(d: Vector3) -> Basis:
		var x := d.normalized()
		var up := Vector3.UP if absf(x.y) < 0.95 else Vector3.BACK
		var y := (up - x * up.dot(x)).normalized()
		var z := x.cross(y)
		return Basis(x, y, z)

	## Surface of revolution around the local X axis. prof = (x, r) points
	## walked so that the solid lies to the right (tail -> nose over the top).
	func lathe(key: String, prof: PackedVector2Array, segs: int, xf: Transform3D = Transform3D.IDENTITY, crease_deg: float = 40.0, th0: float = 0.0, arc: float = TAU) -> void:
		var s := surf(key)
		var np := prof.size()
		if np < 2:
			return
		var nb := xf.basis.inverse().transposed()
		var sn: Array[Vector2] = []
		for i in np - 1:
			var d := prof[i + 1] - prof[i]
			if d.length_squared() < 1e-14:
				sn.append(Vector2.ZERO)
			else:
				d = d.normalized()
				sn.append(Vector2(-d.y, d.x))
		var cc := cos(deg_to_rad(crease_deg))
		for i in np - 1:
			var ns: Vector2 = sn[i]
			if ns == Vector2.ZERO:
				continue
			var na := ns
			if i > 0 and sn[i - 1] != Vector2.ZERO and sn[i - 1].dot(ns) > cc:
				na = (sn[i - 1] + ns).normalized()
			var nz := ns
			if i < np - 2 and sn[i + 1] != Vector2.ZERO and sn[i + 1].dot(ns) > cc:
				nz = (sn[i + 1] + ns).normalized()
			var p0 := prof[i]
			var p1 := prof[i + 1]
			var base := s.v.size()
			for k in segs + 1:
				var th := th0 + arc * float(k) / float(segs)
				var c := cos(th)
				var sv := sin(th)
				vert(s, xf * Vector3(p0.x, p0.y * c, p0.y * sv), (nb * Vector3(na.x, na.y * c, na.y * sv)).normalized())
				vert(s, xf * Vector3(p1.x, p1.y * c, p1.y * sv), (nb * Vector3(nz.x, nz.y * c, nz.y * sv)).normalized())
			for k in segs:
				var a := base + k * 2
				s.tri(a, a + 1, a + 3)
				s.tri(a, a + 3, a + 2)

	## Convex polygon in local XY extruded along local Z (centred).
	func prism(key: String, xf: Transform3D, poly: PackedVector2Array, thick: float) -> void:
		var s := surf(key)
		var nb := xf.basis.inverse().transposed()
		var m := poly.size()
		var h := thick * 0.5
		var cen := Vector2.ZERO
		for p in poly:
			cen += p
		cen /= float(m)
		for side: float in [1.0, -1.0]:
			var nn := (nb * Vector3(0.0, 0.0, side)).normalized()
			var ids: Array[int] = []
			for p in poly:
				ids.append(vert(s, xf * Vector3(p.x, p.y, h * side), nn))
			for k in range(1, m - 1):
				s.tri(ids[0], ids[k], ids[k + 1])
		for k in m:
			var a := poly[k]
			var b := poly[(k + 1) % m]
			var e := b - a
			if e.length_squared() < 1e-14:
				continue
			var en := Vector2(e.y, -e.x).normalized()
			if en.dot((a + b) * 0.5 - cen) < 0.0:
				en = -en
			var nn := (nb * Vector3(en.x, en.y, 0.0)).normalized()
			var i0 := vert(s, xf * Vector3(a.x, a.y, h), nn)
			var i1 := vert(s, xf * Vector3(b.x, b.y, h), nn)
			var i2 := vert(s, xf * Vector3(b.x, b.y, -h), nn)
			var i3 := vert(s, xf * Vector3(a.x, a.y, -h), nn)
			s.tri(i0, i1, i2)
			s.tri(i0, i2, i3)

	## Box of the given size centred at the transform origin.
	func box(key: String, xf: Transform3D, size: Vector3) -> void:
		var hx := size.x * 0.5
		var hy := size.y * 0.5
		prism(key, xf, PackedVector2Array([Vector2(-hx, -hy), Vector2(hx, -hy), Vector2(hx, hy), Vector2(-hx, hy)]), size.z)

	## Rectangular bar from a to b; its width (w) lies along wdir, thickness t across.
	func bar(key: String, a: Vector3, b: Vector3, wdir: Vector3, w: float, t: float) -> void:
		var x := b - a
		var ln := x.length()
		if ln < 1e-6:
			return
		x /= ln
		var y := wdir - x * wdir.dot(x)
		if y.length_squared() < 1e-10:
			y = basis_x(x).y
		y = y.normalized()
		var z := x.cross(y)
		box(key, Transform3D(Basis(x, y, z), (a + b) * 0.5), Vector3(ln, w, t))

	## Round tube (cylinder) from a to b.
	func tube(key: String, a: Vector3, b: Vector3, r: float, segs: int = 6, caps: bool = true) -> void:
		var d := b - a
		var ln := d.length()
		if ln < 1e-6:
			return
		var xf := Transform3D(basis_x(d), a)
		var prof: PackedVector2Array
		if caps:
			prof = PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.0, r), Vector2(ln, r), Vector2(ln, 0.0)])
		else:
			prof = PackedVector2Array([Vector2(0.0, r), Vector2(ln, r)])
		lathe(key, prof, segs, xf)

	func polyline(key: String, pts: PackedVector3Array, r: float, segs: int = 4) -> void:
		for i in pts.size() - 1:
			tube(key, pts[i], pts[i + 1], r, segs, false)

	## Torus around the local X axis of xf (major radius rm, minor radius rt).
	func torus(key: String, xf: Transform3D, rm: float, rt: float, segs: int = 24, rsegs: int = 8) -> void:
		var prof := PackedVector2Array()
		for k in rsegs + 1:
			var ph := TAU - TAU * float(k) / float(rsegs)
			prof.append(Vector2(rt * cos(ph), rm + rt * sin(ph)))
		lathe(key, prof, segs, xf, 70.0)

	func build(nm: String) -> MeshInstance3D:
		var am := ArrayMesh.new()
		for key in order:
			var s: Surf = surfs[key]
			if s.idx.size() < 3:
				continue
			var arr: Array = []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = s.v
			arr[Mesh.ARRAY_NORMAL] = s.n
			arr[Mesh.ARRAY_INDEX] = s.idx
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			am.surface_set_material(am.get_surface_count() - 1, s.mat)
		var mi := MeshInstance3D.new()
		mi.name = nm
		mi.mesh = am
		return mi


# ============================================================ public API ===

## Builds the bomb model at real scale. Long axis +X (nose at +X), centred.
## Metadata on the returned node: "id", "model", "length" (m), "diameter"
## (body diameter, m), "aabb" (AABB in the node's space), "tris",
## "conceptual" (bool, Ivy Mike). Ivy Mike also has a child "Cradle".
static func build(bomb: Dictionary) -> Node3D:
	var L := maxf(float(bomb.get("length_m", 2.0)), 0.1)
	var D := maxf(float(bomb.get("diameter_m", 0.4)), 0.05)
	var R := D * 0.5
	var model := str(bomb.get("model", "generic"))
	var c_body := _col(bomb, "body", Color(0.35, 0.38, 0.3))
	var c_band := _col(bomb, "band", Color(0.9, 0.8, 0.1))
	var c_acc := _col(bomb, "accent", Color(0.2, 0.2, 0.2))
	var g := Geo.new()
	var cradle: Geo = null
	g.mat("body", _mat(c_body, 0.2, 0.55))
	g.mat("band", _mat(c_band, 0.1, 0.5))
	g.mat("acc", _mat(c_acc, 0.4, 0.45))
	g.mat("metal", _mat(Color(0.3, 0.3, 0.31), 0.85, 0.38))
	var body_r := R
	match model:
		"gp_bomb":
			_m_gp(g, L, R, false)
		"gp_bomb_fat":
			_m_gp(g, L, R, true)
		"tallboy":
			_m_tallboy(g, L, R, false)
		"grand_slam":
			_m_tallboy(g, L, R, true)
		"moab":
			_m_moab(g, L, R)
		"watermelon":
			_m_watermelon(g, L, R)
		"foab":
			_m_foab(g, L, R)
		"b61":
			g.mat("body", _mat(c_body, 0.75, 0.3))
			g.mat("acc", _mat(c_acc, 0.7, 0.35))
			_m_b61(g, L, R)
		"little_boy":
			_m_little_boy(g, L, R)
		"shell":
			g.mat("acc", _mat(c_acc, 0.9, 0.32))
			_m_shell(g, L, R)
		"gadget":
			g.mat("body", _mat(c_body, 0.7, 0.42))
			g.mat("acc", _mat(c_acc, 0.6, 0.4))
			g.mat("band", _mat(c_band, 0.1, 0.75))
			_m_gadget(g, L, R)
		"fatman":
			g.mat("band", _mat(c_band, 0.0, 0.8))
			_m_fatman(g, L, R)
		"canister":
			g.mat("body", _mat(c_body, 0.6, 0.4))
			_m_canister(g, L, R)
		"mk18":
			_m_mk18(g, L, R)
		"b83":
			_m_b83(g, L, R)
		"soviet_bomb":
			_m_rds37(g, L, R)
		"sausage":
			g.mat("body", _mat(c_body, 0.55, 0.42))
			cradle = Geo.new()
			cradle.mat("frame", _mat(Color(0.30, 0.29, 0.26), 0.5, 0.55))
			cradle.mat("wood", _mat(Color(0.42, 0.33, 0.22), 0.0, 0.85))
			_m_sausage(g, cradle, L, R)
		"shrimp":
			g.mat("body", _mat(c_body, 0.6, 0.38))
			_m_shrimp(g, L, R)
		"soviet_big":
			_m_test219(g, L, R)
		"tsar":
			_m_tsar(g, L, R)
		_:
			_m_gp(g, L, R, false)
	var root := Node3D.new()
	var bid := str(bomb.get("id", model))
	root.name = "Bomb_" + bid.validate_node_name()
	var box := g.aabb()
	if cradle != null:
		box = box.merge(cradle.aabb())
	var cx := box.get_center().x
	var mi := g.build("Mesh")
	mi.position.x = -cx
	root.add_child(mi)
	var tris := g.tri_count()
	if cradle != null:
		var cm := cradle.build("Cradle")
		cm.position.x = -cx
		root.add_child(cm)
		tris += cradle.tri_count()
	box.position.x -= cx
	root.set_meta("id", bid)
	root.set_meta("model", model)
	root.set_meta("length", box.size.x)
	root.set_meta("diameter", body_r * 2.0)
	root.set_meta("aabb", box)
	root.set_meta("tris", tris)
	root.set_meta("conceptual", model == "sausage" or bool(bomb.get("device", false)))
	return root


## Generic single-stage booster scaled to the bomb. Long axis +Y, nozzle
## exit at y = 0. Children: "Body" (MeshInstance3D), "Payload" (Node3D whose
## origin is the bomb centre; it holds the bomb model "Bomb" rotated so the
## bomb nose points +Y), "Nozzle" (Marker3D at the exhaust, exhaust towards
## -Y). Metadata: "height" (total m), "diameter", "body_length",
## "nozzle_radius", "seat_y" (top of the payload adapter).
static func build_missile(bomb: Dictionary) -> Node3D:
	var bd := maxf(float(bomb.get("diameter_m", 0.5)), 0.05)
	var bl := maxf(float(bomb.get("length_m", 2.0)), 0.1)
	var D := maxf(1.2 * bd, 0.6)
	var R := D * 0.5
	var body_len := clampf(maxf(9.0 * D, 1.3 * bl), 8.0 * D, 12.0 * D)
	var hn := 0.55 * D
	var x0 := hn
	var x1 := hn + body_len
	var g := Geo.new()
	g.mat("white", _mat(Color(0.86, 0.86, 0.83), 0.1, 0.5))
	g.mat("black", _mat(Color(0.05, 0.05, 0.05), 0.1, 0.6))
	g.mat("olive", _mat(Color(0.33, 0.36, 0.24), 0.15, 0.6))
	g.mat("metal", _mat(Color(0.26, 0.26, 0.27), 0.85, 0.35))
	g.mat("nozzle", _mat(Color(0.17, 0.16, 0.15), 0.9, 0.45, true))
	var segs := 32
	# Nozzle bell: exit at x = 0, throat at x = hn.
	var bell := PackedVector2Array()
	for k in 9:
		var s := float(k) / 8.0
		bell.append(Vector2(hn * s, R * (0.30 + 0.36 * pow(1.0 - s, 1.7))))
	g.lathe("nozzle", bell, segs, Transform3D.IDENTITY, 60.0)
	g.torus("metal", Transform3D(Basis.IDENTITY, Vector3(0.026 * D, 0.0, 0.0)), R * 0.66, 0.025 * D, segs, 6)
	# Body: flat base, short boat-tail flare, cylinder, flat top bulkhead.
	var body := PackedVector2Array([Vector2(x0, 0.0), Vector2(x0, 0.74 * R), Vector2(x0 + 0.5 * D, R), Vector2(x1, R), Vector2(x1, 0.0)])
	g.lathe("white", body, segs)
	# Paint: olive engine section and interstage, black roll pattern.
	_band(g, "olive", body, x0, x0 + 1.25 * D, segs, 1.004)
	_band(g, "olive", body, x1 - 0.5 * D, x1, segs, 1.004)
	_band(g, "black", body, x1 - 0.62 * D, x1 - 0.52 * D, segs, 1.004)
	for q in 2:
		_band(g, "black", body, x0 + 1.7 * D, x0 + 3.0 * D, 8, 1.004, PI * float(q), PI * 0.5)
		_band(g, "black", body, x1 - 2.6 * D, x1 - 1.3 * D, 8, 1.004, PI * 0.5 + PI * float(q), PI * 0.5)
	# Dark top bulkhead.
	g.lathe("metal", PackedVector2Array([Vector2(x1 + 0.004 * D, 0.97 * R), Vector2(x1 + 0.004 * D, 0.0)]), segs)
	# Cable raceway.
	var rw := Basis(Vector3.RIGHT, PI * 0.25)
	g.box("olive", Transform3D(rw, rw * Vector3((x0 + 1.4 * D + x1 - 0.3 * D) * 0.5, R + 0.025 * D, 0.0)), Vector3(body_len - 1.7 * D, 0.05 * D, 0.09 * D))
	# Four fins (+ configuration), extending a little below the base.
	_fins(g, "black", body, 4, x0 + 0.02 * D, x0 + 2.3 * D, x0 - 0.3 * D, x0 + 0.75 * D, R + 0.9 * D, 0.05 * D, 0.0)
	# Open-frame payload adapter.
	var h_ad := 0.7 * D
	var r_top := clampf(0.5 * bd * 0.85, 0.3 * R, 0.9 * R)
	var r_bot := 0.86 * R
	var tr := 0.03 * D
	g.torus("metal", Transform3D(Basis.IDENTITY, Vector3(x1 + tr, 0.0, 0.0)), r_bot, tr, segs, 6)
	g.torus("metal", Transform3D(Basis.IDENTITY, Vector3(x1 + h_ad, 0.0, 0.0)), r_top, tr, segs, 6)
	for k in 8:
		var a0 := TAU * float(k) / 8.0
		var a1 := a0 + TAU / 16.0
		var a2 := a0 + TAU / 8.0
		var pb0 := Vector3(x1 + tr, r_bot * cos(a0), r_bot * sin(a0))
		var pt := Vector3(x1 + h_ad, r_top * cos(a1), r_top * sin(a1))
		var pb1 := Vector3(x1 + tr, r_bot * cos(a2), r_bot * sin(a2))
		g.tube("metal", pb0, pt, tr * 0.8, 6)
		g.tube("metal", pt, pb1, tr * 0.8, 6)
	var root := Node3D.new()
	root.name = "Missile"
	var mi := g.build("Body")
	mi.basis = Basis(Vector3(0.0, 0.0, 1.0), PI * 0.5)  # local +X -> +Y
	root.add_child(mi)
	# Payload: the bomb standing nose-up on the adapter.
	var bomb_node := build(bomb)
	bomb_node.name = "Bomb"
	var cr := bomb_node.get_node_or_null("Cradle")
	if cr != null:
		bomb_node.remove_child(cr)
		cr.free()
	var baabb: AABB = bomb_node.get_meta("aabb")
	var seat := x1 + h_ad
	var tail_y := seat - 0.08 * minf(bl, bd)
	var payload := Node3D.new()
	payload.name = "Payload"
	payload.position = Vector3(0.0, tail_y - baabb.position.x, 0.0)
	bomb_node.basis = Basis(Vector3(0.0, 0.0, 1.0), PI * 0.5)
	payload.add_child(bomb_node)
	root.add_child(payload)
	var nz := Marker3D.new()
	nz.name = "Nozzle"
	nz.position = Vector3.ZERO
	root.add_child(nz)
	var height := payload.position.y + baabb.end.x
	root.set_meta("height", height)
	root.set_meta("diameter", D)
	root.set_meta("body_length", body_len)
	root.set_meta("nozzle_radius", R * 0.66)
	root.set_meta("seat_y", seat)
	return root


## Parachute: hemispherical canopy with alternating gores and suspension
## lines. Attach point (line confluence) at the origin, canopy top at +Y.
## Children: "Canopy", "Lines" (MeshInstance3D). Metadata: "height",
## "diameter", "skirt_y".
static func build_parachute(diameter_m: float, color: Color) -> Node3D:
	var dm := maxf(diameter_m, 0.3)
	var rc := dm * 0.5
	var gores := 16
	var line_len := 1.05 * dm
	var skirt_y := sqrt(line_len * line_len - rc * rc)
	var dome_h := 0.62 * rc
	var phi_max := PI * 0.5 * 0.97
	var cmax := cos(phi_max)
	var g := Geo.new()
	g.mat("gore_a", _mat(color, 0.0, 0.85, true))
	g.mat("gore_b", _mat(color.lerp(Color(0.94, 0.93, 0.9), 0.7), 0.0, 0.85, true))
	var rows := 10
	var cols := 4
	var vent := 0.07
	var e := 0.004
	var ctr := Vector3(0.0, skirt_y - rc, 0.0)
	for gi in gores:
		var key := "gore_a" if gi % 2 == 0 else "gore_b"
		var s := g.surf(key)
		var base := s.v.size()
		for rj in rows + 1:
			var v := lerpf(vent, 1.0, float(rj) / float(rows))
			for ci in cols + 1:
				var u := float(ci) / float(cols)
				var p := _canopy_pt(gi, u, v, gores, rc, skirt_y, dome_h, phi_max, cmax)
				var pu := _canopy_pt(gi, u + e, v, gores, rc, skirt_y, dome_h, phi_max, cmax) - _canopy_pt(gi, u - e, v, gores, rc, skirt_y, dome_h, phi_max, cmax)
				var pv := _canopy_pt(gi, u, v + e, gores, rc, skirt_y, dome_h, phi_max, cmax) - _canopy_pt(gi, u, v - e, gores, rc, skirt_y, dome_h, phi_max, cmax)
				var nn := pu.cross(pv).normalized()
				if nn.dot(p - ctr) < 0.0:
					nn = -nn
				g.vert(s, p, nn)
		for rj in rows:
			for ci in cols:
				var a := base + rj * (cols + 1) + ci
				var c := a + cols + 1
				s.tri(a, a + 1, c + 1)
				s.tri(a, c + 1, c)
	var gl := Geo.new()
	gl.mat("line", _mat(Color(0.78, 0.75, 0.68), 0.0, 0.9))
	var lr := maxf(0.0016 * dm, 0.006)
	for k in gores:
		var p := _canopy_pt(k, 0.0, 1.0, gores, rc, skirt_y, dome_h, phi_max, cmax)
		gl.tube("line", p, Vector3.ZERO, lr, 3, false)
	# Small confluence link at the attach point.
	gl.torus("line", Transform3D(Basis(Vector3(0.0, 0.0, 1.0), PI * 0.5), Vector3.ZERO), lr * 4.0, lr * 1.5, 10, 5)
	var root := Node3D.new()
	root.name = "Parachute"
	root.add_child(g.build("Canopy"))
	root.add_child(gl.build("Lines"))
	root.set_meta("height", skirt_y + dome_h)
	root.set_meta("diameter", dm)
	root.set_meta("skirt_y", skirt_y)
	return root


## Suggested canopy diameter (m) for a bomb, from its mass (game estimate).
static func parachute_diameter(bomb: Dictionary) -> float:
	var m := maxf(float(bomb.get("mass_kg", 1000.0)), 1.0)
	return clampf(0.28 * sqrt(m), 5.0, 50.0)


# ================================================================ helpers ===

static func _mat(c: Color, metal: float = 0.15, rough: float = 0.6, double_sided: bool = false) -> StandardMaterial3D:
	var key := "%s_%.2f_%.2f_%d" % [c.to_html(false), metal, rough, int(double_sided)]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	if double_sided:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_cache[key] = m
	return m


static func _col(bomb: Dictionary, field: String, fallback: Color) -> Color:
	var cs: Variant = bomb.get("colors", {})
	if cs is Dictionary and (cs as Dictionary).has(field):
		var a: Variant = cs[field]
		if a is Array and (a as Array).size() >= 3:
			return Color(float(a[0]), float(a[1]), float(a[2]))
	return fallback


static func _x(L: float, t: float) -> float:
	return -0.5 * L + t * L


## Normalised [t, r] points (t: 0 tail .. 1 nose, r in body radii) -> metres.
static func _prof(L: float, R: float, pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(Vector2(_x(L, float(p[0])), float(p[1]) * R))
	return out


## Normalised nose points from t0 (radius r0) to the tip at t1. blunt 0 =
## parabolic (pointed), 1 = elliptical (round). tip = flat tip radius.
static func _nose(t0: float, t1: float, blunt: float, n: int, tip: float = 0.0, r0: float = 1.0) -> Array:
	var pts: Array = []
	for k in range(1, n + 1):
		var u := float(k) / float(n)
		var s := lerpf(u, sin(u * PI * 0.5), blunt)
		var r := lerpf(1.0 - s * s, sqrt(maxf(0.0, 1.0 - s * s)), blunt) * r0
		pts.append([t0 + (t1 - t0) * s, maxf(r, tip)])
	pts.append([t1, 0.0])
	return pts


## Normalised ellipse arc (centre c, half length hl) from t = ta to t = tb.
static func _ellipse(c: float, hl: float, ta: float, tb: float, n: int, rr: float = 1.0) -> Array:
	var pts: Array = []
	var a0 := acos(clampf((c - ta) / hl, -1.0, 1.0))
	var a1 := acos(clampf((c - tb) / hl, -1.0, 1.0))
	for k in n + 1:
		var a := lerpf(a0, a1, float(k) / float(n))
		pts.append([c - hl * cos(a), rr * sin(a)])
	return pts


## Profile radius at axial position x (max over sloped segments).
static func _r_at(prof: PackedVector2Array, x: float) -> float:
	var best := 0.0
	for i in prof.size() - 1:
		var a := prof[i]
		var b := prof[i + 1]
		if b.x - a.x > 1e-6 and x >= a.x - 1e-6 and x <= b.x + 1e-6:
			var t := clampf((x - a.x) / (b.x - a.x), 0.0, 1.0)
			best = maxf(best, lerpf(a.y, b.y, t))
	return best


## A paint band following the body profile between x0 and x1 (optionally only
## an arc of it: th0..th0+arc), slightly proud of the surface.
static func _band(g: Geo, key: String, prof: PackedVector2Array, x0: float, x1: float, segs: int, grow: float = 1.012, th0: float = 0.0, arc: float = TAU) -> void:
	var xs: Array[float] = [x0, x1]
	for k in range(1, 4):
		xs.append(lerpf(x0, x1, float(k) / 4.0))
	for p in prof:
		if p.x > x0 and p.x < x1:
			xs.append(p.x)
	xs.sort()
	var pts := PackedVector2Array()
	var last := -INF
	for x in xs:
		if x - last < 1e-5:
			continue
		last = x
		var r := _r_at(prof, x)
		pts.append(Vector2(x, r * grow + 0.0015))
	g.lathe(key, pts, segs, Transform3D.IDENTITY, 50.0, th0, arc)


## Rectangular-section ring (annulus) from x0 to x1.
static func _ring(g: Geo, key: String, x0: float, x1: float, ri: float, ro: float, segs: int) -> void:
	g.lathe(key, PackedVector2Array([Vector2(x0, ro), Vector2(x1, ro), Vector2(x1, ri), Vector2(x0, ri), Vector2(x0, ro)]), segs)


## n flat fins around the X axis; the root edge follows the body profile.
## x_te/x_le: root trailing/leading edge, tip_te/tip_le: tip edge, r_tip:
## tip radius. roll0: angle of the first fin (0 = +Y). cant in degrees.
static func _fins(g: Geo, key: String, prof: PackedVector2Array, n: int, x_te: float, x_le: float, tip_te: float, tip_le: float, r_tip: float, thick: float, roll0: float = 0.0, cant_deg: float = 0.0) -> void:
	var r_te := _r_at(prof, x_te) * 0.95
	var r_le := _r_at(prof, x_le) * 0.95
	var poly := PackedVector2Array([Vector2(x_te, r_te), Vector2(x_le, r_le), Vector2(tip_le, r_tip), Vector2(tip_te, r_tip)])
	var pivot := Vector3((x_te + x_le) * 0.5, (r_le + r_tip) * 0.5, 0.0)
	for k in n:
		var phi := roll0 + TAU * float(k) / float(n)
		var xf := Transform3D(Basis(Vector3.RIGHT, phi), Vector3.ZERO)
		if cant_deg != 0.0:
			xf = xf * Transform3D(Basis.IDENTITY, pivot) * Transform3D(Basis(Vector3.UP, deg_to_rad(cant_deg)), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -pivot)
		g.prism(key, xf, poly, thick)


## Square shroud of 4 plates around the axis from x0 to x1 (half side `half`).
static func _box_tail(g: Geo, key: String, x0: float, x1: float, half: float, t: float, roll0: float = 0.0) -> void:
	var xm := (x0 + x1) * 0.5
	for k in 4:
		var b := Basis(Vector3.RIGHT, roll0 + PI * 0.5 * float(k))
		g.box(key, Transform3D(b, b * Vector3(xm, half, 0.0)), Vector3(x1 - x0, t, 2.0 * half + t))


## Lattice grid fin. Local frame of xf: X = flow (depth), Y = radial
## (0..h), Z = width (-w/2..w/2).
static func _grid_fin(g: Geo, key: String, xf: Transform3D, w: float, h: float, depth: float, cell: float, bar_t: float) -> void:
	var hw := w * 0.5
	var ax := (xf.basis * Vector3.RIGHT).normalized()
	var ft := bar_t * 2.0
	var corners := [Vector3(0.0, 0.0, -hw), Vector3(0.0, 0.0, hw), Vector3(0.0, h, hw), Vector3(0.0, h, -hw)]
	for k in 4:
		var a: Vector3 = corners[k]
		var b: Vector3 = corners[(k + 1) % 4]
		var dirv := (b - a).normalized()
		g.bar(key, xf * (a - dirv * ft * 0.5), xf * (b + dirv * ft * 0.5), ax, depth, ft)
	var step := cell * 1.41421
	for fam: float in [1.0, -1.0]:
		var c := -hw + step * 0.5
		while c < h + hw:
			# Lines y = fam * z + c clipped to the rectangle.
			var z0: float
			var z1: float
			if fam > 0.0:
				z0 = maxf(-hw, -c)
				z1 = minf(hw, h - c)
			else:
				z0 = maxf(-hw, c - h)
				z1 = minf(hw, c)
			if z1 - z0 > bar_t:
				var a := Vector3(0.0, fam * z0 + c, z0)
				var b := Vector3(0.0, fam * z1 + c, z1)
				g.bar(key, xf * a, xf * b, ax, depth * 0.96, bar_t)
			c += step


## Small box sitting on top (+Y) of the body at axial position x.
static func _lug(g: Geo, key: String, x: float, r: float, size: Vector3) -> void:
	g.box(key, Transform3D(Basis.IDENTITY, Vector3(x, r + size.y * 0.35, 0.0)), size)


## Thin seam line following the profile at angle theta (0 = +Y).
static func _seam(g: Geo, key: String, prof: PackedVector2Array, x0: float, x1: float, theta: float, rt: float, n: int = 14) -> void:
	var pts := PackedVector3Array()
	for k in n + 1:
		var x := lerpf(x0, x1, float(k) / float(n))
		var r := _r_at(prof, x) + rt * 0.3
		pts.append(Vector3(x, r * cos(theta), r * sin(theta)))
	g.polyline(key, pts, rt, 4)


static func _canopy_pt(gi: int, u: float, v: float, gores: int, rc: float, skirt_y: float, dome_h: float, phi_max: float, cmax: float) -> Vector3:
	var th := (float(gi) + u) * TAU / float(gores)
	var phi := v * phi_max
	var uu := clampf(u, 0.0, 1.0)
	var bul := 1.0 + 0.05 * sin(PI * uu) * sin(clampf(v, 0.0, 1.0) * PI * 0.5 + 0.3)
	var r := rc * sin(phi) * bul * (1.0 - 0.04 * pow(clampf(v, 0.0, 1.2), 8.0))
	var y := skirt_y + dome_h * (cos(phi) - cmax) / (1.0 - cmax)
	y += 0.05 * rc * sin(PI * uu) * pow(clampf(v, 0.0, 1.2), 6.0)
	return Vector3(r * cos(th), y, r * sin(th))


## 32 evenly spread directions: the 12 vertices of an icosahedron plus the 20
## vertices of its dual dodecahedron (face centres of a truncated icosahedron).
## Neighbouring directions are ~37 degrees apart.
static func _ti_dirs() -> Array[Vector3]:
	var p := (1.0 + sqrt(5.0)) * 0.5
	var ip := 1.0 / p
	var out: Array[Vector3] = []
	for s1: float in [-1.0, 1.0]:
		for s2: float in [-1.0, 1.0]:
			# Icosahedron (0, +-1, +-p) and cyclic permutations.
			out.append(Vector3(0.0, s1, s2 * p).normalized())
			out.append(Vector3(s1, s2 * p, 0.0).normalized())
			out.append(Vector3(s2 * p, 0.0, s1).normalized())
			# Dual dodecahedron (0, +-p, +-1/p) and cyclic permutations, then
			# (+-1, +-1, +-1). The dual must use this orientation: the
			# (0, +-1/p, +-p) set lies only ~11 degrees from the icosahedron
			# vertices, which made the detonator boxes overlap in pairs.
			out.append(Vector3(0.0, s1 * p, s2 * ip).normalized())
			out.append(Vector3(s1 * ip, 0.0, s2 * p).normalized())
			out.append(Vector3(s2 * p, s1 * ip, 0.0).normalized())
			for s3: float in [-1.0, 1.0]:
				out.append(Vector3(s1, s2, s3).normalized())
	return out


# ================================================================= models ===

## Mk 82 / Mk 84 low-drag general purpose bomb.
static func _m_gp(g: Geo, L: float, R: float, fat: bool) -> void:
	var pts: Array
	var t_nose := 0.64
	if fat:
		pts = [[0.0, 0.0], [0.0, 0.40], [0.22, 0.62], [0.26, 0.70], [0.31, 0.88], [0.36, 0.98], [0.40, 1.0], [0.66, 1.0]]
		t_nose = 0.66
		pts.append_array(_nose(t_nose, 0.975, 0.38, 12, 0.19))
	else:
		pts = [[0.0, 0.0], [0.0, 0.38], [0.24, 0.60], [0.27, 0.66], [0.33, 0.86], [0.38, 0.97], [0.42, 1.0], [0.64, 1.0]]
		pts.append_array(_nose(t_nose, 0.975, 0.12, 12, 0.17))
	var P := _prof(L, R, pts)
	g.lathe("body", P, SEGS)
	# Fuze.
	g.lathe("acc", _prof(L, R, [[0.974, 0.0], [0.974, 0.17], [0.99, 0.15], [1.0, 0.09], [1.0, 0.0]]), 16)
	# Yellow HE band(s) on the nose.
	if fat:
		_band(g, "band", P, _x(L, 0.68), _x(L, 0.70), SEGS)
		_band(g, "band", P, _x(L, 0.72), _x(L, 0.74), SEGS)
	else:
		_band(g, "band", P, _x(L, 0.69), _x(L, 0.72), SEGS)
	# Conical fin assembly: 4 clipped-delta fins in X configuration.
	var span := 1.39 if fat else 1.41
	_fins(g, "body", P, 4, _x(L, 0.0), _x(L, 0.23), _x(L, 0.0), _x(L, 0.075), span * R, maxf(0.006, 0.035 * R), PI * 0.25)
	# Suspension lugs.
	var lug := Vector3(0.18 * R, 0.24 * R, 0.16 * R)
	var gap := 0.16 if not fat else 0.2
	_lug(g, "metal", _x(L, 0.53 - gap * 0.5), R, lug)
	_lug(g, "metal", _x(L, 0.53 + gap * 0.5), R, lug)
	# Weld seam ring where the tail cone meets the body.
	_band(g, "acc", P, _x(L, 0.265), _x(L, 0.275), SEGS, 1.006)


## Tallboy / Grand Slam earthquake bombs: long teardrop body, long tail tube.
static func _m_tallboy(g: Geo, L: float, R: float, grand: bool) -> void:
	var tail_key := "acc"
	var fin_key := "acc"
	if grand:
		tail_key = "band"
		fin_key = "band"
	var tail := _prof(L, R, [[0.0, 0.0], [0.0, 0.27], [0.36, 0.33], [0.39, 0.37], [0.39, 0.0]])
	g.lathe(tail_key, tail, 20)
	var pts: Array = [[0.385, 0.0], [0.385, 0.37], [0.42, 0.45], [0.48, 0.64], [0.54, 0.79], [0.61, 0.91], [0.68, 0.98], [0.74, 1.0]]
	pts.append_array(_nose(0.74, 1.0, 0.42 if not grand else 0.32, 12, 0.0))
	var P := _prof(L, R, pts)
	g.lathe("body", P, SEGS)
	var full := _prof(L, R, [[0.0, 0.27], [0.36, 0.33], [0.39, 0.37]] + pts.slice(2))
	# Four long canted fins on the tail tube (they spin the bomb).
	_fins(g, fin_key, full, 4, _x(L, 0.0), _x(L, 0.31), _x(L, 0.0), _x(L, 0.22), 1.0 * R, maxf(0.01, 0.02 * R), PI * 0.25, 5.0)
	if grand:
		# Black/white photogrammetry test paint: alternating quadrants.
		for q in 2:
			_band(g, "band", P, _x(L, 0.47), _x(L, 0.62), 8, 1.006, PI * float(q), PI * 0.5)
			_band(g, "band", P, _x(L, 0.62), _x(L, 0.77), 8, 1.006, PI * 0.5 + PI * float(q), PI * 0.5)
		_band(g, "band", P, _x(L, 0.92), _x(L, 1.0), SEGS, 1.006)
	else:
		_band(g, "band", P, _x(L, 0.80), _x(L, 0.83), SEGS)
		_band(g, "acc", P, _x(L, 0.385), _x(L, 0.40), SEGS, 1.006)
	_lug(g, "metal", _x(L, 0.66), R, Vector3(0.1 * R, 0.12 * R, 0.08 * R))


## GBU-43/B MOAB: long tube, rounded nose, 4 lattice grid fins.
static func _m_moab(g: Geo, L: float, R: float) -> void:
	var pts: Array = [[0.0, 0.0], [0.0, 0.80], [0.012, 0.87], [0.035, 0.95], [0.065, 1.0], [0.86, 1.0]]
	pts.append_array(_nose(0.86, 1.0, 0.85, 12, 0.22))
	var P := _prof(L, R, pts)
	g.lathe("body", P, SEGS)
	g.lathe("acc", PackedVector2Array([Vector2(_x(L, 0.0) - 0.003, 0.0), Vector2(_x(L, 0.0) - 0.003, 0.78 * R)]), SEGS)
	_band(g, "band", P, _x(L, 0.815), _x(L, 0.825), SEGS)
	_band(g, "band", P, _x(L, 0.84), _x(L, 0.85), SEGS)
	# Four grid fins (X configuration) at the tail.
	var w := 1.35 * R
	var h := 1.45 * R
	var depth := 0.3 * R
	for k in 4:
		var phi := PI * 0.25 + PI * 0.5 * float(k)
		var b := Basis(Vector3.RIGHT, phi)
		var xf := Transform3D(b, b * Vector3(_x(L, 0.0) + depth * 0.5 + 0.02 * L, 0.98 * R, 0.0))
		_grid_fin(g, "acc", xf, w, h, depth, w / 5.0, maxf(0.008, 0.016 * R))
		# Hinge block.
		g.box("metal", Transform3D(b, b * Vector3(_x(L, 0.0) + depth * 0.5 + 0.02 * L, 0.98 * R, 0.0)), Vector3(depth * 1.4, 0.12 * R, 0.3 * R))
	# Carriage rail on top.
	g.box("metal", Transform3D(Basis.IDENTITY, Vector3(_x(L, 0.5), R + 0.02 * R, 0.0)), Vector3(0.45 * L, 0.06 * R, 0.12 * R))


## M388 Davy Crockett round: watermelon warhead on a thin spigot with fins.
static func _m_watermelon(g: Geo, L: float, R: float) -> void:
	g.lathe("metal", _prof(L, R, [[0.0, 0.0], [0.0, 0.2], [0.44, 0.2], [0.44, 0.0]]), 12)
	var pts: Array = [[0.40, 0.0], [0.40, 0.40], [0.46, 0.40]]
	pts.append_array(_ellipse(0.715, 0.285, 0.46, 1.0, 18))
	var P := _prof(L, R, pts)
	g.lathe("body", P, SEGS)
	_band(g, "band", P, _x(L, 0.68), _x(L, 0.745), SEGS)
	# Nose fuze ring.
	_band(g, "acc", P, _x(L, 0.975), _x(L, 0.99), 16, 1.03)
	var rod := _prof(L, R, [[0.0, 0.2], [0.44, 0.2]])
	_fins(g, "acc", rod, 4, _x(L, 0.0), _x(L, 0.13), _x(L, 0.0), _x(L, 0.06), 0.8 * R, 0.004, PI * 0.25)
	# Spigot collar ring.
	_ring(g, "acc", _x(L, 0.13), _x(L, 0.16), 0.18 * R, 0.30 * R, 12)


## "Father of All Bombs": fat cylinder, rounded nose, ring tail.
static func _m_foab(g: Geo, L: float, R: float) -> void:
	var pts: Array = [[0.0, 0.0], [0.0, 0.70], [0.05, 0.82], [0.10, 0.93], [0.15, 0.99], [0.18, 1.0], [0.80, 1.0]]
	pts.append_array(_nose(0.80, 1.0, 0.92, 12, 0.0))
	var P := _prof(L, R, pts)
	g.lathe("body", P, SEGS)
	_band(g, "band", P, _x(L, 0.70), _x(L, 0.74), SEGS)
	_band(g, "acc", P, _x(L, 0.96), _x(L, 1.0), SEGS, 1.006)
	_ring(g, "acc", _x(L, 0.0), _x(L, 0.11), 0.93 * R, 1.0 * R, SEGS)
	_fins(g, "acc", P, 4, _x(L, 0.005), _x(L, 0.105), _x(L, 0.005), _x(L, 0.105), 0.95 * R, maxf(0.012, 0.025 * R), PI * 0.25)
	_lug(g, "metal", _x(L, 0.42), R, Vector3(0.12 * R, 0.1 * R, 0.08 * R))
	_lug(g, "metal", _x(L, 0.62), R, Vector3(0.12 * R, 0.1 * R, 0.08 * R))


## B61: slim, long pointed nose, 4 tail-kit fins, silver.
static func _m_b61(g: Geo, L: float, R: float) -> void:
	var pts: Array = [[0.0, 0.0], [0.0, 0.78], [0.10, 0.90], [0.17, 0.98], [0.20, 1.0], [0.66, 1.0]]
	pts.append_array(_nose(0.66, 0.995, 0.05, 14, 0.10))
	var P := _prof(L, R, pts)
	g.lathe("body", P, SEGS)
	_band(g, "band", P, _x(L, 0.645), _x(L, 0.66), SEGS, 1.008)
	_band(g, "acc", P, _x(L, 0.0), _x(L, 0.20), SEGS, 1.006)
	_fins(g, "acc", P, 4, _x(L, 0.0), _x(L, 0.14), _x(L, 0.0), _x(L, 0.05), 1.9 * R, 0.008, PI * 0.25)
	_lug(g, "metal", _x(L, 0.45), R, Vector3(0.25 * R, 0.2 * R, 0.15 * R))


## Little Boy: long cylinder, blunt nose, box tail with diagonal fins.
static func _m_little_boy(g: Geo, L: float, R: float) -> void:
	var pts: Array = [[0.0, 0.0], [0.0, 0.30], [0.20, 0.38], [0.25, 0.55], [0.29, 0.78], [0.32, 0.93], [0.35, 1.0], [0.87, 1.0]]
	pts.append_array(_nose(0.87, 1.0, 1.0, 12, 0.32))
	var P := _prof(L, R, pts)
	g.lathe("body", P, SEGS)
	_band(g, "acc", P, _x(L, 0.865), _x(L, 0.875), SEGS, 1.006)
	_band(g, "acc", P, _x(L, 0.50), _x(L, 0.51), SEGS, 1.006)
	var half := 0.97 * R
	var t := maxf(0.008, 0.02 * R)
	_box_tail(g, "body", _x(L, 0.0), _x(L, 0.21), half, t)
	_fins(g, "body", P, 4, _x(L, 0.0), _x(L, 0.24), _x(L, 0.0), _x(L, 0.21), half * 1.41, t, PI * 0.25)
	_lug(g, "metal", _x(L, 0.6), R, Vector3(0.2 * R, 0.16 * R, 0.12 * R))
	# Fuze antenna stubs on the tail cone.
	for k in 2:
		var s := 1.0 if k == 0 else -1.0
		var a := Vector3(_x(L, 0.27), 0.0, s * 0.7 * R)
		g.tube("metal", a, a + Vector3(-0.1 * L, 0.0, s * 0.25 * R), 0.012, 5)


## 280 mm artillery shell: ogive nose, copper driving band.
static func _m_shell(g: Geo, L: float, R: float) -> void:
	var pts: Array = [[0.0, 0.0], [0.0, 0.84], [0.05, 0.96], [0.07, 1.0], [0.55, 1.0]]
	pts.append_array(_nose(0.55, 0.955, 0.12, 14, 0.20))
	var P := _prof(L, R, pts)
	g.lathe("body", P, SEGS)
	g.lathe("metal", _prof(L, R, [[0.954, 0.0], [0.954, 0.20], [0.985, 0.15], [1.0, 0.08], [1.0, 0.0]]), 16)
	_ring(g, "acc", _x(L, 0.09), _x(L, 0.14), 0.95 * R, 1.035 * R, SEGS)
	_band(g, "band", P, _x(L, 0.58), _x(L, 0.62), SEGS)


## Trinity "Gadget": a sphere covered with detonator boxes and cables.
static func _m_gadget(g: Geo, L: float, _R: float) -> void:
	var rs := L * 0.5 * 0.9
	var sph := PackedVector2Array()
	for k in 19:
		var a := PI * float(k) / 18.0
		sph.append(Vector2(-rs * cos(a), rs * sin(a)))
	g.lathe("body", sph, SEGS, Transform3D.IDENTITY, 30.0)
	# Bolted equatorial flange and two meridian flanges.
	_ring(g, "metal", -0.02, 0.02, rs * 0.97, rs * 1.03, SEGS)
	g.torus("metal", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO), rs * 1.005, 0.018, SEGS, 6)
	var dirs := _ti_dirs()
	var bs := Vector3(0.13, 0.10, 0.075) * (L / 1.5)
	# Harness rings sit this far from the poles, clear of the nearest
	# detonator boxes (their centres are ~21 degrees from the poles).
	var ring_a := deg_to_rad(12.0)
	for d in dirs:
		var bz := d
		var bx := Geo.basis_x(d).y
		var by := bz.cross(bx)
		g.box("acc", Transform3D(Basis(bx, by, bz), d * (rs + bs.z * 0.5)), bs)
		# Cable from the detonator towards the nearest harness ring.
		var pole := Vector3.UP if d.y >= 0.0 else Vector3.DOWN
		var hz := d - pole * d.dot(pole)
		if hz.length_squared() < 1e-6:
			continue
		hz = hz.normalized()
		var e := (pole * cos(ring_a) + hz * sin(ring_a)).normalized()
		var pts := PackedVector3Array()
		for k in 7:
			var q := d.slerp(e, float(k) / 6.0)
			pts.append(q * (rs * 1.03 + 0.012))
		g.polyline("band", pts, 0.009 * (L / 1.5), 4)
	# Firing-unit junction boxes on the two poles of the long axis.
	for sx: float in [1.0, -1.0]:
		g.box("acc", Transform3D(Basis(Vector3(0.0, 0.0, 1.0), PI * 0.5), Vector3(sx * (rs + bs.z * 0.5), 0.0, 0.0)), Vector3(bs.y * 1.3, bs.z, bs.x * 1.3))
	for sy: float in [1.0, -1.0]:
		var yc := sy * rs * cos(ring_a) * 1.03
		g.torus("band", Transform3D(Basis(Vector3(0.0, 0.0, 1.0), PI * 0.5), Vector3(0.0, yc, 0.0)), rs * sin(ring_a) * 1.03, 0.035, 20, 6)
	# Lifting fixture on top.
	g.torus("metal", Transform3D(Basis.IDENTITY, Vector3(0.0, rs * 1.02 + 0.06, 0.0)), 0.06, 0.015, 12, 5)


## Fat Man (Mk III, Baker): egg body, "California parachute" box tail,
## mustard yellow with black sealant seams.
static func _m_fatman(g: Geo, L: float, R: float) -> void:
	var c := 0.64
	var hl := 0.36
	var pts: Array = [[0.0, 0.0], [0.0, 0.22], [0.29, 0.31]]
	pts.append_array(_ellipse(c, hl, 0.30, 1.0, 24))
	var P := _prof(L, R, pts)
	g.lathe("body", P, SEGS + 4)
	var half := 0.86 * R
	var t := 0.012
	_box_tail(g, "body", _x(L, 0.0), _x(L, 0.27), half, t)
	_box_tail(g, "body", _x(L, 0.04), _x(L, 0.22), half * 0.7071, t, PI * 0.25)
	_fins(g, "body", P, 4, _x(L, 0.0), _x(L, 0.30), _x(L, 0.0), _x(L, 0.27), half * 1.41, t, PI * 0.25)
	# Black sealant seams.
	_band(g, "band", P, _x(L, c - 0.005), _x(L, c + 0.005), SEGS + 4, 1.006)
	_band(g, "band", P, _x(L, 0.925), _x(L, 0.932), SEGS + 4, 1.006)
	_band(g, "band", P, _x(L, 0.36), _x(L, 0.367), SEGS + 4, 1.006)
	for th: float in [PI * 0.5, PI * 1.5]:
		_seam(g, "band", P, _x(L, 0.33), _x(L, 0.985), th, 0.012, 18)
	# Fuze antenna rods on the rear of the egg.
	for k in 4:
		var phi := PI * 0.25 + PI * 0.5 * float(k)
		var b := Basis(Vector3.RIGHT, phi)
		var a := b * Vector3(_x(L, 0.40), 0.66 * R, 0.0)
		g.tube("metal", a, b * Vector3(_x(L, 0.31), 0.78 * R, 0.0), 0.012, 5)
	_lug(g, "metal", _x(L, c), R, Vector3(0.12, 0.10, 0.08))


## Sedan device canister: plain cylinder with end rims.
static func _m_canister(g: Geo, L: float, R: float) -> void:
	var t1 := 0.92
	var P := _prof(L, R, [[0.0, 0.0], [0.0, 0.9], [0.012, 1.0], [t1 - 0.012, 1.0], [t1, 0.9], [t1, 0.0]])
	g.lathe("body", P, SEGS)
	_ring(g, "acc", _x(L, 0.0), _x(L, 0.035), 0.9 * R, 1.05 * R, SEGS)
	_ring(g, "acc", _x(L, t1 - 0.035), _x(L, t1), 0.9 * R, 1.05 * R, SEGS)
	_band(g, "band", P, _x(L, 0.42), _x(L, 0.52), SEGS)
	# Lifting eye on the top end (+X).
	g.tube("metal", Vector3(_x(L, t1), 0.0, 0.0), Vector3(_x(L, t1 + 0.03), 0.0, 0.0), 0.12 * R, 8)
	var eye_r := (L * (1.0 - t1 - 0.03)) * 0.5
	g.torus("metal", Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(_x(L, t1 + 0.03) + eye_r, 0.0, 0.0)), eye_r * 0.75, eye_r * 0.25, 12, 5)
	# Cable connector box on the side.
	g.box("acc", Transform3D(Basis.IDENTITY, Vector3(_x(L, 0.12), 0.0, 1.02 * R)), Vector3(0.1 * L, 0.18 * R, 0.12 * R))
	# Longitudinal stiffeners.
	for k in 3:
		var b := Basis(Vector3.RIGHT, TAU * float(k) / 3.0 + 0.4)
		g.box("acc", Transform3D(b, b * Vector3(_x(L, t1 * 0.5), 1.0 * R, 0.0)), Vector3(L * t1 * 0.9, 0.04 * R, 0.06 * R))


## Mk 18 (Ivy King): big Mk 6-type casing, pointed egg, box tail with + fins.
static func _m_mk18(g: Geo, L: float, R: float) -> void:
	var pts: Array = [[0.0, 0.0], [0.0, 0.26], [0.22, 0.34], [0.28, 0.48], [0.35, 0.68], [0.42, 0.85], [0.50, 0.96], [0.57, 1.0]]
	pts.append_array(_nose(0.57, 1.0, 0.55, 14, 0.10))
	var P := _prof(L, R, pts)
	g.lathe("body", P, SEGS + 4)
	var half := 0.80 * R
	var t := 0.012
	_box_tail(g, "body", _x(L, 0.0), _x(L, 0.25), half, t)
	_fins(g, "body", P, 4, _x(L, 0.0), _x(L, 0.30), _x(L, 0.0), _x(L, 0.25), half, t, 0.0)
	_band(g, "band", P, _x(L, 0.66), _x(L, 0.685), SEGS + 4)
	_band(g, "acc", P, _x(L, 0.95), _x(L, 1.0), SEGS + 4, 1.008)
	_band(g, "acc", P, _x(L, 0.57), _x(L, 0.578), SEGS + 4, 1.006)
	_lug(g, "metal", _x(L, 0.55), R, Vector3(0.14, 0.10, 0.08))


## B83: slim cylinder, blunt ringed nose, small tail fins, white.
static func _m_b83(g: Geo, L: float, R: float) -> void:
	var pts: Array = [[0.0, 0.0], [0.0, 0.55], [0.04, 0.70], [0.09, 0.86], [0.13, 0.96], [0.16, 1.0], [0.90, 1.0], [0.94, 0.985], [0.97, 0.93], [0.99, 0.80], [1.0, 0.55], [1.0, 0.0]]
	var P := _prof(L, R, pts)
	g.lathe("body", P, SEGS)
	for t0: float in [0.905, 0.935, 0.962]:
		_band(g, "band", P, _x(L, t0), _x(L, t0 + 0.008), SEGS, 1.01)
	g.lathe("band", PackedVector2Array([Vector2(_x(L, 1.0) + 0.002, 0.56 * R), Vector2(_x(L, 1.0) + 0.002, 0.0)]), SEGS)
	_band(g, "acc", P, _x(L, 0.30), _x(L, 0.32), SEGS)
	_band(g, "band", P, _x(L, 0.155), _x(L, 0.165), SEGS, 1.008)
	_fins(g, "band", P, 4, _x(L, 0.0), _x(L, 0.11), _x(L, 0.01), _x(L, 0.05), 1.45 * R, 0.008, PI * 0.25)
	_lug(g, "metal", _x(L, 0.42), R, Vector3(0.2 * R, 0.16 * R, 0.12 * R))
	_lug(g, "metal", _x(L, 0.62), R, Vector3(0.2 * R, 0.16 * R, 0.12 * R))


## RDS-37: large streamlined olive body, 4 big fins, parachute pot.
static func _m_rds37(g: Geo, L: float, R: float) -> void:
	g.lathe("acc", _prof(L, R, [[0.0, 0.0], [0.0, 0.34], [0.045, 0.36], [0.045, 0.0]]), SEGS)
	var pts: Array = [[0.04, 0.0], [0.04, 0.42], [0.08, 0.46], [0.18, 0.62], [0.28, 0.80], [0.36, 0.93], [0.42, 1.0], [0.72, 1.0]]
	pts.append_array(_nose(0.72, 1.0, 0.6, 12, 0.0))
	var P := _prof(L, R, pts)
	g.lathe("body", P, SEGS)
	_band(g, "band", P, _x(L, 0.78), _x(L, 0.80), SEGS)
	_band(g, "acc", P, _x(L, 0.42), _x(L, 0.428), SEGS, 1.006)
	_fins(g, "body", P, 4, _x(L, 0.045), _x(L, 0.28), _x(L, 0.0), _x(L, 0.12), 1.25 * R, maxf(0.015, 0.02 * R), PI * 0.25)
	_lug(g, "metal", _x(L, 0.58), R, Vector3(0.14, 0.10, 0.08))


## Ivy Mike "Sausage" (conceptual): big cylinder with flanges and external
## pipes; the cradle goes into a separate geometry (child "Cradle").
static func _m_sausage(g: Geo, cradle: Geo, L: float, R: float) -> void:
	var pts: Array = [[0.0, 0.0], [0.0, 0.62], [0.025, 0.88], [0.05, 0.97], [0.075, 1.0], [0.90, 1.0], [0.93, 0.975], [0.955, 0.91], [0.975, 0.80], [0.99, 0.62], [1.0, 0.35], [1.0, 0.0]]
	var P := _prof(L, R, pts)
	g.lathe("body", P, SEGS + 4)
	var fw := 0.08 / L
	for t0: float in [0.10, 0.30, 0.50, 0.70, 0.88]:
		_ring(g, "band", _x(L, t0), _x(L, t0 + fw), 0.98 * R, 1.045 * R, SEGS + 4)
	# External pipes along the casing.
	var pr := 0.07
	for th: float in [0.45, -0.45, PI - 0.5]:
		var rr := R * 1.045 + pr + 0.02
		var a := Vector3(_x(L, 0.04), rr * cos(th), rr * sin(th))
		var b := Vector3(_x(L, 0.95), rr * cos(th), rr * sin(th))
		g.tube("acc", a, b, pr, 8)
		for t0: float in [0.10, 0.30, 0.50, 0.70, 0.88]:
			var x := _x(L, t0 + fw * 0.5)
			g.bar("acc", Vector3(x, R * cos(th), R * sin(th)), Vector3(x, rr * cos(th), rr * sin(th)), Vector3.RIGHT, 0.06, 0.05)
	# Manifold and riser pipes on top of the nose end.
	g.box("acc", Transform3D(Basis.IDENTITY, Vector3(_x(L, 0.82), R * 1.12, 0.0)), Vector3(0.6, 0.3, 0.7))
	g.tube("acc", Vector3(_x(L, 0.80), R * 1.2, 0.18), Vector3(_x(L, 0.80), R * 1.55, 0.18), 0.09, 8)
	g.tube("acc", Vector3(_x(L, 0.85), R * 1.2, -0.18), Vector3(_x(L, 0.85), R * 1.45, -0.18), 0.07, 8)
	g.torus("acc", Transform3D(Basis.IDENTITY, Vector3(_x(L, 1.0) - 0.05, 0.0, 0.0)), 0.25 * R, 0.04, 16, 6)
	# Cradle: two saddles hugging the bottom, legs and base beams.
	for t0: float in [0.22, 0.78]:
		var x := _x(L, t0)
		var sw := 0.35
		var arc_prof := PackedVector2Array([Vector2(x - sw * 0.5, 1.12 * R), Vector2(x + sw * 0.5, 1.12 * R), Vector2(x + sw * 0.5, 1.0 * R), Vector2(x - sw * 0.5, 1.0 * R), Vector2(x - sw * 0.5, 1.12 * R)])
		cradle.lathe("frame", arc_prof, 12, Transform3D.IDENTITY, 40.0, PI * 0.72, PI * 0.56)
		for sz: float in [1.0, -1.0]:
			var top := Vector3(x, -0.62 * R, sz * 0.88 * R)
			cradle.bar("frame", top, Vector3(x, -1.42 * R, sz * 0.75 * R), Vector3.RIGHT, sw * 0.8, 0.12)
		cradle.box("frame", Transform3D(Basis.IDENTITY, Vector3(x, -1.18 * R, 0.0)), Vector3(sw * 0.8, 0.12, 1.6 * R))
	for sz: float in [1.0, -1.0]:
		cradle.box("wood", Transform3D(Basis.IDENTITY, Vector3(0.0, -1.47 * R, sz * 0.72 * R)), Vector3(0.82 * L, 0.14, 0.3))


## Castle Bravo "Shrimp": cylinder with rounded ends, aluminium.
static func _m_shrimp(g: Geo, L: float, R: float) -> void:
	var pts: Array = _ellipse(0.15, 0.15, 0.0, 0.15, 10)
	pts.append([0.85, 1.0])
	pts.append_array(_ellipse(0.85, 0.15, 0.85, 1.0, 10))
	var P := _prof(L, R, pts)
	g.lathe("body", P, SEGS + 4)
	for t0: float in [0.15, 0.5, 0.85]:
		_band(g, "band", P, _x(L, t0 - 0.006), _x(L, t0 + 0.006), SEGS + 4, 1.008)
	# Cable conduit along the bottom and two small pipes on the side.
	g.box("acc", Transform3D(Basis.IDENTITY, Vector3(_x(L, 0.5), -1.03 * R, 0.0)), Vector3(0.62 * L, 0.08, 0.16))
	for th: float in [0.55, 0.85]:
		var rr := R * 1.06
		g.tube("band", Vector3(_x(L, 0.2), rr * cos(th), rr * sin(th)), Vector3(_x(L, 0.8), rr * cos(th), rr * sin(th)), 0.035, 6)
	g.torus("acc", Transform3D(Basis.IDENTITY, Vector3(_x(L, 1.0) - 0.02, 0.0, 0.0)), 0.18 * R, 0.03, 16, 6)


## Test No. 219: large streamlined body, pointed nose, finned ring tail.
static func _m_test219(g: Geo, L: float, R: float) -> void:
	var pts: Array = [[0.0, 0.0], [0.0, 0.48], [0.06, 0.52], [0.14, 0.66], [0.24, 0.84], [0.31, 0.95], [0.36, 1.0], [0.68, 1.0]]
	pts.append_array(_nose(0.68, 1.0, 0.3, 14, 0.06))
	var P := _prof(L, R, pts)
	g.lathe("body", P, SEGS + 4)
	_band(g, "band", P, _x(L, 0.66), _x(L, 0.68), SEGS + 4)
	_band(g, "band", P, _x(L, 0.40), _x(L, 0.412), SEGS + 4)
	_fins(g, "body", P, 4, _x(L, 0.0), _x(L, 0.22), _x(L, 0.0), _x(L, 0.10), 1.16 * R, 0.025, PI * 0.25)
	_ring(g, "acc", _x(L, 0.0), _x(L, 0.10), 1.12 * R, 1.18 * R, SEGS + 4)
	_lug(g, "metal", _x(L, 0.55), R, Vector3(0.16, 0.12, 0.1))


## Tsar Bomba: fat white body, blunt nose, big + fins, parachute container.
static func _m_tsar(g: Geo, L: float, R: float) -> void:
	g.lathe("acc", _prof(L, R, [[0.0, 0.0], [0.0, 0.50], [0.105, 0.55], [0.105, 0.0]]), SEGS)
	var pts: Array = [[0.10, 0.0], [0.10, 0.62], [0.16, 0.72], [0.22, 0.85], [0.27, 0.95], [0.31, 1.0], [0.84, 1.0]]
	pts.append_array(_nose(0.84, 1.0, 0.9, 12, 0.0))
	var P := _prof(L, R, pts)
	var full := _prof(L, R, [[0.0, 0.50], [0.10, 0.55]] + pts.slice(2))
	g.lathe("body", P, SEGS + 4)
	_band(g, "band", P, _x(L, 0.56), _x(L, 0.575), SEGS + 4)
	_band(g, "band", P, _x(L, 0.82), _x(L, 0.835), SEGS + 4)
	_band(g, "band", P, _x(L, 0.30), _x(L, 0.31), SEGS + 4, 1.006)
	_fins(g, "band", full, 4, _x(L, 0.02), _x(L, 0.30), _x(L, 0.0), _x(L, 0.12), 1.33 * R, 0.035, 0.0)
	_lug(g, "metal", _x(L, 0.6), R, Vector3(0.2, 0.14, 0.12))
