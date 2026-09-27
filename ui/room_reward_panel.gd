class_name RoomRewardPanel
extends Control

## Emitted once when a player confirms an offer. The payload is a deep copy
## containing id, name, description, and a data-only `effect` dictionary.
signal reward_selected(reward: Dictionary)

const CATALOG := preload("res://scripts/room_reward_catalog.gd")
const CONFIRM_DELAY_SECONDS := 2.0

var _room_index := 0
var _offers: Array[Dictionary] = []
var _opened_at_msec := 0
var _selected_index := 0
var _choice_buttons: Array[Button] = []
var _confirm_button: Button
var _countdown_label: Label
var _body: VBoxContainer
var _heading_label: Label
var _subtitle_label: Label
var _has_emitted := false


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_interface()


## Open after a room's clear condition is met. `run_seed` lets the caller make
## offers reproducible per run; omitting it uses a stable room-specific set.
func open_rewards(room_index: int, run_seed: int = 0) -> void:
	_room_index = maxi(0, room_index)
	_offers = CATALOG.get_offers(_room_index, run_seed)
	_selected_index = 0
	_has_emitted = false
	_opened_at_msec = Time.get_ticks_msec()
	_render_offers()
	visible = true
	_update_gate()
	if not _choice_buttons.is_empty():
		_choice_buttons[0].grab_focus()


func close_rewards() -> void:
	visible = false


func is_confirmation_ready() -> bool:
	return Time.get_ticks_msec() - _opened_at_msec >= int(CONFIRM_DELAY_SECONDS * 1000.0)


func _process(_delta: float) -> void:
	if visible:
		_update_gate()


func _build_interface() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.045, 0.04, 0.88)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var outer_margin := MarginContainer.new()
	outer_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer_margin.add_theme_constant_override("margin_left", 28)
	outer_margin.add_theme_constant_override("margin_right", 28)
	outer_margin.add_theme_constant_override("margin_top", 22)
	outer_margin.add_theme_constant_override("margin_bottom", 22)
	add_child(outer_margin)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_margin.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(850.0, 0.0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)

	var padding := MarginContainer.new()
	padding.add_theme_constant_override("margin_left", 28)
	padding.add_theme_constant_override("margin_right", 28)
	padding.add_theme_constant_override("margin_top", 24)
	padding.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(padding)

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 14)
	padding.add_child(_body)

	var eyebrow := Label.new()
	eyebrow.text = "旅途歇息 · 第 %02d 房" % (_room_index + 1)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_color_override("font_color", Color("718069"))
	eyebrow.add_theme_font_size_override("font_size", 14)
	_body.add_child(eyebrow)

	_heading_label = Label.new()
	_heading_label.text = "清理完毕，收下一份馈赠"
	_heading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_heading_label.add_theme_color_override("font_color", Color("263d32"))
	_heading_label.add_theme_font_size_override("font_size", 30)
	_body.add_child(_heading_label)

	_subtitle_label = Label.new()
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.add_theme_color_override("font_color", Color("77816f"))
	_subtitle_label.add_theme_font_size_override("font_size", 15)
	_body.add_child(_subtitle_label)

	var divider := HSeparator.new()
	divider.add_theme_color_override("color", Color("d9d2bc"))
	_body.add_child(divider)

	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 14)
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(cards)
	for i: int in range(3):
		var card := _make_reward_card(i)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cards.add_child(card)
		_choice_buttons.append(card)
	for i: int in range(_choice_buttons.size()):
		_choice_buttons[i].focus_neighbor_left = _choice_buttons[maxi(0, i - 1)].get_path()
		_choice_buttons[i].focus_neighbor_right = _choice_buttons[mini(_choice_buttons.size() - 1, i + 1)].get_path()

	_countdown_label = Label.new()
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_label.add_theme_color_override("font_color", Color("857545"))
	_countdown_label.add_theme_font_size_override("font_size", 14)
	_body.add_child(_countdown_label)

	_confirm_button = Button.new()
	_confirm_button.text = "收下馈赠  ·  Enter / A"
	_confirm_button.custom_minimum_size = Vector2(220.0, 48.0)
	_confirm_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_confirm_button.focus_mode = Control.FOCUS_NONE
	_confirm_button.pressed.connect(_confirm_selected)
	_body.add_child(_confirm_button)


