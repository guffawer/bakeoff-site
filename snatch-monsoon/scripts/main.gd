extends Node
# Monsoon Recovery Co. look test: "Bus off the edge, ghat road, monsoon, 9:40 pm".
# Checkpoint 2 builds the static look. Run with `-- --still out.png` to save one 1080x1920 frame.

const CART := "res://assets/cartoon/"

var frame: SubViewport
var world: Node3D
var cam: Camera3D
var overlay_vp: SubViewport
var rain_mat: ShaderMaterial
var ground_mat: ShaderMaterial
var mist_mats: Array[ShaderMaterial] = []
var tilt: ShaderMaterial
var clock := 0.0
var still_mode := false
var slip_node: Node3D
var roll_node: Node3D
var remote_node: Node3D
var fps_label: Label
var frame_times := PackedFloat32Array()
var fps_timer := 0.0
var slow_streak := 0

var bus: Node3D
var truck: Node3D
var tree: Node3D
var eye := Vector3.ZERO      # bus tow eye
var winch := Vector3.ZERO    # truck winch fairlead
var tree_anchor := Vector3.ZERO
var spots: Array[SpotLight3D] = []

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var still := ""
	if args.has("--still"): still = args[args.find("--still") + 1]
	still_mode = still != ""
	var container := SubViewportContainer.new(); container.stretch = true
	container.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(container)
	frame = SubViewport.new(); frame.msaa_3d = Viewport.MSAA_DISABLED
	frame.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(frame)
	if still != "":
		container.stretch = false; frame.size = Vector2i(1080, 1920)
	else:
		# 3D renders below native resolution and is scaled up; the tilt-shift hides the softness.
		frame.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR; frame.scaling_3d_scale = 0.75
	world = Node3D.new(); frame.add_child(world)
	_environment()
	_ground()
	_props()
	_vehicles()
	_lights()
	_rope_static()
	_rain()
	_mist()
	_camera()
	_post()
	_overlay()
	_fps_readout()
	frame.size_changed.connect(_relayout)
	_relayout()
	if still != "": _save_still(still)

# ---------------------------------------------------------------- world

func _environment() -> void:
	var we := WorldEnvironment.new(); var e := Environment.new()
	# A dim night sky, mainly so wet surfaces and puddles have something to reflect.
	var sky := Sky.new(); var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.03, 0.04, 0.06); sm.sky_horizon_color = Color(0.2, 0.23, 0.27)
	sm.ground_horizon_color = Color(0.2, 0.23, 0.27); sm.ground_bottom_color = Color(0.05, 0.06, 0.07)
	sm.sky_energy_multiplier = 1.0; sm.ground_energy_multiplier = 1.0; sm.sun_angle_max = 1.0
	sky.sky_material = sm
	e.background_mode = Environment.BG_SKY; e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.4, 0.46, 0.54); e.ambient_light_energy = 1.05
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC; e.tonemap_exposure = 1.1
	e.fog_enabled = true; e.fog_light_color = Color(0.11, 0.13, 0.155); e.fog_density = 0.007
	e.fog_sky_affect = 1.0
	e.glow_enabled = true; e.glow_intensity = 0.7; e.glow_bloom = 0.04; e.glow_hdr_threshold = 0.9
	we.environment = e; world.add_child(we)

func _ground() -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = Terrain.make_mesh(-24.0, 32.0, -40.0, 12.0, 0.9)
	ground_mat = ShaderMaterial.new(); ground_mat.shader = load("res://shaders/ground.gdshader")
	mi.material_override = ground_mat
	world.add_child(mi)
	var mk := MeshInstance3D.new(); mk.mesh = Terrain.make_markings()
	var paint := StandardMaterial3D.new(); paint.albedo_color = Color(0.72, 0.72, 0.66); paint.roughness = 0.3; paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	mk.material_override = paint; mk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; world.add_child(mk)

