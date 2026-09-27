class_name HubController
extends Node2D

signal gender_chosen(gender: String, display_name: String)
signal appearance_changed(gender: String, display_name: String)
signal weapon_equipped(weapon_id: String)
signal expedition_requested(profile_payload: Dictionary)
signal profile_payload_changed(profile_payload: Dictionary)

const PLAYER_SCRIPT := preload("res://hub/hub_player.gd")
const PROFILE_ADAPTER := preload("res://hub/profile_payload_adapter.gd")
const WEAPON_UNLOCKS := preload("res://scripts/weapon_unlocks.gd")
const CONFIG_PATH := "res://hub/weapon_costs.json"
const PROFILE_PATH := "user://hub_profile.json"
const ROOM_RECT := Rect2(160, 136, 960, 520)
const INTERACTION_RADIUS := 104.0

const WEAPON_INFO := {
	"bow": {"name": "弓", "role": "远程", "color": Color("#8bc8df"), "shape": "bow"},
	"sword": {"name": "刀", "role": "近战", "color": Color("#edac74"), "shape": "sword"},
	"staff": {"name": "法杖", "role": "辅助", "color": Color("#a6d58f"), "shape": "staff"},
	"spirit_focus": {"name": "御灵器", "role": "召灵", "color": Color("#bdadf0"), "shape": "focus"},
}

var _config: Dictionary = {}
var _profile: Dictionary = {}
var profile_path := PROFILE_PATH
var _player: CharacterBody2D
var _woman_texture: Texture2D
var _man_texture: Texture2D
var _ui_layer: CanvasLayer
var _ui_root: Control
var _modal: PanelContainer
var _modal_body: VBoxContainer
var _status_label: Label
var _profile_label: Label
var _proximity_label: Label
var _name_input: LineEdit
var _appearance_change_mode := false
var _rack_point := Vector2(350, 285)
var _station_point := Vector2(645, 285)
var _door_point := Vector2(965, 285)


func _ready() -> void:
	_config = _read_cost_config()
	_woman_texture = _load_avatar_texture("res://hub/assets/avatar_woman.png")
	_man_texture = _load_avatar_texture("res://hub/assets/avatar_man.png")
	_profile = _load_profile()
	_setup_input_map()
	_build_room()
	_build_player()
	_build_ui()
	_refresh_status()
	if str(_profile["gender"]).is_empty():
		_open_gender_choice()


func _process(_delta: float) -> void:
	_update_nearby_hint()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("hub_interact") and not event.is_echo():
		interact_nearest()


