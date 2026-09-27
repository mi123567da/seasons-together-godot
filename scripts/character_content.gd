class_name CharacterContent
extends RefCounted

## Single-player character and active-skill data ported from source/content.js,
## source/game.js, and source/pets.js. Q/E/R map to primary/secondary/utility.
## This file describes effects; the combat scene owns movement, hit tests,
## timers, visuals, and applying damage/healing/shields.

const KEY_TO_SLOT := {"Q": "primary", "E": "secondary", "R": "utility"}
const BASE_STATS := {
	"max_hp": 120.0,
	"move_speed": 230.0,
	"power": 1.0,
	"radius": 22.0,
}

const _CHARACTERS := {
	"shade": {
		"id": "shade", "name": "影之旅人", "role": "远程弓手 · 身法与连射",
		"description": "自动发射高速穿影箭；以影步拉开距离、齐射并用箭幕挡住近身威胁。",
		"stats": BASE_STATS,
		"basic_attack": {"type": "projectile", "name": "穿影箭", "base_damage": 29.0, "damage_per_level": 11.0, "level_1_damage": 40.0, "speed": 720.0, "cooldown_at_level_1": 0.56, "lifetime": 4.0, "pierce": -1, "homing": false},
		"abilities": {
			"Q": {"id": "shadow_step", "slot": "primary", "name": "影步", "icon": "➶", "cooldown": 4.0, "description": "朝面向突进 230 距离并短暂无敌，留下诱饵、射出追击箭。"},
			"E": {"id": "triple_arrow", "slot": "secondary", "name": "三连箭", "icon": "➶", "cooldown": 2.5, "description": "沿瞄准方向齐射 3 支可穿透的箭；追猎路线增加箭数和伤害。"},
			"R": {"id": "arrow_guard", "slot": "utility", "name": "箭幕护身", "icon": "⌁", "cooldown": 6.0, "description": "获得持续 3 秒的护盾，受击时反击附近敌人。"},
		},
		"paths": ["hunt", "watch"],
	},
	"bloom": {
		"id": "bloom", "name": "花之旅人", "role": "治疗 · 控场 · 接力",
		"description": "自动在敌人脚下种下持续伤害的花；以花庭治疗、花种减速和花瓣护盾支援。",
		"stats": BASE_STATS,
		"basic_attack": {"type": "ground_zone", "name": "绽放之花", "damage_base": 12.0, "damage_per_level": 5.0, "level_1_damage_per_pulse": 17.0, "radius_at_level_1": 100.0, "cooldown_at_level_1": 1.32, "lifetime": 8.0, "pulse_interval": 0.5, "max_zones": 1},
		"abilities": {
			"Q": {"id": "flower_garden", "slot": "primary", "name": "花庭绽放", "icon": "✿", "cooldown": 5.5, "description": "展开花庭，脉冲治疗并减速、打断普通怪。"},
			"E": {"id": "seed_bomb", "slot": "secondary", "name": "花种弹", "icon": "❋", "cooldown": 3.0, "description": "投出花种，命中后范围爆裂并减速；路线可追加治疗或荆棘区。"},
			"R": {"id": "petal_shield", "slot": "utility", "name": "花瓣护盾", "icon": "❀", "cooldown": 6.5, "description": "为附近队友提供护盾；荆棘路线可反击，繁花路线可治疗。"},
		},
		"paths": ["thorns", "verdant"],
	},
	"gale": {
		"id": "gale", "name": "风之旅人", "role": "灵宠 · 召唤 · 强化",
		"description": "自动发射追踪蝙蝠，并带领宠物作战；可召回、治疗强化或召来风灵。",
		"stats": BASE_STATS,
		"basic_attack": {"type": "homing_projectile", "name": "追风蝙蝠", "damage_base": 18.0, "damage_per_level": 6.0, "level_1_damage": 24.0, "speed": 390.0, "cooldown_at_level_1": 0.6, "lifetime": 3.0, "pierce": -1, "homing": true},
		"abilities": {
			"Q": {"id": "recall", "slot": "primary", "name": "归队", "icon": "〰", "cooldown": 2.5, "description": "召回自有宠物，并对身边敌人造成伤害和击退。"},
			"E": {"id": "pet_boost", "slot": "secondary", "name": "强化", "icon": "✧", "cooldown": 10.0, "description": "复活并治疗自有宠物，令其伤害和最大生命提高 50%，持续 10 秒。"},
			"R": {"id": "summon_spirit", "slot": "utility", "name": "唤灵", "icon": "❋", "cooldown": 15.0, "description": "召来一只永久风灵，最多 3 只；死亡后 30 秒复活。"},
		},
		"paths": ["tempest", "renewal"],
	},
	"blade": {
		"id": "blade", "name": "刃之旅人", "role": "近战 · 锁敌追击 · 单人生存",
		"description": "自动贴近目标并挥刀横扫；主动技兼顾清场、突进和格挡。",
		"stats": BASE_STATS,
		"basic_attack": {"type": "melee_sweep", "name": "横刀", "damage_base": 28.0, "damage_per_level": 10.0, "level_1_damage": 38.0, "radius_base": 112.0, "range_per_level": 7.0, "cooldown_at_level_1": 0.3675, "requires_target": true},
		"abilities": {
			"Q": {"id": "returning_slash", "slot": "primary", "name": "回风斩", "icon": "刃", "cooldown": 3.0, "description": "横扫附近敌人并击退普通怪。"},
			"E": {"id": "chase_strike", "slot": "secondary", "name": "踏叶追锋", "icon": "➶", "cooldown": 3.5, "description": "向锁定或最近敌人突进，沿途造成伤害并短暂无敌。"},
			"R": {"id": "guard_counter", "slot": "utility", "name": "守势反刃", "icon": "盾", "cooldown": 6.0, "description": "获得护盾并立即治疗，受击时反击附近敌人。"},
		},
		"paths": ["duelist", "bulwark"],
	},
}


