extends Node

var front_lines: Dictionary = {}

func _ready():
	await get_tree().process_frame
	await get_tree().process_frame

	_create_front_line("DEU", "POL")


func _create_front_line(nation_a: String, nation_b: String):
	var key = nation_a + "_" + nation_b
	if front_lines.has(key):
		return

	print("=== FrontLineManager ===")
	print("Lade states.geojson...")

	var geojson = _load_geojson("res://data/states.geojson")
	var ownership = _load_ownership("res://data/ownership.json")

	if geojson.is_empty() or ownership.is_empty():
		print("Fehler beim Laden der Dateien.")
		return

	# === Automatische state_id aus Reihenfolge berechnen ===
	var OFFSET = 5   # Germany = Feature 53 → ID 48
	var features = geojson.get("features", [])

	var states_a = []
	var states_b = []

	for i in range(features.size()):
		var feature = features[i]
		var props = feature.get("properties", {})
		var state_id = i + OFFSET

		var owner = ""
		for entry in ownership:
			if entry.id == state_id:
				owner = entry.owner
				break

		if owner == nation_a:
			states_a.append({
				"id": state_id,
				"polygon": _get_polygon_from_feature(feature)
			})
		elif owner == nation_b:
			states_b.append({
				"id": state_id,
				"polygon": _get_polygon_from_feature(feature)
			})

	print("Gefundene %s States: %d" % [nation_a, states_a.size()])
	print("Gefundene %s States: %d" % [nation_b, states_b.size()])

	if states_a.is_empty() or states_b.is_empty():
		print("Keine States gefunden.")
		return

	# === Frontlinie erzeugen (einfache Version: alle Grenzen der gefundenen States) ===
	var segments: Array = []

	for state in states_a:
		for ring in state.polygon:
			if ring.size() > 2:
				segments.append(ring)

	for state in states_b:
		for ring in state.polygon:
			if ring.size() > 2:
				segments.append(ring)

	if segments.is_empty():
		print("Keine Polygone gefunden.")
		return

	var fl := FrontLine.new()
	fl.name = "FrontLine_%s" % key
	get_tree().current_scene.add_child(fl)
	fl.set_segments(segments)

	front_lines[key] = fl
	print("Frontlinie erstellt mit %d Segmenten." % segments.size())


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

func _get_polygon_from_feature(feature: Dictionary) -> Array:
	var geometry = feature.get("geometry", {})
	var coords = geometry.get("coordinates", [])
	
	if geometry.get("type") == "Polygon":
		return coords
	elif geometry.get("type") == "MultiPolygon":
		if coords.size() > 0:
			return coords[0]
	return []
