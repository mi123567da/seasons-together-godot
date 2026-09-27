extends SceneTree

const WeaponContentScript = preload("res://scripts/weapon_content.gd")
const WeaponUnlocksScript = preload("res://scripts/weapon_unlocks.gd")
const CharacterContentScript = preload("res://scripts/character_content.gd")


func _initialize() -> void:
	_run()


func _run() -> void:
	var ids: Array[String] = WeaponContentScript.weapon_ids()
	assert(ids == ["bow", "sword", "staff", "spirit_focus"])
	assert(WeaponContentScript.PROTAGONIST_APPEARANCE_IDS == ["male", "female"])
	var expected_kits := {"bow": "shade", "sword": "blade", "staff": "bloom", "spirit_focus": "gale"}
	for weapon_id: String in ids:
		var weapon: Dictionary = WeaponContentScript.get_weapon(weapon_id)
		var legacy_id := str(expected_kits[weapon_id])
		assert(weapon["legacy_kit_id"] == legacy_id)
		assert(weapon["appearance_ids"] == ["male", "female"])
		assert(weapon["combat_stats"] == CharacterContentScript.get_base_stats(legacy_id))
		assert(WeaponContentScript.get_attack(weapon_id) == CharacterContentScript.get_basic_attack(legacy_id).merged({"weapon_id": weapon_id}, true))
		assert(WeaponContentScript.get_ability(weapon_id, "q")["id"] == CharacterContentScript.get_ability(legacy_id, "Q")["id"])
		assert(is_equal_approx(WeaponContentScript.cooldown_seconds(weapon_id, "Q"), CharacterContentScript.cooldown_seconds(legacy_id, "Q")))
		var contract: Dictionary = WeaponContentScript.build_ability_contract(weapon_id, "Q")
		assert(contract["weapon_id"] == weapon_id and contract["legacy_kit_id"] == legacy_id)
	var detached_attack := WeaponContentScript.get_attack("bow")
	detached_attack["name"] = "mutated"
	assert(WeaponContentScript.get_attack("bow")["name"] != "mutated")
	assert(WeaponContentScript.get_weapon("unknown").is_empty())
	assert(WeaponContentScript.get_attack("unknown").is_empty())
	assert(WeaponContentScript.get_ability("bow", "invalid").is_empty())
	assert(WeaponContentScript.cooldown_seconds("unknown", "Q") == -1.0)

	assert(WeaponUnlocksScript.unlock_order() == ids)
	assert(WeaponUnlocksScript.unlock_costs() == {"bow": 0, "sword": 100, "staff": 180, "spirit_focus": 280})
	var state: Dictionary = WeaponUnlocksScript.default_state()
	assert(state == {"unlocked_weapon_ids": ["bow"], "selected_weapon_id": "bow", "material": 0})
	assert(WeaponUnlocksScript.is_unlocked(state, "bow"))
	assert(not WeaponUnlocksScript.is_unlocked(state, "sword"))
	assert(WeaponUnlocksScript.try_unlock(state, "staff")["code"] == "out_of_order")
	assert(WeaponUnlocksScript.try_unlock(state, "sword")["code"] == "insufficient_material")
	assert(WeaponUnlocksScript.select_weapon(state, "sword")["code"] == "locked_weapon")
	var seeded := WeaponUnlocksScript.add_run_material(state, 100)
	assert(seeded["ok"] and seeded["state"]["material"] == 100)
	assert(state["material"] == 0)
	var sword_unlock := WeaponUnlocksScript.try_unlock(seeded["state"], "sword")
	assert(sword_unlock["ok"] and sword_unlock["cost"] == 100)
	assert(sword_unlock["state"]["unlocked_weapon_ids"] == ["bow", "sword"])
	assert(sword_unlock["state"]["material"] == 0)
	var selection := WeaponUnlocksScript.select_weapon(sword_unlock["state"], "sword")
	assert(selection["ok"] and selection["state"]["selected_weapon_id"] == "sword")
	var tuned := WeaponUnlocksScript.try_unlock(state, "sword", {"sword": 0})
	assert(tuned["ok"] and tuned["cost"] == 0)
	assert(WeaponUnlocksScript.get_unlock_cost("missing") == -1)
	assert(WeaponUnlocksScript.unlock_costs({"sword": 25, "staff": -1})["sword"] == 25)
	assert(WeaponUnlocksScript.unlock_costs({"staff": -1})["staff"] == 180)
	assert(not WeaponUnlocksScript.add_run_material(state, -1)["ok"])
	assert(WeaponUnlocksScript.try_unlock({"unlocked_weapon_ids": [], "selected_weapon_id": "bow", "material": 100}, "sword")["code"] == "invalid_state")
	print("WeaponContent smoke passed: kit mapping, appearance-only options, forwarded combat contract, copy safety and sequential material unlocks.")
	quit(0)
