extends Control

signal settings_closed

const STORE_SCRIPT := preload("res://scripts/settings_store.gd")
const ACTIONS := {
	"attack": "普攻",
	"dodge": "闪避",
	"interact": "互动",
}

var _store
var _music_slider: HSlider
var _sfx_slider: HSlider
var _music_value: Label
var _sfx_value: Label
var _fullscreen_toggle: CheckButton
var _hint_option: OptionButton
var _controller_status: Label
var _binding_buttons: Dictionary = {}
var _saved_key_events: Dictionary = {}
var _listening_action := ""
var _message_label: Label


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_store = STORE_SCRIPT.new()
	_capture_default_keys()
	_store.apply_key_overrides()
	_build_interface()
	_sync_controls()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


func open_settings() -> void:
	_listening_action = ""
	visible = true
	_sync_controls()
	_focus_first_control()


func close_settings() -> void:
	if not visible:
		return
	_listening_action = ""
	visible = false
	settings_closed.emit()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _listening_action.is_empty():
		if event.is_action_pressed("ui_cancel"):
			close_settings()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_set_message("已取消按键录入。")
			_end_rebind()
			get_viewport().set_input_as_handled()
			return
		if event.ctrl_pressed or event.alt_pressed or event.meta_pressed:
			return
		var keycode := int(event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode)
		if keycode <= KEY_NONE:
			return
		if _key_is_in_use(keycode, _listening_action):
			_set_message("这个按键已分配给其他操作，请换一个。")
			return
		_set_action_key(_listening_action, keycode)
		_store.set_key_override(_listening_action, keycode)
		_set_message("按键已保存。")
		_end_rebind()
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed:
		_set_message("目前只支持重设键盘按键；手柄按键保持游戏默认设置。")
		get_viewport().set_input_as_handled()


func _build_interface() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.025, 0.03, 0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640.0, 0.0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.add_theme_stylebox_override("panel", _style(Color("f5f1e7"), Color("d3c7ad"), 2, 18))
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	margin.add_child(layout)

	var heading := HBoxContainer.new()
	layout.add_child(heading)
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title_box)
	var eyebrow := Label.new()
	eyebrow.text = "旅途偏好"
	eyebrow.add_theme_color_override("font_color", Color("74826d"))
	eyebrow.add_theme_font_size_override("font_size", 13)
	title_box.add_child(eyebrow)
	var title := Label.new()
	title.text = "游戏设置"
	title.add_theme_color_override("font_color", Color("283b3b"))
	title.add_theme_font_size_override("font_size", 28)
	title_box.add_child(title)
	var close_button := Button.new()
	close_button.text = "关闭  Esc"
	close_button.custom_minimum_size = Vector2(104.0, 42.0)
	close_button.pressed.connect(close_settings)
	heading.add_child(close_button)
	_add_divider(layout)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0.0, 390.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	scroll.add_child(content)

	_add_section_title(content, "声音")
	var audio_card := _add_card(content)
	var audio_layout := VBoxContainer.new()
	audio_layout.add_theme_constant_override("separation", 12)
	audio_card.get_meta("content").add_child(audio_layout)
	var music_row := _make_slider_row("背景音乐", _store.values.music_volume)
	_music_slider = music_row.slider
	_music_value = music_row.value
	audio_layout.add_child(music_row.container)
	var sfx_row := _make_slider_row("战斗音效", _store.values.sfx_volume)
	_sfx_slider = sfx_row.slider
	_sfx_value = sfx_row.value
	audio_layout.add_child(sfx_row.container)
	_music_slider.value_changed.connect(_on_music_changed)
	_sfx_slider.value_changed.connect(_on_sfx_changed)

	_add_section_title(content, "画面")
	var display_card := _add_card(content)
	var display_row := HBoxContainer.new()
	display_card.get_meta("content").add_child(display_row)
	var display_description := _body_label("窗口模式")
	display_description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	display_row.add_child(display_description)
	_fullscreen_toggle = CheckButton.new()
	_fullscreen_toggle.text = "全屏"
	_fullscreen_toggle.toggled.connect(_on_fullscreen_changed)
	display_row.add_child(_fullscreen_toggle)

	_add_section_title(content, "操作")
	var input_card := _add_card(content)
	var input_layout := VBoxContainer.new()
	input_layout.add_theme_constant_override("separation", 10)
	input_card.get_meta("content").add_child(input_layout)
	var hint_row := HBoxContainer.new()
	input_layout.add_child(hint_row)
	var hint_label := _body_label("按键提示")
	hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint_row.add_child(hint_label)
	_hint_option = OptionButton.new()
	_hint_option.add_item("自动检测", 0)
	_hint_option.add_item("键盘", 1)
	_hint_option.add_item("手柄", 2)
	_hint_option.item_selected.connect(_on_hint_mode_changed)
	hint_row.add_child(_hint_option)
	_controller_status = _body_label("")
	_controller_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	input_layout.add_child(_controller_status)
	_add_divider(input_layout)
	for action: String in ACTIONS:
		var binding_row := HBoxContainer.new()
		input_layout.add_child(binding_row)
		var action_label := _body_label(ACTIONS[action])
		action_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		binding_row.add_child(action_label)
		var bind_button := Button.new()
		bind_button.custom_minimum_size = Vector2(155.0, 38.0)
		bind_button.pressed.connect(_begin_rebind.bind(action))
		binding_row.add_child(bind_button)
		_binding_buttons[action] = bind_button
	var binding_actions := HBoxContainer.new()
	input_layout.add_child(binding_actions)
	var reset_button := Button.new()
	reset_button.text = "恢复默认按键"
	reset_button.pressed.connect(_reset_keybindings)
	binding_actions.add_child(reset_button)
	_message_label = _body_label("点击操作右侧的按钮，再按下要绑定的按键。")
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	input_layout.add_child(_message_label)
	var help := _body_label("键鼠：J／鼠标左键：普攻 · Space：闪避 · E：互动\n手柄：左摇杆／十字键移动 · A：普攻 · B：闪避 · X：互动")
	help.add_theme_font_size_override("font_size", 13)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	input_layout.add_child(help)

	var footer := _body_label("设置会自动保存在本地。")
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_color_override("font_color", Color("74826d"))
	layout.add_child(footer)


