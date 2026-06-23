extends Node

var combat_check_timer: float = 0.0
const CHECK_INTERVAL := 0.8

func _ready():
	print("=== CombatManager (Initiative + Sticky Combat + Rote Linie) gestartet ===")


func _process(delta: float):
	combat_check_timer += delta
	if combat_check_timer >= CHECK_INTERVAL:
		combat_check_timer = 0.0
		_check_combat_start()
		_run_combat_rounds()


func _check_combat_start():
	var entities = get_tree().get_nodes_in_group("ground_entities")

	for i in range(entities.size()):
		var a: GroundEntity = entities[i]
		if not a.is_combat_unit or a.in_combat:
			continue

		for j in range(i + 1, entities.size()):
			var b: GroundEntity = entities[j]
			if not b.is_combat_unit or b.in_combat or a.nation_code == b.nation_code:
				continue

			if not a.is_at_war_with(b.nation_code):
				continue

			var dist = a.global_position.distance_to(b.global_position)
			if dist < 38.0:
				_start_combat_between(a, b)


func _start_combat_between(a: GroundEntity, b: GroundEntity):
	var init_a = a.initiative + a.experience * 0.1
	var init_b = b.initiative + b.experience * 0.1
	var a_is_attacker = init_a >= init_b

	a.start_combat(b, a_is_attacker)
	b.start_combat(a, not a_is_attacker)

	print("Kampf gestartet: %s vs %s | Angreifer: %s" % [
		a.entity_name, b.entity_name, a.entity_name if a_is_attacker else b.entity_name
	])


func _run_combat_rounds():
	var entities = get_tree().get_nodes_in_group("ground_entities")

	for entity in entities:
		if not entity is GroundEntity or not entity.in_combat or not entity.current_enemy:
			continue

		var attacker = entity if entity.is_attacker else entity.current_enemy
		var defender = entity if not entity.is_attacker else entity.current_enemy

		if not is_instance_valid(attacker) or not is_instance_valid(defender):
			continue

		_resolve_combat_round(attacker, defender)


func _resolve_combat_round(attacker: GroundEntity, defender: GroundEntity):
	var org_mod = clamp(attacker.current_organization / 100.0, 0.25, 1.3)
	var exp_mod = 1.0 + (attacker.experience / 70.0)
	var eq_mod = clamp(attacker.equipment_fulfillment, 0.5, 1.15)
	var init_mod = 1.0 + (attacker.initiative / 25.0)

	var soft_dmg = attacker.soft_attack * org_mod * exp_mod * eq_mod * init_mod * 0.8
	var hard_dmg = attacker.hard_attack * org_mod * exp_mod * eq_mod * init_mod * 0.7

	var def_value = defender.defense + defender.breakthrough * 0.35
	var def_org_mod = clamp(defender.current_organization / 100.0, 0.3, 1.2)

	var actual_soft = max(0.0, soft_dmg - def_value * def_org_mod * 0.55)
	var actual_hard = max(0.0, hard_dmg - def_value * def_org_mod * 0.5)
	var total_dmg = actual_soft + actual_hard

	defender.take_combat_damage(actual_soft * 0.55, actual_hard * 0.55, total_dmg * 0.6)
	defender.take_combat_damage(actual_soft * 0.45, actual_hard * 0.45, 0.0)

	attacker.gain_experience(0.04)
	defender.gain_experience(0.015)

	if attacker.combat_line and is_instance_valid(attacker.combat_line):
		attacker.combat_line.global_position = attacker.global_position
