class_name HubProfilePayloadAdapter
extends RefCounted

## Owns only the hub-specific sidecar. It deliberately does not mutate or save
## scripts/profile_progression.gd, whose documented schema has no hub weapons.

const SCHEMA_VERSION := 1
const WEAPON_IDS: Array[String] = ["bow", "sword", "staff", "spirit_focus"]
const GENDERS: Array[String] = ["female", "male"]


static func default_payload(starting_marks: int) -> Dictionary:
	var levels: Dictionary = {}
	for weapon_id in WEAPON_IDS:
		levels[weapon_id] = 0
	levels["bow"] = 1
	return {
		"schema_version": SCHEMA_VERSION,
		"gender": "",
		"display_name": "",
		"equipped_weapon": "bow",
		"unlocked_weapons": ["bow"],
		"weapon_levels": levels,
		"hub_marks": maxi(0, starting_marks),
	}


static func normalize_payload(raw: Dictionary, starting_marks: int) -> Dictionary:
	var payload := default_payload(starting_marks)
	if raw.get("schema_version", SCHEMA_VERSION) != SCHEMA_VERSION:
		return payload
	if GENDERS.has(str(raw.get("gender", ""))):
		payload["gender"] = str(raw["gender"])
	var display_name := str(raw.get("display_name", "")).strip_edges()
	payload["display_name"] = display_name.substr(0, 24)
	var unlocked: Array[String] = ["bow"]
	var raw_unlocked: Variant = raw.get("unlocked_weapons", [])
	if typeof(raw_unlocked) == TYPE_ARRAY:
		for weapon_value in raw_unlocked:
			var weapon_id := str(weapon_value)
			if WEAPON_IDS.has(weapon_id) and not unlocked.has(weapon_id):
				unlocked.append(weapon_id)
	payload["unlocked_weapons"] = unlocked
	var raw_levels: Variant = raw.get("weapon_levels", {})
	if typeof(raw_levels) == TYPE_DICTIONARY:
		for weapon_id in WEAPON_IDS:
			if unlocked.has(weapon_id):
				payload["weapon_levels"][weapon_id] = clampi(int(raw_levels.get(weapon_id, payload["weapon_levels"][weapon_id])), 1, 4)
	var equipped := str(raw.get("equipped_weapon", "bow"))
	if unlocked.has(equipped):
		payload["equipped_weapon"] = equipped
	var marks: Variant = raw.get("hub_marks", starting_marks)
	if typeof(marks) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(marks)):
		payload["hub_marks"] = maxi(0, int(marks))
	return payload


static func combine_with_progression(hub_payload: Dictionary, progression_snapshot: Dictionary) -> Dictionary:
	## Transport envelope for a parent controller. The progression snapshot is
	## preserved as-is; hub fields remain namespaced and never enter its schema.
	return {
		"progression": progression_snapshot.duplicate(true),
		"hub": hub_payload.duplicate(true),
	}
