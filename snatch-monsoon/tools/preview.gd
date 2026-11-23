extends SceneTree
# Renders a model from four sides: Godot --path . --script res://tools/preview.gd -- name out.png
func _initialize():
	var a := OS.get_cmdline_user_args()
	get_root().size = Vector2i(800, 600)
	var w := Node3D.new(); get_root().add_child(w)
	var m: Node3D = load("res://assets/models/" + a[0] + ".glb").instantiate(); w.add_child(m)
	var we := WorldEnvironment.new(); var e := Environment.new(); e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.5,0.55,0.6); e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.6,0.6,0.6); we.environment = e; w.add_child(we)
	var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-45, 30, 0); w.add_child(l)
	var aabb := AABB(); var first := true
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = mi.global_transform * mi.get_aabb(); aabb = b if first else aabb.merge(b); first = false
	var c := Camera3D.new(); w.add_child(c); c.current = true
	var r := aabb.size.length() * 1.1
	var imgs := []
	for dir in [Vector3(1, 0.3, 0), Vector3(0, 0.3, 1), Vector3(-1, 0.3, 0), Vector3(0.6, 0.8, -0.6)]:
		c.look_at_from_position(aabb.get_center() + dir.normalized() * r, aabb.get_center())
		for i in 4: await process_frame
		var im := get_root().get_texture().get_image(); var sz := im.get_size(); var side := mini(sz.x, sz.y); im = im.get_region(Rect2i((sz.x - side) / 2, (sz.y - side) / 2, side, side)); im.resize(400, 400); imgs.append(im)
	var out := Image.create(800, 800, false, imgs[0].get_format())
	for i in 4: out.blit_rect(imgs[i], Rect2i(0, 0, 400, 400), Vector2i((i % 2) * 400, (i / 2) * 400))
	out.save_png(a[1]); print(a[0], " aabb ", aabb); quit()
