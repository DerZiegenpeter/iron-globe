extends Node3D

@export var radius: float = 1000.0
@export var max_features: int = 10000
@export var border_color: Color = Color(0.0, 1.0, 0.4)
@export var border_emission: float = 3.5

@onready var polygons_container: Node3D = get_node("../Polygons")

func _ready():
	load_regions()

func load_regions():
	var file_path = "res://data/states.geojson"
	if not FileAccess.file_exists(file_path):
		print("❌ states.geojson nicht gefunden!")
		return
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	var json = JSON.new()
	json.parse(file.get_as_text())
	file.close()
	
	var features = json.data.get("features", [])
	print("Lade ", features.size(), " States...")

	for idx in features.size():
		if idx >= max_features: break
		var feature = features[idx]
		var geometry = feature.get("geometry", {})
		var rings = _extract_rings(geometry)
		if rings.is_empty(): continue

		var border_node = MeshInstance3D.new()
		border_node.name = "Border_%04d" % idx
		polygons_container.add_child(border_node)

		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_LINES)
		for ring in rings:
			for j in range(ring.size()):
				var p1 = lat_lon_to_vector3(ring[j][1], ring[j][0], radius)
				var p2 = lat_lon_to_vector3(ring[(j+1)%ring.size()][1], ring[(j+1)%ring.size()][0], radius)
				st.add_vertex(p1)
				st.add_vertex(p2)
		border_node.mesh = st.commit()

		var mat = StandardMaterial3D.new()
		mat.albedo_color = border_color
		mat.emission_enabled = true
		mat.emission = border_color * border_emission
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		border_node.material_override = mat

		# === LAND KOLLISION (StaticBody + CollisionShape) ===
		var static_body = StaticBody3D.new()
		border_node.add_child(static_body)

		var collision_shape = CollisionShape3D.new()
		static_body.add_child(collision_shape)

		var shape = border_node.mesh.create_trimesh_shape()
		if shape:
			collision_shape.shape = shape

		static_body.collision_layer = 2
		static_body.collision_mask = 2

	print("✅ ", features.size(), " States mit Kollision geladen.")

# Hilfsfunktionen
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

func lat_lon_to_vector3(lat: float, lon: float, r: float) -> Vector3:
	var lat_rad = deg_to_rad(lat)
	var lon_rad = deg_to_rad(lon)
	return Vector3(
		r * cos(lat_rad) * sin(lon_rad),
		r * sin(lat_rad),
		r * cos(lat_rad) * cos(lon_rad)
	)
