extends Node2D

const CHARACTER_CONTENT = preload("res://scripts/character_content.gd")
const ENEMY_ROOM_CONTENT = preload("res://scripts/enemy_room_content.gd")
const WEAPON_CONTENT = preload("res://scripts/weapon_content.gd")
const WEAPON_UNLOCKS = preload("res://scripts/weapon_unlocks.gd")
const PROFILE_PROGRESSION = preload("res://scripts/profile_progression.gd")
const BITMAP_ANIMATION_CATALOG = preload("res://scripts/bitmap_animation_catalog.gd")
const SETTINGS_PANEL = preload("res://ui/settings_panel.tscn")
const REWARD_PANEL = preload("res://ui/room_reward_panel.tscn")
const HUB_SCENE = preload("res://hub/hub.tscn")
const ROOM_NAMES := ["芽语林径", "流萤浅滩", "金叶旧路", "初雪松林"]
const ROOM_TAGS := ["春", "夏", "秋", "冬"]
const ROOM_TINTS := [Color("a7d583"), Color("f2a264"), Color("e9bd69"), Color("a7d8e8")]
const HERO_NAMES := ["长弓行者", "花杖行者", "灵契行者", "长剑行者"]
const HERO_ROLES := ["贯穿箭矢", "范围花灵", "追踪风刃", "近身斩击"]
const HERO_IDS := ["shade", "bloom", "gale", "blade"]
const WEAPON_IDS := ["bow", "sword", "staff", "spirit_focus"]
const WEAPON_NAMES := ["长弓", "长剑", "法杖", "灵契法器"]
const KIT_BY_WEAPON := {"bow": "shade", "sword": "blade", "staff": "bloom", "spirit_focus": "gale"}
const HERO_PATHS := ["res://assets/heroes/shadow.png", "res://assets/heroes/bloom.png", "res://assets/heroes/gale.png", "res://assets/heroes/blade.png"]
const ROOM_PATHS := ["res://assets/rooms/spring.png", "res://assets/rooms/summer.png", "res://assets/rooms/autumn.png", "res://assets/rooms/winter.png"]
const ROOM_SIZE := Vector2(1280.0, 720.0)
const ARENA := Rect2(64.0, 106.0, 1152.0, 540.0)

var hero_textures: Array[Texture2D] = []
var room_textures: Array[Texture2D] = []
var appearance_textures: Dictionary = {}
var font: Font
var player_facing := "E"
var player_anim_action := "idle"
var player_anim_elapsed := 0.0
var player_anim_oneshot_remaining := 0.0
var player_anim_priority := 0
var player_anim_frame_index := -1
var player_anim_source_direction := "E"
var player_anim_texture: Texture2D
var player_anim_flip_h := false
var player_anim_cache: Dictionary = {}
var game_state := "hub"
var selected_hero := 0
var selected_weapon_id := "bow"
var appearance_gender := ""
var hub_payload: Dictionary = {}
var hub_controller: Node2D
var hub_material_awarded := 0
var room_index := 0
var player: CharacterBody2D
var character_data: Dictionary = {}
var basic_attack_data: Dictionary = {}
var room_data: Dictionary = {}
var boss_data: Dictionary = {}
var player_hp := 120.0
var player_max_hp := 120.0
var player_speed := 230.0
var player_shield := 0.0
var shield_time := 0.0
var damage_buff := 1.0
var damage_buff_time := 0.0
var player_invulnerability := 0.0
var attack_cooldown := 0.0
var dash_cooldown := 0.0
var dash_time := 0.0
var ability_cooldowns: Dictionary = {"Q": 0.0, "E": 0.0, "R": 0.0}
var attack_press_buffered := false
var flower_zones: Array[Dictionary] = []
var spirit_count := 0
var spirit_attack_timer := 0.0
var spawn_timer := 0.0
var spawned_count := 0
var defeated_count := 0
var boss_spawned := false
var boss_defeated := false
var run_time := 0.0
var enemies: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var exit_visible := false
var hit_flash := 0.0
var skip_ability_frame := false
var settings_panel: Control
var reward_panel: RoomRewardPanel
var profile: ProfileProgression
var profile_error := ""
var run_id := ""
var run_seed := 0
var run_kills := 0
var run_boss_kills := 0
var run_earned_gold := 0.0
var run_settlement: Dictionary = {}
var reward_pending := false
var rewarded_rooms: Dictionary = {}
var run_damage_multiplier := 1.0
var run_cooldown_multiplier := 1.0
var growth_power_multiplier := 1.0
var growth_regen := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = load("res://assets/fonts/NotoSansSC-Regular.otf") as Font
	assert(font != null, "Chinese UI font failed to load")
	for path in HERO_PATHS:
		hero_textures.append(load(path) as Texture2D)
	for path in ROOM_PATHS:
		room_textures.append(load(path) as Texture2D)
	appearance_textures["female"] = load("res://hub/assets/avatar_woman.png") as Texture2D
	appearance_textures["male"] = load("res://hub/assets/avatar_man.png") as Texture2D
	_configure_input()
	profile = PROFILE_PROGRESSION.new()
	if not profile.last_error.is_empty():
		profile_error = profile.last_error
	var settings_layer := SETTINGS_PANEL.instantiate()
	add_child(settings_layer)
	settings_panel = settings_layer.get_node("SettingsPanel")
	settings_panel.settings_closed.connect(_on_settings_closed)
	reward_panel = REWARD_PANEL.instantiate()
	add_child(reward_panel)
	reward_panel.reward_selected.connect(_on_reward_selected)
	player = CharacterBody2D.new()
	player.name = "Player"
	player.collision_layer = 0
	player.collision_mask = 0
	add_child(player)
	player.position = Vector2(ROOM_SIZE.x * 0.5, ROOM_SIZE.y * 0.61)
	character_data = WEAPON_CONTENT.get_weapon(selected_weapon_id)
	basic_attack_data = WEAPON_CONTENT.get_attack(selected_weapon_id)
	room_data = ENEMY_ROOM_CONTENT.get_room(room_index)
	hub_controller = HUB_SCENE.instantiate() as Node2D
	hub_controller.gender_chosen.connect(_on_gender_chosen)
	hub_controller.weapon_equipped.connect(_on_weapon_equipped)
	hub_controller.expedition_requested.connect(_on_expedition_requested)
	hub_controller.profile_payload_changed.connect(_on_hub_payload_changed)
	if hub_controller.has_signal("appearance_changed"):
		hub_controller.connect("appearance_changed", _on_appearance_changed)
	add_child(hub_controller)
	hub_payload = hub_controller.get_profile_payload()
	appearance_gender = str(hub_payload.get("gender", ""))
	_set_run_view_active(false)
	queue_redraw()


func _on_gender_chosen(gender: String, _display_name: String) -> void:
	appearance_gender = gender
	if hub_controller != null:
		hub_payload = hub_controller.get_profile_payload()


func _on_appearance_changed(gender: String, _display_name: String) -> void:
	appearance_gender = gender
	if hub_controller != null:
		hub_payload = hub_controller.get_profile_payload()


func _on_weapon_equipped(weapon_id: String) -> void:
	if WEAPON_IDS.has(weapon_id):
		selected_weapon_id = weapon_id
		hub_payload = hub_controller.get_profile_payload()
		queue_redraw()


func _on_hub_payload_changed(payload: Dictionary) -> void:
	hub_payload = payload.duplicate(true)
	appearance_gender = str(hub_payload.get("gender", appearance_gender))
	selected_weapon_id = str(hub_payload.get("equipped_weapon", selected_weapon_id))


