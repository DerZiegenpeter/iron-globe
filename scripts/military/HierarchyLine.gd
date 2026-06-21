extends MeshInstance3D

# HierarchyLine - Zeichnet eine gebogene, leuchtende Linie zwischen zwei Einheiten.
# Dynamische Bogenhöhe je nach Distanz (näher = flacher, weiter = höher, nie durch Erde).
# Dicke sehr dezent und abhängig von der übergeordneten Einheit (High Command = etwas dicker, Division = dünner).
# Immer leuchtend in der Farbe der Globe-States.

var from_entity: Node3D = null
var to_entity: Node3D = null
var segments: int = 24
var bow_height: float = 32.0

const GLOBE_RADIUS := 1002.0
const MIN_BOW := 4.0
const MAX_BOW := 180.0
const MIN_WIDTH := 0.55
const MAX_WIDTH := 1.85

func setup(from: Node3D, to: Node3D, segs: int = 24, bow: float = 32.0):
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
	
	var from_dir = from_pos.normalized()
	var to_dir = to_pos.normalized()
	var dot_val = clampf(from_dir.dot(to_dir), -1.0, 1.0)
	var angle = acos(dot_val)
	
	var t = angle / PI
	var dynamic_bow = lerp(MIN_BOW, MAX_BOW, t * t)
	
	# Dicke abhängig von der übergeordneten Einheit (from_entity = Parent)
	var parent_level := 1
	if from_entity and from_entity.has_meta("unit_type"):
		var ptype = from_entity.get_meta("unit_type")
		if ptype == "high_command":
			parent_level = 5
		elif ptype == "army_group":
			parent_level = 4
		elif ptype == "army":
			parent_level = 3
		elif ptype == "corps":
			parent_level = 2
		else:
			parent_level = 1   # Division / Brigade
	
	var level_factor = lerp(0.65, 1.35, float(parent_level - 1) / 4.0)
	var dynamic_width = lerp(MIN_WIDTH, MAX_WIDTH, t * 0.5) * level_factor
	
	var points: Array[Vector3] = []
	for i in range(segments + 1):
		var tt = float(i) / segments
		var p = from_pos.lerp(to_pos, tt)
		var lifted = p.normalized() * (GLOBE_RADIUS + dynamic_bow * sin(tt * PI))
		points.append(lifted)
	
	var half_w = dynamic_width * 0.5
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	
	for i in range(segments + 1):
		var p = points[i]
		var radial = p.normalized()
		
		var tangent: Vector3
		if i < segments:
			tangent = (points[i + 1] - p).normalized()
		else:
			tangent = (p - points[i - 1]).normalized()
		
		var side = radial.cross(tangent)
		if side.length() < 0.001:
			side = Vector3(0, 1, 0)
		side = side.normalized()
		
		var left = p + side * half_w
		var right = p - side * half_w
		
		st.add_vertex(left)
		st.add_vertex(right)
	
	mesh = st.commit()
	
	if not material_override:
		var mat = StandardMaterial3D.new()
		# Leuchtend in der Farbe der Globe-States (schönes helles Cyan-Blau)
		mat.albedo_color = Color(0.45, 0.82, 1.0, 0.85)
		mat.emission_enabled = true
		mat.emission = Color(0.25, 0.65, 1.0) * 5.5
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		material_override = mat
