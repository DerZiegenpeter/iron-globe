extends Control

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var info_label: RichTextLabel = $VBoxContainer/InfoLabel
@onready var pie_chart: PieChart = $VBoxContainer/PieChartContainer/PieChart

func _ready():
	hide()
	
	# Schriftgröße des RichTextLabels per Code setzen (sicherer Fallback)
	if info_label:
		info_label.add_theme_font_size_override("normal_font_size", 24)
	
	var game_data = get_node_or_null("/root/GameData")
	if game_data:
		game_data.state_selected.connect(_on_state_selected)
		game_data.state_deselected.connect(hide_panel)
		game_data.unit_selected.connect(_on_unit_selected)

func _on_state_selected(info: Dictionary):
	show_state(info)

func _on_unit_selected(entity: GroundEntity):
	show_unit(entity)

func show_state(info: Dictionary):
	show()
	
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

func show_unit(entity: GroundEntity):
	show()
	title_label.text = entity.entity_name if entity else "Einheit"
	info_label.text = "Einheit ausgewählt"
	pie_chart.data.clear()
	pie_chart.queue_redraw()

func hide_panel():
	hide()
	pie_chart.data.clear()

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
		Color(0.4, 0.8, 0.8),
		Color(0.9, 0.4, 0.4),
		Color(0.5, 0.3, 0.8),
	]
	for i in keys.size():
		result[keys[i]] = base_colors[i % base_colors.size()]
	return result