static func character_ids() -> Array[String]:
	return ["shade", "bloom", "gale", "blade"]


static func get_character(character_id: String) -> Dictionary:
	if not _CHARACTERS.has(character_id):
		return {}
	return (_CHARACTERS[character_id] as Dictionary).duplicate(true)


static func get_base_stats(character_id: String) -> Dictionary:
	var character := get_character(character_id)
	return (character.get("stats", {}) as Dictionary).duplicate(true)


static func get_basic_attack(character_id: String) -> Dictionary:
	var character := get_character(character_id)
	return (character.get("basic_attack", {}) as Dictionary).duplicate(true)


static func get_ability(character_id: String, key: String) -> Dictionary:
	var character := get_character(character_id)
	var normalized_key := key.to_upper()
	if character.is_empty() or not KEY_TO_SLOT.has(normalized_key):
		return {}
	return (character["abilities"] as Dictionary)[normalized_key].duplicate(true)


## The old web simulation divided content.js cooldowns by two. `haste` mirrors
## its hourglass equipment modifier (0.85); callers can omit it in this slice.
static func cooldown_seconds(character_id: String, key: String, path_id: String = "", path_level: int = 0, haste: float = 1.0) -> float:
	var ability := get_ability(character_id, key)
	if ability.is_empty():
		return -1.0
	var source_seconds := float(ability["cooldown"])
	var rank := clampi(path_level, 0, 3)
	if character_id == "gale" and key.to_upper() == "E" and path_id == "renewal":
		source_seconds = maxf(0.0, source_seconds - rank * 1.5)
	var seconds := source_seconds * 0.5
	if character_id == "blade" and key.to_upper() == "E" and path_id == "duelist":
		seconds = maxf(1.0, seconds - rank * 0.5)
	return seconds * maxf(0.0, haste)