func _make_slider_row(caption: String, initial_value: float) -> Dictionary:
	var row := HBoxContainer.new()
	var label := _body_label(caption)
	label.custom_minimum_size = Vector2(96.0, 0.0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = initial_value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(190.0, 30.0)
	row.add_child(slider)
	var value := _body_label("%d%%" % roundi(initial_value * 100.0))
	value.custom_minimum_size = Vector2(45.0, 0.0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	return {"container": row, "slider": slider, "value": value}


func _add_card(parent: Control) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _style(Color("fffdf7"), Color("e1d7c4"), 1, 12))
	var padding := MarginContainer.new()
	padding.add_theme_constant_override("margin_left", 14)
	padding.add_theme_constant_override("margin_right", 14)
	padding.add_theme_constant_override("margin_top", 12)
	padding.add_theme_constant_override("margin_bottom", 12)
	card.add_child(padding)
	var slot := VBoxContainer.new()
	padding.add_child(slot)
	parent.add_child(card)
	# Return a wrapper that can accept controls while preserving card padding.
	card.set_meta("content", slot)
	return card


func _add_section_title(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color("425d52"))
	label.add_theme_font_size_override("font_size", 17)
	parent.add_child(label)


func _add_divider(parent: Control) -> void:
	var line := HSeparator.new()
	line.add_theme_color_override("color", Color("ddd4c2"))
	parent.add_child(line)


func _body_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color("354847"))
	return label


