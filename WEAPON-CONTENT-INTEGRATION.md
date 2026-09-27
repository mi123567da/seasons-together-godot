# Weapon content and unlock integration

The protagonist is one gameplay actor. `male` and `female` are appearance IDs
only; both use the same weapon data and combat values. The four weapon IDs and
their established combat kit sources are:

| Weapon ID | Display name | Existing kit source |
| --- | --- | --- |
| `bow` | 长弓 | `shade` |
| `sword` | 长剑 | `blade` |
| `staff` | 法杖 | `bloom` |
| `spirit_focus` | 灵契法器 | `gale` |

## Combat API

`WeaponContent` is in `scripts/weapon_content.gd`. All methods are static and
returned dictionaries are detached copies.

- `weapon_ids() -> Array[String]`
- `get_weapon(weapon_id) -> Dictionary`: weapon metadata, appearance IDs and
  unchanged base stats from `CharacterContent`.
- `get_attack(weapon_id) -> Dictionary`: the old kit's basic attack, with
  `weapon_id` added.
- `get_ability(weapon_id, key) -> Dictionary`: existing Q/E/R ability metadata,
  with `weapon_id` added.
- `cooldown_seconds(weapon_id, key, path_id = "", path_level = 0, haste = 1.0)
  -> float`: forwards existing cooldown conversion and path modifiers. Unknown
  input returns `-1.0`.
- `build_ability_contract(weapon_id, key, options = {}) -> Dictionary`:
  forwards the existing data-only action contract and adds weapon/source IDs.

The hub/main integration should persist a selected `weapon_id`, choose an
appearance ID independently, and use `build_ability_contract` for ability
execution. Do not derive stats or cooldowns from the appearance choice. During
the transition, legacy kit IDs remain valid inputs only at the existing
`CharacterContent` boundary.

## Unlock rules API

`WeaponUnlocks` in `scripts/weapon_unlocks.gd` contains no file access and does
not mutate input dictionaries. It exposes:

- `unlock_order() -> Array[String]`: bow, sword, staff, spirit_focus.
- `unlock_costs(overrides = {}) -> Dictionary` and
  `get_unlock_cost(weapon_id, overrides = {}) -> int`.
- `default_state(material = 0) -> Dictionary`: bow is available and selected;
  state fields are `unlocked_weapon_ids`, `selected_weapon_id`, and `material`.
- `add_run_material(state, earned_material) -> Dictionary`: adds a nonnegative
  integer supplied by run settlement; this module does not set run rewards.
- `is_unlocked(state, weapon_id) -> bool`.
- `select_weapon(state, weapon_id) -> Dictionary`: selects only an unlocked
  weapon and returns a detached updated state.
- `try_unlock(state, weapon_id, overrides = {}) -> Dictionary`: only the next
  locked weapon can be purchased. On success, persist the returned `state`
  explicitly. Result codes include `unlocked`, `already_unlocked`,
  `out_of_order`, `insufficient_material`, `invalid_weapon`, and `invalid_state`.

Prototype costs are Bow 0, Sword 100, Staff 180, and Spirit Focus 280 units of
run-earned material. Pass a cost override dictionary to tune these values.
Material rewards and profile persistence belong to the hub/profile layer.

## Existing profile migration

The current `ProfileProgression` save is version 1 and has these top-level
fields: `version`, `mode`, `coins`, `runes`, `stars`, `permanentGear`,
`recoveryTraining`, and `settledRuns`. Its `stars` map uses `shade`, `bloom`,
`gale`, and `blade` keys. `ProfileProgression` rejects other versions and
refuses to save when loading fails.

When the hub/profile owner adopts a new version, preserve the original v1 JSON
as a backup and retain its fields, especially the old `stars` map, as legacy
history. Add the selected appearance and weapon unlock state as new fields;
do not silently translate character stars into weapon unlocks or treat old
coins/runes as the new run-earned material. Build the adapted object in memory,
validate it, and only replace the active save after an explicit migration
decision. Keep the v1 file available until the migrated save has been read
back successfully.

## Smoke verification

Run `godot --headless --path . --script res://tests/weapon_content_smoke.gd`.
The smoke checks kit mappings, shared stats independent of appearance, the
forwarded attack/ability/cooldown contract, copy safety, and unlock ordering,
cost overrides, insufficient funds, and state immutability.
