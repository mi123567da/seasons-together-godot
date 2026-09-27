class_name WeaponContent
extends RefCounted

## Weapon-facing view over the established four combat kits.
## Gameplay values continue to come from CharacterContent, so appearance never
## selects or modifies a combat kit.

const CharacterContentScript = preload("res://scripts/character_content.gd")

const _WEAPONS := {
	"bow": {"id": "bow", "name": "长弓", "legacy_kit_id": "shade", "appearance_ids": ["male", "female"]},
	"sword": {"id": "sword", "name": "长剑", "legacy_kit_id": "blade", "appearance_ids": ["male", "female"]},
	"staff": {"id": "staff", "name": "法杖", "legacy_kit_id": "bloom", "appearance_ids": ["male", "female"]},
	"spirit_focus": {"id": "spirit_focus", "name": "灵契法器", "legacy_kit_id": "gale", "appearance_ids": ["male", "female"]},
}

const PROTAGONIST_APPEARANCE_IDS: Array[String] = ["male", "female"]


static func weapon_ids() -> Array[String]:
	return ["bow", "sword", "staff", "spirit_focus"]


static func get_weapon(weapon_id: String) -> Dictionary:
	if not _WEAPONS.has(weapon_id):
		return {}
	var weapon: Dictionary = (_WEAPONS[weapon_id] as Dictionary).duplicate(true)
	weapon["combat_stats"] = CharacterContentScript.get_base_stats(str(weapon["legacy_kit_id"]))
	return weapon


static func get_attack(weapon_id: String) -> Dictionary:
	var weapon := get_weapon(weapon_id)
	if weapon.is_empty():
		return {}
	var attack: Dictionary = CharacterContentScript.get_basic_attack(str(weapon["legacy_kit_id"]))
	attack["weapon_id"] = weapon_id
	return attack


static func get_ability(weapon_id: String, key: String) -> Dictionary:
	var weapon := get_weapon(weapon_id)
	if weapon.is_empty():
		return {}
	var ability: Dictionary = CharacterContentScript.get_ability(str(weapon["legacy_kit_id"]), key)
	if ability.is_empty():
		return {}
	ability["weapon_id"] = weapon_id
	return ability


static func build_ability_contract(weapon_id: String, key: String, options: Dictionary = {}) -> Dictionary:
	var weapon := get_weapon(weapon_id)
	if weapon.is_empty():
		return {}
	var contract: Dictionary = CharacterContentScript.build_ability_contract(str(weapon["legacy_kit_id"]), key, options)
	if contract.is_empty():
		return {}
	contract["weapon_id"] = weapon_id
	contract["legacy_kit_id"] = weapon["legacy_kit_id"]
	return contract


## Matches the existing slice cooldown contract (source cooldown conversion,
## path modifiers and haste). Unknown weapons/keys return -1 as the character
## provider does.
static func cooldown_seconds(weapon_id: String, key: String, path_id: String = "", path_level: int = 0, haste: float = 1.0) -> float:
	var weapon := get_weapon(weapon_id)
	if weapon.is_empty():
		return -1.0
	return CharacterContentScript.cooldown_seconds(str(weapon["legacy_kit_id"]), key, path_id, path_level, haste)
