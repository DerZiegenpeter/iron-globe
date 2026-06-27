extends Node

var front_lines: Dictionary = {}

func _ready():
	await get_tree().process_frame
	await get_tree().process_frame

	# Korrekte Codes aus Diplomacy + ownership.json
	_create_front_line("GER", "POL")


func _create_front_line(nation_a: String, nation_b: String):
	var key = nation_a + "_" + nation_b
	if front_lines.has(key):
		return

	var geojson = _load_geojson("res://data/states.geojson")
	var ownership_data = _load_ownership("res://data/ownership.json")

	print("=== FrontLine Debug ===")
	print("Suche nach Owner-Codes:", nation_a, "und", nation_b)

	var states_a = _get_states_of_nation(geojson, ownership_data, nation_a)
	var states_b = _get_states_of_nation(geojson, ownership_data, nation_b)

	print("Gefundene %s States: %d" % [nation_a, states_a.size()])
	print("Gefundene %s States: %d" % [nation_b, states_b.size()])

	if states_a.is_empty() or states_b.is_empty():
		print("→ Keine States gefunden. Prüfe, ob der Owner-Code in ownership.json wirklich", nation_a, "lautet.")
		return

	var front_segments: Array = []

	for state_a in states_a:
		var center_a = _get_polygon_center(state_a.polygon)
		var is_front = false

		for state_b in states_b:
			var center_b = _get_polygon_center(state_b.polygon)
			if center_a.distance_to(center_b) < 40.0:
				is_front = true
				break

		if is_front:
			for ring in state_a.polygon:
				if ring.size() > 2:
					front_segments.append(ring)

	print("Gefundene Front-Segmente: ", front_segments.size())

	if front_segments.is_empty():
		print("→ Keine angrenzenden Front-States gefunden.")
		return

	var fl := FrontLine.new()
	fl.name = "FrontLine_%s" % key
	get_tree().current_scene.add_child(fl)
	fl.set_segments(front_segments)

	front_lines[key] = fl
	print("Frontlinie zwischen %s und %s auf State-Grenzen erstellt!" % [nation_a, nation_b])


# ==================== HELPER ====================

func _load_geojson(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	var content = file.get_as_text()
	file.close()
	var json = JSON.new()
	if json.parse(content) != OK:
		return {}
	return json.data

func _load_ownership(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var file = FileAccess.open(path, FileAccess.READ)
	var content = file.get_as_text()
	file.close()
	var json = JSON.new()
	if json.parse(content) != OK:
		return []
	return json.data.get("ownership", [])

func _get_states_of_nation(geojson: Dictionary, ownership: Array, nation: String) -> Array:
	var result = []
	var owner_map = {}
	for entry in ownership:
		owner_map[entry.id] = entry.owner

	if not geojson.has("features"):
		return result

	for feature in geojson.features:
		var props = feature.get("properties", {})
		var state_id = props.get("id", -1)
		if owner_map.get(state_id, "") != nation:
			continue

		var geometry = feature.get("geometry", {})
		if geometry.get("type") != "Polygon" and geometry.get("type") != "MultiPolygon":
			continue

		var coords = geometry.get("coordinates", [])
		var polygons = [coords] if geometry.type == "Polygon" else coords

		for poly in polygons:
			result.append({
				"id": state_id,
				"polygon": poly
			})

	return result

func _get_polygon_center(polygon: Array) -> Vector3:
	if polygon.is_empty() or polygon[0].is_empty():
		return Vector3.ZERO

	var sum := Vector3.ZERO
	var count := 0
	for point in polygon[0]:
		if point.size() >= 2:
			var lon = deg_to_rad(point[0])
			var lat = deg_to_rad(point[1])
			var pos = Vector3(
				cos(lat) * sin(lon),
				sin(lat),
				cos(lat) * cos(lon)
			)
			sum += pos
			count += 1

	if count == 0:
		return Vector3.ZERO
	return (sum / count).normalized() * 1002.0
