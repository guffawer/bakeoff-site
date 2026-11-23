class_name Terrain
extends RefCounted
# Ghat-road hairpin as an analytic heightfield. The road climbs from the lower leg (z = -4)
# round a bend centred on (-4, -12) to the upper leg (z = -20). Outside the lower leg and the
# bend the hill drops into a gully; outside the upper leg it rises as a cut face.

const HALF_WIDTH := 3.5
const CENTRE := Vector2(-4.0, -12.0)
const RADIUS := 8.0

enum { ROAD, SHOULDER, BANK, CUT, GULLY, WATER }

static var _pts := PackedVector3Array()   # x, elevation, z
static var _tan := PackedVector3Array()
static var _seg := PackedFloat32Array()   # 0 upper leg, 0..1 along the bend, 1 lower leg
static var _noise: FastNoiseLite

static func build() -> void:
	if _pts.size() > 0: return
	_noise = FastNoiseLite.new(); _noise.seed = 7; _noise.frequency = 0.08
	for i in 31:
		_add(Vector3(30.0 - i * 34.0 / 30.0, lerpf(4.7, 4.0, i / 30.0), -20.0), Vector3.LEFT, 0.0)
	for i in range(1, 48):
		var a := PI * i / 48.0
		var th := -PI / 2.0 - a
		var p := Vector3(CENTRE.x + RADIUS * cos(th), lerpf(4.0, 0.3, smoothstep(0.0, 1.0, a / PI)), CENTRE.y + RADIUS * sin(th))
		_add(p, Vector3(sin(th), 0.0, -cos(th)), a / PI)
	for i in 31:
		_add(Vector3(-4.0 + i * 34.0 / 30.0, lerpf(0.3, -0.2, i / 30.0), -4.0), Vector3.RIGHT, 1.0)

static func _add(p: Vector3, t: Vector3, s: float) -> void:
	_pts.append(p); _tan.append(t); _seg.append(s)