func _draw() -> void:
	# Room shell and layered floor are drawn in-world so the player can walk
	# behind furniture without introducing a costly tilemap or animation loop.
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), Color("#101a20"), true)
	draw_rect(ROOM_RECT.grow(12), Color("#35464a"), true)
	draw_rect(ROOM_RECT, Color("#7e897d"), true)
	for row in range(13):
		for column in range(24):
			var tile_color := Color("#839083") if (row + column) % 2 == 0 else Color("#7b887c")
			draw_rect(Rect2(ROOM_RECT.position + Vector2(column * 40, row * 40), Vector2(39, 39)), tile_color, true)
	# Soft central runner and inlaid gold border.
	draw_rect(Rect2(430, 365, 420, 240), Color("#505c5b"), true)
	draw_rect(Rect2(438, 373, 404, 224), Color("#675e50"), true)
	draw_rect(Rect2(449, 384, 382, 202), Color("#465554"), true)
	for point in [Vector2(430, 365), Vector2(850, 365), Vector2(430, 605), Vector2(850, 605)]:
		draw_circle(point, 7.0, Color("#d5ae72"))
	# Left wall weapon rack.
	draw_rect(Rect2(275, 203, 150, 96), Color("#3b3430"), true)
	draw_rect(Rect2(284, 211, 132, 79), Color("#604d3c"), true)
	draw_line(Vector2(293, 252), Vector2(407, 252), Color("#d0ae77"), 5.0, true)
	_draw_weapon_mark(Vector2(309, 247), "bow", 20.0)
	_draw_weapon_mark(Vector2(337, 247), "sword", 20.0)
	_draw_weapon_mark(Vector2(366, 247), "staff", 20.0)
	_draw_weapon_mark(Vector2(394, 247), "spirit_focus", 20.0)
	# Center upgrade plinth.
	draw_circle(_station_point, 57.0, Color("#454344"))
	draw_circle(_station_point, 49.0, Color("#b29361"))
	draw_circle(_station_point, 42.0, Color("#514b42"))
	draw_circle(_station_point, 31.0, Color("#86734f"))
	draw_circle(_station_point, 20.0, Color("#bfd0aa"))
	draw_circle(_station_point, 9.0, Color("#ecdfac"))
	for angle_index in range(8):
		var angle := TAU * float(angle_index) / 8.0
		draw_line(_station_point + Vector2.from_angle(angle) * 35.0, _station_point + Vector2.from_angle(angle) * 45.0, Color("#e4d6a7"), 2.0, true)
	# Expedition arch, rune path and door plane.
	draw_rect(Rect2(908, 207, 114, 112), Color("#3b3734"), true)
	draw_rect(Rect2(921, 218, 88, 101), Color("#d0a96c"), true)
	draw_rect(Rect2(930, 227, 70, 92), Color("#282d34"), true)
	draw_rect(Rect2(937, 234, 56, 85), Color("#35434a"), true)
	draw_arc(_door_point + Vector2(0, -15), 45.0, PI, TAU, 32, Color("#d7be88"), 5.0, true)
	draw_circle(_door_point + Vector2(0, 24), 6.0, Color("#f0d492"))
	draw_line(Vector2(915, 346), Vector2(1015, 346), Color("#c3aa79"), 2.0, true)
	for x in range(0, 5):
		draw_circle(Vector2(925 + x * 20, 346), 3.5, Color("#d6c392"))
	# Bench and a small plant make the safe room readable as a lived-in space.
	draw_rect(Rect2(727, 213, 104, 36), Color("#493a31"), true)
	draw_rect(Rect2(735, 217, 88, 19), Color("#a77d54"), true)
	for x in [743.0, 814.0]:
		draw_line(Vector2(x, 237), Vector2(x, 263), Color("#44382f"), 5.0, true)
	draw_circle(Vector2(520, 254), 18.0, Color("#425b4d"))
	draw_circle(Vector2(512, 248), 10.0, Color("#6e8a64"))
	draw_circle(Vector2(529, 246), 10.0, Color("#79906b"))
	draw_rect(Rect2(509, 260, 23, 19), Color("#70533d"), true)
	# Wall seams, warm lanterns, and a small raised sill around the room.
	draw_rect(Rect2(160, 136, 960, 12), Color("#ad9a7b"), true)
	draw_rect(Rect2(160, 644, 960, 12), Color("#665848"), true)
	for x in [190.0, 1090.0]:
		draw_circle(Vector2(x, 163), 10.0, Color("#e6bd75"))
		draw_circle(Vector2(x, 163), 18.0, Color("#e6bd75", 0.14))


func get_profile_payload() -> Dictionary:
	return _profile.duplicate(true)


func set_hub_hud_visible(visible: bool) -> void:
	if _ui_layer != null:
		_ui_layer.visible = visible


func set_profile_payload(payload: Dictionary) -> void:
	_profile = PROFILE_ADAPTER.normalize_payload(payload, int(_config["starting_marks"]))
	_sync_avatar()
	_save_profile()
	_refresh_status()
	profile_payload_changed.emit(get_profile_payload())
	if str(_profile["gender"]).is_empty():
		_open_gender_choice()
	elif _modal != null and _modal.visible:
		_close_modal()


