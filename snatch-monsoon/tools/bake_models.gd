extends SceneTree
# Offline asset bake: raw glTF (raw/, not committed) -> light .glb files in assets/models/.
# Decimates, merges by material, thins leaf cards, flattens far props to vertex colour,
# removes plates and signs, and remaps colours reserved for the rope (orange) and danger (red).
#   Godot --headless --path . --script res://tools/bake_models.gd [-- name ...]

const RAW := "res://raw/"
const OUT := "res://assets/models/"

var SPECS := {
	"bus": {"src": "models/ddfd0b9846c24a058874521e9d170bcb.glb", "tris": 26000, "tex": 512, "recolour": "bus",
		"fills": {6: [Rect2i(478, 328, 136, 90), Rect2i(362, 422, 120, 32), Rect2i(526, 462, 36, 42), Rect2i(158, 598, 48, 52)]}},
	"truck": {"src": "models/568eecbaaff347d5b62c952d591605ac.glb", "tris": 4000, "tex": 512, "recolour": "truck"},
	"tree": {"src": "ph/jacaranda_tree/jacaranda_tree.gltf", "tex": 512, "recolour": "leaves",
		"per_mat": {"jacaranda_tree_trunk": 7000, "jacaranda_tree_branches": 9000},
		"leaves": {"mat": "jacaranda_tree_leaves", "keep": 0.012, "scale": 2.6}},
	"roots": {"src": "ph/root_cluster_01/root_cluster_01.gltf", "tris": 3500, "tex": 512},
	"boulder": {"src": "ph/boulder_01/boulder_01.gltf", "tris": 900, "tex": 256},
	"excavator": {"src": "models/940258497f9f4eba9710bb359a9e777e.glb", "tris": 5000, "flatten": true},
	"loader": {"src": "models/2137d93b5a804161bc65b44d583aa68e.glb", "tris": 4000, "flatten": true},
}

func _initialize():
	var only := OS.get_cmdline_user_args()
	for name in SPECS:
		if only.size() > 0 and not only.has(name): continue
		var t := Time.get_ticks_msec()
		bake(name, SPECS[name])
		print(name, " done in ", (Time.get_ticks_msec() - t) / 1000.0, " s")
	quit()

func bake(name: String, spec: Dictionary) -> void:
	var doc := GLTFDocument.new(); var st := GLTFState.new()
	if doc.append_from_file(ProjectSettings.globalize_path(RAW + spec.src), st) != OK:
		push_error("cannot read " + spec.src); return
	# Global transform for every node.
	var nodes := st.get_nodes(); var glob := []
	glob.resize(nodes.size())
	for i in nodes.size(): glob[i] = _global(nodes, i)
	# Gather surfaces by material.
	var groups := {}  # material -> {v, n, uv, uv2, tan, col, idx}
	for i in nodes.size():
		var gn: GLTFNode = nodes[i]
		if gn.mesh < 0: continue
		var im: ImporterMesh = st.get_meshes()[gn.mesh].mesh
		var xf: Transform3D = glob[i]
		for s in im.get_surface_count():
			if im.get_surface_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES: continue
			var mat: Material = im.get_surface_material(s)
			var key = null if spec.get("flatten", false) else mat
			if not groups.has(key): groups[key] = {"v": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array(), "col": PackedColorArray(), "idx": PackedInt32Array(), "mat": mat}
			_append(groups[key], im.get_surface_arrays(s), xf, mat if spec.get("flatten", false) else null)
	var root := Node3D.new(); root.name = name
	var aabb := AABB(); var first := true; var total := 0
	var all_tris := 0
	for k in groups: all_tris += groups[k].idx.size() / 3
	for k in groups:
		var g: Dictionary = groups[k]
		var mname: String = g.mat.resource_name if g.mat else ""
		var tris_in: int = g.idx.size() / 3
		if spec.has("leaves") and mname == spec.leaves.mat:
			_thin_leaves(g, spec.leaves.keep, spec.leaves.scale)
		else:
			var target := 0
			if spec.has("per_mat"): target = spec.per_mat.get(mname, 0)
			elif spec.has("tris"): target = int(float(spec.tris) * tris_in / all_tris)
			if target > 0 and tris_in > target: _decimate(g, target)
		_compact(g)
		var arr := []; arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = g.v; arr[Mesh.ARRAY_NORMAL] = g.n; arr[Mesh.ARRAY_INDEX] = g.idx
		if g.uv.size() == g.v.size(): arr[Mesh.ARRAY_TEX_UV] = g.uv
		var mat: Material
		if spec.get("flatten", false):
			arr[Mesh.ARRAY_COLOR] = g.col
			var sm := StandardMaterial3D.new(); sm.vertex_color_use_as_albedo = true; sm.roughness = 0.75; sm.resource_name = "flat"
			mat = sm
		else:
			mat = _process_material(g.mat, spec)
		var am := ArrayMesh.new(); am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr); am.surface_set_material(0, mat)
		var mi := MeshInstance3D.new(); mi.mesh = am; mi.name = mname if mname != "" else "flat"; root.add_child(mi)
		var b := am.get_aabb(); aabb = b if first else aabb.merge(b); first = false
		total += g.idx.size() / 3
		print("  ", mi.name, ": ", tris_in, " -> ", g.idx.size() / 3, " tris")
	print("  aabb ", aabb, " total tris ", total)
	var out := GLTFDocument.new(); out.image_format = "Lossy WebP"; out.lossy_quality = 0.82
	var st2 := GLTFState.new()
	out.append_from_scene(root, st2)
	out.write_to_filesystem(st2, ProjectSettings.globalize_path(OUT + name + ".glb"))
	root.free()

