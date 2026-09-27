extends Node

const CONTENT = preload("res://scripts/enemy_room_content.gd")


func _ready() -> void:
	assert(CONTENT.get_room_count() == 4)
	var expected_quotas := [6, 8, 10, 12]
	var expected_bosses := ["spring_boss", "summer_boss", "autumn_boss", "winter_boss"]
	var expected_names := ["古樱守望者", "赤焰炎龙", "枯林鹿王", "永冬之王"]
	for index in range(4):
		var room: Dictionary = CONTENT.get_room(index)
		assert(room["kill_quota"] == expected_quotas[index])
		assert(room["boss_id"] == expected_bosses[index])
		assert(room["is_boss_room"] == true and room["boss_after_quota"] == true)
		assert((room["enemy_ids"] as Array).size() == 4)
		assert(CONTENT.get_boss(str(room["boss_id"]))["name"] == expected_names[index])
		assert(room["next_room"] == (index + 1 if index < 3 else -1))
		assert(room["max_enemies"] > 0)
	assert(CONTENT.get_room(-1).is_empty())
	assert(CONTENT.get_room(4).is_empty())
	assert(CONTENT.get_enemy("missing_grunt").is_empty())
	assert(CONTENT.get_boss("missing_boss").is_empty())
	var spring_enemy: Dictionary = CONTENT.get_enemy("spring_grunt")
	assert(spring_enemy["name"] == "苔团")
	assert(spring_enemy["source_stats"]["hp"] == 18)
	assert(spring_enemy["prototype_stats"]["hp"] == 1)
	assert("contact_attack" in spring_enemy["behavior_tags"])
	var winter_ranged: Dictionary = CONTENT.get_enemy("winter_ranged")
	assert(winter_ranged["name"] == "雪铃灵")
	assert("projectile_attack" in winter_ranged["behavior_tags"])
	var boss: Dictionary = CONTENT.get_boss("winter_boss")
	assert(boss["source_stats"]["hp"] == 26000)
	assert("slow_ice_projectiles" in boss["behavior_tags"])
	var room_copy: Dictionary = CONTENT.get_room(0)
	(room_copy["enemy_ids"] as Array).clear()
	assert((CONTENT.get_room(0)["enemy_ids"] as Array).size() == 4)
	spring_enemy["source_stats"]["hp"] = -1
	assert(CONTENT.get_enemy("spring_grunt")["source_stats"]["hp"] == 18)
	print("EnemyRoomContent smoke check passed: 4 rooms, 16 seasonal mobs, 4 bosses, copy safety.")
