extends Node

const PANEL_SCENE := preload("res://ui/settings_panel.tscn")
const SETTINGS_PATH := "user://game_settings.cfg"

var _settings_file_existed := false
var _settings_file_backup := PackedByteArray()
var _failures := 0


func _ready() -> void:
	_backup_user_settings()
	for action: String in ["attack", "dodge", "interact"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	var attack_key := InputEventKey.new()
	attack_key.physical_keycode = KEY_J
	InputMap.action_add_event("attack", attack_key)
	var dodge_key := InputEventKey.new()
	dodge_key.physical_keycode = KEY_SPACE
	InputMap.action_add_event("dodge", dodge_key)
	var interact_key := InputEventKey.new()
	interact_key.physical_keycode = KEY_E
	InputMap.action_add_event("interact", interact_key)
	_run_smoke.call_deferred()


func _run_smoke() -> void:
	var layer := PANEL_SCENE.instantiate()
	add_child(layer)
	var panel: Control = layer.get_node("SettingsPanel")
	await get_tree().process_frame
	_expect(not panel.visible, "panel starts closed")
	panel.open_settings()
	_expect(panel.visible, "open_settings shows panel")
	var visible_copy := _collect_control_text(panel)
	_expect(visible_copy.contains("游戏设置"), "settings title is Simplified Chinese")
	_expect(visible_copy.contains("窗口模式") and visible_copy.contains("全屏"), "display options are Simplified Chinese")
	_expect(visible_copy.contains("自动检测") and visible_copy.contains("键盘") and visible_copy.contains("手柄"), "input hint choices are Simplified Chinese")
	_expect(visible_copy.contains("鼠标左键：普攻"), "attack help includes the left mouse button mapping")
	_expect(not visible_copy.contains("遊戲設定") and not visible_copy.contains("全螢幕"), "settings contain no Traditional Chinese UI copy")
	panel._on_music_changed(0.5)
	_expect(is_equal_approx(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index("Music")), 0.5), "music slider applies to Music bus")
	panel._on_sfx_changed(0.4)
	_expect(is_equal_approx(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index("SFX")), 0.4), "sound slider applies to SFX bus")
	panel._begin_rebind("dodge")
	var rebind_event := InputEventKey.new()
	rebind_event.pressed = true
	rebind_event.physical_keycode = KEY_F8
	panel._input(rebind_event)
	var found_key := false
	for event: InputEvent in InputMap.action_get_events("dodge"):
		if event is InputEventKey and event.physical_keycode == KEY_F8:
			found_key = true
	_expect(found_key, "keyboard rebind updates InputMap")
	panel.close_settings()
	_expect(not panel.visible, "close hides panel")
	panel.queue_free()
	_restore_user_settings()
	if _failures == 0:
		print("SETTINGS PANEL SMOKE: PASS")
		await get_tree().create_timer(1.0).timeout
		get_tree().quit(0)
	else:
		push_error("Settings panel smoke had %d failure(s)." % _failures)
		get_tree().quit(1)


func _backup_user_settings() -> void:
	_settings_file_existed = FileAccess.file_exists(SETTINGS_PATH)
	if _settings_file_existed:
		_settings_file_backup = FileAccess.get_file_as_bytes(SETTINGS_PATH)


func _restore_user_settings() -> void:
	var absolute_path := ProjectSettings.globalize_path(SETTINGS_PATH)
	if _settings_file_existed:
		var file := FileAccess.open(absolute_path, FileAccess.WRITE)
		if file != null:
			file.store_buffer(_settings_file_backup)
			file.close()
	else:
		DirAccess.remove_absolute(absolute_path)


func _expect(condition: bool, description: String) -> void:
	if not condition:
		_failures += 1
		push_error("Settings smoke failed: " + description)


func _collect_control_text(node: Node) -> String:
	var result := ""
	if node is Label:
		result += (node as Label).text + "\n"
	elif node is OptionButton:
		for index: int in range((node as OptionButton).item_count):
			result += (node as OptionButton).get_item_text(index) + "\n"
	elif node is Button:
		result += (node as Button).text + "\n"
	for child: Node in node.get_children():
		result += _collect_control_text(child)
	return result