func apply_parent_payload(envelope: Dictionary) -> void:
	## Optional parent integration. Accepts either a hub payload or the namespaced
	## {"progression": ..., "hub": ...} envelope made by the adapter.
	var payload: Dictionary = envelope.get("hub", envelope)
	if typeof(payload) == TYPE_DICTIONARY:
		set_profile_payload(payload)


func interact_nearest() -> bool:
	if _modal.visible:
		return false
	if str(_profile["gender"]).is_empty():
		_open_gender_choice()
		return true
	var nearest := _nearest_interactable()
	if nearest.is_empty():
		_set_status("靠近武器架、强化台或出征之门后再互动。")
		return false
	return interact_object(str(nearest["id"]))


func interact_object(object_id: String) -> bool:
	if _modal.visible or str(_profile["gender"]).is_empty():
		return false
	var point := _point_for_object(object_id)
	if point == Vector2(-1, -1) or _player.global_position.distance_to(point) > INTERACTION_RADIUS:
		return false
	match object_id:
		"weapon_rack":
			_open_weapon_rack()
		"upgrade_station":
			_open_upgrade_station()
		"expedition_door":
			_open_expedition_prompt()
		_:
			return false
	return true


func unlock_weapon(weapon_id: String) -> bool:
	if not WEAPON_INFO.has(weapon_id) or (_profile["unlocked_weapons"] as Array).has(weapon_id):
		return false
	var result: Dictionary = WEAPON_UNLOCKS.try_unlock(_unlock_state(), weapon_id, _config["unlock_cost_overrides"])
	if not result["ok"]:
		if result["code"] == "insufficient_material":
			_set_status("港湾印记不足，解锁%s还需%d枚。" % [WEAPON_INFO[weapon_id]["name"], int(result["cost"])])
		else:
			_set_status("请按顺序解锁：弓、刀、法杖、御灵器。")
		return false
	var state: Dictionary = result["state"]
	_profile["hub_marks"] = int(state["material"])
	_profile["unlocked_weapons"] = state["unlocked_weapon_ids"]
	(_profile["weapon_levels"] as Dictionary)[weapon_id] = 1
	_save_and_publish()
	return true


func equip_weapon(weapon_id: String) -> bool:
	if not WEAPON_INFO.has(weapon_id) or not (_profile["unlocked_weapons"] as Array).has(weapon_id):
		return false
	var result: Dictionary = WEAPON_UNLOCKS.select_weapon(_unlock_state(), weapon_id)
	if not result["ok"]:
		return false
	_profile["equipped_weapon"] = str(result["state"]["selected_weapon_id"])
	_sync_avatar()
	_save_and_publish()
	weapon_equipped.emit(weapon_id)
	return true


func upgrade_equipped_weapon() -> bool:
	var weapon_id := str(_profile["equipped_weapon"])
	var level := int((_profile["weapon_levels"] as Dictionary).get(weapon_id, 1))
	var costs: Array = _config["upgrade_costs"]
	if level >= int(_config["max_weapon_level"]) or level - 1 >= costs.size():
		_set_status("%s已达到当前最高等级。" % WEAPON_INFO[weapon_id]["name"])
		return false
	var cost := int(costs[level - 1])
	if int(_profile["hub_marks"]) < cost:
		_set_status("强化需要%d枚港湾印记。" % cost)
		return false
	_profile["hub_marks"] = int(_profile["hub_marks"]) - cost
	(_profile["weapon_levels"] as Dictionary)[weapon_id] = level + 1
	_save_and_publish()
	return true


func request_expedition() -> void:
	if str(_profile["gender"]).is_empty():
		_open_gender_choice()
		return
	_modal.hide()
	_player.movement_enabled = true
	_set_status("已请求出发。")
	expedition_requested.emit(get_profile_payload())