func _on_expedition_requested(payload: Dictionary) -> void:
	hub_payload = payload.duplicate(true)
	appearance_gender = str(payload.get("gender", ""))
	selected_weapon_id = str(payload.get("equipped_weapon", "bow"))
	_start_run()


func _set_run_view_active(active: bool) -> void:
	if hub_controller == null:
		return
	hub_controller.visible = not active
	hub_controller.set_hub_hud_visible(not active)
	hub_controller.process_mode = Node.PROCESS_MODE_DISABLED if active else Node.PROCESS_MODE_INHERIT


func _configure_input() -> void:
	_add_key_to_action("ui_up", KEY_W)
	_add_key_to_action("ui_down", KEY_S)
	_add_key_to_action("ui_left", KEY_A)
	_add_key_to_action("ui_right", KEY_D)
	if not InputMap.has_action("attack"):
		InputMap.add_action("attack")
	_add_key_to_action("attack", KEY_J)
	_add_key_to_action("attack", KEY_ENTER)
	_add_key_to_action("attack", KEY_KP_ENTER)
	var mouse_attack := InputEventMouseButton.new()
	mouse_attack.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("attack", mouse_attack)
	_add_pad_button_to_action("attack", JOY_BUTTON_A)
	if not InputMap.has_action("dodge"):
		InputMap.add_action("dodge")
	_add_key_to_action("dodge", KEY_SPACE)
	_add_key_to_action("dodge", KEY_SHIFT)
	_add_pad_button_to_action("dodge", JOY_BUTTON_B)
	if not InputMap.has_action("interact"):
		InputMap.add_action("interact")
	_add_key_to_action("interact", KEY_E)
	_add_pad_button_to_action("interact", JOY_BUTTON_START)
	for key_name in ["Q", "E", "R"]:
		var action_name: String = "ability_" + key_name.to_lower()
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
	var q_action := "ability_q"
	var e_action := "ability_e"
	var r_action := "ability_r"
	_add_key_to_action(q_action, KEY_Q)
	_add_key_to_action(e_action, KEY_E)
	_add_key_to_action(r_action, KEY_R)
	_add_pad_button_to_action(q_action, JOY_BUTTON_X)
	_add_pad_button_to_action(e_action, JOY_BUTTON_Y)
	_add_pad_button_to_action(r_action, JOY_BUTTON_RIGHT_SHOULDER)


func _add_key_to_action(action: String, key: Key) -> void:
	var event := InputEventKey.new()
	# This method receives logical Key constants (e.g. KEY_D / KEY_E), not
	# physical key-position codes. Using physical_keycode here made desktop
	# key events fail to match on layouts where keycode and physical_keycode
	# differ (Windows GUI trace: D keycode=68, physical_keycode=4194313).
	event.keycode = key
	InputMap.action_add_event(action, event)


func _add_pad_button_to_action(action: String, button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)


func _input(event: InputEvent) -> void:
	if game_state != "run" or get_tree().paused or settings_panel.visible or reward_pending:
		return
	if event.is_action_pressed("attack"):
		attack_press_buffered = true


func _unhandled_input(event: InputEvent) -> void:
	if _is_settings_toggle(event):
		if settings_panel.visible:
			settings_panel.close_settings()
		elif not reward_pending:
			_open_settings()
		get_viewport().set_input_as_handled()
		return
	if settings_panel.visible or reward_pending:
		return
	if game_state == "run" and event.is_action_pressed("interact") and exit_visible:
		skip_ability_frame = true
		_advance_room()
	elif game_state in ["dead", "victory"] and (event.is_action_pressed("attack") or event.is_action_pressed("ui_accept")):
		_reset_run()


func _physics_process(delta: float) -> void:
	if game_state != "run" or get_tree().paused:
		return
	run_time += delta
	player_hp = minf(player_max_hp, player_hp + growth_regen * delta)
	player_invulnerability = maxf(0.0, player_invulnerability - delta)
	shield_time = maxf(0.0, shield_time - delta)
	damage_buff_time = maxf(0.0, damage_buff_time - delta)
	if damage_buff_time <= 0.0:
		damage_buff = 1.0
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	dash_time = maxf(0.0, dash_time - delta)
	for ability_key in ["Q", "E", "R"]:
		ability_cooldowns[ability_key] = maxf(0.0, float(ability_cooldowns.get(ability_key, 0.0)) - delta)
	hit_flash = maxf(0.0, hit_flash - delta)
	for index in range(effects.size() - 1, -1, -1):
		effects[index]["time"] -= delta
		if effects[index]["time"] <= 0.0:
			effects.remove_at(index)
	_process_player(delta)
	_update_player_animation(delta)
	skip_ability_frame = false
	_process_spawning(delta)
	_process_enemies(delta)
	_process_projectiles(delta)
	_process_flower_zones(delta)
	_process_spirits(delta)
	if game_state == "run":
		_check_room_clear()
	elif game_state == "dead":
		_settle_run(false)
	queue_redraw()


func _process_player(delta: float) -> void:
	var input_vector := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if input_vector != Vector2.ZERO:
		_set_player_facing(input_vector)
	for ability_key in ["Q", "E", "R"]:
		if not skip_ability_frame and Input.is_action_just_pressed("ability_" + ability_key.to_lower()) and not (ability_key == "E" and exit_visible):
			_activate_ability(ability_key)
	if Input.is_action_just_pressed("dodge") and dash_cooldown <= 0.0:
		var dash_direction := input_vector
		if dash_direction == Vector2.ZERO:
			dash_direction = _nearest_enemy_direction()
		if dash_direction == Vector2.ZERO:
			dash_direction = Vector2.RIGHT
		player.velocity = dash_direction.normalized() * 780.0
		dash_cooldown = 2.3
		dash_time = 0.18
		player_invulnerability = 0.38
		_set_player_facing(dash_direction)
		_start_player_oneshot("dash")
		effects.append({"kind": "dash", "position": player.position, "color": ROOM_TINTS[room_index], "time": 0.25, "max_time": 0.25})
	elif dash_time <= 0.0:
		player.velocity = input_vector * player_speed
	player.move_and_slide()
	player.position.x = clampf(player.position.x, ARENA.position.x + 24.0, ARENA.end.x - 24.0)
	player.position.y = clampf(player.position.y, ARENA.position.y + 24.0, ARENA.end.y - 24.0)
	if (Input.is_action_pressed("attack") or Input.is_action_just_pressed("attack") or attack_press_buffered) and attack_cooldown <= 0.0:
		_attack()
		attack_press_buffered = false


func _nearest_enemy_direction() -> Vector2:
	var nearest_distance := INF
	var nearest_direction := Vector2.ZERO
	for enemy in enemies:
		var delta: Vector2 = enemy["body"].position - player.position
		if delta.length_squared() < nearest_distance:
			nearest_distance = delta.length_squared()
			nearest_direction = delta.normalized()
	return nearest_direction


func _set_player_facing(direction: Vector2) -> void:
	if direction.length_squared() < 0.0001:
		return
	var octants := ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
	var octant := posmod(roundi(direction.angle() / (PI / 4.0)), octants.size())
	player_facing = str(octants[octant])
	_refresh_player_animation_texture()


func _player_animation_frame_count(action: String) -> int:
	return BITMAP_ANIMATION_CATALOG.get_frame_count(appearance_gender if appearance_gender in ["female", "male"] else "male", selected_weapon_id, action)


func _player_animation_frame_duration(action: String) -> float:
	var frame_count := _player_animation_frame_count(action)
	var metadata: Dictionary = BITMAP_ANIMATION_CATALOG.get_action_metadata(action)
	var fps := maxf(1.0, float(metadata.get("fps", 8.0)))
	return float(frame_count) / fps


