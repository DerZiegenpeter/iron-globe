extends Control

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var content_label: RichTextLabel = $VBoxContainer/ContentLabel
@onready var close_button: Button = $VBoxContainer/CloseButton

var equip_manager: Node


func _ready():
	close_button.pressed.connect(close_window)
	equip_manager = get_node_or_null("/root/EquipmentManager")
	hide()


func open_for_category(category: String, nation: String = "GER"):
	if not equip_manager:
		print("EquipmentManager nicht gefunden!")
		return

	show()
	title_label.text = "%s - %s" % [nation, category]

	var stock = equip_manager.call("get_stockpile", nation)
	var definitions = equip_manager.get("equipment_definitions")

	if definitions == null:
		content_label.text = "Fehler beim Laden der Ausrüstung."
		return

	var text := ""

	for equip_id in definitions:
		var cat = equip_manager.call("get_equipment_category", equip_id)
		if cat != category:
			continue

		var name = equip_manager.call("get_equipment_display_name", equip_id)
		var amount = stock.get(equip_id, 0)

		text += "[b]%s[/b]\n   Bestand: %d\n\n" % [name, amount]

	content_label.text = text if text != "" else "Keine Einträge in dieser Kategorie."


func close_window():
	hide()