func _place(file: String, pos: Vector3, scale: float, yaw: float) -> Node3D:
	var n: Node3D = load(CART + file + ".glb").instantiate()
	n.scale = Vector3.ONE * scale; n.rotation.y = yaw
	n.position = Vector3(pos.x, Terrain.height(pos.x, pos.z) + pos.y, pos.z)
	world.add_child(n); return n

func _props() -> void:
	# The tree at the bend: the anchor. Trunk sits at the model origin.
	tree = _place("tree_detailed", Vector3(-3.2, -0.1, -12.0), 6.5, 0.6)
	tree_anchor = tree.position + Vector3(0.0, 1.1, 0.0)
	_tint(tree, Color(0.23, 0.36, 0.17))
	# Background trees on the bank and above the cut.
	var rng := RandomNumberGenerator.new(); rng.seed = 11
	var spots_xz := [Vector2(-10, -28), Vector2(-2, -29), Vector2(6, -29.5), Vector2(16, -30), Vector2(24, -28),
		Vector2(29, -24), Vector2(-15, -20), Vector2(-17, -5), Vector2(22, -12), Vector2(-12, 6), Vector2(19, 6)]
	var kinds := ["tree_default_dark", "tree_fat_darkh", "tree_pineRoundA", "tree_default_dark"]
	for i in spots_xz.size():
		var p: Vector2 = spots_xz[i]
		_tint(_place(kinds[i % kinds.size()], Vector3(p.x, -0.1, p.y), rng.randf_range(3.2, 4.4), rng.randf() * TAU), Color(0.15, 0.27, 0.15))
	for p in [Vector2(9, -9), Vector2(-9, -15), Vector2(1, -14), Vector2(18, -8.5), Vector2(-6, 3), Vector2(8, 5)]:
		_tint(_place("plant_bushLarge", Vector3(p.x, -0.05, p.y), rng.randf_range(1.4, 2.0), rng.randf() * TAU), Color(0.2, 0.33, 0.16))
	for p in [Vector2(-11, -21), Vector2(24, -24.5), Vector2(-4.5, 2.5), Vector2(11, 3.5), Vector2(-14.5, -9)]:
		_place(["rock_largeA", "rock_largeB", "rock_tallA"][rng.randi() % 3], Vector3(p.x, -0.3, p.y), rng.randf_range(1.6, 2.6), rng.randf() * TAU)
	# Parapet blocks along the outer edge of the lower leg, with a gap where the bus went over.
	var block := BoxMesh.new(); block.size = Vector3(0.9, 0.45, 0.35)
	var white := StandardMaterial3D.new(); white.albedo_color = Color(0.78, 0.78, 0.74); white.roughness = 0.35
	var black := StandardMaterial3D.new(); black.albedo_color = Color(0.08, 0.08, 0.08); black.roughness = 0.35
	var k := 0
	for x in range(-2, 30, 2):
		if x >= 0 and x <= 6: k += 1; continue
		var mi := MeshInstance3D.new(); mi.mesh = block
		mi.material_override = white if k % 2 == 0 else black
		var z := -0.2
		mi.position = Vector3(x, Terrain.height(x, z) + 0.2, z); mi.rotation.y = 0.04 * sin(x)
		world.add_child(mi); k += 1
	# One block knocked into the gully.
	var fallen := MeshInstance3D.new(); fallen.mesh = block; fallen.material_override = white
	fallen.position = Vector3(5.2, Terrain.height(5.2, 2.6) + 0.15, 2.6); fallen.rotation = Vector3(0.5, 0.9, 0.3)
	world.add_child(fallen)
	# Parked shovel tractor up the road, for scale.
	_place("tractor-shovel", Vector3(24.0, 0.0, -21.0), 1.9, -PI / 2.0)