func _style(background: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style


func _sync_controls() -> void:
	if _music_slider == null:
		return
	_music_slider.set_value_no_signal(float(_store.values.music_volume))
	_sfx_slider.set_value_no_signal(float(_store.values.sfx_volume))
	_music_value.text = "%d%%" % roundi(float(_store.values.music_volume) * 100.0)
	_sfx_value.text = "%d%%" % roundi(float(_store.values.sfx_volume) * 100.0)
	_fullscreen_toggle.set_pressed_no_signal(bool(_store.values.fullscreen))
	var hint_mode: String = _store.values.input_hint
	_hint_option.select({"auto": 0, "keyboard": 1, "gamepad": 2}[hint_mode])
	_refresh_binding_labels()
	_refresh_controller_status()


func _on_music_changed(value: float) -> void:
	_store.set_setting("music_volume", value)
	_store.apply_audio()
	_music_value.text = "%d%%" % roundi(value * 100.0)


func _on_sfx_changed(value: float) -> void:
	_store.set_setting("sfx_volume", value)
	_store.apply_audio()
	_sfx_value.text = "%d%%" % roundi(value * 100.0)


func _on_fullscreen_changed(enabled: bool) -> void:
	_store.set_setting("fullscreen", enabled)
	_store.apply_display()


func _on_hint_mode_changed(index: int) -> void:
	_store.set_setting("input_hint", ["auto", "keyboard", "gamepad"][index])
	_refresh_controller_status()


func _refresh_controller_status() -> void:
	if _controller_status == null:
		return
	var mode: String = _store.values.input_hint
	var connected := not Input.get_connected_joypads().is_empty()
	if mode == "keyboard" or (mode == "auto" and not connected):
		_controller_status.text = "键盘：WASD／方向键移动 · J／鼠标左键：普攻 · Space 闪避 · E 互动"
	elif connected:
		_controller_status.text = "手柄已连接 · 左摇杆／十字键移动 · A 普攻 · B 闪避 · X 互动"
	else:
		_controller_status.text = "尚未连接手柄；连接后会显示对应操作提示。"


func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	_refresh_controller_status()


func _capture_default_keys() -> void:
	for action: String in ACTIONS:
		var events: Array[InputEvent] = []
		if InputMap.has_action(action):
			for input_event: InputEvent in InputMap.action_get_events(action):
				if input_event is InputEventKey:
					events.append(input_event.duplicate())
		_saved_key_events[action] = events


func _begin_rebind(action: String) -> void:
	_listening_action = action
	_set_message("请按下“%s”的新按键；按 Esc 取消。" % ACTIONS[action])
	_refresh_binding_labels()


func _end_rebind() -> void:
	_listening_action = ""
	_refresh_binding_labels()


func _set_action_key(action: String, physical_keycode: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var retained: Array[InputEvent] = []
	for input_event: InputEvent in InputMap.action_get_events(action):
		if not input_event is InputEventKey:
			retained.append(input_event.duplicate())
	InputMap.action_erase_events(action)
	for input_event: InputEvent in retained:
		InputMap.action_add_event(action, input_event)
	var key_event := InputEventKey.new()
	key_event.physical_keycode = physical_keycode as Key
	InputMap.action_add_event(action, key_event)


func _key_is_in_use(physical_keycode: int, except_action: String) -> bool:
	if physical_keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_TAB, KEY_BACKSPACE, KEY_F2]:
		return true
	for action: StringName in InputMap.get_actions():
		if str(action) == except_action or not InputMap.has_action(action):
			continue
		for input_event: InputEvent in InputMap.action_get_events(action):
			if input_event is InputEventKey and input_event.physical_keycode == physical_keycode:
				return true
	return false


func _refresh_binding_labels() -> void:
	for action: String in ACTIONS:
		var button: Button = _binding_buttons.get(action)
		if button == null:
			continue
		button.text = "请按键…" if _listening_action == action else _action_key_label(action)
		button.disabled = not _listening_action.is_empty() and _listening_action != action


func _action_key_label(action: String) -> String:
	if not InputMap.has_action(action):
		return "未设置"
	var labels := PackedStringArray()
	for input_event: InputEvent in InputMap.action_get_events(action):
		if input_event is InputEventKey:
			var keycode: int = input_event.physical_keycode if input_event.physical_keycode != KEY_NONE else input_event.keycode
			var label := OS.get_keycode_string(keycode)
			if not labels.has(label):
				labels.append(label)
	return " / ".join(labels) if not labels.is_empty() else "未设置"


func _reset_keybindings() -> void:
	for action: String in ACTIONS:
		if not InputMap.has_action(action):
			continue
		var retained: Array[InputEvent] = []
		for input_event: InputEvent in InputMap.action_get_events(action):
			if not input_event is InputEventKey:
				retained.append(input_event.duplicate())
		InputMap.action_erase_events(action)
		for input_event: InputEvent in retained:
			InputMap.action_add_event(action, input_event)
		for input_event: InputEvent in _saved_key_events.get(action, []):
			InputMap.action_add_event(action, input_event.duplicate())
	_store.clear_key_overrides()
	_set_message("已恢复游戏默认按键。")
	_end_rebind()


func _set_message(message: String) -> void:
	if _message_label != null:
		_message_label.text = message


func _focus_first_control() -> void:
	if _music_slider != null:
		_music_slider.grab_focus()