func _global(nodes: Array, i: int) -> Transform3D:
	var gn: GLTFNode = nodes[i]
	var xf: Transform3D = gn.xform
	if gn.parent >= 0: xf = _global(nodes, gn.parent) * xf
	return xf

func _append(g: Dictionary, a: Array, xf: Transform3D, flat_mat: Material) -> void:
	var base: int = g.v.size()
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]; var n = a[Mesh.ARRAY_NORMAL]; var uv = a[Mesh.ARRAY_TEX_UV]
	var idx = a[Mesh.ARRAY_INDEX]
	var basis := xf.basis.inverse().transposed()
	var img: Image = null; var tint := Color.WHITE
	if flat_mat is StandardMaterial3D:
		tint = flat_mat.albedo_color
		if flat_mat.albedo_texture: img = flat_mat.albedo_texture.get_image().duplicate(); img.decompress(); img.resize(64, 64)
	for j in v.size():
		g.v.append(xf * v[j])
		g.n.append((basis * n[j]).normalized() if n else Vector3.UP)
		var t: Vector2 = uv[j] if uv else Vector2.ZERO
		g.uv.append(t)
		if flat_mat != null:
			var c := tint
			if img:
				var px := Vector2i(posmod(int(t.x * 64.0), 64), posmod(int(t.y * 64.0), 64))
				c = c * img.get_pixelv(px)
			g.col.append(c)
	if idx:
		for j in idx: g.idx.append(base + j)
	else:
		for j in v.size(): g.idx.append(base + j)

func _decimate(g: Dictionary, target: int) -> void:
	var im := ImporterMesh.new()
	var arr := []; arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = g.v; arr[Mesh.ARRAY_NORMAL] = g.n; arr[Mesh.ARRAY_INDEX] = g.idx
	if g.uv.size() == g.v.size(): arr[Mesh.ARRAY_TEX_UV] = g.uv
	if g.col.size() == g.v.size(): arr[Mesh.ARRAY_COLOR] = g.col
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arr)
	im.generate_lods(60.0, 25.0, [])
	var best: PackedInt32Array = g.idx
	for l in im.get_surface_lod_count(0):
		var li := im.get_surface_lod_indices(0, l)
		best = li
		if li.size() / 3 <= target: break
	g.idx = best

func _thin_leaves(g: Dictionary, keep: float, scale: float) -> void:
	# Leaves are separate small cards: find connected components, keep a sparse sample, enlarge each.
	var n: int = g.v.size()
	var parent := PackedInt32Array(); parent.resize(n)
	for i in n: parent[i] = i
	var idx: PackedInt32Array = g.idx
	for t in range(0, idx.size(), 3):
		_union(parent, idx[t], idx[t + 1]); _union(parent, idx[t], idx[t + 2])
	var keep_root := {}  # root -> [sum, count]
	var out := PackedInt32Array()
	var th := int(keep * 1000003.0)
	for t in range(0, idx.size(), 3):
		var r := _find(parent, idx[t])
		if (r * 2654435761) % 1000003 >= th: continue
		out.append(idx[t]); out.append(idx[t + 1]); out.append(idx[t + 2])
		if not keep_root.has(r): keep_root[r] = true
	# Centroid per kept component.
	var sums := {}
	var seen := {}
	for j in out:
		if seen.has(j): continue
		seen[j] = true
		var r := _find(parent, j)
		if not sums.has(r): sums[r] = [Vector3.ZERO, 0]
		sums[r][0] += g.v[j]; sums[r][1] += 1
	for j in seen:
		var r := _find(parent, j)
		var c: Vector3 = sums[r][0] / float(sums[r][1])
		g.v[j] = c + (g.v[j] - c) * scale
	g.idx = out
	print("    leaf components kept: ", sums.size())