func _start_player_oneshot(action: String) -> void:
	var metadata: Dictionary = BITMAP_ANIMATION_CATALOG.get_action_metadata(action)
	if metadata.is_empty() or bool(metadata.get("loop", false)):
		return
	var priority := int({"basic": 1, "q": 2, "e": 2, "r": 2, "dash": 3, "hurt": 4}.get(action, 0))
	if player_anim_oneshot_remaining > 0.0 and priority < player_anim_priority:
		return
	var duration := _player_animation_frame_duration(action)
	if duration <= 0.0:
		return
	player_anim_action = action
	player_anim_elapsed = 0.0
	player_anim_oneshot_remaining = duration
	player_anim_priority = priority
	_refresh_player_animation_texture(true)


func _update_player_animation(delta: float) -> void:
	player_anim_elapsed += delta
	if player_anim_oneshot_remaining > 0.0:
		player_anim_oneshot_remaining = maxf(0.0, player_anim_oneshot_remaining - delta)
		if player_anim_oneshot_remaining <= 0.0:
			player_anim_priority = 0
		var current_metadata: Dictionary = BITMAP_ANIMATION_CATALOG.get_action_metadata(player_anim_action)
		if not bool(current_metadata.get("loop", false)) and player_anim_oneshot_remaining <= 0.0:
			player_anim_action = ""
	if player_anim_oneshot_remaining <= 0.0:
		var locomotion := "run" if player.velocity.length_squared() > 100.0 else "idle"
		if player_anim_action != locomotion:
			player_anim_action = locomotion
			player_anim_elapsed = 0.0
			player_anim_frame_index = -1
	_refresh_player_animation_texture()
	queue_redraw()


func _refresh_player_animation_texture(force: bool = false) -> void:
	var action := player_anim_action if not player_anim_action.is_empty() else "idle"
	var frame_count := _player_animation_frame_count(action)
	if frame_count <= 0:
		player_anim_frame_index = -1
		player_anim_source_direction = "E"
		player_anim_texture = appearance_textures.get("female" if appearance_gender == "female" else "male")
		player_anim_flip_h = false
		return
	var metadata: Dictionary = BITMAP_ANIMATION_CATALOG.get_action_metadata(action)
	var fps := maxf(1.0, float(metadata.get("fps", 8.0)))
	var frame_index := int(floor(player_anim_elapsed * fps))
	if bool(metadata.get("loop", false)):
		frame_index = posmod(frame_index, frame_count)
	else:
		frame_index = mini(frame_index, frame_count - 1)
	var resolved: Dictionary = BITMAP_ANIMATION_CATALOG.resolve_direction(player_facing)
	var stored_direction := str(resolved.get("source_direction", "E"))
	var flip_h := bool(resolved.get("flip_h", false))
	if not force and frame_index == player_anim_frame_index and player_anim_flip_h == flip_h and player_anim_source_direction == stored_direction:
		return
	player_anim_frame_index = frame_index
	player_anim_source_direction = stored_direction
	player_anim_flip_h = flip_h
	var gender := appearance_gender if appearance_gender in ["female", "male"] else "male"
	var cache_key := "%s|%s|%s|%s|%d" % [gender, selected_weapon_id, action, stored_direction, frame_index]
	if player_anim_cache.has(cache_key):
		player_anim_texture = player_anim_cache[cache_key]
	else:
		var portrait: Texture2D = appearance_textures.get(gender)
		var texture: Texture2D = BITMAP_ANIMATION_CATALOG.load_frame_or_fallback(gender, selected_weapon_id, action, player_facing, frame_index, portrait)
		player_anim_cache[cache_key] = texture
		player_anim_texture = texture


func _player_animation_is_catalog_frame() -> bool:
	var action := player_anim_action if not player_anim_action.is_empty() else "idle"
	if player_anim_frame_index < 0:
		return false
	var frame_path: Variant = BITMAP_ANIMATION_CATALOG.get_frame_path(appearance_gender if appearance_gender in ["female", "male"] else "male", selected_weapon_id, action, player_facing, player_anim_frame_index)
	return frame_path != null and player_anim_texture != null and BITMAP_ANIMATION_CATALOG.has_complete_direction(appearance_gender if appearance_gender in ["female", "male"] else "male", selected_weapon_id, action, player_facing)


func _attack() -> void:
	var target := _nearest_enemy()
	if target < 0:
		attack_cooldown = 0.2
		return
	var enemy_position: Vector2 = enemies[target]["body"].position
	var direction: Vector2 = (enemy_position - player.position).normalized()
	_set_player_facing(direction)
	_start_player_oneshot("basic")
	var tint: Color = [Color("c7d5df"), Color("ffd09b"), Color("9fe29a"), Color("9fd9ff")][selected_hero]
	var attack_type := str(basic_attack_data.get("type", "projectile"))
	attack_cooldown = float(basic_attack_data.get("cooldown_at_level_1", 0.55))
	match attack_type:
		"projectile", "homing_projectile":
			var pierce := int(basic_attack_data.get("pierce", 1))
			if pierce < 0:
				pierce = maxi(1, enemies.size() + 1)
			_launch_projectile(direction, float(basic_attack_data.get("level_1_damage", 20.0)) * _effective_power(), float(basic_attack_data.get("speed", 420.0)), float(basic_attack_data.get("lifetime", 2.0)), pierce, attack_type == "homing_projectile", tint)
		"ground_zone":
			flower_zones.clear()
			flower_zones.append({"position": enemy_position, "radius": float(basic_attack_data.get("radius_at_level_1", 100.0)), "damage": float(basic_attack_data.get("level_1_damage_per_pulse", 17.0)) * _effective_power(), "pulse_interval": float(basic_attack_data.get("pulse_interval", 0.5)), "pulse_timer": 0.0, "life": float(basic_attack_data.get("lifetime", 8.0)), "color": tint})
			attack_cooldown = maxf(0.4, attack_cooldown)
			_effect_at("bloom", enemy_position, tint, 0.3)
		"melee_sweep":
			var slash_reach := float(basic_attack_data.get("radius_base", 112.0))
			var damage := float(basic_attack_data.get("level_1_damage", 38.0)) * _effective_power()
			for i in range(enemies.size() - 1, -1, -1):
				var to_enemy: Vector2 = enemies[i]["body"].position - player.position
				if to_enemy.length() <= slash_reach and direction.dot(to_enemy.normalized()) >= 0.15:
					_damage_enemy(i, roundi(damage))
			effects.append({"kind": "slash", "position": player.position + direction * 45.0, "direction": direction, "color": tint, "time": 0.22, "max_time": 0.22})


func _launch_projectile(direction: Vector2, damage: float, speed: float, lifetime: float, pierce: int, homing: bool, tint: Color, burst_radius: float = 0.0) -> void:
	projectiles.append({"position": player.position + direction * 25.0, "velocity": direction * speed, "damage": roundi(damage), "pierce": maxi(1, pierce), "radius": 10.0 if homing else 9.0, "color": tint, "life": lifetime, "homing": homing, "burst_radius": burst_radius})


func _effect_at(kind: String, position: Vector2, color: Color, duration: float) -> void:
	effects.append({"kind": kind, "position": position, "color": color, "time": duration, "max_time": duration})


func _activate_ability(key: String) -> void:
	if float(ability_cooldowns.get(key, 0.0)) > 0.0:
		return
	var contract: Dictionary = WEAPON_CONTENT.build_ability_contract(selected_weapon_id, key, {"power": _effective_power(), "cooldown_haste": run_cooldown_multiplier})
	if contract.is_empty():
		return
	var aim_direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if aim_direction == Vector2.ZERO:
		aim_direction = _nearest_enemy_direction()
	_set_player_facing(aim_direction)
	_start_player_oneshot(key.to_lower())
	ability_cooldowns[key] = float(contract.get("cooldown", 0.0))
	for action in contract.get("actions", []):
		_execute_ability_action(action)


