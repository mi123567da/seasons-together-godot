extends SceneTree

const HUB_SCENE := preload("res://hub/hub.tscn")
const WEAPON_UNLOCKS := preload("res://scripts/weapon_unlocks.gd")
const BITMAP_CATALOG := preload("res://scripts/bitmap_animation_catalog.gd")


func _initialize() -> void:
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	var hub := HUB_SCENE.instantiate()
	hub.profile_path = "user://hub_smoke_%s.json" % str(Time.get_ticks_usec())
	var captured_gender: Array[String] = []
	var captured_appearance: Array[String] = []
	var captured_equipment: Array[String] = []
	var expedition_payloads: Array[Dictionary] = []
	hub.gender_chosen.connect(func(gender: String, display_name: String): captured_gender.assign([gender, display_name]))
	hub.appearance_changed.connect(func(gender: String, display_name: String): captured_appearance.assign([gender, display_name]))
	hub.weapon_equipped.connect(func(weapon_id: String): captured_equipment.append(weapon_id))
	hub.expedition_requested.connect(func(payload: Dictionary): expedition_payloads.append(payload))
	root.add_child(hub)
	await process_frame
	assert(hub.get_node("Protagonist") is CharacterBody2D, "Hub must contain a navigable CharacterBody2D")
	assert(hub._modal.visible, "An uninitialized profile must begin with one-time gender choice")
	var onboarding_text := _collect_ui_text(hub._modal_body)
	assert(onboarding_text.has("创建你的旅者"), "First-run heading should be localized")
	assert(onboarding_text.has("角色名字"), "Name placeholder should be localized")
	assert(onboarding_text.has("女性外观") and onboarding_text.has("男性外观"), "Appearance choices should be localized")
	assert(hub.WEAPON_INFO["bow"]["name"] == "弓" and hub.WEAPON_INFO["sword"]["name"] == "刀")
	assert(hub.WEAPON_INFO["staff"]["name"] == "法杖" and hub.WEAPON_INFO["spirit_focus"]["name"] == "御灵器")
	var hud_layer: CanvasLayer = hub._ui_layer
	hub.set_hub_hud_visible(false)
	assert(not hud_layer.visible and hub.visible, "HUD visibility API should only toggle the hub CanvasLayer")
	hub.set_hub_hud_visible(true)
	assert(hud_layer.visible, "HUD visibility API should restore the hub CanvasLayer")
	assert(hub.choose_gender("female", "Mira"), "Gender and display name should be accepted once")
	assert(captured_gender == ["female", "Mira"], "Gender choice signal payload mismatch")
	assert(not hub.choose_gender("male", "Mira"), "Gender choice must not be repeatable")
	assert(hub.change_appearance("male", "Mira"), "Returning profiles should be able to change avatar metadata")
	assert(captured_appearance == ["male", "Mira"], "Appearance change signal payload mismatch")
	assert(hub.change_appearance("female", "Mira"), "Appearance change should remain independent of weapon state")

	var player: CharacterBody2D = hub.get_node("Protagonist")
	assert(player.animation_action == "idle", "Stationary hub protagonist should use the idle clip")
	var idle_complete := BITMAP_CATALOG.has_complete_direction("female", "bow", "idle", "S")
	if not idle_complete:
		assert(player._avatar.texture == player._portrait_texture, "Missing idle PNGs should preserve the approved portrait")
	var start_position := player.position
	var right_key := InputEventKey.new()
	right_key.keycode = KEY_D
	right_key.pressed = true
	Input.parse_input_event(right_key)
	for _frame in range(8):
		await physics_frame
	assert(player.animation_action == "run", "Moving protagonist should switch to the run clip")
	assert(player.animation_direction == "E", "Rightward movement should select the east direction")
	assert(player.animation_frame >= 0 and player.animation_frame < BITMAP_CATALOG.get_frame_count("female", "bow", "run"))
	var east_run_complete := BITMAP_CATALOG.has_complete_direction("female", "bow", "run", "E")
	if not east_run_complete:
		assert(player._avatar.texture == player._portrait_texture, "Missing run PNGs should preserve the approved portrait")
	right_key.pressed = false
	Input.parse_input_event(right_key)
	assert(player.position.x > start_position.x + 5.0, "Keyboard movement action should move the player")
	var up_key := InputEventKey.new()
	up_key.keycode = KEY_UP
	up_key.pressed = true
	Input.parse_input_event(up_key)
	for _frame in range(8):
		await physics_frame
	up_key.pressed = false
	Input.parse_input_event(up_key)
	assert(player.position.y < start_position.y - 5.0, "Arrow-key movement should move the player vertically")
	assert(player.animation_direction == "N", "Upward movement should select the north direction")
	player.position.y = -100.0
	for _frame in range(2):
		await physics_frame
	assert(player.position.y >= player.movement_bounds.position.y, "Player movement should stay inside the room at its upper edge")
	var left_key := InputEventKey.new()
	left_key.keycode = KEY_A
	left_key.pressed = true
	Input.parse_input_event(left_key)
	for _frame in range(8):
		await physics_frame
	left_key.pressed = false
	Input.parse_input_event(left_key)
	assert(player.animation_direction == "W", "Leftward movement should select the west direction")
	assert(player.animation_flip_h, "Leftward art should use horizontal mirroring rather than rotation")
	assert(BITMAP_CATALOG.resolve_direction("W")["source_direction"] == "E")

	player.position = Vector2(350, 285)
	var interact_key := InputEventKey.new()
	interact_key.keycode = KEY_E
	interact_key.pressed = true
	hub._unhandled_input(interact_key)
	assert(hub._modal.visible, "Rack interaction should open the weapon panel")
	var rack_text := _collect_ui_text(hub._modal_body)
	assert(rack_text.has("武器架"), "Weapon rack heading should be localized")
	assert(rack_text.has("关闭"), "Weapon rack close button should be localized")
	assert(rack_text.any(func(value: String): return value.contains("弓") and value.contains("已装备")))
	assert(rack_text.any(func(value: String): return value.contains("刀") and value.contains("未解锁")))
	hub._close_modal()
	assert(not hub.unlock_weapon("staff"), "Shared rules should keep later weapons locked until prior weapons unlock")
	var unlock_result: Dictionary = WEAPON_UNLOCKS.try_unlock(hub._unlock_state(), "sword", hub._config["unlock_cost_overrides"])
	assert(unlock_result["ok"], "Shared unlock rule rejected sword: %s; config=%s" % [unlock_result, hub._config])
	assert(hub.unlock_weapon("sword"), "Provisional marks should unlock the sword")
	assert(hub.equip_weapon("sword"), "Unlocked weapons should be equippable")
	assert(player._weapon_id == "sword", "Equipping a weapon should select its matching hub animation set")
	assert(captured_equipment == ["sword"], "Equipment signal should identify the selected weapon")

	player.position = Vector2(645, 285)
	assert(hub.interact_object("upgrade_station"), "Upgrade station should respond in range")
	var upgrade_text := _collect_ui_text(hub._modal_body)
	assert(upgrade_text.has("武器强化") and upgrade_text.has("关闭"), "Upgrade station should be localized")
	assert(upgrade_text.any(func(value: String): return value.contains("港湾印记") and value.contains("当前持有")))
	assert(hub.upgrade_equipped_weapon(), "Configured marks should buy an upgrade")
	hub._close_modal()
	var profile: Dictionary = hub.get_profile_payload()
	assert(profile["gender"] == "female" and profile["display_name"] == "Mira")
	assert(profile["equipped_weapon"] == "sword")
	assert(int(profile["weapon_levels"]["sword"]) == 2)
	assert(int(profile["hub_marks"]) == 15)

	player.position = Vector2(965, 285)
	assert(hub.interact_nearest(), "Expedition door should be reachable in the room")
	assert(hub._modal.visible, "Door interaction should show the departure prompt")
	var expedition_text := _collect_ui_text(hub._modal_body)
	assert(expedition_text.has("准备出发？"), "Expedition heading should be localized")
	assert(expedition_text.has("开始远征") and expedition_text.has("留在港湾"), "Expedition actions should be localized")
	hub.request_expedition()
	assert(expedition_payloads.size() == 1, "Door should emit one expedition request")
	assert(expedition_payloads[0]["equipped_weapon"] == "sword")
	assert(expedition_payloads[0]["weapon_levels"]["sword"] == 2)
	var reloaded := HUB_SCENE.instantiate()
	reloaded.profile_path = hub.profile_path
	root.add_child(reloaded)
	await process_frame
	var persisted_profile: Dictionary = reloaded.get_profile_payload()
	assert(persisted_profile["gender"] == "female", "Appearance should persist in the sidecar")
	assert(persisted_profile["equipped_weapon"] == "sword", "Equipment should persist in the sidecar")
	assert(persisted_profile["weapon_levels"]["sword"] == 2, "Weapon level should persist in the sidecar")

	var absolute_profile := ProjectSettings.globalize_path(hub.profile_path)
	if FileAccess.file_exists(hub.profile_path):
		DirAccess.remove_absolute(absolute_profile)
	if FileAccess.file_exists(hub.profile_path + ".tmp"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(hub.profile_path + ".tmp"))
	hub.queue_free()
	reloaded.queue_free()
	print("Hub smoke passed: onboarding, movement, rack unlock/equip, upgrade station, and expedition signal.")
	quit(0)


func _collect_ui_text(node: Node) -> Array[String]:
	var values: Array[String] = []
	if node is Label:
		values.append((node as Label).text)
	elif node is Button:
		values.append((node as Button).text)
	elif node is LineEdit:
		values.append((node as LineEdit).placeholder_text)
	for child in node.get_children():
		values.append_array(_collect_ui_text(child))
	return values
