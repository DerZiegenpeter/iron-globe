extends Node3D
class_name FrontLine

@export var line_color: Color = Color(0.15, 0.45, 1.0, 0.85)
@export var line_width: float = 3.0
@export var glow_intensity: float = 5.0
@export var height_offset: float = 2.0

var _mesh_instance: MeshInstance3D

func _ready():
	_mesh_instance = MeshInstance3D.new()
	add_child(_mesh_instance)
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

# points_list = Array von Arrays (jedes innere Array = ein zusammenhängendes Liniensegment)
func set_segments(segments: Array):
	_rebuild_mesh(segments)

func _rebuild_mesh(segments: Array):
	if segments.is_empty():
		if _mesh_instance:
			_mesh_instance.mesh = null
		return

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)

	var half_w = line_width * 0.5

	for segment in segments:
		if segment.size() < 2:
			continue

		for i in range(segment.size() - 1):
			var p1 = segment[i].normalized() * (1002.0 + height_offset)
			var p2 = segment[i + 1].normalized() * (1002.0 + height_offset)

			var right = p1.cross(p2).normalized()
			if right.length() < 0.01:
				right = Vector3(0, 1, 0)

			var offset = right * half_w

			st.add_vertex(p1 - offset)
			st.add_vertex(p1 + offset)
			st.add_vertex(p2 - offset)
			st.add_vertex(p2 + offset)

	var mesh = st.commit()
	_mesh_instance.mesh = mesh

	var mat := StandardMaterial3D.new()
	mat.albedo_color = line_color
	mat.emission_enabled = true
	mat.emission = line_color * glow_intensity
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mesh_instance.material_override = mat
