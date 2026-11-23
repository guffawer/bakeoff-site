extends SceneTree
# Lists meshes, triangle counts, materials and texture sizes of each glTF given after "--".
func _initialize():
	for p in OS.get_cmdline_user_args():
		var doc := GLTFDocument.new(); var st := GLTFState.new()
		if doc.append_from_file(p, st) != OK: print("FAIL ", p); continue
		var tris := 0; var surf := 0
		for gm in st.get_meshes():
			var im: ImporterMesh = gm.mesh
			for s in im.get_surface_count():
				surf += 1
				var a := im.get_surface_arrays(s); var idx = a[Mesh.ARRAY_INDEX]
				tris += (idx.size() if idx else a[Mesh.ARRAY_VERTEX].size()) / 3
		var texs := []
		for im in st.get_images(): texs.append("%dx%d" % [im.get_width(), im.get_height()])
		print(p.get_file(), ": nodes=", st.get_nodes().size(), " meshes=", st.get_meshes().size(), " surfaces=", surf, " tris=", tris, " materials=", st.get_materials().size(), " images=", texs)
		for m in st.get_materials(): print("   mat ", m.resource_name, " ", m.albedo_color if m is StandardMaterial3D else "")
	quit()