func choose_gender(gender: String, display_name: String) -> bool:
	if not str(_profile["gender"]).is_empty() or not PROFILE_ADAPTER.GENDERS.has(gender):
		return false
	var clean_name := display_name.strip_edges()
	if clean_name.is_empty():
		_set_status("请先输入角色名字。")
		return false
	_store_appearance(gender, clean_name)
	gender_chosen.emit(gender, str(_profile["display_name"]))
	return true


func change_appearance(gender: String, display_name: String) -> bool:
	if str(_profile["gender"]).is_empty() or not PROFILE_ADAPTER.GENDERS.has(gender):
		return false
	var clean_name := display_name.strip_edges()
	if clean_name.is_empty():
		_set_status("请先输入角色名字。")
		return false
	if gender == str(_profile["gender"]) and clean_name == str(_profile["display_name"]):
		_close_modal()
		return true
	_store_appearance(gender, clean_name)
	appearance_changed.emit(gender, str(_profile["display_name"]))
	return true


func _store_appearance(gender: String, display_name: String) -> void:
	_profile["gender"] = gender
	_profile["display_name"] = display_name.substr(0, 24)
	_sync_avatar()
	_save_and_publish()
	_modal.hide()
	_player.movement_enabled = true


func _unlock_state() -> Dictionary:
	return {
		"unlocked_weapon_ids": (_profile["unlocked_weapons"] as Array).duplicate(),
		"selected_weapon_id": str(_profile["equipped_weapon"]),
		"material": int(_profile["hub_marks"]),
	}


