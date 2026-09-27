extends SceneTree

const ProfileProgressionScript = preload("res://scripts/profile_progression.gd")


func _initialize() -> void:
	_run()


func _run() -> void:
	var token := Crypto.new().generate_random_bytes(12).hex_encode()
	var path := "user://profile_progression_smoke_%s.json" % token
	var corrupt_path := "user://profile_progression_corrupt_%s.json" % token
	var service = ProfileProgressionScript.new(path)
	assert(service.profile_snapshot()["stars"] == {"shade": 0, "bloom": 0, "gale": 0, "blade": 0})
	assert(service.profile_snapshot()["mode"] == "single_player")
	assert(service.get_character_growth("gale")["regen_bonus"] == 0.0)
	assert(service.get_character_growth("unknown").is_empty())

	var fixture: Dictionary = ProfileProgressionScript.default_profile()
	fixture["coins"] = 2500.0
	fixture["runes"] = 100
	var seed_file := FileAccess.open(path, FileAccess.WRITE)
	assert(seed_file != null)
	seed_file.store_string(JSON.stringify(fixture))
	seed_file.close()
	assert(service.load_profile())

	var star_result: Dictionary = service.upgrade_star("gale")
	assert(star_result["ok"] and star_result["cost"] == 30)
	assert(service.get_character_growth("gale")["max_hp_bonus"] == 20)
	assert(is_equal_approx(service.get_character_growth("gale")["power_bonus"], 0.08))
	assert(service.upgrade_star("missing")["code"] == "invalid_character")

	var gear_result: Dictionary = service.buy_permanent_gear("head", "summer")
	assert(gear_result["ok"] and gear_result["cost"] == 500)
	assert(service.buy_permanent_gear("head", "winter")["code"] == "already_unlocked")
	assert(service.set_permanent_gear_season("head", "winter")["ok"])
	assert(service.profile_snapshot()["permanentGear"]["head"] == "winter")
	assert(service.upgrade_recovery_training()["ok"])
	assert(service.get_character_growth("shade")["recovery_training"] == 1)
	assert(is_equal_approx(service.get_character_growth("shade")["regen_bonus"], 0.35))

	var victory := service.settle_room_run("run-win", {
		"victory": true, "kills": 35, "boss_kills": 1, "earned_gold": 101.25,
	})
	assert(victory["ok"] and victory["runes_awarded"] == 56)
	assert(is_equal_approx(victory["banked_coins"], 101.25))
	var duplicate := service.settle_room_run("run-win", {
		"victory": true, "kills": 35, "boss_kills": 1, "earned_gold": 101.25,
	})
	assert(duplicate["ok"] and duplicate["duplicate"])
	assert(service.profile_snapshot()["runes"] == 126)
	assert(is_equal_approx(service.profile_snapshot()["coins"], 1851.25))

	var abandoned := service.settle_room_run("run-abandoned", {
		"victory": false, "abandoned": true, "kills": 29, "boss_kills": 1, "earned_gold": 11.0,
	})
	assert(abandoned["ok"] and abandoned["runes_awarded"] == 7)
	assert(is_equal_approx(abandoned["banked_coins"], 5.5))
	assert(service.save_profile())
	var reloaded = ProfileProgressionScript.new(path)
	assert(reloaded.profile_snapshot() == service.profile_snapshot())

	var corrupt_file := FileAccess.open(corrupt_path, FileAccess.WRITE)
	assert(corrupt_file != null)
	corrupt_file.store_string("{ definitely not valid json")
	corrupt_file.close()
	var corrupted = ProfileProgressionScript.new(corrupt_path)
	assert(not corrupted.load_profile())
	assert(not corrupted.save_profile())
	assert(FileAccess.get_file_as_string(corrupt_path) == "{ definitely not valid json")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(corrupt_path))
	print("ProfileProgression smoke passed: defaults, growth actions, settlement replay guard, JSON round-trip and corrupt-save protection.")
	quit(0)
