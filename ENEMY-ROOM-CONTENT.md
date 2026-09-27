# Enemy and room content contract

`EnemyRoomContent` is a pure data provider in `scripts/enemy_room_content.gd`.
Its public methods are static and return deep copies, so the combat scene may
change runtime state without changing the source tables:

- `get_room(index) -> Dictionary`: room metadata, seasonal enemy ID pool,
  normal-kill quota, concurrent-enemy cap, door condition, boss phase, and the
  next room index (`-1` after the last room).
- `get_enemy(id) -> Dictionary`: seasonal display name, archetype, original
  baseline stats, prototype stats, and behavior tags. IDs are
  `spring_grunt`, `summer_fast`, and so on; each season currently exposes the
  four basic source archetypes `grunt`, `fast`, `tank`, and `ranged`.
- `get_boss(id) -> Dictionary`: seasonal representative boss profile. IDs are
  `spring_boss`, `summer_boss`, `autumn_boss`, and `winter_boss`.
- `get_room_count() -> int`: number of rooms in the run.

The room quotas 6/8/10/12 preserve the current Godot slice. Each room then
starts the representative boss phase; the door remains locked until both the
quota and boss are cleared. `max_enemies` is a prototype cap selected for the
small arena. `door_state` describes the unlock condition; the room manager
owns the live locked/open state. `is_boss_room` and `boss_after_quota` are true
for all four rooms because each contains a post-quota boss encounter.

## Source mapping and prototype differences

Names and source baselines were read from `source/game.js` (`SEASONS`,
`spawnEnemy`'s base table) and `source/content.js` (`encounters`). The seasonal
mob names and representative boss names match those source tables. The
original base stats are preserved under `source_stats` before normal/hard
difficulty, co-op multipliers, late-run growth, or boss time scaling:

| Archetype | Original HP / speed / radius / damage | Godot prototype HP / speed / radius / damage |
| --- | --- | --- |
| grunt | 18 / 73 / 16 / 8 | 1 / 84 / 15 / 9 |
| fast | 12 / 127 / 12 / 6 | 1 / 108 / 13 / 7 |
| tank | 62 / 47 / 25 / 13 | 2 / 66 / 21 / 13 |
| ranged | 24 / 56 / 17 / 10 | 1 / 68 / 16 / 9 |
| seasonal boss | 26000 / 57 / 72 / 28 | 14 / 72 / 30 / 15 |

Prototype stats are not a fixed-ratio conversion: ordinary HP was compressed
to match the current slice's 1–2 damage attacks, and boss HP/radius/damage
were reduced so four consecutive rooms can be cleared in a short solo run.
Speeds were tuned around the slice's 255 player movement speed and its compact
arena. These prototype values do not represent old-game progression balance.

Behavior tags preserve recognizable source mechanics as content labels.
Current `main.gd` only implements pursuit/contact damage and does not yet
execute projectile attacks, boss telegraphs, seasonal hazards, summons, or
special enemy AI. Those behaviors are deferred until the room runtime consumes
these contracts. In particular, the tags `three_delayed_blasts`,
`aimed_fan_projectiles`, `summons_five_adds`, and `large_delayed_slow_blast`
summarize the seasonal branches in `bossAttack` in `source/game.js`.

Run `tests/enemy_room_content_smoke.tscn` in Godot 4.7.2 (F6). The output panel
prints a pass line after all room, source-data, behavior-tag, and copy-safety
assertions succeed. Stop the smoke scene after reading the output.