## Returns a data-only action contract. The scene should execute actions in
## order, clamp numeric healing/shields using its own actor state, and apply
## power to damage fields tagged `power_scaled`.
## Supported path IDs: shade hunt/watch, bloom thorns/verdant,
## gale tempest/renewal, blade duelist/bulwark. Complex web-only mechanics
## (co-op combos, AI pet simulation, map constraints, enemy-specific interrupts)
## are identified in `deferred` and intentionally left to later integration.
static func build_ability_contract(character_id: String, key: String, options: Dictionary = {}) -> Dictionary:
	var ability := get_ability(character_id, key)
	if ability.is_empty():
		return {}
	var path_id := str(options.get("path_id", ""))
	var rank := clampi(int(options.get("path_level", 0)), 0, 3)
	var power := maxf(0.0, float(options.get("power", 1.0)))
	var cd_haste := float(options.get("cooldown_haste", 1.0))
	var actions: Array[Dictionary] = []
	var deferred: Array[String] = []
	var path_rank := rank if path_id in (get_character(character_id)["paths"] as Array) else 0

	match character_id:
		"shade":
			var hunt := path_rank if path_id == "hunt" else 0
			var watch := path_rank if path_id == "watch" else 0
			match key.to_upper():
				"Q":
					actions = [
					{"type": "dash", "distance": 230.0, "invulnerability": 0.8, "direction": "facing", "power_scaled": false},
					{"type": "projectile", "name": "影步追射", "damage": 28.0 * power * (1.0 + hunt * 0.3), "speed": 720.0, "lifetime": 1.2, "pierce": 1, "power_scaled": false},
					{"type": "decoy", "lifetime": 2.5 + watch, "at": "dash_origin"},
				]
				"E":
					actions = [{"type": "fan_projectiles", "name": "三连箭", "count": 7 if hunt >= 3 else (5 if hunt > 0 else 3), "damage_each": 26.0 * power * (1.0 + hunt * 0.2), "spread_radians": 0.16, "speed": 720.0, "lifetime": 1.1, "pierce": 3 if hunt >= 2 else 2, "freeze_seconds": 0.2 + watch * 0.1 if watch > 0 else 0.0, "power_scaled": false}]
				"R":
					actions = [{"type": "shield_counter", "shield": 36.0 + watch * 18.0, "duration": 3.0 + watch, "retaliation_damage": 24.0 * power * (1.0 + hunt * 0.35), "retaliation_radius": 120.0 + watch * 20.0, "power_scaled": false}]
			deferred = ["箭矢影印连携", "诱饵吸引怪物", "箭幕按受击触发反击"]
		"bloom":
			var thorns := path_rank if path_id == "thorns" else 0
			var verdant := path_rank if path_id == "verdant" else 0
			match key.to_upper():
				"Q":
					actions = [{"type": "healing_zone", "name": "花庭绽放", "radius": 175.0 + verdant * 25.0, "duration": 5.0 + verdant, "heal_per_pulse": 5.0 + verdant * 2.0, "pulse_interval": 0.65, "ordinary_enemy_slow": true, "interrupt_seconds": 0.2, "damage_per_pulse": (4.0 + thorns * 4.0) * power if thorns > 0 else 0.0, "power_scaled": false}]
				"E":
					actions = [{"type": "projectile_burst", "name": "花种弹", "damage": 52.0 * power * (1.0 + thorns * 0.3), "projectile_speed": 420.0, "burst_radius": 95.0 + thorns * 15.0 + verdant * 20.0, "slow_seconds": 1.2, "ally_heal": 12.0 + verdant * 6.0 if verdant > 0 else 0.0, "thorn_zone_seconds": thorns if thorns >= 2 else 0.0, "power_scaled": false}]
				"R":
					actions = [{"type": "area_shield", "radius": 240.0 + verdant * 35.0, "shield": 30.0 + verdant * 14.0, "duration": 4.0 + verdant, "retaliation_damage": (12.0 + thorns * 8.0) * power if thorns > 0 else 0.0, "retaliation_radius": 120.0, "cast_heal_at_rank_3": 12.0 if verdant >= 3 else 0.0, "power_scaled": false}]
			deferred = ["花影回廊与队友协同", "荆棘区持续伤害", "多人范围目标筛选"]
		"gale":
			var renewal := path_rank if path_id == "renewal" else 0
			match key.to_upper():
				"Q":
					actions = [{"type": "recall_pets", "recall_radius": 155.0, "damage": 23.4 * power, "interrupt_seconds": 0.4, "ordinary_enemy_knockback": 65.0, "power_scaled": false}]
				"E":
					actions = [{"type": "pet_boost", "duration": 10.0, "damage_multiplier": 1.5, "max_hp_multiplier": 1.5, "heal_each": 100.0 + renewal * 25.0, "revive_owned_pets": true, "power_scaled": false}]
				"R":
					actions = [{"type": "summon_spirit", "count": 1, "maximum": 3, "max_hp_owner_multiplier": 1.35, "revive_delay": 30.0, "power_scaled": false}]
			deferred = ["追踪宠物寻路与独立生命状态", "风灵与火龙/大狗成长", "队友花庭协同效果"]
		"blade":
			var duelist := path_rank if path_id == "duelist" else 0
			var bulwark := path_rank if path_id == "bulwark" else 0
			match key.to_upper():
				"Q":
					actions = [{"type": "melee_sweep", "radius": 125.0 + duelist * 8.0 + bulwark * 10.0, "damage": 46.0 * power * (1.0 + duelist * 0.2), "ordinary_enemy_knockback": 22.0 + bulwark * 10.0, "ordinary_enemy_freeze": 0.55 if bulwark >= 3 else 0.0, "power_scaled": false}]
				"E":
					actions = [{"type": "dash_strike", "distance": 300.0, "no_target_distance": 180.0, "damage": 58.0 * power * (1.0 + duelist * 0.2), "invulnerability": 0.65, "hit_radius": 62.0, "power_scaled": false}]
				"R":
					actions = [{"type": "shield_counter", "shield": 42.0 + bulwark * 20.0, "duration": 3.0 + bulwark * 0.7, "retaliation_damage": (18.0 + bulwark * 7.0) * power, "retaliation_radius": 135.0 + bulwark * 10.0, "cast_heal": 10.0 + bulwark * 8.0, "power_scaled": false}]
			deferred = ["目标锁定与自动贴近攻击", "沿途线段命中和场地边界约束"]

	return {
		"character_id": character_id,
		"key": key.to_upper(),
		"slot": ability["slot"],
		"ability_id": ability["id"],
		"name": ability["name"],
		"cooldown": cooldown_seconds(character_id, key, path_id, path_rank, cd_haste),
		"actions": actions,
		"deferred": deferred,
	}
