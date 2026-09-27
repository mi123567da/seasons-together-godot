class_name EnemyRoomContent
extends RefCounted

## Data-only port of seasonal enemies, bosses, and the four-room run.
## Source: ../source/game.js (SEASONS and spawnEnemy) and content.js encounters.
## `source_stats` records the original simulation's base values; `prototype_stats`
## are intentionally retuned for this small, single-player Godot slice.

const _ROOMS: Array[Dictionary] = [
	{
		"index": 0, "id": "spring_grove", "season": "spring", "season_name": "春",
		"name": "芽语林径", "stage_name": "芽语林径",
		"enemy_ids": ["spring_grunt", "spring_fast", "spring_tank", "spring_ranged"],
		"kill_quota": 6, "max_enemies": 4, "next_room": 1,
		"door_state": "locked_until_quota_and_boss_clear",
		"is_boss_room": true, "boss_id": "spring_boss", "boss_after_quota": true,
	},
	{
		"index": 1, "id": "summer_shallows", "season": "summer", "season_name": "夏",
		"name": "流萤浅滩", "stage_name": "流萤浅滩",
		"enemy_ids": ["summer_grunt", "summer_fast", "summer_tank", "summer_ranged"],
		"kill_quota": 8, "max_enemies": 5, "next_room": 2,
		"door_state": "locked_until_quota_and_boss_clear",
		"is_boss_room": true, "boss_id": "summer_boss", "boss_after_quota": true,
	},
	{
		"index": 2, "id": "autumn_old_road", "season": "autumn", "season_name": "秋",
		"name": "金叶旧路", "stage_name": "金叶旧路",
		"enemy_ids": ["autumn_grunt", "autumn_fast", "autumn_tank", "autumn_ranged"],
		"kill_quota": 10, "max_enemies": 5, "next_room": 3,
		"door_state": "locked_until_quota_and_boss_clear",
		"is_boss_room": true, "boss_id": "autumn_boss", "boss_after_quota": true,
	},
	{
		"index": 3, "id": "winter_pinewood", "season": "winter", "season_name": "冬",
		"name": "初雪松林", "stage_name": "初雪松林",
		"enemy_ids": ["winter_grunt", "winter_fast", "winter_tank", "winter_ranged"],
		"kill_quota": 12, "max_enemies": 6, "next_room": -1,
		"door_state": "locked_until_quota_and_boss_clear",
		"is_boss_room": true, "boss_id": "winter_boss", "boss_after_quota": true,
	},
]

const _ARCHETYPES := {
	"grunt": {
		"kind": "grunt", "source_stats": {"hp": 18, "speed": 73, "radius": 16, "damage": 8, "xp": 5},
		"prototype_stats": {"hp": 1, "speed": 84.0, "radius": 15.0, "damage": 9.0},
		"behavior_tags": ["chase", "contact_attack"],
	},
	"fast": {
		"kind": "fast", "source_stats": {"hp": 12, "speed": 127, "radius": 12, "damage": 6, "xp": 4},
		"prototype_stats": {"hp": 1, "speed": 108.0, "radius": 13.0, "damage": 7.0},
		"behavior_tags": ["chase", "fast_move", "contact_attack"],
	},
	"tank": {
		"kind": "tank", "source_stats": {"hp": 62, "speed": 47, "radius": 25, "damage": 13, "xp": 12},
		"prototype_stats": {"hp": 2, "speed": 66.0, "radius": 21.0, "damage": 13.0},
		"behavior_tags": ["chase", "high_hp", "heavy_contact_attack"],
	},
	"ranged": {
		"kind": "ranged", "source_stats": {"hp": 24, "speed": 56, "radius": 17, "damage": 10, "xp": 8},
		"prototype_stats": {"hp": 1, "speed": 68.0, "radius": 16.0, "damage": 9.0},
		"behavior_tags": ["keep_distance", "projectile_attack"],
	},
}