# Pull a Kenney model's palette towards a wet monsoon green (leaves only; trunks keep their brown).
func _tint(root: Node3D, green: Color) -> void:
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		for si in mi.mesh.get_surface_count():
			var sm := mi.mesh.surface_get_material(si) as StandardMaterial3D
			if sm == null: continue
			var c := sm.albedo_color
			if c.g > c.r * 1.2 or c.b > c.r * 1.2:
				var nm := sm.duplicate() as StandardMaterial3D
				nm.albedo_color = green.lerp(Color(c.v, c.v, c.v) * green * 1.6, 0.35); nm.roughness = 0.4
				mi.set_surface_override_material(si, nm)

func _vehicles() -> void:
	# Bus 5 sits rotated inside its file, in centimetres, with a number-plate text mesh: strip it.
	var model: Node3D = load(CART + "bus.glb").instantiate()
	for n in model.find_children("Text*", "", true, false): n.free()
	var centre := Vector3(1993.0, 0.76, -431.6)
	var fwd := Vector3(-220.0, 0.0, 440.0).normalized()
	var s := 0.0135
	var inner := Node3D.new()
	var b := Basis.looking_at(fwd).inverse().scaled(Vector3.ONE * s)
	inner.transform = Transform3D(b, -(b * centre))
	inner.add_child(model)
	# Mute the bus paint: strong colour is kept for the rope (orange) and danger (red).
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for si in mi.mesh.get_surface_count():
			var sm := mi.mesh.surface_get_material(si) as StandardMaterial3D
			if sm == null: continue
			var c := sm.albedo_color
			var nm := sm.duplicate() as StandardMaterial3D
			nm.albedo_color = Color.from_hsv(c.h, c.s * 0.42, c.v * 0.82, c.a); nm.roughness = 0.35
			mi.set_surface_override_material(si, nm)
	bus = Node3D.new(); bus.add_child(inner); world.add_child(bus)
	# Front axle on the road, rear axle over the edge in the gully.
	var x := 3.0
	var zf := -4.4; var zr := zf + 4.8
	var pf := Vector3(x, Terrain.height(x, zf), zf); var pr := Vector3(x, Terrain.height(x, zr), zr)
	var f := (pf - pr).normalized()
	var up := Vector3.UP.rotated(f, deg_to_rad(4.0))
	var right := f.cross(up).normalized(); up = right.cross(f).normalized()
	bus.transform = Transform3D(Basis(right, up, -f), (pf + pr) * 0.5 + up * 0.02)
	eye = bus.transform * Vector3(0.0, 0.55, -3.95)
	# Recovery truck up the road, nose pointed at the bus.
	truck = Node3D.new()
	var tm: Node3D = load(CART + "truck-flat.glb").instantiate(); tm.scale = Vector3.ONE * 2.0; truck.add_child(tm)
	var tp := Vector3(14.0, 0.0, -18.3); tp.y = Terrain.height(tp.x, tp.z)
	var to := eye - tp; to.y = 0.0
	truck.transform = Transform3D(Basis.looking_at(-to.normalized()), tp)
	world.add_child(truck)
	winch = truck.transform * Vector3(0.0, 0.7, 2.95)
	print("eye ", eye, " winch ", winch, " tree ", tree_anchor)
	var a1 := (winch - eye).normalized(); var a2 := (tree_anchor - eye).normalized()
	print("angle between legs ", rad_to_deg(a1.angle_to(a2)), " deg; advantage ", a1.dot(-bus.transform.basis.z) + a2.dot(-bus.transform.basis.z))

