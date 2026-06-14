extends Node3D

@export var radius: float = 1000.0
@export var max_features: int = 1000
@export var fill_alpha: float = 0.22

@onready var polygons_container: Node3D = get_node("../Polygons")
@onready var game_data: Node = get_node_or_null("/root/GameData")

var region_polygons: Array = []
var fill_material: ShaderMaterial

func _ready():
	_create_material()
	load_regions()

func _create_material():
	fill_material = ShaderMaterial.new()
	var shader = load("res://shaders/region_fill.gdshader")
	if shader:
		fill_material.shader = shader
	else:
		print("Shader nicht gefunden!")

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
	print("Lade ", features.size(), " Regionen...")

	region_polygons.clear()
	
	for i in features.size():
		if i >= max_features: break
		
		var feature = features[i]
		var props = feature.get("properties", {})
		var geometry = feature.get("geometry", {})
		
		var region_id = i + 1
		var region_name = props.get("NAME", props.get("name", "Region " + str(region_id)))
		
		var nation_color = Color(0.3, 0.55, 0.9, fill_alpha)
		if game_data and game_data.has_method("get_province_info"):
			var info = game_data.get_province_info(region_id, region_name)
			if typeof(info) == TYPE_DICTIONARY and info.has("color"):
				nation_color = Color(info.color)
				nation_color.a = fill_alpha
		
		var rings = _extract_rings(geometry)
		if rings.is_empty(): continue
		
		var mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "Region_%04d" % i
		polygons_container.add_child(mesh_instance)
		
		var immediate = ImmediateMesh.new()
		mesh_instance.mesh = immediate
		
		var mat = fill_material.duplicate()
		mat.set_shader_parameter("country_color", nation_color)
		mat.set_shader_parameter("emission", 1.0)
		mesh_instance.material_override = mat
		
		immediate.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for ring in rings:
			_triangulate_ring_better(immediate, ring)
		immediate.surface_end()
		
		region_polygons.append({
			"id": region_id,
			"name": region_name,
			"color": nation_color,
			"mesh": mesh_instance
		})
	
	print("✅ ", region_polygons.size(), " Regionen geladen.")

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

func _triangulate_ring_better(immediate: ImmediateMesh, ring: Array):
	if ring.size() < 3: return
	var v0 = lat_lon_to_vector3(ring[0][1], ring[0][0], radius)
	for j in range(1, ring.size() - 1):
		var v1 = lat_lon_to_vector3(ring[j][1], ring[j][0], radius)
		var v2 = lat_lon_to_vector3(ring[j+1][1], ring[j+1][0], radius)
		immediate.surface_add_vertex(v0)
		immediate.surface_add_vertex(v1)
		immediate.surface_add_vertex(v2)

func lat_lon_to_vector3(lat: float, lon: float, r: float) -> Vector3:
	var lat_rad = deg_to_rad(lat)
	var lon_rad = deg_to_rad(lon)
	return Vector3(
		r * cos(lat_rad) * sin(lon_rad),
		r * sin(lat_rad),
		r * cos(lat_rad) * cos(lon_rad)
	)
