class_name WeaponUnlocks
extends RefCounted

## Pure prototype unlock rules. Persistence and run reward calculation belong
## to the profile/hub layer; callers pass their current state into these APIs.

const UNLOCK_ORDER: Array[String] = ["bow", "sword", "staff", "spirit_focus"]
const DEFAULT_COSTS := {
	"bow": 0,
	"sword": 100,
	"staff": 180,
	"spirit_focus": 280,
}


static func unlock_order() -> Array[String]:
	return UNLOCK_ORDER.duplicate()


## Pass a partial overrides dictionary to tune the prototype without changing
## these defaults. Unknown keys and invalid (negative/non-integer) costs are
## ignored.
static func unlock_costs(overrides: Dictionary = {}) -> Dictionary:
	var result: Dictionary = DEFAULT_COSTS.duplicate(true)
	for weapon_id: String in UNLOCK_ORDER:
		if not overrides.has(weapon_id):
			continue
		var value: Variant = overrides[weapon_id]
		if typeof(value) == TYPE_INT and int(value) >= 0:
			result[weapon_id] = int(value)
	return result


static func get_unlock_cost(weapon_id: String, cost_overrides: Dictionary = {}) -> int:
	if not UNLOCK_ORDER.has(weapon_id):
		return -1
	return int(unlock_costs(cost_overrides)[weapon_id])


static func default_state(material: int = 0) -> Dictionary:
	return {
		"unlocked_weapon_ids": ["bow"],
		"selected_weapon_id": "bow",
		"material": maxi(0, material),
	}


static func is_unlocked(state: Dictionary, weapon_id: String) -> bool:
	if not UNLOCK_ORDER.has(weapon_id):
		return false
	var ids: Variant = state.get("unlocked_weapon_ids", [])
	return typeof(ids) == TYPE_ARRAY and (ids as Array).has(weapon_id)


static func select_weapon(state: Dictionary, weapon_id: String) -> Dictionary:
	var checked := _validated_state(state)
	if not checked["ok"]:
		return checked
	if not UNLOCK_ORDER.has(weapon_id):
		return _failure("invalid_weapon")
	var selected_state: Dictionary = checked["state"]
	if not (selected_state["unlocked_weapon_ids"] as Array).has(weapon_id):
		return _failure("locked_weapon", selected_state)
	selected_state["selected_weapon_id"] = weapon_id
	return {"ok": true, "state": selected_state}


## Awarded material should be the amount already earned by a completed run.
## This helper only adds it to a state; it does not decide what a run earns.
static func add_run_material(state: Dictionary, earned_material: int) -> Dictionary:
	var checked := _validated_state(state)
	if not checked["ok"]:
		return checked
	if earned_material < 0:
		return _failure("invalid_amount")
	var updated: Dictionary = checked["state"]
	updated["material"] = int(updated["material"]) + earned_material
	return {"ok": true, "state": updated}


## Only the next weapon in the configured order can be purchased. The input
## dictionary is never mutated; persist the returned state explicitly.
static func try_unlock(state: Dictionary, weapon_id: String, cost_overrides: Dictionary = {}) -> Dictionary:
	var checked := _validated_state(state)
	if not checked["ok"]:
		return checked
	if not UNLOCK_ORDER.has(weapon_id):
		return _failure("invalid_weapon")
	var current: Dictionary = checked["state"]
	if (current["unlocked_weapon_ids"] as Array).has(weapon_id):
		return _failure("already_unlocked", current)
	var next_weapon := ""
	for candidate: String in UNLOCK_ORDER:
		if not (current["unlocked_weapon_ids"] as Array).has(candidate):
			next_weapon = candidate
			break
	if weapon_id != next_weapon:
		return _failure("out_of_order", current)
	var cost := get_unlock_cost(weapon_id, cost_overrides)
	if int(current["material"]) < cost:
		var insufficient := _failure("insufficient_material", current)
		insufficient["cost"] = cost
		return insufficient
	(current["unlocked_weapon_ids"] as Array).append(weapon_id)
	current["material"] = int(current["material"]) - cost
	return {"ok": true, "code": "unlocked", "weapon_id": weapon_id, "cost": cost, "state": current}


static func _validated_state(state: Dictionary) -> Dictionary:
	var raw_ids: Variant = state.get("unlocked_weapon_ids", null)
	var raw_selected: Variant = state.get("selected_weapon_id", null)
	var raw_material: Variant = state.get("material", null)
	if typeof(raw_ids) != TYPE_ARRAY or typeof(raw_selected) != TYPE_STRING or typeof(raw_material) != TYPE_INT or int(raw_material) < 0:
		return _failure("invalid_state")
	var ids: Array[String] = []
	for index: int in range((raw_ids as Array).size()):
		var value: Variant = (raw_ids as Array)[index]
		if typeof(value) != TYPE_STRING or index >= UNLOCK_ORDER.size() or str(value) != UNLOCK_ORDER[index]:
			return _failure("invalid_state")
		ids.append(str(value))
	if ids.is_empty():
		return _failure("invalid_state")
	if not ids.has(str(raw_selected)):
		return _failure("invalid_state")
	return {
		"ok": true,
		"state": {
			"unlocked_weapon_ids": ids,
			"selected_weapon_id": str(raw_selected),
			"material": int(raw_material),
		},
	}


static func _failure(code: String, state: Dictionary = {}) -> Dictionary:
	var result := {"ok": false, "code": code}
	if not state.is_empty():
		result["state"] = state.duplicate(true)
	return result