func _lights() -> void:
	var moon := DirectionalLight3D.new(); moon.light_color = Color(0.6, 0.7, 0.9); moon.light_energy = 0.55
	moon.rotation_degrees = Vector3(-62, 35, 0); moon.shadow_enabled = true
	world.add_child(moon)
	# Truck headlights on the bus.
	var hl := SpotLight3D.new(); hl.light_color = Color(1.0, 0.88, 0.68); hl.light_energy = 6.5
	hl.spot_range = 32.0; hl.spot_angle = 26.0; hl.spot_attenuation = 0.8; hl.shadow_enabled = true
	world.add_child(hl)
	hl.global_transform = Transform3D(Basis.looking_at(eye - winch + Vector3(0, -0.6, 0)), truck.transform * Vector3(0.0, 1.5, 2.9))
	spots.append(hl)
	# Bus headlights up the bank.
	var bl := SpotLight3D.new(); bl.light_color = Color(1.0, 0.9, 0.72); bl.light_energy = 6.0
	bl.spot_range = 22.0; bl.spot_angle = 30.0; bl.spot_attenuation = 0.8
	world.add_child(bl)
	bl.global_transform = Transform3D(bus.transform.basis.orthonormalized(), bus.transform * Vector3(0.0, 1.0, -4.0))
	bl.rotate_object_local(Vector3.RIGHT, deg_to_rad(-8.0))
	spots.append(bl)
	# Work lamp over the winch.
	var wl := OmniLight3D.new(); wl.light_color = Color(0.8, 0.88, 1.0); wl.light_energy = 1.6; wl.omni_range = 9.0
	wl.position = truck.transform * Vector3(0.0, 3.4, 1.0); world.add_child(wl)

func _beam(l: SpotLight3D) -> void:
	var h := l.spot_range * 0.55
	var cone := CylinderMesh.new(); cone.top_radius = 0.2; cone.bottom_radius = tan(deg_to_rad(l.spot_angle)) * h; cone.height = h
	cone.radial_segments = 16; cone.rings = 1; cone.cap_top = false; cone.cap_bottom = false
	var mi := MeshInstance3D.new(); mi.mesh = cone
	var m := ShaderMaterial.new(); m.shader = load("res://shaders/beam.gdshader")
	m.set_shader_parameter("height", h); m.set_shader_parameter("colour", l.light_color); m.set_shader_parameter("strength", 0.045)
	mi.material_override = m; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mi)
	var d := -l.global_transform.basis.z
	# Cone axis is local Y; point local -Y along the beam.
	var y := -d; var x := y.cross(Vector3.FORWARD if absf(y.y) > 0.9 else Vector3.UP).normalized(); var z := x.cross(y)
	mi.global_transform = Transform3D(Basis(x, y, z), l.global_position + d * h * 0.5)

# ---------------------------------------------------------------- rope (static for the still)

func _rope_static() -> void:
	var pts := PackedVector3Array()
	var n := 28
	for i in n + 1:
		var u := float(i) / n
		var p := winch.lerp(eye, u); p.y -= sin(u * PI) * 0.35
		p.y = maxf(p.y, Terrain.height(p.x, p.z) + 0.06)
		pts.append(p)
	var mi := MeshInstance3D.new(); mi.mesh = _tube(pts, 0.06)
	var m := StandardMaterial3D.new(); m.albedo_color = Color(1.0, 0.42, 0.04); m.roughness = 0.45
	m.emission_enabled = true; m.emission = Color(1.0, 0.35, 0.02); m.emission_energy_multiplier = 0.35
	mi.material_override = m; world.add_child(mi)
	var hook := MeshInstance3D.new(); var hb := BoxMesh.new(); hb.size = Vector3(0.18, 0.28, 0.12); hook.mesh = hb
	var steel := StandardMaterial3D.new(); steel.albedo_color = Color(0.55, 0.56, 0.58); steel.metallic = 0.8; steel.roughness = 0.3
	hook.material_override = steel; hook.position = eye; world.add_child(hook)

static func _tube(pts: PackedVector3Array, r: float) -> ArrayMesh:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 6
	var rings := []
	for i in pts.size():
		var t := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var a := t.cross(Vector3.UP).normalized(); var b := t.cross(a)
		var ring := []
		for k in sides:
			var ang := TAU * k / sides
			ring.append([pts[i] + (a * cos(ang) + b * sin(ang)) * r, (a * cos(ang) + b * sin(ang))])
		rings.append(ring)
	for i in pts.size() - 1:
		for k in sides:
			var k2 := (k + 1) % sides
			for v in [rings[i][k], rings[i + 1][k], rings[i][k2], rings[i][k2], rings[i + 1][k], rings[i + 1][k2]]:
				st.set_normal(v[1]); st.add_vertex(v[0])
	return st.commit()

