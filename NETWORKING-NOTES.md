# Multiplayer migration points

The playable core is deliberately local-only for now. Preserve the room-run rules and replace local ownership at these boundaries when multiplayer is scheduled:

1. **Run/session authority:** move `game_state`, `room_index`, run timer, quotas, `spawned_count`, `defeated_count`, room transitions, and victory decisions into a host/server session object. Clients should receive room state and request transitions; they should not unlock doors locally.
2. **Player authority:** keep one input owner per player. Send movement/attack/dash intents, then replicate authoritative position, health, dash invulnerability, and attack cooldown state. `CharacterBody2D` motion should execute once in the authority simulation.
3. **Enemy authority:** spawn enemies and advance AI only on the authority. Replicate stable enemy IDs, positions, health, deaths, and room clear counts. Clients may interpolate positions and predict cosmetic motion.
4. **Combat authority:** turn `_attack()` into an attack command plus authoritative hit resolution. Keep each character's attack profile data separate from input and presentation. Do not trust client-reported damage, kills, or quota progress.
5. **Room transitions:** the lit exit remains presentation. The authoritative session validates quota completion, advances the room index once, resets room-local enemies/projectiles, and replicates the seasonal scene and player spawn.
6. **Persistence/reconnect:** this slice has no save/session recovery. Add a run snapshot (room, health, character, quotas, enemy state, timer) before supporting reconnect or host migration.

Recommended first multiplayer increment: two local players over a host-authoritative transport, with shared room quota and separate health. Decide shared versus individual kill credit, revive rules, host migration, and disconnect behavior before adding them.
