extends MeshInstance3D

var from_entity: Node3D = null
var to_entity: Node3D = null
var segments: int = 18
var bow_height: float = 28.0

func setup(from: Node3D, to: Node3D, segs: int = 18, bow: float = 28.0):
	from_entity = from
	to_entity = to
	segments = segs
	bow_height = bow
	
	if from_entity and to_entity:
		_update_line()

func _process(_delta):
	if from_entity and to_entity:
		_update_line()

func _update_line():
	var from_pos = from_entity.global_position
	var to_pos = to_entity.global_position
	
	var points: Array[Vector3] = []
	for i in range(segments + 1):
		var t = float(i) / segments
		var p = from_pos.lerp(to_pos, t)
		var bow = sin(t * PI) * bow_height
		p = p.normalized() * (p.length() + bow)
		points.append(p)
	
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINE_STRIP)
	for p in points:
		st.add_vertex(p)
	mesh = st.commit()
	
	if not material_override:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 1.0, 1.0)
		mat.emission_enabled = true
		mat.emission = Color(0.7, 0.85, 1.0) * 4.0
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material_override = mat