func _make_reward_card(index: int) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0.0, 230.0)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", _card_style(Color("f5f0df"), Color("c5b785")))
	button.add_theme_stylebox_override("hover", _card_style(Color("fff9e8"), Color("a89153")))
	button.add_theme_stylebox_override("pressed", _card_style(Color("e8e4d0"), Color("998044")))
	button.add_theme_stylebox_override("focus", _card_style(Color("fff9e8"), Color("7c9868"), 3))
	button.pressed.connect(_on_card_pressed.bind(index))
	var content := VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_theme_constant_override("separation", 9)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(content)

	var number := Label.new()
	number.text = "0%d" % (index + 1)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	number.add_theme_color_override("font_color", Color("a09267"))
	number.add_theme_font_size_override("font_size", 12)
	content.add_child(number)

	var icon := Label.new()
	icon.name = "RewardIcon"
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_color_override("font_color", Color("71815b"))
	icon.add_theme_font_size_override("font_size", 42)
	content.add_child(icon)

	var rarity := Label.new()
	rarity.name = "RewardRarity"
	rarity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity.add_theme_color_override("font_color", Color("9a8450"))
	rarity.add_theme_font_size_override("font_size", 12)
	content.add_child(rarity)

	var name := Label.new()
	name.name = "RewardName"
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.add_theme_color_override("font_color", Color("2f4638"))
	name.add_theme_font_size_override("font_size", 19)
	content.add_child(name)

	var description := Label.new()
	description.name = "RewardDescription"
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description.add_theme_color_override("font_color", Color("6e7969"))
	description.add_theme_font_size_override("font_size", 14)
	content.add_child(description)
	return button


func _render_offers() -> void:
	if _body == null:
		return
	var eyebrow: Label = _body.get_child(0) as Label
	eyebrow.text = "旅途歇息 · 第 %02d 房" % (_room_index + 1)
	for i: int in range(_choice_buttons.size()):
		var reward: Dictionary = _offers[i]
		var content := _choice_buttons[i].get_child(0) as VBoxContainer
		(content.get_node("RewardIcon") as Label).text = str(reward["icon"])
		(content.get_node("RewardRarity") as Label).text = str(reward["rarity"])
		(content.get_node("RewardName") as Label).text = str(reward["name"])
		(content.get_node("RewardDescription") as Label).text = str(reward["description"])
		_choice_buttons[i].set_meta("reward_index", i)
		_set_card_selected(i, i == _selected_index)


func _on_card_pressed(index: int) -> void:
	if index < 0 or index >= _offers.size() or _has_emitted:
		return
	_selected_index = index
	for i: int in range(_choice_buttons.size()):
		_set_card_selected(i, i == index)
	if is_confirmation_ready():
		_confirm_selected()
	else:
		_update_gate()


func _confirm_selected() -> void:
	if not visible or _has_emitted or not is_confirmation_ready() or _selected_index >= _offers.size():
		return
	_has_emitted = true
	var reward: Dictionary = _offers[_selected_index].duplicate(true)
	reward_selected.emit(reward)
	visible = false


func _update_gate() -> void:
	if _countdown_label == null or _confirm_button == null:
		return
	var remaining_msec := maxi(0, int(CONFIRM_DELAY_SECONDS * 1000.0) - (Time.get_ticks_msec() - _opened_at_msec))
	var ready := remaining_msec == 0
	_countdown_label.text = "已选中：%s" % str(_offers[_selected_index].get("name", "")) if ready and _selected_index < _offers.size() else "请先停留片刻，再确认奖励。剩余 %.1f 秒" % (float(remaining_msec) / 1000.0)
	_confirm_button.disabled = not ready
	_confirm_button.modulate = Color.WHITE if ready else Color(0.82, 0.82, 0.78)


func _set_card_selected(index: int, selected: bool) -> void:
	var button := _choice_buttons[index]
	button.add_theme_stylebox_override("normal", _card_style(Color("fff9e8") if selected else Color("f5f0df"), Color("84986b") if selected else Color("c5b785"), 3 if selected else 1))


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("ece6d3")
	style.border_color = Color("a99a6d")
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.34)
	style.shadow_size = 18
	return style


func _card_style(background: Color, border: Color, border_width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(8)
	style.content_margin_left = 13.0
	style.content_margin_right = 13.0
	style.content_margin_top = 13.0
	style.content_margin_bottom = 13.0
	return style
