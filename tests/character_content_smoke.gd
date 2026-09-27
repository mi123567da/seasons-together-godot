extends Node

const CONTENT = preload("res://scripts/character_content.gd")


func _ready() -> void:
	assert(CONTENT.character_ids().size() == 4)
	assert(CONTENT.get_base_stats("shade")["max_hp"] == 120.0)
	assert(CONTENT.get_base_stats("blade")["move_speed"] == 230.0)
	assert(CONTENT.get_basic_attack("gale")["homing"] == true)
	assert(CONTENT.get_ability("missing", "Q").is_empty())
	assert(CONTENT.cooldown_seconds("shade", "Q") == 2.0)
	assert(CONTENT.cooldown_seconds("gale", "E", "renewal", 2) == 3.5)
	assert(CONTENT.cooldown_seconds("blade", "E", "duelist", 3) == 1.0)
	assert(is_equal_approx(CONTENT.cooldown_seconds("bloom", "R", "", 0, 0.85), 2.7625))
	for character_id in CONTENT.character_ids():
		for key in ["Q", "E", "R"]:
			var ability: Dictionary = CONTENT.get_ability(character_id, key)
			var contract: Dictionary = CONTENT.build_ability_contract(character_id, key)
			assert(not ability.is_empty(), "%s %s ability missing" % [character_id, key])
			assert(not contract.is_empty(), "%s %s contract missing" % [character_id, key])
			assert(not (contract["actions"] as Array).is_empty(), "%s %s actions missing" % [character_id, key])
	print("CharacterContent smoke check passed: 4 characters, 12 abilities, cooldown and contract APIs.")
	get_tree().quit(0)
