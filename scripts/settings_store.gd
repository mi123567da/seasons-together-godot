extends RefCounted
class_name SettingsStore

const SETTINGS_PATH := "user://game_settings.cfg"
const SECTION := "settings"
const DEFAULTS := {
	"music_volume": 0.35,
	"sfx_volume": 0.60,
	"fullscreen": false,
	"input_hint": "auto",
	"key_overrides": {},
}

var values: Dictionary = DEFAULTS.duplicate(true)


func _init() -> void:
	load_settings()
	apply_audio()
	apply_display()


func load_settings() -> Dictionary:
	values = DEFAULTS.duplicate(true)
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return values
	values["music_volume"] = clampf(float(config.get_value(SECTION, "music_volume", DEFAULTS.music_volume)), 0.0, 1.0)
	values["sfx_volume"] = clampf(float(config.get_value(SECTION, "sfx_volume", DEFAULTS.sfx_volume)), 0.0, 1.0)
	values["fullscreen"] = bool(config.get_value(SECTION, "fullscreen", DEFAULTS.fullscreen))
	var input_hint: String = str(config.get_value(SECTION, "input_hint", DEFAULTS.input_hint))
	values["input_hint"] = input_hint if input_hint in ["auto", "keyboard", "gamepad"] else "auto"
	var saved_overrides: Variant = config.get_value(SECTION, "key_overrides", {})
	if saved_overrides is Dictionary:
		var clean_overrides: Dictionary = {}
		for action: Variant in saved_overrides:
			var keycode := int(saved_overrides[action])
			if str(action) in ["attack", "dodge", "interact"] and keycode > KEY_NONE:
				clean_overrides[str(action)] = keycode
		values["key_overrides"] = clean_overrides
	return values


func set_setting(key: String, value: Variant) -> Error:
	if not DEFAULTS.has(key):
		return ERR_INVALID_PARAMETER
	values[key] = value
	return save_settings()


func set_key_override(action: String, physical_keycode: int) -> Error:
	if action not in ["attack", "dodge", "interact"] or physical_keycode <= KEY_NONE:
		return ERR_INVALID_PARAMETER
	var overrides: Dictionary = values.get("key_overrides", {}).duplicate()
	overrides[action] = physical_keycode
	values["key_overrides"] = overrides
	return save_settings()


func clear_key_overrides() -> Error:
	values["key_overrides"] = {}
	return save_settings()


func save_settings() -> Error:
	var config := ConfigFile.new()
	for key: String in DEFAULTS:
		config.set_value(SECTION, key, values.get(key, DEFAULTS[key]))
	return config.save(SETTINGS_PATH)


func apply_audio() -> void:
	_ensure_audio_bus("Music")
	_ensure_audio_bus("SFX")
	var music_bus := AudioServer.get_bus_index("Music")
	var sfx_bus := AudioServer.get_bus_index("SFX")
	if music_bus >= 0:
		AudioServer.set_bus_volume_linear(music_bus, float(values.music_volume))
	if sfx_bus >= 0:
		AudioServer.set_bus_volume_linear(sfx_bus, float(values.sfx_volume))


func apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if bool(values.fullscreen) else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)


func apply_key_overrides() -> void:
	var overrides: Dictionary = values.get("key_overrides", {})
	for action: Variant in overrides:
		if not InputMap.has_action(str(action)):
			continue
		var retained: Array[InputEvent] = []
		for input_event: InputEvent in InputMap.action_get_events(str(action)):
			if not input_event is InputEventKey:
				retained.append(input_event.duplicate())
		InputMap.action_erase_events(str(action))
		for input_event: InputEvent in retained:
			InputMap.action_add_event(str(action), input_event)
		var key_event := InputEventKey.new()
		key_event.physical_keycode = int(overrides[action]) as Key
		InputMap.action_add_event(str(action), key_event)


func _ensure_audio_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	var index := AudioServer.bus_count
	AudioServer.add_bus(index)
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, "Master")