func _execute_ability_action(action: Dictionary) -> void:
	var action_type := str(action.get("type", ""))
	var tint: Color = ROOM_TINTS[room_index]
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if direction == Vector2.ZERO:
		direction = _nearest_enemy_direction()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	match action_type:
		"dash":
			var origin := player.position
			player.position += direction * float(action.get("distance", 160.0))
			player.position.x = clampf(player.position.x, ARENA.position.x + 24.0, ARENA.end.x - 24.0)
			player.position.y = clampf(player.position.y, ARENA.position.y + 24.0, ARENA.end.y - 24.0)
			player.velocity = direction * 780.0
			dash_time = 0.22
			player_invulnerability = maxf(player_invulnerability, float(action.get("invulnerability", 0.4)))
			_effect_at("dash", origin, tint, 0.35)
			_effect_at("dash", player.position, tint, 0.35)
		"projectile":
			_launch_projectile(direction, float(action.get("damage", 20.0)), float(action.get("speed", 500.0)), float(action.get("lifetime", 1.5)), int(action.get("pierce", 1)), false, tint)
		"fan_projectiles":
			var count := int(action.get("count", 3))
			var spread := float(action.get("spread_radians", 0.16))
			for index in range(count):
				var offset := float(index) - float(count - 1) * 0.5
				_launch_projectile(direction.rotated(offset * spread), float(action.get("damage_each", 20.0)), float(action.get("speed", 500.0)), float(action.get("lifetime", 1.2)), int(action.get("pierce", 1)), false, tint)
		"melee_sweep":
			_apply_area_damage(player.position, float(action.get("radius", 125.0)), float(action.get("damage", 30.0)))
			_effect_at("slash", player.position + direction * 40.0, tint, 0.3)
		"projectile_burst":
			_launch_projectile(direction, float(action.get("damage", 30.0)), float(action.get("projectile_speed", 420.0)), 1.7, 1, false, tint, float(action.get("burst_radius", 95.0)))
		"healing_zone":
			flower_zones.append({"position": player.position, "radius": float(action.get("radius", 175.0)), "damage": float(action.get("damage_per_pulse", 0.0)), "heal": float(action.get("heal_per_pulse", 5.0)), "pulse_interval": float(action.get("pulse_interval", 0.65)), "pulse_timer": 0.0, "life": float(action.get("duration", 5.0)), "color": Color("a6df99")})
			_effect_at("bloom", player.position, Color("a6df99"), 0.5)
		"shield_counter", "area_shield":
			player_shield += float(action.get("shield", 25.0))
			shield_time = maxf(shield_time, float(action.get("duration", 3.0)))
			player_hp = minf(player_max_hp, player_hp + float(action.get("cast_heal", 0.0)))
			if action_type == "area_shield":
				_apply_area_damage(player.position, float(action.get("radius", 240.0)), float(action.get("retaliation_damage", 0.0)))
			_effect_at("dash", player.position, Color("dbeeff"), 0.55)
		"dash_strike":
			var origin := player.position
			var target_index := _nearest_enemy()
			var destination := player.position + direction * float(action.get("distance", 220.0))
			if target_index >= 0:
				destination = enemies[target_index]["body"].position
			var travel := (destination - player.position).limit_length(float(action.get("distance", 220.0)))
			player.position += travel
			player.position.x = clampf(player.position.x, ARENA.position.x + 24.0, ARENA.end.x - 24.0)
			player.position.y = clampf(player.position.y, ARENA.position.y + 24.0, ARENA.end.y - 24.0)
			player_invulnerability = maxf(player_invulnerability, float(action.get("invulnerability", 0.5)))
			_apply_area_damage(player.position, float(action.get("hit_radius", 62.0)), float(action.get("damage", 40.0)))
			_effect_at("slash", (origin + player.position) * 0.5, tint, 0.35)
		"recall_pets":
			_apply_area_damage(player.position, float(action.get("recall_radius", 155.0)), float(action.get("damage", 20.0)))
			_effect_at("dash", player.position, tint, 0.45)
		"pet_boost":
			damage_buff = maxf(damage_buff, float(action.get("damage_multiplier", 1.5)))
			damage_buff_time = float(action.get("duration", 10.0))
			player_hp = minf(player_max_hp, player_hp + float(action.get("heal_each", 0.0)))
		"summon_spirit":
			spirit_count = mini(int(action.get("maximum", 3)), spirit_count + int(action.get("count", 1)))
			_effect_at("dash", player.position, Color("b9e6ff"), 0.8)
		"decoy":
			_effect_at("pop", player.position, Color("bdc5d0"), float(action.get("lifetime", 2.5)))
		"":
			return


func _process_flower_zones(delta: float) -> void:
	for index in range(flower_zones.size() - 1, -1, -1):
		var zone := flower_zones[index]
		zone["life"] = float(zone["life"]) - delta
		zone["pulse_timer"] = float(zone["pulse_timer"]) - delta
		if float(zone["pulse_timer"]) <= 0.0:
			zone["pulse_timer"] = float(zone.get("pulse_interval", 0.6))
			_apply_area_damage(zone["position"], float(zone["radius"]), float(zone.get("damage", 0.0)))
			player_hp = minf(player_max_hp, player_hp + float(zone.get("heal", 0.0)))
		if float(zone["life"]) <= 0.0:
			flower_zones.remove_at(index)
		else:
			flower_zones[index] = zone


func _process_spirits(delta: float) -> void:
	if spirit_count <= 0 or enemies.is_empty():
		return
	spirit_attack_timer -= delta
	if spirit_attack_timer > 0.0:
		return
	spirit_attack_timer = 0.9
	var direction: Vector2 = enemies[_nearest_enemy() ]["body"].position - player.position
	_launch_projectile(direction.normalized(), 6.0 * float(spirit_count), 430.0, 2.0, 1, true, Color("a7dfff"))


func _apply_area_damage(center: Vector2, radius: float, damage: float) -> void:
	if damage <= 0.0:
		return
	for index in range(enemies.size() - 1, -1, -1):
		var body: CharacterBody2D = enemies[index]["body"]
		if body.position.distance_to(center) <= radius:
			_damage_enemy(index, roundi(maxf(1.0, damage)))


