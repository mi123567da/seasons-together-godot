# Room reward panel integration

`room_reward_panel.tscn` is a standalone native `Control` overlay. Instance it once, keep it as a child of the active scene, and connect `reward_selected` to the room/run progression owner.

```gdscript
const REWARD_PANEL := preload("res://ui/room_reward_panel.tscn")
var reward_panel: RoomRewardPanel

func _ready() -> void:
    reward_panel = REWARD_PANEL.instantiate()
    add_child(reward_panel)
    reward_panel.reward_selected.connect(_apply_room_reward)

func _on_room_cleared(room_index: int, run_seed: int) -> void:
    get_tree().paused = true
    reward_panel.open_rewards(room_index, run_seed)

func _apply_room_reward(reward: Dictionary) -> void:
    _apply_effect(reward["effect"])
    get_tree().paused = false
```

The panel runs while the scene tree is paused. It owns only presentation, focus, the two-second confirmation gate, and a one-shot selection signal. It closes itself after emitting. It does not mutate the player or resume the game; the caller applies the contract and resumes the room flow.

Each signal payload is a deep-copied reward dictionary with `id`, `name`, `icon`, `rarity`, `description`, and `effect`. The catalog currently emits these effect contracts:

| `effect.type` | Fields | Suggested application |
| --- | --- | --- |
| `heal` | `amount` | Add health and clamp to current max health. |
| `damage_multiplier` | `multiplier` | Multiply the run's damage bonus accumulator. |
| `cooldown_multiplier` | `multiplier` | Multiply the run's skill cooldown accumulator. |
| `max_health_and_heal` | `max_health`, `heal` | Increase max health, then heal with the new cap. |
| `damage_and_heal` | `damage_multiplier`, `heal` | Apply the run damage bonus and capped healing. |

Offers are three distinct catalog entries. `RoomRewardCatalog.get_offers(room_index, run_seed)` returns repeatable results for a given pair; use a per-run seed if offer persistence or replay is needed. Character-specific restrictions can be layered on by the run owner before opening the panel.

Keyboard arrows and gamepad D-pad move focus between cards. Enter / Space / gamepad A activates the focused card; mouse click selects it directly. Selection and confirmation are locked for two seconds after `open_rewards`, including when the tree is paused. The caller can query `is_confirmation_ready()` if it needs to show a parallel hint.

Smoke check with the project Godot executable:

```powershell
& 'E:\Godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path 'E:\GAME\四季同行\godot-vertical-slice' --scene 'res://tests/room_reward_panel_smoke.tscn'
```