# Returns [height, class, lateral offset (+ = inside the bend), road elevation].
static func sample(x: float, z: float) -> Array:
	build()
	var best := 0; var bd := INF
	for i in _pts.size():
		var d := Vector2(_pts[i].x - x, _pts[i].z - z).length_squared()
		if d < bd: bd = d; best = i
	# Project onto the better neighbouring segment for a smooth result.
	var e := _pts[best].y; var t := _tan[best]; var s := _seg[best]; var c := _pts[best]
	for j in [best - 1, best]:
		if j < 0 or j + 1 >= _pts.size(): continue
		var a := Vector2(_pts[j].x, _pts[j].z); var b := Vector2(_pts[j + 1].x, _pts[j + 1].z)
		var u := clampf((Vector2(x, z) - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
		var q := a.lerp(b, u)
		if q.distance_squared_to(Vector2(x, z)) <= bd + 1e-6:
			bd = q.distance_squared_to(Vector2(x, z))
			e = lerpf(_pts[j].y, _pts[j + 1].y, u); t = _tan[j].lerp(_tan[j + 1], u).normalized()
			s = lerpf(_seg[j], _seg[j + 1], u); c = Vector3(q.x, e, q.y)
	var left := Vector3.UP.cross(t)
	var lat := Vector3(x - c.x, 0.0, z - c.z).dot(left)
	var n := _noise.get_noise_2d(x, z)
	var h := e; var cls := ROAD
	if absf(lat) <= HALF_WIDTH:
		h = e - 0.03 * lat * lat / HALF_WIDTH
		# Wheel ruts hold water.
		cls = ROAD
	elif lat > HALF_WIDTH:
		# Inside the hairpin: a grassy bank that climbs from the lower leg to the upper leg.
		var mid := 0.3 + clampf((-4.0 - z) / 16.0, 0.0, 1.0) * 3.7 + 0.5 + n * 0.6
		var k := smoothstep(HALF_WIDTH, HALF_WIDTH + 3.0, lat)
		h = lerpf(e - 0.05, mid, k)
		cls = SHOULDER if lat < HALF_WIDTH + 1.0 else BANK
	else:
		var u := -lat - HALF_WIDTH
		var cut := e + 0.3 + u * 1.15 + n * 0.8
		var drop := e - 1.9 * smoothstep(0.0, 1.8, u) - 0.32 * u + n * 0.35
		var w := 1.0 - smoothstep(0.15, 0.4, s)   # upper leg and the start of the bend are cut
		h = lerpf(drop, minf(cut, e + 9.0), w)
		if w > 0.5: cls = SHOULDER if u < 0.8 else CUT
		else: cls = SHOULDER if u < 0.5 else GULLY
		if w < 0.5 and u > 4.5 and u < 7.0 and n > -0.2: cls = WATER
	return [h, cls, lat, e]

static func height(x: float, z: float) -> float:
	return sample(x, z)[0]

static func colour(cls: int, n: float) -> Color:
	# Alpha carries roughness for the ground shader.
	match cls:
		ROAD: return Color(0.2, 0.205, 0.215, 0.12).lerp(Color(0.24, 0.245, 0.25, 0.2), n)
		SHOULDER: return Color(0.42, 0.19, 0.11, 0.35).lerp(Color(0.5, 0.24, 0.13, 0.45), n)
		BANK: return Color(0.17, 0.3, 0.16, 0.7).lerp(Color(0.24, 0.37, 0.19, 0.75), n)
		CUT: return Color(0.33, 0.3, 0.28, 0.55).lerp(Color(0.2, 0.31, 0.17, 0.7), n * n)
		GULLY: return Color(0.42, 0.2, 0.11, 0.25).lerp(Color(0.5, 0.25, 0.13, 0.3), n)
		WATER: return Color(0.12, 0.13, 0.12, 0.04)
	return Color.MAGENTA

# Flat-shaded low-poly ground mesh.
static func make_mesh(x0: float, x1: float, z0: float, z1: float, step: float) -> ArrayMesh:
	var nx := int((x1 - x0) / step) + 1; var nz := int((z1 - z0) / step) + 1
	var hs := PackedFloat32Array(); hs.resize(nx * nz)
	var cl := PackedInt32Array(); cl.resize(nx * nz)
	var rng := RandomNumberGenerator.new(); rng.seed = 3
	for j in nz:
		for i in nx:
			var x := x0 + i * step; var z := z0 + j * step
			# Jitter off-road vertices for a hand-made low-poly look.
			var smp := sample(x, z)
			var hh: float = smp[0]
			if smp[1] != ROAD and smp[1] != SHOULDER: hh += rng.randf_range(-0.12, 0.12)
			hs[j * nx + i] = hh; cl[j * nx + i] = smp[1]
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in nz - 1:
		for i in nx - 1:
			var p := []
			for k in [[0, 0], [1, 0], [0, 1], [1, 1]]:
				var ii: int = i + k[0]; var jj: int = j + k[1]
				p.append(Vector3(x0 + ii * step, hs[jj * nx + ii], z0 + jj * step))
			for tri in [[0, 2, 1], [1, 2, 3]]:
				var a: Vector3 = p[tri[0]]; var b: Vector3 = p[tri[1]]; var c: Vector3 = p[tri[2]]
				var ctr := (a + b + c) / 3.0
				var cls: int = sample(ctr.x, ctr.z)[1]
				var col := colour(cls, rng.randf())
				var nrm := (b - a).cross(c - a).normalized()
				if nrm.y < 0: nrm = -nrm
				# Steep faces of the cut read as rock.
				if cls == CUT and nrm.y > 0.75: col = colour(BANK, rng.randf())
				for v in [a, b, c]:
					st.set_normal(nrm); st.set_color(col); st.set_uv(Vector2(v.x, v.z)); st.add_vertex(v)
	return st.commit()

# Painted centre dashes and edge lines as thin strips just above the road.
static func make_markings() -> ArrayMesh:
	build()
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dist := 0.0
	for i in _pts.size() - 1:
		var a := _pts[i]; var b := _pts[i + 1]
		var t := (b - a); t.y = 0.0; var seg := t.length(); t = t.normalized()
		var left := Vector3.UP.cross(t)
		var steps := int(ceil(seg / 0.5))
		for k in steps:
			var u0 := float(k) / steps; var u1 := float(k + 1) / steps
			var p0 := a.lerp(b, u0); var p1 := a.lerp(b, u1)
			var d := dist + seg * u0
			var lines := [[0.0, 0.07, fmod(d, 3.0) < 1.6]]
			lines.append([HALF_WIDTH - 0.25, 0.06, true]); lines.append([-(HALF_WIDTH - 0.25), 0.06, true])
			for ln in lines:
				if not ln[2]: continue
				var o: float = ln[0]; var w: float = ln[1]
				var q := [p0 + left * (o - w), p0 + left * (o + w), p1 + left * (o - w), p1 + left * (o + w)]
				for j in 4:
					var v: Vector3 = q[j]; v.y = height(v.x, v.z) + 0.03; q[j] = v
				for idx in [0, 2, 1, 1, 2, 3]:
					st.set_normal(Vector3.UP); st.add_vertex(q[idx])
		dist += seg
	return st.commit()