func _nearest_enemy() -> int:
	var nearest_index := -1
	var nearest_distance := INF
	for index in range(enemies.size()):
		var distance: float = enemies[index]["body"].position.distance_squared_to(player.position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = index
	return nearest_index


func _process_spawning(delta: float) -> void:
	if spawned_count >= _room_quota() or enemies.size() >= int(room_data.get("max_enemies", 4)):
		return
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_spawn_enemy()
		spawned_count += 1
		spawn_timer = maxf(0.65, 1.25 - float(room_index) * 0.1)


func _spawn_enemy() -> void:
	var enemy_ids: Array = room_data.get("enemy_ids", [])
	if enemy_ids.is_empty():
		return
	var enemy_data: Dictionary = ENEMY_ROOM_CONTENT.get_enemy(str(enemy_ids[randi_range(0, enemy_ids.size() - 1)]))
	var stats: Dictionary = enemy_data.get("prototype_stats", {})
	var angle := randf() * TAU
	var radius := randf_range(280.0, 500.0)
	var spawn_position := player.position + Vector2.RIGHT.rotated(angle) * radius
	spawn_position.x = clampf(spawn_position.x, ARENA.position.x + 30.0, ARENA.end.x - 30.0)
	spawn_position.y = clampf(spawn_position.y, ARENA.position.y + 30.0, ARENA.end.y - 30.0)
	if spawn_position.distance_to(player.position) < 230.0:
		spawn_position = Vector2(ARENA.end.x - spawn_position.x, ARENA.end.y - spawn_position.y)
	var body := CharacterBody2D.new()
	body.name = "Enemy_%02d" % spawned_count
	body.collision_layer = 0
	body.collision_mask = 0
	body.position = spawn_position
	add_child(body)
	var hp := int(stats.get("hp", 1))
	enemies.append({"body": body, "id": enemy_data.get("id", ""), "name": enemy_data.get("name", "Enemy"), "kind": enemy_data.get("kind", "grunt"), "is_boss": false, "hp": hp, "max_hp": hp, "speed": float(stats.get("speed", 84.0)), "damage": float(stats.get("damage", 8.0)), "contact_cooldown": 1.35, "attack_timer": 0.5, "wobble": randf() * TAU, "size": float(stats.get("radius", 15.0))})


func _process_enemies(delta: float) -> void:
	for index in range(enemies.size() - 1, -1, -1):
		var enemy := enemies[index]
		var body: CharacterBody2D = enemy["body"]
		var toward_player := player.position - body.position
		var direction := toward_player.normalized()
		enemy["wobble"] += delta * 2.2
		var drift := Vector2(sin(enemy["wobble"]), cos(enemy["wobble"] * 0.73)) * 0.2
		body.velocity = (direction + drift).normalized() * float(enemy["speed"])
		body.move_and_slide()
		enemy["attack_timer"] = maxf(0.0, float(enemy["attack_timer"]) - delta)
		var is_boss := bool(enemy.get("is_boss", false))
		if body.position.distance_to(player.position) < (float(enemy["size"]) + 20.0) and float(enemy["attack_timer"]) <= 0.0:
			if player_invulnerability <= 0.0:
				var incoming := float(enemy.get("damage", 8.0))
				var absorbed := minf(player_shield, incoming)
				player_shield -= absorbed
				player_hp -= incoming - absorbed
				player_invulnerability = 0.82
				hit_flash = 0.22
				_set_player_facing(-direction)
				_start_player_oneshot("hurt")
				if player_hp <= 0.0:
					player_hp = 0.0
					game_state = "dead"
					_settle_run(false)
			enemy["attack_timer"] = float(enemy.get("contact_cooldown", 1.35)) if not is_boss else 1.25
		if game_state == "dead":
			return


func _process_projectiles(delta: float) -> void:
	for p_index in range(projectiles.size() - 1, -1, -1):
		var projectile := projectiles[p_index]
		projectile["life"] = float(projectile["life"]) - delta
		if projectile.get("homing", false) and not enemies.is_empty():
			var closest := _nearest_enemy_to(projectile["position"])
			if closest >= 0:
				var target_position: Vector2 = enemies[closest]["body"].position
				var current_velocity: Vector2 = projectile["velocity"]
				projectile["velocity"] = current_velocity.lerp((target_position - projectile["position"]).normalized() * 385.0, 0.09)
		projectile["position"] += projectile["velocity"] * delta
		var collided := false
		for e_index in range(enemies.size() - 1, -1, -1):
			var body: CharacterBody2D = enemies[e_index]["body"]
			if body.position.distance_to(projectile["position"]) <= float(projectile["radius"]) + float(enemies[e_index]["size"]):
				var hit_position: Vector2 = body.position
				_damage_enemy(e_index, int(projectile["damage"]))
				if float(projectile.get("burst_radius", 0.0)) > 0.0:
					_apply_area_damage(hit_position, float(projectile["burst_radius"]), float(projectile["damage"]) * 0.65)
					_effect_at("bloom", hit_position, projectile["color"], 0.35)
					collided = true
					break
				projectile["pierce"] = int(projectile["pierce"]) - 1
				if int(projectile["pierce"]) <= 0:
					collided = true
				break
		if collided or float(projectile["life"]) <= 0.0 or not ARENA.has_point(projectile["position"]):
			projectiles.remove_at(p_index)


func _nearest_enemy_to(position: Vector2) -> int:
	var nearest_index := -1
	var nearest_distance := INF
	for index in range(enemies.size()):
		var distance: float = enemies[index]["body"].position.distance_squared_to(position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = index
	return nearest_index


func _damage_enemy(index: int, amount: int) -> void:
	if index < 0 or index >= enemies.size():
		return
	var enemy := enemies[index]
	enemy["hp"] = int(enemy["hp"]) - amount
	if int(enemy["hp"]) <= 0:
		var body: CharacterBody2D = enemy["body"]
		effects.append({"kind": "pop", "position": body.position, "color": ROOM_TINTS[room_index], "time": 0.35, "max_time": 0.35})
		body.queue_free()
		enemies.remove_at(index)
		if bool(enemy.get("is_boss", false)):
			boss_defeated = true
			run_boss_kills += 1
		else:
			defeated_count += 1
			run_kills += 1
	else:
		effects.append({"kind": "spark", "position": enemy["body"].position, "color": Color.WHITE, "time": 0.16, "max_time": 0.16})


func _check_room_clear() -> void:
	if defeated_count < _room_quota() or spawned_count < _room_quota() or not enemies.is_empty():
		return
	if bool(room_data.get("is_boss_room", false)):
		if not boss_spawned:
			_spawn_boss()
			return
		if not boss_defeated:
			return
	if room_index < ENEMY_ROOM_CONTENT.get_room_count() - 1 and not rewarded_rooms.has(room_index):
		if not reward_pending:
			reward_pending = true
			get_tree().paused = true
			reward_panel.open_rewards(room_index, run_seed)
		return
	exit_visible = true


func _room_quota() -> int:
	return int(room_data.get("kill_quota", [6, 8, 10, 12][room_index]))


func _spawn_boss() -> void:
	boss_data = ENEMY_ROOM_CONTENT.get_boss(str(room_data.get("boss_id", "")))
	var stats: Dictionary = boss_data.get("prototype_stats", {})
	var body := CharacterBody2D.new()
	body.name = "Boss_" + str(boss_data.get("id", "boss"))
	body.collision_layer = 0
	body.collision_mask = 0
	body.position = Vector2(ARENA.end.x - 150.0, ARENA.position.y + 110.0)
	add_child(body)
	var hp := int(stats.get("hp", 14))
	enemies.append({"body": body, "id": boss_data.get("id", "boss"), "name": boss_data.get("name", "Boss"), "kind": "boss", "is_boss": true, "hp": hp, "max_hp": hp, "speed": float(stats.get("speed", 72.0)), "damage": float(stats.get("damage", 15.0)), "contact_cooldown": float(stats.get("attack_cooldown", 3.5)), "attack_timer": 1.5, "wobble": 0.0, "size": float(stats.get("radius", 30.0))})
	boss_spawned = true
	_effect_at("bloom", body.position, ROOM_TINTS[room_index], 0.6)


func _start_run() -> void:
	if not profile_error.is_empty():
		return
	if hub_controller != null:
		hub_payload = hub_controller.get_profile_payload()
	selected_weapon_id = str(hub_payload.get("equipped_weapon", selected_weapon_id))
	if not WEAPON_IDS.has(selected_weapon_id):
		selected_weapon_id = "bow"
	selected_hero = HERO_IDS.find(str(KIT_BY_WEAPON[selected_weapon_id]))
	appearance_gender = str(hub_payload.get("gender", appearance_gender))
	if appearance_gender.is_empty():
		return
	game_state = "run"
	_set_run_view_active(true)
	room_index = 0
	run_id = PROFILE_PROGRESSION.new_run_id()
	run_seed = hash(run_id)
	run_kills = 0
	run_boss_kills = 0
	run_earned_gold = 0.0
	run_settlement.clear()
	hub_material_awarded = 0
	rewarded_rooms.clear()
	reward_pending = false
	run_damage_multiplier = 1.0
	run_cooldown_multiplier = 1.0
	damage_buff = 1.0
	damage_buff_time = 0.0
	player_shield = 0.0
	spirit_count = 0
	var kit_id: String = str(KIT_BY_WEAPON[selected_weapon_id])
	character_data = WEAPON_CONTENT.get_weapon(selected_weapon_id)
	var stats: Dictionary = character_data.get("combat_stats", CHARACTER_CONTENT.get_base_stats(kit_id))
	var growth: Dictionary = profile.get_character_growth(kit_id)
	basic_attack_data = WEAPON_CONTENT.get_attack(selected_weapon_id)
	player_max_hp = float(stats.get("max_hp", 120.0)) + float(growth.get("max_hp_bonus", 0.0))
	player_speed = float(stats.get("move_speed", 230.0))
	var weapon_levels: Dictionary = hub_payload.get("weapon_levels", {})
	var weapon_level := clampi(int(weapon_levels.get(selected_weapon_id, 1)), 1, 4)
	growth_power_multiplier = (1.0 + float(growth.get("power_bonus", 0.0))) * (1.0 + float(weapon_level - 1) * 0.06)
	growth_regen = float(growth.get("regen_bonus", 0.0))
	player_hp = player_max_hp
	run_time = 0.0
	player_anim_action = "idle"
	player_anim_elapsed = 0.0
	player_anim_oneshot_remaining = 0.0
	player_anim_priority = 0
	player_anim_frame_index = -1
	_enter_room()


func _enter_room() -> void:
	room_data = ENEMY_ROOM_CONTENT.get_room(room_index)
	boss_data = {}
	player.position = ROOM_SIZE * Vector2(0.5, 0.61)
	player.velocity = Vector2.ZERO
	player_anim_action = "idle"
	player_anim_elapsed = 0.0
	player_anim_oneshot_remaining = 0.0
	player_anim_priority = 0
	player_anim_frame_index = -1
	_refresh_player_animation_texture(true)
	enemies.clear()
	projectiles.clear()
	effects.clear()
	spawned_count = 0
	defeated_count = 0
	boss_spawned = false
	boss_defeated = false
	ability_cooldowns = {"Q": 0.0, "E": 0.0, "R": 0.0}
	flower_zones.clear()
	spawn_timer = 0.8
	exit_visible = false
	dash_cooldown = 0.0
	attack_cooldown = 0.15
	attack_press_buffered = false
	if room_index > 0:
		player_hp = minf(player_max_hp, player_hp + 12.0)
	queue_redraw()


func _advance_room() -> void:
	if reward_pending or (room_index < ENEMY_ROOM_CONTENT.get_room_count() - 1 and not rewarded_rooms.has(room_index)):
		return
	if room_index >= ENEMY_ROOM_CONTENT.get_room_count() - 1:
		game_state = "victory"
		_settle_run(true)
		queue_redraw()
		return
	room_index += 1
	_enter_room()


func _reset_run() -> void:
	get_tree().paused = false
	game_state = "hub"
	attack_press_buffered = false
	_set_run_view_active(false)
	player_hp = player_max_hp
	room_index = 0
	enemies.clear()
	projectiles.clear()
	effects.clear()
	reward_pending = false
	reward_panel.close_rewards()
	if hub_controller != null:
		hub_payload = hub_controller.get_profile_payload()
		appearance_gender = str(hub_payload.get("gender", ""))
		selected_weapon_id = str(hub_payload.get("equipped_weapon", "bow"))
	queue_redraw()


func _effective_power() -> float:
	return damage_buff * run_damage_multiplier * growth_power_multiplier


func _is_settings_toggle(event: InputEvent) -> bool:
	return (event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode == KEY_F2 or event.keycode == KEY_F2)) or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_BACK)


