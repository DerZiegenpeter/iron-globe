extends Control

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var info_label: RichTextLabel = $VBoxContainer/InfoLabel
@onready var details_button: Button = $VBoxContainer/DetailsButton
@onready var pie_chart = $VBoxContainer/PieChartContainer/PieChart as PieChart

const GroundEntityScript = preload("res://scripts/military/GroundEntity.gd")

var details_window = null
var current_selected_unit: GroundEntityScript = null   # ← NEU


func _ready():
	hide()
	details_button.hide()

	if info_label:
		info_label.add_theme_font_size_override("normal_font_size", 24)

	var game_data = get_node_or_null("/root/GameData")
	if game_data:
		game_data.state_selected.connect(_on_state_selected)
		game_data.state_deselected.connect(hide_panel)
		game_data.unit_selected.connect(_on_unit_selected)
		game_data.unit_deselected.connect(hide_panel)

	details_button.pressed.connect(_on_details_pressed)


func _on_state_selected(info: Dictionary):
	show_state(info)
	details_button.hide()
	current_selected_unit = null


func _on_unit_selected(entity):
	var ground_entity = entity as GroundEntityScript
	show_unit(ground_entity)
	details_button.show()
	current_selected_unit = ground_entity   # ← speichern


func show_state(info: Dictionary):
	show()
	details_button.hide()
	title_label.text = info.get("name", "Unbekannt")

	var text := ""
	text += "Owner: %s (%s)\n" % [info.get("owner", "?"), info.get("owner_code", "?")]
	text += "Controller: %s (%s)\n" % [info.get("controller", "?"), info.get("controller_code", "?")]
	text += "Bevölkerung: %s\n" % info.get("population", 0)

	info_label.text = text

	var pop_data := _parse_full_pop_summary(info.get("pops", ""))
	pie_chart.data = pop_data
	pie_chart.colors = _generate_colors(pop_data.keys())
	pie_chart.queue_redraw()


func show_unit(entity):
	if not entity:
		hide_panel()
		return

	show()
	title_label.text = entity.entity_name if entity.entity_name else "Einheit"

	var text := ""
	text += "Typ: %s\n" % entity.entity_type.capitalize()
	text += "Nation: %s\n" % entity.nation_code
	text += "Readiness: %.1f%%\n" % (entity.equipment_readiness * 100)
	text += "Manpower: %d / %d\n" % [entity.manpower, entity.max_manpower]

	info_label.text = text

	pie_chart.data.clear()
	pie_chart.queue_redraw()


func _on_details_pressed():
	if not current_selected_unit:
		print("Keine Einheit ausgewählt!")
		return

	if not details_window:
		details_window = preload("res://scenes/ui/unit_details_window.tscn").instantiate()
		get_tree().current_scene.add_child(details_window)

	if details_window and details_window.has_method("open_for_entity"):
		details_window.open_for_entity(current_selected_unit)


func hide_panel():
	hide()
	details_button.hide()
	pie_chart.data.clear()
	current_selected_unit = null
	if details_window:
		details_window.hide()


func _parse_full_pop_summary(summary: String) -> Dictionary:
	var result := {}
	if summary.is_empty() or summary == "Keine Pops in diesem State.":
		return result

	var parts := summary.split(" | ")
	for part in parts:
		var regex := RegEx.new()
		regex.compile("(.+) \\((.+)\\): (\\d+)")
		var match := regex.search(part.strip_edges())
		if match:
			var full_name := match.get_string(1).strip_edges()
			var amount := int(match.get_string(3))
			result[full_name] = amount
	return result


func _generate_colors(keys: Array) -> Dictionary:
	var result := {}
	var base_colors := [
		Color(0.2, 0.6, 0.9),
		Color(0.9, 0.5, 0.2),
		Color(0.3, 0.8, 0.4),
		Color(0.8, 0.3, 0.6),
		Color(0.6, 0.6, 0.2),
	]
	for i in keys.size():
		result[keys[i]] = base_colors[i % base_colors.size()]
	return result
