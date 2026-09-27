# Safe Harbor hub module

This is a small, navigable between-run hub for the Godot 4.7 vertical slice. Open the parent `project.godot` and run `res://hub/hub.tscn`, or instance that scene from a controller. The room is drawn from lightweight Godot shapes; the avatar uses read-only copies of the approved woman/man character images under `assets/` so those textures are easy to swap.

The protagonist reads animation frames through `BitmapAnimationCatalog` for the current appearance, equipped weapon, movement action, and facing. Idle and run use the catalog's 4-frame/6 FPS and 5-frame/10 FPS clips. A direction switches to bitmaps only when its complete clip exists; missing or partial PNG deliveries keep the approved static portrait visible while movement continues. West-facing animation uses the catalog's horizontal mirror mapping, not sprite rotation. The catalog owns the slot path and cache contract; the hub does not create or edit art.

## Controls

- Move: WASD, arrow keys, or gamepad left stick.
- Interact: E or gamepad A while near a station.
- Gender and display name are required at first entry. The profile card also allows a returning player to change appearance or name later. Gender only chooses the avatar image and form of address. Weapon unlocks, equipment, and abilities are independent.

The room contains a weapon rack, an upgrade plinth, and an expedition door. Bow starts unlocked. The rack unlocks or equips the bow, sword, staff, and spirit focus. The upgrade plinth upgrades the equipped weapon. The door emits a request for the parent room-run controller; the hub does not launch a second scene itself.

## Parent controller API

Instance `HubController` from `res://hub/hub.tscn`; connect signals before `add_child()` if the parent's initial payload may immediately lead into other state.

```gdscript
var hub := preload("res://hub/hub.tscn").instantiate()
hub.gender_chosen.connect(_on_gender_chosen)
hub.weapon_equipped.connect(_on_weapon_equipped)
hub.profile_payload_changed.connect(_on_hub_profile_changed)
hub.expedition_requested.connect(_on_expedition_requested)
add_child(hub)

func _on_expedition_requested(hub_payload: Dictionary) -> void:
	# Hide or remove the hub and pass this payload into the run controller.
	start_room_run(hub_payload)
```

- `gender_chosen(gender: String, display_name: String)` fires on first selection. Gender IDs are `female` or `male`, matching the weapon profile appearance IDs.
- `appearance_changed(gender: String, display_name: String)` fires when a returning player changes avatar metadata.
- `weapon_equipped(weapon_id: String)` fires when a rack choice changes equipment.
- `expedition_requested(profile_payload: Dictionary)` fires at the door.
- `profile_payload_changed(profile_payload: Dictionary)` fires after any profile mutation.
- `get_profile_payload() -> Dictionary` returns a deep copy.
- `set_profile_payload(payload: Dictionary)` replaces the hub-owned fields from a parent profile.
- `set_hub_hud_visible(visible: bool)` toggles only the hub's separate HUD CanvasLayer; the room and player remain active.
- `apply_parent_payload(envelope: Dictionary)` accepts either a hub payload or the adapter's `{ "progression": ..., "hub": ... }` envelope.
- `unlock_weapon(weapon_id: String) -> bool` and `equip_weapon(weapon_id: String) -> bool` are callable from the parent controller.

The sidecar at `user://hub_profile.json` is the only persistent owner of gender, display name, unlocked weapons, equipped weapon, weapon levels, and provisional hub marks. Parent controllers may own their own run currency reward policy and pass updated `hub_marks` back through `set_profile_payload`.

## Provisional costs and progression boundary

`weapon_costs.json` contains the easily changed prototype economy: start with 60 hub marks; bow is free; sword costs 25, staff 40, and spirit focus 55. This one override table is passed to the shared `WeaponUnlocks` rules API, which also enforces the configured unlock order. Upgrade costs are 20, 35, and 55 marks, to level 4. These values are provisional tuning data, not locked product economy. The parent room-run is expected to decide when and how to add marks after a run.

The current documented `scripts/profile_progression.gd` profile schema contains coins, runes, legacy character stars, seasonal permanent gear, and recovery training. It has no protagonist gender/name, per-weapon unlock state, weapon levels, or hub mark currency. `profile_payload_adapter.gd` therefore keeps hub state namespaced and supplies `combine_with_progression(hub_payload, progression_snapshot)` for a parent-owned transport envelope. The adapter does not mutate or persist fields into the existing progression service.

## Smoke check

Run from the parent project directory:

```powershell
& 'E:\Godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://hub/tests/hub_smoke.gd
```

The smoke check instantiates the actual hub scene, exercises required avatar selection and later appearance changes, idle/run state selection, movement, eight-direction selection and horizontal mirroring, missing-art portrait fallback, all three room interactions, a provisional unlock/equip/upgrade, the expedition signal, and sidecar reload. It uses a unique temporary sidecar and removes it at the end.

## Official engine references

- [CharacterBody2D](https://docs.godotengine.org/en/4.7/classes/class_characterbody2d.html) — scripted movement, floating top-down motion, and collision handling.
- [Control](https://docs.godotengine.org/en/4.7/classes/class_control.html) — responsive UI layout and keyboard/gamepad focus.
- [Signal](https://docs.godotengine.org/en/4.7/classes/class_signal.html) — decoupled parent-controller events.