func _open_settings() -> void:
	get_tree().paused = true
	settings_panel.open_settings()


func _on_settings_closed() -> void:
	get_tree().paused = false
	queue_redraw()


func _on_reward_selected(reward: Dictionary) -> void:
	if not reward_pending or rewarded_rooms.has(room_index) or game_state != "run":
		return
	var effect: Dictionary = reward.get("effect", {})
	match str(effect.get("type", "")):
		"heal":
			player_hp = minf(player_max_hp, player_hp + float(effect.get("amount", 0.0)))
		"damage_multiplier":
			run_damage_multiplier *= float(effect.get("multiplier", 1.0))
		"cooldown_multiplier":
			run_cooldown_multiplier *= float(effect.get("multiplier", 1.0))
		"max_health_and_heal":
			player_max_hp += float(effect.get("max_health", 0.0))
			player_hp = minf(player_max_hp, player_hp + float(effect.get("heal", 0.0)))
		"damage_and_heal":
			run_damage_multiplier *= float(effect.get("damage_multiplier", 1.0))
			player_hp = minf(player_max_hp, player_hp + float(effect.get("heal", 0.0)))
		_:
			return
	rewarded_rooms[room_index] = str(reward.get("id", ""))
	reward_pending = false
	exit_visible = true
	get_tree().paused = false
	queue_redraw()


func _settle_run(victory: bool) -> void:
	if not run_settlement.is_empty() or run_id.is_empty():
		return
	run_settlement = profile.settle_room_run(run_id, {"victory": victory, "kills": run_kills, "boss_kills": run_boss_kills, "earned_gold": run_earned_gold})
	if not bool(run_settlement.get("ok", false)):
		profile_error = str(run_settlement.get("error", "档案写入失败"))
	_award_hub_marks()
	queue_redraw()


func _award_hub_marks() -> void:
	if hub_material_awarded > 0 or hub_controller == null:
		return
	hub_material_awarded = run_kills + run_boss_kills * 5
	if hub_material_awarded <= 0:
		return
	var updated: Dictionary = hub_controller.get_profile_payload()
	updated["hub_marks"] = int(updated.get("hub_marks", 0)) + hub_material_awarded
	hub_controller.set_profile_payload(updated)
	hub_payload = hub_controller.get_profile_payload()


func _draw() -> void:
	if game_state == "hub":
		return
	if game_state == "select":
		_draw_selection()
		return
	if room_textures.size() > room_index:
		draw_texture_rect(room_textures[room_index], Rect2(Vector2.ZERO, ROOM_SIZE), false, Color(0.83, 0.88, 0.86, 1.0))
	else:
		draw_rect(Rect2(Vector2.ZERO, ROOM_SIZE), Color("263c34"))
	draw_rect(Rect2(Vector2.ZERO, ROOM_SIZE), Color(0.04, 0.08, 0.09, 0.36))
	_draw_arena_frame()
	for zone in flower_zones:
		var zone_color: Color = zone["color"]
		draw_circle(zone["position"], float(zone["radius"]), Color(zone_color.r, zone_color.g, zone_color.b, 0.09))
		draw_arc(zone["position"], float(zone["radius"]), 0.0, TAU, 48, Color(zone_color.r, zone_color.g, zone_color.b, 0.65), 3.0)
	for enemy in enemies:
		_draw_enemy(enemy)
	for projectile in projectiles:
		_draw_projectile(projectile)
	for effect in effects:
		_draw_effect(effect)
	_draw_player()
	_draw_hud()
	if game_state == "dead":
		_draw_end_overlay(false)
	elif game_state == "victory":
		_draw_end_overlay(true)


