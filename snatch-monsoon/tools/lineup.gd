extends SceneTree
# Side-by-side render of candidate models at true relative size: -- out.png name:length_m ...
func _initialize():
	go()
func go():
	await process_frame
	var a := OS.get_cmdline_user_args()
	DisplayServer.window_set_size(Vector2i(1600, 600)); await process_frame
	var w := Node3D.new(); get_root().add_child(w)
	var we := WorldEnvironment.new(); var e := Environment.new(); e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.42, 0.47, 0.5)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.55, 0.55, 0.6); we.environment = e; w.add_child(we)
	var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-40, -35, 0); l.light_energy = 1.2; w.add_child(l)
	var x := 0.0
	for spec in a.slice(1):
		var parts: PackedStringArray = spec.split(":")
		var n: Node3D = load("res://assets/cartoon/" + parts[0] + ".glb").instantiate(); w.add_child(n)
		var b := _aabb(n); var s := float(parts[1]) / maxf(b.size.x, b.size.z)
		n.scale = Vector3.ONE * s; await process_frame; b = _aabb(n)
		n.position = Vector3(x - b.position.x, -b.position.y, -b.get_center().z)
		x += b.size.x + 1.5
		print(parts[0], " raw size ", b.size / s, " -> ", b.size)
	var c := Camera3D.new(); w.add_child(c); c.current = true; c.fov = 22
	c.look_at_from_position(Vector3(x * 0.5, 9, 30 + x * 0.6), Vector3(x * 0.5, 2.5, 0))
	for i in 5: await process_frame
	get_root().get_texture().get_image().save_png(a[0]); quit()
func _aabb(n: Node3D) -> AABB:
	var r := AABB(); var f := true
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = mi.global_transform * mi.get_aabb(); r = b if f else r.merge(b); f = false
	return r