const _SEASONS := {
	"spring": {"name": "春", "mobs": ["苔团", "刺芽", "树根卫士", "花孢灵"], "boss": "古樱守望者"},
	"summer": {"name": "夏", "mobs": ["炭团", "火蜥", "熔岩卫士", "余烬灵"], "boss": "赤焰炎龙"},
	"autumn": {"name": "秋", "mobs": ["菇怪", "枯叶蝠", "南瓜卫士", "乌鸦灵"], "boss": "枯林鹿王"},
	"winter": {"name": "冬", "mobs": ["雪团", "霜狼", "冰晶卫士", "雪铃灵"], "boss": "永冬之王"},
}

const _KIND_ORDER := ["grunt", "fast", "tank", "ranged"]
const _BOSSES := {
	"spring_boss": {
		"id": "spring_boss", "name": "古樱守望者", "season": "spring", "kind": "boss",
		"source_stats": {"hp": 26000, "speed": 57, "radius": 72, "damage": 28, "xp": 500},
		"prototype_stats": {"hp": 14, "speed": 72.0, "radius": 30.0, "damage": 15.0, "attack_cooldown": 3.5},
		"behavior_tags": ["chase", "telegraphed_slam", "radial_wave", "seasonal_projectiles", "three_delayed_blasts", "slow_on_blast"],
	},
	"summer_boss": {
		"id": "summer_boss", "name": "赤焰炎龙", "season": "summer", "kind": "boss",
		"source_stats": {"hp": 26000, "speed": 57, "radius": 72, "damage": 28, "xp": 500},
		"prototype_stats": {"hp": 14, "speed": 72.0, "radius": 30.0, "damage": 15.0, "attack_cooldown": 3.5},
		"behavior_tags": ["chase", "telegraphed_slam", "radial_wave", "aimed_fan_projectiles", "two_delayed_blasts", "fast_projectiles"],
	},
	"autumn_boss": {
		"id": "autumn_boss", "name": "枯林鹿王", "season": "autumn", "kind": "boss",
		"source_stats": {"hp": 26000, "speed": 57, "radius": 72, "damage": 28, "xp": 500},
		"prototype_stats": {"hp": 14, "speed": 72.0, "radius": 30.0, "damage": 15.0, "attack_cooldown": 3.5},
		"behavior_tags": ["chase", "telegraphed_slam", "radial_wave", "seasonal_projectiles", "summons_five_adds"],
	},
	"winter_boss": {
		"id": "winter_boss", "name": "永冬之王", "season": "winter", "kind": "boss",
		"source_stats": {"hp": 26000, "speed": 57, "radius": 72, "damage": 28, "xp": 500},
		"prototype_stats": {"hp": 14, "speed": 72.0, "radius": 30.0, "damage": 15.0, "attack_cooldown": 3.5},
		"behavior_tags": ["chase", "telegraphed_slam", "radial_wave", "slow_ice_projectiles", "large_delayed_slow_blast"],
	},
}


static func get_room_count() -> int:
	return _ROOMS.size()


static func get_room(index: int) -> Dictionary:
	if index < 0 or index >= _ROOMS.size():
		return {}
	return _ROOMS[index].duplicate(true)


static func get_enemy(enemy_id: String) -> Dictionary:
	var parts := enemy_id.split("_", false, 1)
	if parts.size() != 2 or not _SEASONS.has(parts[0]) or not _ARCHETYPES.has(parts[1]):
		return {}
	var season_id: String = parts[0]
	var kind: String = parts[1]
	var season: Dictionary = _SEASONS[season_id]
	var archetype: Dictionary = _ARCHETYPES[kind]
	var mob_index: int = _KIND_ORDER.find(kind)
	return {
		"id": enemy_id,
		"name": season["mobs"][mob_index],
		"season": season_id,
		"kind": kind,
		"source_stats": (archetype["source_stats"] as Dictionary).duplicate(true),
		"prototype_stats": (archetype["prototype_stats"] as Dictionary).duplicate(true),
		"behavior_tags": (archetype["behavior_tags"] as Array).duplicate(),
	}


static func get_boss(boss_id: String) -> Dictionary:
	if not _BOSSES.has(boss_id):
		return {}
	return (_BOSSES[boss_id] as Dictionary).duplicate(true)
