extends Node3D

@export var radius: float = 1000.0
@export var max_features: int = 1000
@export var line_color: Color = Color(0.0, 1.0, 0.4)
@export var emission_strength: float = 2.2
@export var fill_alpha: float = 0.0

@onready var polygons_container: Node3D = get_node("../Polygons")

var region_polygons: Array = []

func _ready():
	if polygons_container == null:
		print("Fehler: Node 'Polygons' nicht gefunden!")
		return
	load_regions()

func load_regions():
	var file_path = "res://data/states.geojson"
	if not FileAccess.file_exists(file_path):
		print("Datei nicht gefunden: ", file_path)
		return
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	var content = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(content)
	if error != OK:
		print("JSON Parse Fehler: ", error)
		return
	
	var features = json.data.get("features", [])
	print("Lade Regionen: ", features.size(), " Features...")
	
	var count = 0
	region_polygons.clear()
	
	for feature in features:
		if count >= max_features:
			break
		
		var geometry = feature.get("geometry", {})
		var geom_type = geometry.get("type", "")
		if geom_type != "Polygon" and geom_type != "MultiPolygon":
			continue
		
		var props = feature.get("properties", {})
		
		# === ROBUSTE ID & NAME Extraktion ===
		var region_id = props.get("id")
		if region_id == null: region_id = props.get("ID")
		if region_id == null: region_id = props.get("GID_1")
		if region_id == null: region_id = props.get("ISO_A2")
		if region_id == null: region_id = props.get("OBJECTID")
		if region_id == null: region_id = props.get("admin_code")
		if region_id == null: region_id = count + 1
		
		var region_name = props.get("name")
		if region_name == null: region_name = props.get("NAME")
		if region_name == null: region_name = props.get("NAME_EN")
		if region_name == null: region_name = props.get("NAME_LONG")
		if region_name == null: region_name = props.get("admin")
		if region_name == null: region_name = "Region " + str(count + 1)
		
		# Debug für erste Region
		if count == 0:
			print("Beispiel-Properties: ", props)
		
		var all_rings = []
		if geom_type == "MultiPolygon":
			for poly in geometry.get("coordinates", []):
				if not poly.is_empty() and poly[0].size() >= 3:
					all_rings.append(poly[0])
		else:
			var poly = geometry.get("coordinates", [])
			if not poly.is_empty() and poly[0].size() >= 3:
				all_rings.append(poly[0])
		
		if all_rings.is_empty():
			continue
		
		# Mesh erstellen
		var mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "Region_%04d" % count
		polygons_container.add_child(mesh_instance)
		if get_tree().edited_scene_root:
			mesh_instance.owner = get_tree().edited_scene_root
		
		var immediate_mesh = ImmediateMesh.new()
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(line_color.r, line_color.g, line_color.b, fill_alpha)
		mat.emission_enabled = true
		mat.emission = line_color * emission_strength
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		
		mesh_instance.material_override = mat
		mesh_instance.mesh = immediate_mesh
		
		immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		for ring in all_rings:
			for i in range(ring.size() - 1):
				var p1 = ring[i]
				var p2 = ring[i + 1]
				immediate_mesh.surface_add_vertex(lat_lon_to_vector3(p1[1], p1[0], radius))
				immediate_mesh.surface_add_vertex(lat_lon_to_vector3(p2[1], p2[0], radius))
			immediate_mesh.surface_add_vertex(lat_lon_to_vector3(ring[0][1], ring[0][0], radius))
			immediate_mesh.surface_add_vertex(lat_lon_to_vector3(ring[-1][1], ring[-1][0], radius))
		immediate_mesh.surface_end()
		
		region_polygons.append({
			"id": str(region_id),      # als String speichern für Sicherheit
			"name": str(region_name),
			"rings": all_rings
		})
		
		count += 1
	
	print("Fertig! ", count, " Regionen geladen (mit echten IDs & Namen)")

func lat_lon_to_vector3(lat: float, lon: float, r: float) -> Vector3:
	var lat_rad = deg_to_rad(lat)
	var lon_rad = deg_to_rad(lon)
	return Vector3(
		r * cos(lat_rad) * sin(lon_rad),
		r * sin(lat_rad),
		r * cos(lat_rad) * cos(lon_rad)
	)
