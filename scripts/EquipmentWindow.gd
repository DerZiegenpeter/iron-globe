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
		content_label.text = "EquipmentManager nicht gefunden!"
		show()
		move_to_front()
		return

	show()
	move_to_front()
	title_label.text = "%s - %s" % [nation, category]

	var stock = equip_manager.get_stockpile(nation)
	var equipment_types = equip_manager.get("equipment_types")

	if equipment_types == null or equipment_types.is_empty():
		content_label.text = "Fehler beim Laden der Ausrüstung.\n\n(Die Datei equipment_types.json wurde nicht geladen.)"
		return

	var text := ""

	for equip_id in equipment_types:
		var data = equipment_types[equip_id]
		var cat = data.get("category", "")

		if cat != category:
			continue

		var display_name = data.get("display_name", equip_id)
		var amount = stock.get(equip_id, 0)

		text += "[b]%s[/b]\n   Bestand: %d\n\n" % [display_name, amount]

	content_label.text = text if text != "" else "Keine Einträge in dieser Kategorie."

func close_window():
	hide()