func _draw_arena_frame() -> void:
	draw_rect(ARENA, Color(0.02, 0.035, 0.04, 0.72), false, 3.0)
	var tint: Color = ROOM_TINTS[room_index]
	for index in range(8):
		var x := ARENA.position.x + 90.0 + index * 142.0
		var y := ARENA.end.y - 24.0 - float((index % 3) * 11)
		draw_colored_polygon(PackedVector2Array([Vector2(x, y), Vector2(x + 18.0, y - 44.0), Vector2(x + 35.0, y)]), Color(tint.r, tint.g, tint.b, 0.30))
	if exit_visible:
		var door := Rect2(ARENA.end.x - 82.0, ROOM_SIZE.y * 0.5 - 57.0, 54.0, 114.0)
		draw_rect(door.grow(15.0), Color(tint.r, tint.g, tint.b, 0.2))
		draw_rect(door, Color("15201e"))
		draw_rect(door, tint, false, 4.0)
		draw_circle(door.position + Vector2(39.0, 57.0), 4.0, Color("ffe4a1"))
		_draw_text("出口 · E / 手柄开始键", Vector2(door.position.x - 50.0, door.position.y - 16.0), 12, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 160)


func _draw_enemy(enemy: Dictionary) -> void:
	var body: CharacterBody2D = enemy["body"]
	var radius: float = enemy["size"]
	var center: Vector2 = body.position
	var enemy_color: Color = [Color("719c72"), Color("bd6549"), Color("bd824f"), Color("8cb8c5")][room_index]
	_draw_shadow_ellipse(center + Vector2(0.0, radius * 0.63), Vector2(radius * 0.88, radius * 0.35), Color(0.01, 0.02, 0.02, 0.36))
	var boss := bool(enemy.get("is_boss", false))
	if boss:
		radius *= 1.35
		draw_circle(center, radius + 9.0, Color(ROOM_TINTS[room_index].r, ROOM_TINTS[room_index].g, ROOM_TINTS[room_index].b, 0.22))
	draw_circle(center, radius, Color("18221f"))
	draw_circle(center, radius - 3.0, enemy_color)
	draw_circle(center + Vector2(-radius * 0.25, -radius * 0.12), maxf(4.0, radius * 0.13), Color("f0e4c8"))
	draw_circle(center + Vector2(radius * 0.24, -radius * 0.12), maxf(4.0, radius * 0.13), Color("f0e4c8"))
	draw_circle(center + Vector2(-radius * 0.23, -radius * 0.1), 2.2, Color("202321"))
	draw_circle(center + Vector2(radius * 0.25, -radius * 0.1), 2.2, Color("202321"))
	if boss:
		_draw_text(str(enemy.get("name", "首领")), center + Vector2(-110, -radius - 22), 14, Color("fff2d5"), HORIZONTAL_ALIGNMENT_CENTER, 220)
	if int(enemy["max_hp"]) > 1:
		var bar := Rect2(center + Vector2(-radius, -radius - 11.0), Vector2(radius * 2.0, 4.0))
		draw_rect(bar, Color(0.1, 0.12, 0.12, 0.84))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(enemy["hp"]) / float(enemy["max_hp"]), bar.size.y)), Color("f1ca7b"))


func _draw_player() -> void:
	var center: Vector2 = player.position
	if player_invulnerability > 0.0 and int(player_invulnerability * 18.0) % 2 == 0:
		return
	_draw_shadow_ellipse(center + Vector2(0.0, 42.0), Vector2(30.0, 11.0), Color(0.0, 0.02, 0.02, 0.45))
	var gender := "female" if appearance_gender == "female" else "male"
	var texture: Texture2D = player_anim_texture if player_anim_texture != null else appearance_textures.get(gender)
	var is_catalog_frame := _player_animation_is_catalog_frame()
	var target_size := Vector2(110.0, 110.0) if is_catalog_frame else Vector2(88.0, 110.0)
	var rect := Rect2(Vector2(center.x - target_size.x * 0.5, center.y - target_size.y) if is_catalog_frame else center - Vector2(target_size.x * 0.5, target_size.y * 0.66), target_size)
	if texture != null:
		if is_catalog_frame and player_anim_flip_h:
			draw_set_transform(Vector2(center.x, center.y), 0.0, Vector2(-1.0, 1.0))
			draw_texture_rect(texture, Rect2(Vector2(-target_size.x * 0.5, -target_size.y), target_size), false)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			draw_texture_rect(texture, rect, false)
	else:
		draw_circle(center + Vector2(0.0, -15.0), 19.0, Color("d1a57a"))
		draw_rect(Rect2(center + Vector2(-22.0, 0.0), Vector2(44.0, 50.0)), Color("465b58"))
	if hit_flash > 0.0:
		draw_arc(center, 43.0, 0.0, TAU, 36, Color(1.0, 0.44, 0.36, 0.72), 3.0)


func _draw_projectile(projectile: Dictionary) -> void:
	var pos: Vector2 = projectile["position"]
	var radius: float = projectile["radius"]
	var color: Color = projectile["color"]
	draw_circle(pos, radius + 6.0, Color(color.r, color.g, color.b, 0.19))
	draw_circle(pos, radius, color)
	draw_circle(pos, radius * 0.42, Color.WHITE)


func _draw_effect(effect: Dictionary) -> void:
	var fade: float = float(effect["time"]) / float(effect["max_time"])
	var color: Color = effect["color"]
	color.a *= fade
	var position: Vector2 = effect["position"]
	match effect["kind"]:
		"bloom":
			var radius := 112.0 * (1.0 - fade * 0.35)
			draw_circle(position, radius, Color(color.r, color.g, color.b, 0.16 * fade))
			draw_arc(position, radius, 0.0, TAU, 48, color, 4.0)
			for petal in range(5):
				draw_circle(position + Vector2.RIGHT.rotated(TAU * petal / 5.0) * radius * 0.7, 8.0 * fade, color)
		"slash":
			var direction: Vector2 = effect["direction"]
			var from := position.angle() - 0.95
			var to := position.angle() + 0.95
			draw_arc(position - direction * 45.0, 95.0, from, to, 24, color, 9.0 * fade)
		"dash":
			draw_arc(position, 34.0 + (1.0 - fade) * 22.0, 0.0, TAU, 28, color, 3.0 * fade)
		"pop", "spark":
			draw_circle(position, (12.0 + (1.0 - fade) * 30.0) * fade, color)


