extends Control
class_name PopulationWindow

@onready var total_population_label: Label = $VBoxContainer/Header/TotalPopulationLabel
@onready var pie_chart = $VBoxContainer/PieChartContainer/PieChart
@onready var details_label: RichTextLabel = $VBoxContainer/DetailsLabel

var pop_manager: Node = null


func _ready():
	hide()
	pop_manager = get_node_or_null("/root/PopManager")
	
	# Später mit TopBar verbinden
	# self.visible = false


func open_window():
	show()
	_refresh_data()


func close_window():
	hide()


func _refresh_data():
	if not pop_manager:
		total_population_label.text = "Keine Pop-Daten verfügbar"
		return

	# === Gesamtbevölkerung (später global über alle Provinzen) ===
	var total_pop = 0
	# Hier später die echte Summierung über alle Provinzen machen
	# Beispiel: total_pop = pop_manager.get_total_population_for_country("GER")

	total_population_label.text = "Gesamtbevölkerung: %s" % _format_number(total_pop)

	# === Pop Breakdown (aktuell nur Beispiel / später aus PopManager) ===
	var pop_data := _get_pop_breakdown()

	pie_chart.data = pop_data
	pie_chart.colors = _generate_colors(pop_data.keys())
	pie_chart.queue_redraw()

	# Details als Text
	var text := ""
	for pop_type in pop_data.keys():
		var amount = pop_data[pop_type]
		var percent = (float(amount) / total_pop * 100.0) if total_pop > 0 else 0
		text += "%s: %s (%.1f%%)\n" % [pop_type, _format_number(amount), percent]

	details_label.text = text


func _get_pop_breakdown() -> Dictionary:
	# TODO: Später echte Daten vom PopManager holen
	# Für jetzt Dummy-Daten zum Testen
	return {
		"Farmers": 12400000,
		"Workers": 8750000,
		"Soldiers": 1850000,
		"Clerks": 920000,
		"Aristocrats": 340000,
		"Academics": 180000
	}


func _format_number(number: int) -> String:
	var s := str(number)
	var result := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		result = s[i] + result
		count += 1
		if count % 3 == 0 and i != 0:
			result = "." + result
	return result


func _generate_colors(keys: Array) -> Dictionary:
	var result := {}
	var base_colors := [
		Color(0.3, 0.7, 0.4),   # Farmers - Grün
		Color(0.9, 0.5, 0.2),   # Workers - Orange
		Color(0.8, 0.3, 0.3),   # Soldiers - Rot
		Color(0.4, 0.6, 0.9),   # Clerks - Blau
		Color(0.9, 0.8, 0.3),   # Aristocrats - Gold
		Color(0.6, 0.4, 0.8),   # Academics - Lila
	]
	for i in keys.size():
		result[keys[i]] = base_colors[i % base_colors.size()]
	return result


func _on_close_button_pressed():
	close_window()