# ---------------------------------------------------------------- weather

func _rain() -> void:
	var n := 3600
	var rng := RandomNumberGenerator.new(); rng.seed = 5
	var v := PackedVector3Array(); var uv := PackedVector2Array(); var idx := PackedInt32Array()
	for i in n:
		var b := Vector3(rng.randf(), rng.randf(), rng.randf())
		for c in [Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(1, 1)]:
			v.append(b); uv.append(c)
		var o := i * 4
		idx.append_array([o, o + 1, o + 2, o + 1, o + 3, o + 2])
	var arr := []; arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v; arr[Mesh.ARRAY_TEX_UV] = uv; arr[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new(); am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new(); mi.mesh = am
	mi.custom_aabb = AABB(Vector3(-100, -100, -100), Vector3(200, 200, 200))
	rain_mat = ShaderMaterial.new(); rain_mat.shader = load("res://shaders/rain.gdshader")
	rain_mat.set_shader_parameter("centre", Vector3(5.0, 6.0, -9.0))
	rain_mat.set_shader_parameter("spot_pos", PackedVector3Array([spots[0].global_position, spots[1].global_position]))
	rain_mat.set_shader_parameter("spot_dir", PackedVector3Array([-spots[0].global_transform.basis.z, -spots[1].global_transform.basis.z]))
	mi.material_override = rain_mat; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mi)

func _mist() -> void:
	# Low mist banks drifting up out of the gully and over the bend.
	for spec in [[Vector3(6, -1.2, 4.5), Vector2(26, 6), 0.0], [Vector3(-13, 1.2, -8), Vector2(14, 6), 1.2], [Vector3(10, 7.5, -27), Vector2(30, 6), 0.0]]:
		var q := QuadMesh.new(); q.size = spec[1]
		var mi := MeshInstance3D.new(); mi.mesh = q
		var m := ShaderMaterial.new(); m.shader = load("res://shaders/mist.gdshader")
		mi.material_override = m; mist_mats.append(m)
		mi.position = spec[0]; mi.rotation = Vector3(-deg_to_rad(35.0), spec[2], 0.0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(mi)

# ---------------------------------------------------------------- camera and post

func _camera() -> void:
	cam = Camera3D.new(); world.add_child(cam); cam.current = true
	# Frame the bus, the truck and the anchor tree, leaving the bottom fifth for the tool roll and remote.
	var target := (eye + winch + tree_anchor) / 3.0 + Vector3(-2.6, 0.0, 4.6)
	var dist := 68.0; var pitch := deg_to_rad(60.0); var yaw := deg_to_rad(-20.0)
	var off := Vector3(0.0, sin(pitch), cos(pitch)) * dist
	off = off.rotated(Vector3.UP, yaw)
	cam.fov = 34.0; cam.near = 1.0; cam.far = 140.0
	cam.look_at_from_position(target + off, target)

func _post() -> void:
	var cl := CanvasLayer.new(); cl.layer = 1; frame.add_child(cl)
	var r := ColorRect.new(); r.set_anchors_preset(Control.PRESET_FULL_RECT); r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tilt = ShaderMaterial.new(); tilt.shader = load("res://shaders/tiltshift.gdshader"); r.material = tilt
	cl.add_child(r)


# ---------------------------------------------------------------- in-world interface

func _overlay() -> void:
	var cl := CanvasLayer.new(); cl.layer = 2; frame.add_child(cl)
	var c := SubViewportContainer.new(); c.stretch = true; c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE; cl.add_child(c)
	overlay_vp = SubViewport.new(); overlay_vp.own_world_3d = true; overlay_vp.transparent_bg = true
	c.add_child(overlay_vp)
	var ow := Node3D.new(); overlay_vp.add_child(ow)
	var oc := Camera3D.new(); oc.projection = Camera3D.PROJECTION_ORTHOGONAL; oc.size = 10.0
	oc.position = Vector3(0, 0, 10); ow.add_child(oc); oc.current = true
	var key := DirectionalLight3D.new(); key.rotation_degrees = Vector3(-35, -30, 0); key.light_energy = 1.1; ow.add_child(key)
	var we := WorldEnvironment.new(); var e := Environment.new(); e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.5, 0.52, 0.58); e.ambient_light_energy = 0.7
	we.environment = e; ow.add_child(we)
	slip_node = _job_slip(ow, Vector3.ZERO)
	roll_node = _tool_roll(ow, Vector3.ZERO)
	remote_node = _remote(ow, Vector3.ZERO)

