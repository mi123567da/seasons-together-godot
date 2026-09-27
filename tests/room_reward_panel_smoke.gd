extends Node

const PANEL_SCENE := preload("res://ui/room_reward_panel.tscn")
const CATALOG := preload("res://scripts/room_reward_catalog.gd")

var _picked: Dictionary = {}


func _ready() -> void:
	var panel: RoomRewardPanel = PANEL_SCENE.instantiate()
	add_child(panel)
	panel.reward_selected.connect(_on_reward_selected)
	await get_tree().process_frame
	panel.open_rewards(2, 456)
	assert(panel.visible, "opening rewards should show the native panel")
	var room_heading: String = (panel._body.get_child(0) as Label).text
	assert(room_heading == "旅途歇息 · 第 03 房", "room heading should be Simplified Chinese")
	assert(not room_heading.contains("ROOM"), "room heading should not contain English UI text")
	assert(panel._offers.size() == 3, "each room should offer three choices")
	assert(panel._offers[0]["id"] != panel._offers[1]["id"])
	assert(panel._offers[1]["id"] != panel._offers[2]["id"])
	assert(panel._offers[0]["id"] != panel._offers[2]["id"])
	assert(CATALOG.get_offers(2, 456) == panel._offers, "seeded offers should be repeatable")

	panel._choice_buttons[0].pressed.emit()
	assert(_picked.is_empty(), "button activation before two seconds must be ignored")

	await get_tree().create_timer(2.1).timeout
	assert(panel.is_confirmation_ready(), "confirmation should unlock after two seconds")
	panel._choice_buttons[0].pressed.emit()
	assert(not _picked.is_empty(), "confirm activation should emit a reward after the gate")
	assert(_picked.has("id") and _picked.has("effect"), "signal should carry the application contract")
	assert(not panel.visible, "panel should close after one successful choice")
	print("ROOM_REWARD_PANEL_SMOKE_OK id=%s effect=%s" % [_picked["id"], _picked["effect"].get("type", "")])
	get_tree().quit()


func _on_reward_selected(reward: Dictionary) -> void:
	_picked = reward.duplicate(true)
