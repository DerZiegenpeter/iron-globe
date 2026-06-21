extends Node

@export var ground_entity_scene: PackedScene = preload("res://scenes/military/GroundEntity.tscn")

var entities: Dictionary = {}
var parent_map: Dictionary = {}
var allowed_types: Dictionary = {}

func _ready():
	print("=== MilitaryManager gestartet ===")
	_load_allowed_types()
	load_order_of_battle()
	create_hierarchy_lines()

func _load_allowed_types():
	var path = "res://data/ground_entity_types.json"
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var json = JSON.new()
		json.parse(file.get_as_text())
		file.close()
		allowed_types = json.data.get("types", {})

func _normalize_type(raw_type: String) -> String:
	var t = raw_type.to_lower().strip_edges()
	if allowed_types.has(t): return t
	if t in ["cavalry", "cav", "horse"]: return "brigade"
	return "division"

func load_order_of_battle():
	var path = "res://data/oob.json"
	if not FileAccess.file_exists(path): return

	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	json.parse(file.get_as_text())
	file.close()

	for nation_code in json.data.keys():
		if nation_code == "metadata": continue
		var nation_data = json.data.get(nation_code, {})
		if not nation_data is Dictionary: continue

		for item in nation_data.get("divisions", []) + nation_data.get("brigades", []):
			if item is Dictionary and item.has("id"):
				spawn_combat_unit(item, nation_code)

		if nation_data.has("high_command"):
			var hc = nation_data.high_command
			if hc is Dictionary:
				spawn_simple_unit(hc, "high_command", nation_code)
				for child_id in hc.get("children", []): parent_map[child_id] = hc.id

		for key in ["army_groups", "armies", "corps"]:
			for item in nation_data.get(key, []):
				if item is Dictionary:
					spawn_simple_unit(item, key.trim_suffix("s"), nation_code)
					for child_id in item.get("children", []): parent_map[child_id] = item.id

func spawn_combat_unit(data: Dictionary, nation_code: String):
	if ground_entity_scene == null: return
	var entity = ground_entity_scene.instantiate()
	var safe_type = _normalize_type(data.get("type", "division"))

	entity.name = data.get("name", data.get("id", "Unit"))
	entity.set_meta("unit_data", data)
	entity.set_meta("nation_code", nation_code)
	entity.set_meta("unit_type", safe_type)

	get_tree().current_scene.add_child(entity)

	if data.has("position") and data.position is Array and data.position.size() >= 3:
		var raw_pos = Vector3(data.position[0], data.position[1], data.position[2])
		entity.global_position = raw_pos.normalized() * 1002.0

	entities[data.id] = entity

func spawn_simple_unit(data: Dictionary, type: String, nation_code: String):
	if ground_entity_scene == null: return
	var entity = ground_entity_scene.instantiate()
	var safe_type = _normalize_type(type)

	entity.name = data.get("name", data.get("id", type))
	entity.set_meta("unit_data", data)
	entity.set_meta("unit_type", safe_type)
	entity.set_meta("nation_code", nation_code)

	get_tree().current_scene.add_child(entity)

	if data.has("position") and data.position is Array and data.position.size() >= 3:
		var raw_pos = Vector3(data.position[0], data.position[1], data.position[2])
		entity.global_position = raw_pos.normalized() * 1002.0

	entities[data.id] = entity

func create_hierarchy_lines():
	print("=== Erstelle Hierarchy Lines ===")
	var container = Node3D.new()
	container.name = "HierarchyLines"
	get_tree().current_scene.add_child(container)

	var count = 0
	for child_id in parent_map:
		var parent_id = parent_map[child_id]
		if entities.has(child_id) and entities.has(parent_id):
			var line = MeshInstance3D.new()
			line.name = "Line_%s_to_%s" % [parent_id, child_id]
			container.add_child(line)
			line.set_script(load("res://scripts/military/HierarchyLine.gd"))
			if line.has_method("setup"):
				line.setup(entities[parent_id], entities[child_id], 24, 120.0)
			count += 1
	print("Checkmark %d Hierarchy Lines erstellt" % count)
