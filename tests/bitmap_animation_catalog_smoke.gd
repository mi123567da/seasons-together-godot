extends SceneTree

const Catalog = preload("res://scripts/bitmap_animation_catalog.gd")
const PORTRAIT_FALLBACK: Texture2D = preload("res://assets/heroes/shadow.png")
const OTHER_TEXTURE: Texture2D = preload("res://assets/heroes/bloom.png")


func _initialize() -> void:
	_run()


func _run() -> void:
	assert(Catalog.appearance_ids() == ["female", "male"])
	assert(Catalog.weapon_ids() == ["bow", "sword", "staff", "spirit_focus"])
	assert(Catalog.action_ids() == ["idle", "run", "basic", "q", "e", "r", "dash", "hurt"])
	assert(Catalog.directions() == ["N", "NE", "E", "SE", "S", "W", "NW", "SW"])
	assert(Catalog.source_directions() == ["N", "NE", "E", "SE", "S"])
	assert(Catalog.get_frame_size() == Vector2i(256, 256))
	assert(Catalog.get_anchor_normalized() == Vector2(0.5, 1.0))

	var expected_counts := {"idle": 4, "run": 5, "basic": 5, "q": 5, "e": 5, "r": 5, "dash": 5, "hurt": 5}
	for appearance_id: String in Catalog.appearance_ids():
		for weapon_id: String in Catalog.weapon_ids():
			for action_id: String in Catalog.action_ids():
				var count: int = expected_counts[action_id]
				assert(Catalog.get_frame_count(appearance_id, weapon_id, action_id) == count)
				var clip := Catalog.get_clip_metadata(appearance_id, weapon_id, action_id)
				assert(clip["frame_count"] == count)
				assert(clip["frame_size"] == Vector2i(256, 256))
				assert(clip["anchor_normalized"] == Vector2(0.5, 1.0))
	assert(Catalog.get_action_metadata("idle") == {"frame_count": 4, "fps": 6.0, "loop": true, "playback": "loop"})
	assert(Catalog.get_action_metadata("run") == {"frame_count": 5, "fps": 10.0, "loop": true, "playback": "loop"})
	for action_id: String in ["basic", "q", "e", "r", "dash"]:
		assert(Catalog.get_action_metadata(action_id)["fps"] == 12.0)
		assert(Catalog.get_action_metadata(action_id)["loop"] == false)
		assert(Catalog.get_action_metadata(action_id)["playback"] == "one_shot")
	assert(Catalog.get_action_metadata("hurt")["fps"] == 8.0)
	assert(Catalog.get_action_metadata("hurt")["loop"] == false)

	assert(Catalog.resolve_direction("N") == {"source_direction": "N", "flip_h": false})
	assert(Catalog.resolve_direction("ne") == {"source_direction": "NE", "flip_h": false})
	assert(Catalog.resolve_direction("E") == {"source_direction": "E", "flip_h": false})
	assert(Catalog.resolve_direction("SE") == {"source_direction": "SE", "flip_h": false})
	assert(Catalog.resolve_direction("S") == {"source_direction": "S", "flip_h": false})
	assert(Catalog.resolve_direction("W") == {"source_direction": "E", "flip_h": true})
	assert(Catalog.resolve_direction("NW") == {"source_direction": "NE", "flip_h": true})
	assert(Catalog.resolve_direction("SW") == {"source_direction": "SE", "flip_h": true})
	assert(Catalog.resolve_direction("north").is_empty())

	var expected_path := "res://assets/animation_slots/female/bow/idle/E_00.png"
	assert(Catalog.expected_frame_path("female", "bow", "idle", "W", 0) == expected_path)
	assert(Catalog.expected_frame_path("female", "bow", "idle", "S", 3) == "res://assets/animation_slots/female/bow/idle/S_03.png")
	assert(Catalog.expected_frame_path("female", "bow", "idle", "S", 4).is_empty())
	assert(Catalog.expected_frame_path("unknown", "bow", "idle", "S", 0).is_empty())
	Catalog.clear_cache()
	assert(Catalog.get_frame_path("female", "bow", "idle", "S", 0) == null)
	assert(Catalog.load_frame("female", "bow", "idle", "S", 0) == null)
	assert(not Catalog.has_complete_direction("female", "bow", "idle", "S"))
	assert(Catalog.load_frame_or_fallback("female", "bow", "idle", "S", 0, PORTRAIT_FALLBACK) == PORTRAIT_FALLBACK)
	assert(Catalog.load_frame_or_fallback("female", "bow", "idle", "S", 0) == null)
	assert(not Catalog._has_complete_paths(["res://slot/S_00.png", null, "res://slot/S_02.png", "res://slot/S_03.png"], 4))
	assert(Catalog._has_complete_paths(["res://slot/S_00.png", "res://slot/S_01.png", "res://slot/S_02.png", "res://slot/S_03.png"], 4))
	assert(Catalog._select_animation_or_fallback(OTHER_TEXTURE, PORTRAIT_FALLBACK, false) == PORTRAIT_FALLBACK)
	assert(Catalog.get_frame_count("female", "bow", "missing") == 0)
	assert(Catalog.get_clip_metadata("female", "invalid", "idle").is_empty())
	print("BitmapAnimationCatalog smoke passed: slots, frame contracts, direction mirrors, missing-art fallback and clip completeness.")
	quit(0)