func _find(p: PackedInt32Array, i: int) -> int:
	while p[i] != i:
		p[i] = p[p[i]]; i = p[i]
	return i

func _union(p: PackedInt32Array, a: int, b: int) -> void:
	var ra := _find(p, a); var rb := _find(p, b)
	if ra != rb: p[ra] = rb

func _compact(g: Dictionary) -> void:
	var remap := {}
	var nv := PackedVector3Array(); var nn := PackedVector3Array(); var nuv := PackedVector2Array(); var nc := PackedColorArray()
	var has_uv: bool = g.uv.size() == g.v.size(); var has_c: bool = g.col.size() == g.v.size()
	var ni := PackedInt32Array(); ni.resize(g.idx.size())
	for k in g.idx.size():
		var j: int = g.idx[k]
		if not remap.has(j):
			remap[j] = nv.size(); nv.append(g.v[j]); nn.append(g.n[j])
			if has_uv: nuv.append(g.uv[j])
			if has_c: nc.append(g.col[j])
		ni[k] = remap[j]
	g.v = nv; g.n = nn; g.uv = nuv; g.col = nc; g.idx = ni

func _process_material(m: Material, spec: Dictionary) -> Material:
	var sm := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
	var size: int = spec.get("tex", 512)
	for prop in ["albedo_texture", "normal_texture", "roughness_texture", "metallic_texture", "emission_texture", "orm_texture", "ao_texture"]:
		var t = sm.get(prop)
		if not t: continue
		var img: Image = t.get_image().duplicate(); img.decompress()
		if img.get_format() != Image.FORMAT_RGBA8 and img.get_format() != Image.FORMAT_RGB8: img.convert(Image.FORMAT_RGBA8)
		if prop == "albedo_texture":
			if spec.has("fills") and m.resource_name == "09_-_Default": _fill_regions(img, spec)
		if prop in ["albedo_texture", "emission_texture"]:
			if spec.has("recolour") and (spec.recolour != "leaves" or m.resource_name.ends_with("leaves")): _recolour(img, spec.recolour)
		if img.get_width() > size: img.resize(size, size, Image.INTERPOLATE_LANCZOS)
		sm.set(prop, ImageTexture.create_from_image(img))
	return sm

var _fill_done := {}
func _fill_regions(img: Image, spec: Dictionary) -> void:
	# The plate and sign sit on the 1024 px albedo atlas of material 09.
	if img.get_width() != 1024: return
	for k in spec.fills:
		for r in spec.fills[k]:
			var c := _border_mean(img, r)
			img.fill_rect(r, c)
			_fill_done[r] = true
	print("    plate and sign removed")

func _border_mean(img: Image, r: Rect2i) -> Color:
	var s := Color(0, 0, 0, 0); var n := 0
	for x in range(r.position.x, r.end.x, 2):
		for y in [r.position.y + 2, r.end.y - 3]:
			s += img.get_pixel(x, y); n += 1
	return s / float(n)

func _recolour(img: Image, mode: String) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var h := c.h; var s := c.s; var v := c.v
			match mode:
				"bus":
					if s > 0.3 and (h < 0.045 or h > 0.92):
						c = Color.from_hsv(0.42, s * 0.32, v * 0.95, c.a)   # red livery -> faded teal green
					elif s > 0.35 and h < 0.13:
						c = Color.from_hsv(0.11, s * 0.22, v * 0.8, c.a)    # orange -> dull ochre grey
					else: continue
				"truck":
					if s > 0.2: c = Color.from_hsv(h, s * 0.1, v * (0.78 if h < 0.2 else 0.55), c.a)
					else: continue
				"leaves":
					# Jacaranda blossom is violet: map to a wet monsoon green, keep luminance variation.
					var l := c.get_luminance()
					c = Color(0.16, 0.26, 0.12, c.a).lerp(Color(0.33, 0.45, 0.22, c.a), clampf(l * 1.6, 0.0, 1.0))
			img.set_pixel(x, y, c)