# Keeps the tilt-shift band on the rope and the in-world kit pinned to the screen edges.
func _relayout() -> void:
	if frame.size.x <= 0 or frame.size.y <= 0: return
	var sz := Vector2(frame.size)
	var screen_eye := cam.unproject_position(eye) / sz
	var screen_mid := cam.unproject_position(eye.lerp(winch, 0.4)) / sz
	tilt.set_shader_parameter("focus", (screen_eye.y + screen_mid.y) * 0.5)
	var hw := 5.0 * sz.x / sz.y
	# Narrow phones (19.5:9 and taller) get a smaller tool roll, remote and slip so nothing overlaps.
	var k := clampf(hw / 2.82, 0.72, 1.0)
	var rk := clampf((2.0 * hw - 1.5 * k - 0.3) / 4.1, 0.55, 1.0)
	slip_node.scale = Vector3.ONE * 0.82 * k
	slip_node.position = Vector3(-hw + 0.15 + 2.15 * 0.82 * k, 5.0 - 0.6 * k, 0.0)
	remote_node.scale = Vector3.ONE * k
	remote_node.position = Vector3(hw - 0.2 - 0.65 * k, -5.0 + 1.45 * k, 0.0)
	roll_node.scale = Vector3.ONE * rk
	roll_node.position = Vector3(-hw + 0.1 + 1.65 * rk, -5.0 + 0.65 * rk, 0.0)

# Debug fps readout (Clip Mode will hide it). It also drops the 3D resolution on slow devices.
func _fps_readout() -> void:
	var cl := CanvasLayer.new(); cl.layer = 10; add_child(cl)
	fps_label = Label.new(); fps_label.add_theme_font_size_override("font_size", 12)
	fps_label.add_theme_color_override("font_color", Color(0.85, 0.9, 0.85, 0.85))
	fps_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	fps_label.set_anchors_preset(Control.PRESET_TOP_RIGHT); fps_label.position = Vector2(-120, 4)
	fps_label.size = Vector2(116, 40); fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fps_label.visible = not still_mode
	cl.add_child(fps_label)

func _update_fps(delta: float) -> void:
	frame_times.append(delta); fps_timer += delta
	if fps_timer < 1.0: return
	var n := frame_times.size(); var sum := 0.0
	var sorted := frame_times.duplicate(); sorted.sort()
	for d in frame_times: sum += d
	var avg := n / sum
	var worst := 1.0 / sorted[maxi(0, int(n * 0.99) - 1)]
	var scale := frame.scaling_3d_scale
	fps_label.text = "%d fps\nlow %d  ·  3D %d%%" % [roundi(avg), roundi(worst), roundi(scale * 100.0)]
	if avg < 54.0: slow_streak += 1
	else: slow_streak = 0
	if slow_streak >= 2 and scale > 0.5:
		frame.scaling_3d_scale = maxf(0.5, scale - 0.1); slow_streak = 0
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.lookFps = {avg: %f, low: %f, scale: %f};" % [avg, worst, frame.scaling_3d_scale])
	frame_times.clear(); fps_timer = 0.0

