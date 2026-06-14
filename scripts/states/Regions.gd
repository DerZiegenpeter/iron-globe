extends Node3D

@export var radius: float = 1000.0
@export var max_features: int = 1000
@export var default_alpha: float = 0.35

@onready var polygons_container: Node3D = get_node("../Polygons")
@onready var game_data: Node = get_node_or_null("/root/GameData")

var region_polygons: Array = []
var fill_material: ShaderMaterial

func _ready():
	_create_fill_material()
	load_regions()

func _create_fill_material():
	fill_material = ShaderMaterial.new()
	var shader = load("res://shaders/region_fill.gdshader")
	if shader:
		fill_material.shader = shader
	else:
		print("WARNUNG: Shader nicht gefunden!")

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
	print("Lade ", features.size(), " Regionen mit Shader-Schleier...")
	
	region_polygons.clear()
	
	for i in features.size():
		if i >= max_features: break
		
		var feature = features[i]
		var props = feature.get("properties", {})
		var geometry = feature.get("geometry", {})
		
		var region_id = i + 1
		var region_name = props.get("NAME", props.get("name", "Region " + str(region_id)))
		
		# Farbe aus GameData holen
		var nation_color = Color(0.4, 0.4, 0.6, default_alpha)
		
		if game_data and game_data.has_method("get_province_info"):
			var info = game_data.get_province_info(region_id, region_name)
			if typeof(info) == TYPE_DICTIONARY and info.has("color"):
				nation_color = Color(info.color)
				nation_color.a = default_alpha
		
		var rings = _extract_rings(geometry)
		if rings.is_empty(): continue
		
		# Mesh erstellen
		var mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "Region_%04d" % i
		polygons_container.add_child(mesh_instance)
		
		var immediate = ImmediateMesh.new()
		mesh_instance.mesh = immediate
		
		var mat = fill_material.duplicate()
		mat.set_shader_parameter("albedo", nation_color)
		mesh_instance.material_override = mat
		
		immediate.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for ring in rings:
			_triangulate_ring(immediate, ring)
		immediate.surface_end()
		
		region_polygons.append({
			"id": region_id,
			"name": region_name,
			"rings": rings,
			"mesh": mesh_instance,
			"color": nation_color
		})
	
	print("✅ ", region_polygons.size(), " Regionen mit farbigem Shader-Schleier geladen!")

func _extract_rings(geometry: Dictionary) -> Array:
	var rings = []
	var coords = geometry.get("coordinates", [])
	var geom_type = geometry.get("type", "")
	
	if geom_type == "MultiPolygon":
		for p in coords:
			if p.size() > 0 and p[0].size() >= 3:
				rings.append(p[0])
	elif geom_type == "Polygon":
		if coords.size() > 0 and coords[0].size() >= 3:
			rings.append(coords[0])
	
	return rings

func _triangulate_ring(immediate: ImmediateMesh, ring: Array):
	if ring.size() < 3: return
	for j in range(1, ring.size() - 1):
		immediate.surface_add_vertex(lat_lon_to_vector3(ring[0][1], ring[0][0], radius))
		immediate.surface_add_vertex(lat_lon_to_vector3(ring[j][1], ring[j][0], radius))
		immediate.surface_add_vertex(lat_lon_to_vector3(ring[j+1][1], ring[j+1][0], radius))

func lat_lon_to_vector3(lat: float, lon: float, r: float) -> Vector3:
	var lat_rad = deg_to_rad(lat)
	var lon_rad = deg_to_rad(lon)
	return Vector3(
		r * cos(lat_rad) * sin(lon_rad),
		r * sin(lat_rad),
		r * cos(lat_rad) * cos(lon_rad)
	)