func _setup_input_map() -> void:
	for action in ["hub_left", "hub_right", "hub_up", "hub_down", "hub_interact"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
	_add_key_action("hub_left", KEY_A)
	_add_key_action("hub_left", KEY_LEFT)
	_add_key_action("hub_right", KEY_D)
	_add_key_action("hub_right", KEY_RIGHT)
	_add_key_action("hub_up", KEY_W)
	_add_key_action("hub_up", KEY_UP)
	_add_key_action("hub_down", KEY_S)
	_add_key_action("hub_down", KEY_DOWN)
	_add_axis_action("hub_left", JOY_AXIS_LEFT_X, -1.0)
	_add_axis_action("hub_right", JOY_AXIS_LEFT_X, 1.0)
	_add_axis_action("hub_up", JOY_AXIS_LEFT_Y, -1.0)
	_add_axis_action("hub_down", JOY_AXIS_LEFT_Y, 1.0)
	var key_event := InputEventKey.new()
	key_event.keycode = KEY_E
	_add_event_if_missing("hub_interact", key_event)
	var pad_event := InputEventJoypadButton.new()
	pad_event.button_index = JOY_BUTTON_A
	_add_event_if_missing("hub_interact", pad_event)


func _add_key_action(action: String, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventKey.new()
	event.keycode = keycode
	_add_event_if_missing(action, event)


func _add_axis_action(action: String, axis: JoyAxis, axis_value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = axis_value
	_add_event_if_missing(action, event)


func _add_event_if_missing(action: String, event: InputEvent) -> void:
	for existing in InputMap.action_get_events(action):
		if existing.is_match(event):
			return
	InputMap.action_add_event(action, event)


func _build_room() -> void:
	_add_wall(Vector2(640, 130), Vector2(990, 36))
	_add_wall(Vector2(640, 663), Vector2(990, 34))
	_add_wall(Vector2(151, 396), Vector2(36, 554))
	_add_wall(Vector2(1129, 396), Vector2(36, 554))
	_add_world_label("武器架", Vector2(281, 300), 138)
	_add_world_label("强化台", Vector2(560, 352), 170)
	_add_world_label("出征之门", Vector2(911, 344), 110)
	_add_world_label("稍作休整，再踏上自己的旅程。", Vector2(421, 625), 440, 15, Color("#d4c7a6"))


func _add_wall(center: Vector2, size: Vector2) -> void:
	var wall := StaticBody2D.new()
	wall.position = center
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	shape_node.shape = shape
	wall.add_child(shape_node)
	add_child(wall)


func _add_world_label(text_value: String, point: Vector2, width: float, font_size: int = 13, color: Color = Color("#f1e5ca")) -> void:
	var label := Label.new()
	label.text = text_value
	label.position = point
	label.custom_minimum_size = Vector2(width, 22)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	add_child(label)


func _build_player() -> void:
	_player = CharacterBody2D.new()
	_player.name = "Protagonist"
	_player.set_script(PLAYER_SCRIPT)
	_player.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_player.position = Vector2(640, 474)
	_player.movement_bounds = Rect2(205, 205, 870, 380)
	var collider := CollisionShape2D.new()
	var capsule := CircleShape2D.new()
	capsule.radius = 18.0
	collider.shape = capsule
	_player.add_child(collider)
	add_child(_player)
	_sync_avatar()


func _sync_avatar() -> void:
	if _player == null or _woman_texture == null or _man_texture == null:
		return
	var gender := str(_profile.get("gender", "male"))
	_player.configure_avatar(gender, _woman_texture, _man_texture, str(_profile["equipped_weapon"]))


func _load_avatar_texture(resource_path: String) -> Texture2D:
	var avatar := load(resource_path) as Texture2D
	assert(avatar != null, "Unable to load approved avatar placeholder: %s" % resource_path)
	return avatar


func _build_ui() -> void:
	_ui_layer = CanvasLayer.new()
	add_child(_ui_layer)
	_ui_root = Control.new()
	_ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_layer.add_child(_ui_root)
	var title := Label.new()
	title.text = "四季同行   /   安全港湾"
	title.position = Vector2(28, 22)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#f1e7d2"))
	_ui_root.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "征途之间  ·  从容整备"
	subtitle.position = Vector2(30, 52)
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color("#bdad8c"))
	_ui_root.add_child(subtitle)
	var profile_card := _make_panel(Vector2(900, 22), Vector2(350, 84))
	_ui_root.add_child(profile_card)
	_profile_label = Label.new()
	_profile_label.position = Vector2(16, 12)
	_profile_label.size = Vector2(318, 61)
	_profile_label.add_theme_font_size_override("font_size", 15)
	_profile_label.add_theme_color_override("font_color", Color("#efe4cc"))
	profile_card.add_child(_wrap_in_margin(_profile_label, 0))
	var appearance_button := Button.new()
	appearance_button.text = "更改外观 / 名字"
	appearance_button.position = Vector2(1012, 111)
	appearance_button.size = Vector2(238, 30)
	appearance_button.add_theme_font_size_override("font_size", 12)
	appearance_button.focus_mode = Control.FOCUS_ALL
	appearance_button.pressed.connect(_open_appearance_choice)
	_ui_root.add_child(appearance_button)
	var hint_panel := _make_panel(Vector2(255, 668), Vector2(770, 34))
	_ui_root.add_child(hint_panel)
	_proximity_label = Label.new()
	_proximity_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_proximity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_proximity_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_proximity_label.add_theme_font_size_override("font_size", 14)
	_proximity_label.add_theme_color_override("font_color", Color("#e8dcc4"))
	hint_panel.add_child(_wrap_in_margin(_proximity_label, 8))
	_status_label = Label.new()
	_status_label.position = Vector2(28, 621)
	_status_label.size = Vector2(400, 24)
	_status_label.add_theme_font_size_override("font_size", 13)
	_status_label.add_theme_color_override("font_color", Color("#c9bc9f"))
	_ui_root.add_child(_status_label)
	_modal = _make_panel(Vector2(350, 166), Vector2(580, 394))
	_modal.visible = false
	_ui_root.add_child(_modal)
	_modal_body = VBoxContainer.new()
	_modal_body.add_theme_constant_override("separation", 12)
	_modal.add_child(_wrap_in_margin(_modal_body, 24))


func _wrap_in_margin(child: Control, margin: int) -> MarginContainer:
	var wrapper := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		wrapper.add_theme_constant_override("margin_%s" % side, margin)
	wrapper.add_child(child)
	return wrapper


func _make_panel(point: Vector2, size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = point
	panel.size = size
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#202a2d", 0.96)
	style.border_color = Color("#9a805b")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _open_gender_choice() -> void:
	_clear_modal()
	_add_modal_title("创建你的旅者")
	_add_modal_text("选择角色外观并取个名字即可进入港湾。性别只影响外观与称呼；武器和技能可另行选择。")
	_appearance_change_mode = false
	_name_input = LineEdit.new()
	_name_input.placeholder_text = "角色名字"
	_name_input.max_length = 24
	_name_input.text = str(_profile.get("display_name", ""))
	_modal_body.add_child(_name_input)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_modal_body.add_child(row)
	_add_button(row, "女性外观", func(): choose_gender("female", _name_input.text))
	_add_button(row, "男性外观", func(): choose_gender("male", _name_input.text))
	_add_modal_text("键盘 / 手柄：W/A/S/D、方向键或左摇杆移动；按 E 或手柄 A 互动。")
	_show_modal()
	_name_input.grab_focus()


func _open_appearance_choice() -> void:
	_clear_modal()
	_add_modal_title("更改外观")
	_add_modal_text("仅更换角色外观与称呼，不影响已装备武器、解锁状态和等级。")
	_appearance_change_mode = true
	_name_input = LineEdit.new()
	_name_input.placeholder_text = "角色名字"
	_name_input.max_length = 24
	_name_input.text = str(_profile["display_name"])
	_modal_body.add_child(_name_input)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_modal_body.add_child(row)
	_add_button(row, "使用女性外观", func(): change_appearance("female", _name_input.text))
	_add_button(row, "使用男性外观", func(): change_appearance("male", _name_input.text))
	_add_button(_modal_body, "取消", _close_modal)
	_show_modal()
	_name_input.grab_focus()


func _open_weapon_rack() -> void:
	_clear_modal()
	_add_modal_title("武器架")
	_add_modal_text("武器决定战斗方式；性别只影响角色外观和称呼。")
	for weapon_id in PROFILE_ADAPTER.WEAPON_IDS:
		var info: Dictionary = WEAPON_INFO[weapon_id]
		var unlocked := (_profile["unlocked_weapons"] as Array).has(weapon_id)
		var equipped := str(_profile["equipped_weapon"]) == weapon_id
		var cost := int((_config["unlock_costs"] as Dictionary).get(weapon_id, 0))
		var label := "%s  ·  %s" % [info["name"], str(info["role"])]
		if equipped:
			label += "  ·  已装备"
		elif unlocked:
			label += "  ·  装备"
		else:
			label += "  ·  未解锁  ·  %d 枚港湾印记" % cost
		_add_button(_modal_body, label, _on_weapon_row.bind(weapon_id, unlocked))
	_add_button(_modal_body, "关闭", _close_modal)
	_show_modal()


func _on_weapon_row(weapon_id: String, was_unlocked: bool) -> void:
	if was_unlocked:
		if equip_weapon(weapon_id):
			_open_weapon_rack()
	else:
		if unlock_weapon(weapon_id):
			_set_status("%s已解锁，可在武器架装备。" % WEAPON_INFO[weapon_id]["name"])
			_open_weapon_rack()
		else:
			_open_weapon_rack()


func _open_upgrade_station() -> void:
	_clear_modal()
	var weapon_id := str(_profile["equipped_weapon"])
	var level := int((_profile["weapon_levels"] as Dictionary).get(weapon_id, 1))
	var costs: Array = _config["upgrade_costs"]
	_add_modal_title("武器强化")
	_add_modal_text("%s · 等级 %d / %d" % [WEAPON_INFO[weapon_id]["name"], level, int(_config["max_weapon_level"])])
	if level < int(_config["max_weapon_level"]):
		var cost := int(costs[level - 1])
		_add_modal_text("下次强化需要：%d 枚港湾印记。当前持有：%d。" % [cost, int(_profile["hub_marks"])])
		_add_button(_modal_body, "强化已装备武器", func():
			if upgrade_equipped_weapon():
				_open_upgrade_station()
		)
	else:
		_add_modal_text("已达到当前最高等级。")
	_add_button(_modal_body, "关闭", _close_modal)
	_show_modal()


func _open_expedition_prompt() -> void:
	_clear_modal()
	_add_modal_title("准备出发？")
	_add_modal_text("当前装备：%s · 等级 %d\n整备资料将交给战斗流程。" % [WEAPON_INFO[str(_profile["equipped_weapon"])]["name"], int((_profile["weapon_levels"] as Dictionary).get(str(_profile["equipped_weapon"]), 1))])
	_add_button(_modal_body, "开始远征", request_expedition)
	_add_button(_modal_body, "留在港湾", _close_modal)
	_show_modal()


func _add_modal_title(text_value: String) -> void:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color("#f2e7d2"))
	_modal_body.add_child(label)


func _add_modal_text(text_value: String) -> void:
	var label := Label.new()
	label.text = text_value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color("#d0c6b1"))
	_modal_body.add_child(label)


func _add_button(parent: Control, text_value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(0, 38)
	button.add_theme_font_size_override("font_size", 14)
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _show_modal() -> void:
	_modal.show()
	_player.movement_enabled = false
	var first_button := _first_button(_modal_body)
	if first_button != null:
		first_button.grab_focus()


func _first_button(node: Node) -> Button:
	for child in node.get_children():
		if child is Button:
			return child
		var nested := _first_button(child)
		if nested != null:
			return nested
	return null


func _clear_modal() -> void:
	for child in _modal_body.get_children():
		_modal_body.remove_child(child)
		child.free()
	_modal.hide()


func _close_modal() -> void:
	_modal.hide()
	_player.movement_enabled = true


func _update_nearby_hint() -> void:
	if _modal.visible or _player == null:
		return
	if str(_profile["gender"]).is_empty():
		_proximity_label.text = "先选择角色外观和名字，再进入港湾。"
		return
	var nearest := _nearest_interactable()
	if nearest.is_empty():
		_proximity_label.text = "W/A/S/D、方向键或左摇杆移动   ·   E / 手柄 A 互动"
		return
	_proximity_label.text = "E / 手柄 A 互动   ·   %s" % nearest["label"]


func _nearest_interactable() -> Dictionary:
	var candidates := [
		{"id": "weapon_rack", "label": "武器架：解锁或更换武器", "point": _rack_point},
		{"id": "upgrade_station", "label": "强化台：强化已装备武器", "point": _station_point},
		{"id": "expedition_door", "label": "出征之门：进入战斗", "point": _door_point},
	]
	var best: Dictionary = {}
	var best_distance := INTERACTION_RADIUS
	for candidate in candidates:
		var distance := _player.global_position.distance_to(candidate["point"])
		if distance <= best_distance:
			best = candidate
			best_distance = distance
	return best


func _point_for_object(object_id: String) -> Vector2:
	match object_id:
		"weapon_rack": return _rack_point
		"upgrade_station": return _station_point
		"expedition_door": return _door_point
		_: return Vector2(-1, -1)


func _draw_weapon_mark(center: Vector2, weapon_id: String, size: float) -> void:
	var color: Color = WEAPON_INFO[weapon_id]["color"]
	match weapon_id:
		"bow":
			draw_arc(center, size * 0.7, -PI * 0.42, PI * 0.42, 16, color, 3.0, true)
			draw_line(center + Vector2(0, -size * 0.64), center + Vector2(0, size * 0.64), color, 1.5, true)
		"sword":
			draw_line(center + Vector2(0, -size), center + Vector2(0, size * 0.45), color, 4.0, true)
			draw_line(center + Vector2(-7, size * 0.35), center + Vector2(7, size * 0.35), color, 3.0, true)
			draw_line(center, center + Vector2(0, size), color, 3.0, true)
		"staff":
			draw_line(center + Vector2(0, size), center + Vector2(0, -size * 0.65), color, 3.0, true)
			draw_circle(center + Vector2(0, -size * 0.75), 5.0, color)
		"spirit_focus":
			draw_circle(center, 7.0, color)
			draw_arc(center, size * 0.65, 0, TAU, 20, color, 2.0, true)


func _read_cost_config() -> Dictionary:
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	assert(file != null, "Missing hub/weapon_costs.json")
	var json := JSON.new()
	assert(json.parse(file.get_as_text()) == OK, "weapon_costs.json must be valid JSON")
	var raw: Dictionary = json.data
	var defaults := {"currency_id": "hub_marks", "starting_marks": 60, "unlock_cost_overrides": {}, "upgrade_costs": [], "max_weapon_level": 1}
	for key in defaults:
		assert(raw.has(key), "weapon_costs.json is missing %s" % key)
	var normalized_overrides: Dictionary = {}
	for weapon_id in WEAPON_UNLOCKS.UNLOCK_ORDER:
		var value: Variant = (raw["unlock_cost_overrides"] as Dictionary).get(weapon_id, null)
		if typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) >= 0.0 and floor(float(value)) == float(value):
			normalized_overrides[weapon_id] = int(value)
	raw["unlock_cost_overrides"] = normalized_overrides
	raw["unlock_costs"] = WEAPON_UNLOCKS.unlock_costs(raw["unlock_cost_overrides"])
	return raw


func _load_profile() -> Dictionary:
	if not FileAccess.file_exists(profile_path):
		return PROFILE_ADAPTER.default_payload(int(_config["starting_marks"]))
	var file := FileAccess.open(profile_path, FileAccess.READ)
	if file == null:
		return PROFILE_ADAPTER.default_payload(int(_config["starting_marks"]))
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return PROFILE_ADAPTER.default_payload(int(_config["starting_marks"]))
	return PROFILE_ADAPTER.normalize_payload(json.data, int(_config["starting_marks"]))


func _save_profile() -> void:
	var destination := ProjectSettings.globalize_path(profile_path)
	var temp_path := destination + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		_set_status("整备资料保存失败，已保留上一次记录。")
		return
	file.store_string(JSON.stringify(_profile, "\t"))
	file.flush()
	file.close()
	var error := DirAccess.rename_absolute(ProjectSettings.globalize_path(profile_path + ".tmp"), destination)
	if error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(profile_path + ".tmp"))
		_set_status("整备资料更新失败（错误码 %d）。" % error)


func _save_and_publish() -> void:
	_save_profile()
	_refresh_status()
	profile_payload_changed.emit(get_profile_payload())


func _refresh_status() -> void:
	if _profile_label != null:
		var name := str(_profile["display_name"])
		if name.is_empty():
			name = "尚未选择旅者"
		var gender := str(_profile["gender"])
		var address := ""
		if gender == "female":
			address = " · 女"
		elif gender == "male":
			address = " · 男"
		var weapon_id := str(_profile["equipped_weapon"])
		var weapon_name: String = WEAPON_INFO[weapon_id]["name"]
		var level := int((_profile["weapon_levels"] as Dictionary).get(weapon_id, 1))
		_profile_label.text = "%s%s\n%s  ·  等级 %d      %d 枚港湾印记" % [name, address, weapon_name, level, int(_profile["hub_marks"])]
	if _status_label != null and _status_label.text.is_empty():
		_set_status("在这里安心整备，准备下一段旅程。")


func _set_status(message: String) -> void:
	if _status_label != null:
		_status_label.text = message
