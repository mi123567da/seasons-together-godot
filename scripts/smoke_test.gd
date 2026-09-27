extends SceneTree

const WEAPON_CONTENT = preload("res://scripts/weapon_content.gd")
const HUB_ADAPTER = preload("res://hub/profile_payload_adapter.gd")
const PROFILE_PROGRESSION = preload("res://scripts/profile_progression.gd")
const BITMAP_ANIMATION_CATALOG = preload("res://scripts/bitmap_animation_catalog.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for action_id in ["idle", "run", "basic", "q", "e", "r", "dash", "hurt"]:
		var expected_frames := 4 if action_id == "idle" else 5
		assert(BITMAP_ANIMATION_CATALOG.get_frame_count("female", "bow", action_id) == expected_frames, "%s must keep its catalog frame timing without image files" % action_id)
	var mirrored_sw: Dictionary = BITMAP_ANIMATION_CATALOG.resolve_direction("SW")
	assert(mirrored_sw.get("source_direction") == "SE" and mirrored_sw.get("flip_h", false), "SW must mirror the SE slot, not rotate it")
	assert(BITMAP_ANIMATION_CATALOG.resolve_direction("N").get("source_direction") == "N", "N must use its dedicated source direction")
	assert(BITMAP_ANIMATION_CATALOG.get_frame_path("unknown_appearance", "bow", "idle", "E", 0) == null, "Invalid art-slot lookup must safely return null")
	assert(WEAPON_CONTENT.weapon_ids().size() == 4)
	for weapon_id in WEAPON_CONTENT.weapon_ids():
		assert(not WEAPON_CONTENT.get_attack(weapon_id).is_empty(), "%s attack missing" % weapon_id)
		for key in ["Q", "E", "R"]:
			var contract: Dictionary = WEAPON_CONTENT.build_ability_contract(weapon_id, key)
			assert(not contract.is_empty(), "%s %s contract missing" % [weapon_id, key])
			assert(not (contract["actions"] as Array).is_empty(), "%s %s actions missing" % [weapon_id, key])

	var scene := load("res://main.tscn") as PackedScene
	var game := scene.instantiate()
	root.add_child(game)
	await process_frame
	assert(game.game_state == "hub", "New project should start in the safe hub")
	assert(game.font != null and game.font.has_char("四".unicode_at(0)), "Bundled Chinese font must cover UI glyphs")
	var has_logical_d := false
	for input_event in InputMap.action_get_events("ui_right"):
		if input_event is InputEventKey and input_event.keycode == KEY_D:
			has_logical_d = true
	assert(has_logical_d, "Room movement must include a logical D key binding")
	var has_left_mouse := false
	for input_event in InputMap.action_get_events("attack"):
		if input_event is InputEventMouseButton and input_event.button_index == MOUSE_BUTTON_LEFT:
			has_left_mouse = true
	assert(has_left_mouse, "Mouse left button must be mapped to basic attack")
	var left_click := InputEventMouseButton.new()
	left_click.button_index = MOUSE_BUTTON_LEFT
	left_click.pressed = true
	Input.parse_input_event(left_click)
	await process_frame
	assert(Input.is_action_pressed("attack"), "Left mouse event must activate the attack action")
	left_click.pressed = false
	Input.parse_input_event(left_click)
	await process_frame
	assert(not Input.is_action_pressed("attack"), "Left mouse release must stop the attack action")
	var profile_path := "user://integration_smoke_%s.json" % PROFILE_PROGRESSION.new_run_id()
	var hub_path := "user://hub_integration_smoke_%s.json" % PROFILE_PROGRESSION.new_run_id()
	game.profile = PROFILE_PROGRESSION.new(profile_path)
	game.profile_error = ""
	game.hub_controller.profile_path = hub_path
	var hub_payload: Dictionary = HUB_ADAPTER.default_payload(60)
	hub_payload["gender"] = "female"
	hub_payload["display_name"] = "Smoke"
	game.hub_controller.set_profile_payload(hub_payload)
	assert(game.hub_controller.unlock_weapon("sword"), "Hub should unlock Sword using shared rules and marks")
	assert(game.hub_controller.equip_weapon("sword"), "Hub should equip unlocked Sword")

	var settings_event := InputEventKey.new()
	settings_event.physical_keycode = KEY_F2
	settings_event.pressed = true
	game._unhandled_input(settings_event)
	assert(game.settings_panel.visible and paused, "Settings should open from hub")
	game.settings_panel.close_settings()
	assert(not game.settings_panel.visible and not paused, "Closing settings should restore play")
	game.hub_controller.request_expedition()
	assert(game.game_state == "run", "Hub expedition request should launch the room run")
	assert(not game.hub_controller.visible and not game.hub_controller.get("_ui_layer").visible, "Hub world and CanvasLayer HUD should hide during a room run")
	assert(game.selected_weapon_id == "sword" and game.basic_attack_data["type"] == "melee_sweep", "Sword should map to the old Blade combat kit")
	assert(game.appearance_gender == "female", "Appearance should pass independently into the run")
	assert(game.player_anim_action == "idle", "A no-art run should begin in idle with the portrait fallback")
	var idle_clip_complete := BITMAP_ANIMATION_CATALOG.has_complete_direction("female", "sword", "idle", "E")
	if not idle_clip_complete:
		assert(game.player_anim_texture == game.appearance_textures["female"], "Missing animation art must retain the existing appearance portrait")
	else:
		assert(game.player_anim_texture != null, "Complete idle art must load a drawable frame")
	game._spawn_enemy()
	var click_target_index: int = game.enemies.size() - 1
	game.enemies[click_target_index]["body"].position = game.player.position + Vector2(70.0, 0.0)
	game.attack_cooldown = 0.0
	var quick_left_click := InputEventMouseButton.new()
	quick_left_click.button_index = MOUSE_BUTTON_LEFT
	quick_left_click.pressed = true
	Input.parse_input_event(quick_left_click)
	game._input(quick_left_click)
	var quick_left_release := quick_left_click.duplicate() as InputEventMouseButton
	quick_left_release.pressed = false
	Input.parse_input_event(quick_left_release)
	await process_frame
	assert(game.defeated_count == 1, "A brief left click between physics ticks must still trigger one attack")
	assert(game.player_anim_action == "basic", "A consumed basic attack must start the basic animation state")
	if not BITMAP_ANIMATION_CATALOG.has_complete_direction("female", "sword", "basic", game.player_facing):
		assert(game.player_anim_texture == game.appearance_textures["female"], "Missing basic frames must keep the existing portrait visible")
	else:
		assert(game.player_anim_texture != null, "Complete basic art must load a drawable frame")
	for ability_key in ["Q", "E", "R"]:
		game._activate_ability(ability_key)
		assert(game.player_anim_action == ability_key.to_lower(), "%s must start its matching animation state" % ability_key)
	game.player.velocity = Vector2.ZERO
	game._update_player_animation(1.0)
	assert(game.player_anim_action == "idle", "A one-shot ability should return to idle after catalog duration")
	game.player.velocity = Vector2.RIGHT * 150.0
	game._update_player_animation(0.016)
	assert(game.player_anim_action == "run", "Motion after a one-shot should select run")
	game.player.velocity = Vector2.ZERO
	game._update_player_animation(0.016)
	assert(game.player_anim_action == "idle", "Stopping after run should select idle")
	game.spawned_count = 0
	game.defeated_count = 0
	game.run_kills = 0
	game.run_earned_gold = 0.0
	game._unhandled_input(settings_event)
	assert(game.settings_panel.visible and paused, "Settings should open during a run")
	game.settings_panel.close_settings()
	assert(not paused)

	for room in range(4):
		assert(game.room_index == room)
		var room_data: Dictionary = game.room_data
		var quota := int(room_data["kill_quota"])
		for _i in range(quota):
			game._spawn_enemy()
			game.spawned_count += 1
			var enemy_index: int = game.enemies.size() - 1
			game.enemies[enemy_index]["hp"] = 1
			game._damage_enemy(enemy_index, 1)
			game._check_room_clear()
		assert(game.defeated_count == quota, "room %d quota mismatch" % room)
		assert(not game.exit_visible, "door opened before boss clear")
		assert(game.boss_spawned and game.enemies.size() == 1, "room %d boss not spawned" % room)
		game.enemies[0]["hp"] = 1
		game._damage_enemy(0, 1)
		game._check_room_clear()
		assert(game.boss_defeated, "room %d boss clear not recorded" % room)
		if room < 3:
			assert(game.reward_pending and paused, "room %d reward gate not opened" % room)
			assert(not game.exit_visible, "room %d door opened before reward" % room)
			assert(game.reward_panel.visible and game.reward_panel._offers.size() == 3)
			var previous_room: int = game.room_index
			game._advance_room()
			assert(game.room_index == previous_room, "reward gate should block transition")
			game.reward_panel._opened_at_msec -= 3000
			game.reward_panel._confirm_selected()
			assert(not game.reward_pending and not paused and game.exit_visible, "reward confirmation should unlock door")
			game._advance_room()
		else:
			assert(game.exit_visible, "final door did not unlock after boss")
			game._advance_room()

	assert(game.game_state == "victory", "Final room should reach result state")
	assert(game.run_kills == 36 and game.run_boss_kills == 4, "run totals incorrect")
	assert(game.run_settlement.get("ok", false), "victory profile settlement failed")
	assert(int(game.hub_controller.get_profile_payload()["hub_marks"]) == 60 - 25 + 36 + 20, "hub marks should be +1 per foe and +5 per boss after paying sword unlock")
	assert((PROFILE_PROGRESSION.new(profile_path).profile_snapshot()["settledRuns"] as Array).has(game.run_id), "settlement was not persisted")
	game._reset_run()
	assert(game.game_state == "hub" and game.hub_controller.visible, "Result continue should return to hub")
	assert(game.hub_controller.get("_ui_layer").visible, "Returning to hub should restore its CanvasLayer HUD")

	if FileAccess.file_exists(profile_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(profile_path))
	if FileAccess.file_exists(profile_path + ".tmp"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(profile_path + ".tmp"))
	if FileAccess.file_exists(hub_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(hub_path))
	if FileAccess.file_exists(hub_path + ".tmp"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(hub_path + ".tmp"))
	print("INTEGRATION_SMOKE_OK: Chinese font/UI glyph, mouse-left attack input, animation catalog/timing/direction/fallback/state transitions, hub -> four quotas/bosses/rewards/doors -> result; Q/E/R contracts for all weapons.")
	quit(0)
