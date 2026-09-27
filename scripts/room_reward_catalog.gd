class_name RoomRewardCatalog
extends RefCounted

## Data-only rewards granted after a room is cleared. The main combat flow is
## responsible for applying these effects to its current player/run state.
const REWARDS: Array[Dictionary] = [
	{
		"id": "spring_dew",
		"name": "春露回生",
		"icon": "✿",
		"rarity": "生机",
		"description": "恢复 28 点生命。",
		"effect": {"type": "heal", "amount": 28.0},
	},
	{
		"id": "moonlit_edge",
		"name": "月辉锋芒",
		"icon": "✦",
		"rarity": "攻击",
		"description": "本轮伤害提高 12%。",
		"effect": {"type": "damage_multiplier", "multiplier": 1.12},
	},
	{
		"id": "swift_breeze",
		"name": "逐风铭文",
		"icon": "〰",
		"rarity": "迅捷",
		"description": "本轮主动技能冷却缩短 10%。",
		"effect": {"type": "cooldown_multiplier", "multiplier": 0.9},
	},
	{
		"id": "ironbark_heart",
		"name": "铁木之心",
		"icon": "⬟",
		"rarity": "守护",
		"description": "最大生命提高 18 点，并立即恢复 18 点生命。",
		"effect": {"type": "max_health_and_heal", "max_health": 18.0, "heal": 18.0},
	},
	{
		"id": "deep_focus",
		"name": "澄心诀",
		"icon": "◎",
		"rarity": "专注",
		"description": "本轮主动技能冷却缩短 6%。",
		"effect": {"type": "cooldown_multiplier", "multiplier": 0.94},
	},
	{
		"id": "sunfire_oath",
		"name": "日炎誓约",
		"icon": "☼",
		"rarity": "攻击",
		"description": "本轮伤害提高 7%，并恢复 10 点生命。",
		"effect": {"type": "damage_and_heal", "damage_multiplier": 1.07, "heal": 10.0},
	},
]


static func get_reward(reward_id: String) -> Dictionary:
	for reward: Dictionary in REWARDS:
		if str(reward.get("id", "")) == reward_id:
			return reward.duplicate(true)
	return {}


static func get_offers(room_index: int, run_seed: int = 0) -> Array[Dictionary]:
	## Return three distinct, repeatable offers. A stable seed makes it easy for
	## save/replay code to reproduce a room's choices without owning UI state.
	var pool := REWARDS.duplicate(true)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run_seed, room_index, "room_rewards"])
	for i: int in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temporary: Dictionary = pool[i]
		pool[i] = pool[j]
		pool[j] = temporary
	var offers: Array[Dictionary] = []
	for i: int in range(3):
		offers.append((pool[i] as Dictionary).duplicate(true))
	return offers