func _draw_hud() -> void:
	var tint: Color = ROOM_TINTS[room_index]
	draw_rect(Rect2(0.0, 0.0, ROOM_SIZE.x, 92.0), Color("121b1d"))
	draw_rect(Rect2(0.0, 90.0, ROOM_SIZE.x, 2.0), Color(tint.r, tint.g, tint.b, 0.75))
	_draw_text("四季同行", Vector2(42, 31), 15, Color("b7c5bf"))
	_draw_text(ROOM_NAMES[room_index], Vector2(42, 68), 24, Color("fff2d5"))
	_draw_text("第 %d / 4 房 · %s季" % [room_index + 1, ROOM_TAGS[room_index]], Vector2(478, 39), 17, tint, HORIZONTAL_ALIGNMENT_CENTER, 330)
	var phase_label := "首领：%s" % ("已击败" if boss_defeated else "战斗中") if boss_spawned else "击败敌人  %02d / %02d" % [defeated_count, _room_quota()]
	_draw_text(phase_label, Vector2(478, 68), 18, Color("f6ead0"), HORIZONTAL_ALIGNMENT_CENTER, 330)
	_draw_text(str(WEAPON_CONTENT.get_weapon(selected_weapon_id).get("name", WEAPON_NAMES[selected_hero])), Vector2(826, 35), 14, Color("f4e9d4"), HORIZONTAL_ALIGNMENT_RIGHT, 280)
	_draw_text("本次用时  %s" % _format_time(run_time), Vector2(826, 61), 14, Color("a8b8b1"), HORIZONTAL_ALIGNMENT_RIGHT, 280)
	var health_rect := Rect2(44.0, 666.0, 202.0, 16.0)
	draw_rect(Rect2(health_rect.position - Vector2(10, 14), Vector2(health_rect.size.x + 70, 43)), Color(0.035, 0.06, 0.065, 0.92))
	_draw_text("生命", Vector2(health_rect.position.x, 668), 13, Color("ecdfcb"))
	draw_rect(health_rect, Color(0.09, 0.12, 0.12, 0.9))
	draw_rect(Rect2(health_rect.position, Vector2(health_rect.size.x * player_hp / player_max_hp, health_rect.size.y)), Color("d47165") if player_hp <= player_max_hp * 0.35 else Color("7db494"))
	_draw_text("%d / %d" % [int(player_hp), int(player_max_hp)], Vector2(health_rect.end.x + 14.0, 679), 13, Color("f6ead0"))
	_draw_text("WASD / 摇杆移动 · 鼠标左键 / J / A 普攻 · 空格 / B 闪避 · Q E R / X Y RB 技能 · F2 / 手柄返回键 设置", Vector2(420, 675), 11, Color("d7d7c8"), HORIZONTAL_ALIGNMENT_CENTER, 790)
	if exit_visible:
		_draw_text("本房已清理 · 前往发光出口继续", Vector2(640, 634), 14, Color("fff1c4"), HORIZONTAL_ALIGNMENT_CENTER, 650)
	elif defeated_count >= _room_quota() and not boss_defeated:
		_draw_text("季节首领 · %s 即将出现" % str(boss_data.get("name", "首领")), Vector2(640, 634), 13, Color("fff1c4"), HORIZONTAL_ALIGNMENT_CENTER, 420)


func _draw_selection() -> void:
	draw_rect(Rect2(Vector2.ZERO, ROOM_SIZE), Color("172520"))
	draw_texture_rect(room_textures[0], Rect2(Vector2.ZERO, ROOM_SIZE), false, Color(0.55, 0.66, 0.62, 1.0))
	draw_rect(Rect2(Vector2.ZERO, ROOM_SIZE), Color(0.035, 0.065, 0.065, 0.67))
	_draw_text("四季同行", Vector2(400, 75), 18, Color("c9d6ca"), HORIZONTAL_ALIGNMENT_CENTER, 480)
	_draw_text("四境远征", Vector2(240, 132), 38, Color("fff1d2"), HORIZONTAL_ALIGNMENT_CENTER, 800)
	_draw_text("选择你的行者", Vector2(390, 174), 17, Color("c7d1c7"), HORIZONTAL_ALIGNMENT_CENTER, 500)
	var card_width := 254.0
	var card_gap := 18.0
	var start_x := (ROOM_SIZE.x - (card_width * 4.0 + card_gap * 3.0)) * 0.5
	for index in range(4):
		var card := Rect2(start_x + index * (card_width + card_gap), 218.0, card_width, 344.0)
		var selected := index == selected_hero
		draw_rect(card, Color(0.035, 0.055, 0.055, 0.83) if not selected else Color(0.09, 0.12, 0.105, 0.96))
		draw_rect(card, ROOM_TINTS[index] if selected else Color(0.69, 0.73, 0.67, 0.28), false, 3.0 if selected else 1.0)
		var image_size := Vector2(152.0, 192.0)
		draw_texture_rect(hero_textures[index], Rect2(Vector2(card.position.x + 51.0, card.position.y + 21.0), image_size), false)
		_draw_text(HERO_NAMES[index], Vector2(card.position.x + 10.0, card.position.y + 250.0), 16, Color("fff1d2") if selected else Color("d7dfd6"), HORIZONTAL_ALIGNMENT_CENTER, card.size.x - 20.0)
		_draw_text(HERO_ROLES[index], Vector2(card.position.x + 10.0, card.position.y + 279.0), 11, ROOM_TINTS[index], HORIZONTAL_ALIGNMENT_CENTER, card.size.x - 20.0)
		if selected:
			_draw_text("当前选择", Vector2(card.position.x + 10.0, card.position.y + 315.0), 12, Color("fff0c5"), HORIZONTAL_ALIGNMENT_CENTER, card.size.x - 20.0)
	_draw_text("← → 选择 · 回车 / J / 点击 / 手柄 A 开始远征", Vector2(170, 612), 15, Color("fff0d4"), HORIZONTAL_ALIGNMENT_CENTER, 940)
	_draw_text("击败每个房间的指定数量敌人，即可继续前进。", Vector2(290, 649), 14, Color("c9d4ca"), HORIZONTAL_ALIGNMENT_CENTER, 700)
	_draw_text("F2 / 手柄返回键 打开设置", Vector2(420, 691), 13, Color("e1d9bc"), HORIZONTAL_ALIGNMENT_CENTER, 440)
	if profile_error.is_empty():
		var snapshot: Dictionary = profile.profile_snapshot()
		_draw_text("永久进度  %d 金币 · %d 符文 · %d★ · 恢复训练 %d" % [int(snapshot.get("coins", 0)), int(snapshot.get("runes", 0)), int((snapshot.get("stars", {}) as Dictionary).get(HERO_IDS[selected_hero], 0)), int(snapshot.get("recoveryTraining", 0))], Vector2(120, 190), 13, Color("fff1d2"), HORIZONTAL_ALIGNMENT_CENTER, 1040)
	else:
		_draw_text("档案错误：%s" % profile_error, Vector2(120, 190), 14, Color("ffb1a6"), HORIZONTAL_ALIGNMENT_CENTER, 1040)


func _draw_end_overlay(won: bool) -> void:
	draw_rect(Rect2(Vector2.ZERO, ROOM_SIZE), Color(0.015, 0.025, 0.03, 0.76))
	var title := "四季回应了你" if won else "远征暂告一段落"
	var subline := "四间房间全部清理 · %s" % _format_time(run_time) if won else "抵达第 %d 房 · 击败 %d 名敌人" % [room_index + 1, defeated_count]
	_draw_text(title, Vector2(190, 285), 36, Color("fff1d2"), HORIZONTAL_ALIGNMENT_CENTER, 900)
	_draw_text(subline, Vector2(190, 337), 17, Color("c9d6cc"), HORIZONTAL_ALIGNMENT_CENTER, 900)
	if bool(run_settlement.get("ok", false)):
		_draw_text("击败敌人 %d · 首领 %d · 港湾印记 +%d · 符文 +%d" % [run_kills, run_boss_kills, hub_material_awarded, int(run_settlement.get("runes_awarded", 0))], Vector2(190, 373), 16, Color("e2d9aa"), HORIZONTAL_ALIGNMENT_CENTER, 900)
	elif not profile_error.is_empty():
		_draw_text("档案保存失败：%s" % profile_error, Vector2(190, 373), 15, Color("ffb1a6"), HORIZONTAL_ALIGNMENT_CENTER, 900)
	_draw_text("按回车 / 手柄 A 返回港湾", Vector2(315, 411), 14, Color("ecd59f"), HORIZONTAL_ALIGNMENT_CENTER, 650)


func _draw_text(text_value: String, position: Vector2, size: int, color: Color, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	var draw_width := width if width > 0.0 else 1080.0
	draw_string(font, position, text_value, alignment, draw_width, size, color)


func _format_time(seconds: float) -> String:
	var whole := int(seconds)
	return "%02d:%02d" % [whole / 60, whole % 60]


func _draw_shadow_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(25):
		var angle := TAU * float(index) / 24.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)
