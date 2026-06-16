extends MeshInstance3D

func draw_line(from_pos: Vector3, to_pos: Vector3):
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	st.set_color(Color.WHITE)
	st.add_vertex(from_pos)
	st.add_vertex(to_pos)
	mesh = st.commit()
	
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material_override = mat