func _mat(col: Color, rough := 0.7, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = col; m.roughness = rough; m.metallic = metal; return m

func _box(parent: Node3D, size: Vector3, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var b := BoxMesh.new(); b.size = size; mi.mesh = b
	mi.material_override = m; mi.position = pos; mi.rotation = rot; parent.add_child(mi); return mi

func _label(parent: Node3D, text: String, pos: Vector3, px: float, col: Color, w := 0) -> Label3D:
	var l := Label3D.new(); l.text = text; l.position = pos; l.pixel_size = px; l.modulate = col
	l.outline_size = 0; l.shaded = false; l.double_sided = false
	if w > 0: l.autowrap_mode = TextServer.AUTOWRAP_WORD; l.width = w
	parent.add_child(l); return l

func _job_slip(ow: Node3D, at: Vector3) -> Node3D:
	var slip := Node3D.new(); slip.position = at; slip.rotation.z = deg_to_rad(-2.0); ow.add_child(slip)
	_box(slip, Vector3(4.3, 1.15, 0.02), Vector3.ZERO, _mat(Color(0.86, 0.84, 0.76), 0.95))
	_box(slip, Vector3(4.3, 0.05, 0.03), Vector3(0, 0.42, 0.01), _mat(Color(0.55, 0.6, 0.66), 0.9))
	_label(slip, "JOB 0417  ·  MONSOON RECOVERY CO.", Vector3(-2.0, 0.3, 0.03), 0.0042, Color(0.25, 0.27, 0.3)).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_label(slip, "Bus off the edge, ghat road", Vector3(-2.0, -0.02, 0.03), 0.0078, Color(0.1, 0.1, 0.12)).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_label(slip, "Monsoon  ·  9:40 pm", Vector3(-2.0, -0.36, 0.03), 0.0052, Color(0.25, 0.27, 0.3)).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return slip

func _tool_roll(ow: Node3D, at: Vector3) -> Node3D:
	var roll := Node3D.new(); roll.position = at; ow.add_child(roll)
	var canvas := _mat(Color(0.33, 0.31, 0.22), 1.0)
	_box(roll, Vector3(3.3, 1.15, 0.08), Vector3.ZERO, canvas)
	# Rolled-up end.
	var cyl := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.24; cm.bottom_radius = 0.24; cm.height = 1.2
	cyl.mesh = cm; cyl.material_override = canvas; cyl.position = Vector3(1.75, 0, 0.12); roll.add_child(cyl)
	for x in [-1.1, 0.0]:
		_box(roll, Vector3(1.0, 0.55, 0.1), Vector3(x, -0.25, 0.08), _mat(Color(0.28, 0.26, 0.18), 1.0))
		_box(roll, Vector3(1.0, 0.03, 0.11), Vector3(x, 0.02, 0.09), _mat(Color(0.2, 0.19, 0.13), 1.0))
	# The snatch block: hi-vis orange cheek plates, steel sheave and swivel eye.
	var blk := Node3D.new(); blk.position = Vector3(-1.1, 0.05, 0.3); blk.rotation.z = deg_to_rad(12.0); roll.add_child(blk)
	var orange := _mat(Color(1.0, 0.42, 0.04), 0.5)
	var steel := _mat(Color(0.62, 0.63, 0.65), 0.3, 0.85)
	for z in [-0.07, 0.07]:
		var d := MeshInstance3D.new(); var dm := CylinderMesh.new(); dm.top_radius = 0.34; dm.bottom_radius = 0.34; dm.height = 0.05
		d.mesh = dm; d.material_override = orange; d.rotation.x = PI / 2.0; d.position = Vector3(0, 0, z); blk.add_child(d)
	var sh := MeshInstance3D.new(); var sm := CylinderMesh.new(); sm.top_radius = 0.26; sm.bottom_radius = 0.26; sm.height = 0.1
	sh.mesh = sm; sh.material_override = steel; sh.rotation.x = PI / 2.0; blk.add_child(sh)
	var ey := MeshInstance3D.new(); var tm := TorusMesh.new(); tm.inner_radius = 0.07; tm.outer_radius = 0.13
	ey.mesh = tm; ey.material_override = steel; ey.rotation.x = PI / 2.0; ey.position = Vector3(0, 0.46, 0); blk.add_child(ey)
	var hub := MeshInstance3D.new(); var hm := CylinderMesh.new(); hm.top_radius = 0.09; hm.bottom_radius = 0.09; hm.height = 0.22
	hub.mesh = hm; hub.material_override = steel; hub.rotation.x = PI / 2.0; blk.add_child(hub)
	_box(blk, Vector3(0.5, 0.06, 0.2), Vector3(0, -0.36, 0), steel)
	return roll
	_box(blk, Vector3(0.08, 0.16, 0.12), Vector3(0, 0.34, 0), steel)

func _remote(ow: Node3D, at: Vector3) -> Node3D:
	var r := Node3D.new(); r.position = at; r.rotation.z = deg_to_rad(-7.0); ow.add_child(r)
	var body := _mat(Color(0.14, 0.145, 0.15), 0.55)
	_box(r, Vector3(1.25, 2.1, 0.32), Vector3.ZERO, body)
	_box(r, Vector3(1.31, 0.18, 0.34), Vector3(0, -0.98, 0), _mat(Color(1.0, 0.42, 0.04), 0.6))   # hi-vis bumper
	# Dial: white face, red danger arc near Limit, black needle.
	var face := MeshInstance3D.new(); var fm := CylinderMesh.new(); fm.top_radius = 0.36; fm.bottom_radius = 0.36; fm.height = 0.03
	face.mesh = fm; face.material_override = _mat(Color(0.88, 0.87, 0.82), 0.6); face.rotation.x = PI / 2.0; face.position = Vector3(0, 0.55, 0.17); r.add_child(face)
	for k in 5:
		var a := deg_to_rad(60.0 - k * 12.0)
		_box(r, Vector3(0.12, 0.05, 0.01), Vector3(cos(a) * 0.27, 0.55 + sin(a) * 0.27, 0.19), _mat(Color(0.75, 0.08, 0.06), 0.6), Vector3(0, 0, a))
	var needle_a := deg_to_rad(150.0 - 0.3 * 120.0)
	_box(r, Vector3(0.3, 0.025, 0.01), Vector3(cos(needle_a) * 0.14, 0.55 + sin(needle_a) * 0.14, 0.2), _mat(Color(0.05, 0.05, 0.05), 0.5), Vector3(0, 0, needle_a))
	# IN and OUT buttons.
	for spec in [["IN", Vector3(0, -0.15, 0.17), 0.33], ["OUT", Vector3(0, -0.72, 0.17), 0.2]]:
		var b := MeshInstance3D.new(); var bm := CylinderMesh.new(); bm.top_radius = spec[2]; bm.bottom_radius = spec[2]; bm.height = 0.1
		b.mesh = bm; b.material_override = _mat(Color(0.7, 0.71, 0.7), 0.5); b.rotation.x = PI / 2.0; b.position = spec[1]; r.add_child(b)
		_label(r, spec[0], spec[1] + Vector3(0, 0, 0.06), 0.0062 if spec[0] == "IN" else 0.0042, Color(0.1, 0.1, 0.1))
	return r

# ---------------------------------------------------------------- loop and capture

func _process(delta: float) -> void:
	clock += delta
	if fps_label and not still_mode: _update_fps(delta)
	if rain_mat: rain_mat.set_shader_parameter("t", clock)
	if ground_mat: ground_mat.set_shader_parameter("t", clock)
	if tilt: tilt.set_shader_parameter("t", clock)
	for m in mist_mats: m.set_shader_parameter("t", clock)

func _save_still(path: String) -> void:
	for i in 12: await get_tree().process_frame
	frame.get_texture().get_image().save_png(path)
	print("saved ", path)
	get_tree().quit()
