class_name Pop
extends Resource

@export var state_id: int = 0
@export var profession: String = ""
@export var ethnicity: String = ""
@export var culture: String = ""
@export var religion: String = ""
@export var size: int = 0

# Später erweiterbar:
# @export var wealth: float = 0.0
# @export var literacy: float = 0.0
# @export var militancy: float = 0.0

func _init(p_state_id: int = 0, p_profession: String = "", p_ethnicity: String = "", 
		   p_culture: String = "", p_religion: String = "", p_size: int = 0):
	state_id = p_state_id
	profession = p_profession
	ethnicity = p_ethnicity
	culture = p_culture
	religion = p_religion
	size = p_size

func get_description() -> String:
	return "%s %s (%s) - Size: %s" % [ethnicity.capitalize(), profession, culture, size]
