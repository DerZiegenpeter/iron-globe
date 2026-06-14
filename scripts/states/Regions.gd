extends Node3D

@export var radius: float = 1000.0
@export var max_features: int = 1000
@export var border_color: Color = Color(0.0, 1.0, 0.4)
@export var border_emission: float = 3.5

# === SEHR AGGRESSIVE TEXTGRÖSSE ===
@export var text_scale: float = 22.0          # Stark erhöht
@export var min_font_size: int = 60
@export var max_font_size: int = 420

@onready var polygons_container: Node3D = get_node("../Polygons")

var region_data: Array = []

func _ready():
	load_regions()

func load_regions():
	var file_path = "res://data/states.geojson"
	if not FileAccess.file_exists(file_path):
		print("states.geojson nicht gefunden!")
		return
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	var json = JSON.new()
	json.parse(file.get_as_text())
	file.close()
	
	var features = json.data.get("features", [])
	print("Lade ", features.size(), " Regionen mit riesiger Schrift...")

	region_data.clear()
	
	for idx in features.size():
		if idx >= max_features: break
		
		var feature = features[idx]
		var props = feature.get("properties", {})
		var geometry = feature.get("geometry", {})
		
		var region_id = idx + 1
		var region_name = props.get("NAME", props.get("name", ""))
		if region_name == "": continue
		
		var rings = _extract_rings(geometry)
		if rings.is_empty(): continue
		
		# GRÜNE GRENZEN
		var border_node = MeshInstance3D.new()
		border_node.name = "Border_%04d" % idx
		polygons_container.add_child(border_node)
		
		var border_st = SurfaceTool.new()
		border_st.begin(Mesh.PRIMITIVE_LINES)
		
		for ring in rings:
			for j in range(ring.size()):
				var p1 = lat_lon_to_vector3(ring[j][1], ring[j][0], radius)
				var p2 = lat_lon_to_vector3(ring[(j + 1) % ring.size()][1], ring[(j + 1) % ring.size()][0], radius)
				border_st.add_vertex(p1)
				border_st.add_vertex(p2)
		
		border_node.mesh = border_st.commit()
		
		var border_mat = StandardMaterial3D.new()
		border_mat.albedo_color = border_color
		border_mat.emission_enabled = true
		border_mat.emission = border_color * border_emission
		border_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		border_node.material_override = border_mat
		
		# RIESIGE LÄNDERNAMEN
		var text_node = Label3D.new()
		text_node.text = region_name
		text_node.font = load("res://fonts/Schluber.otf")
		text_node.font_size = 90
		text_node.outline_size = 16
		text_node.modulate = Color(0.3, 1.0, 0.4)
		text_node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		text_node.no_depth_test = true
		text_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text_node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		
		# Sehr aggressive Größenberechnung
		var diameter = _get_3d_diameter(rings)
		var font_size = clamp(int(diameter * text_scale), min_font_size, max_font_size)
		text_node.font_size = font_size
		
		# Nahe an der Oberfläche
		var center = _get_ring_center(rings[0])
		var surface_pos = lat_lon_to_vector3(center.y, center.x, radius)
		text_node.position = surface_pos * 1.004
		
		polygons_container.add_child(text_node)
		
		region_data.append({
			"id": region_id,
			"name": region_name,
			"border": border_node,
			"label": text_node
		})
	
	print("✅ ", region_data.size(), " Regionen geladen.")

func _extract_rings(geometry: Dictionary) -> Array:
	var rings = []
	var coords = geometry.get("coordinates", [])
	var t = geometry.get("type", "")
	
	if t == "MultiPolygon":
		for poly in coords:
			if poly.size() > 0: rings.append(poly[0])
	elif t == "Polygon":
		if coords.size() > 0: rings.append(coords[0])
	return rings

func _get_ring_center(ring: Array) -> Vector2:
	var sum = Vector2.ZERO
	for p in ring:
		sum += Vector2(p[0], p[1])
	return sum / ring.size()

func _get_3d_diameter(rings: Array) -> float:
	var min_pos = Vector3(INF, INF, INF)
	var max_pos = Vector3(-INF, -INF, -INF)
	
	for ring in rings:
		for p in ring:
			var v = lat_lon_to_vector3(p[1], p[0], radius)
			min_pos.x = min(min_pos.x, v.x)
			min_pos.y = min(min_pos.y, v.y)
			min_pos.z = min(min_pos.z, v.z)
			max_pos.x = max(max_pos.x, v.x)
			max_pos.y = max(max_pos.y, v.y)
			max_pos.z = max(max_pos.z, v.z)
	
	return (max_pos - min_pos).length()

func lat_lon_to_vector3(lat: float, lon: float, r: float) -> Vector3:
	var lat_rad = deg_to_rad(lat)
	var lon_rad = deg_to_rad(lon)
	return Vector3(
		r * cos(lat_rad) * sin(lon_rad),
		r * sin(lat_rad),
		r * cos(lat_rad) * cos(lon_rad)
	)
