extends Node

@export var ground_entity_scene: PackedScene = preload("res://scenes/military/GroundEntity.tscn")

var entities: Dictionary = {}

func _ready():
	print("=== MilitaryManager gestartet ===")
	load_order_of_battle()

func load_order_of_battle():
	var path = "res://data/oob.json"
	if not FileAccess.file_exists(path):
		print("❌ oob.json nicht gefunden!")
		return

	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	json.parse(file.get_as_text())
	file.close()

	var data = json.data.get("GER", {})

	# High Command
	if data.has("high_command"):
		spawn("high_command", data.high_command, "high_command")

	for item in data.get("army_groups", []):
		spawn(item.id, item, "army_group")

	for item in data.get("armies", []):
		spawn(item.id, item, "army")

	for item in data.get("corps", []):
		spawn(item.id, item, "corps")

	for item in data.get("divisions", []):
		spawn(item.id, item, "division")

	for item in data.get("brigades", []):
		spawn(item.id, item, "brigade")

func spawn(id: String, data: Dictionary, type: String):
	if ground_entity_scene == null:
		print("❌ GroundEntity.tscn nicht gefunden!")
		return

	var entity = ground_entity_scene.instantiate()
	get_tree().current_scene.add_child(entity)
	entity.setup(data, type)
	entity._ready_after_add()

	entities[id] = entity
	print("✅", type.to_upper(), "gespawnt:", data.get("name", id))
