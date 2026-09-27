class_name ProfileProgression
extends RefCounted

## Single-player permanent profile persistence and progression rules.
## The profile is intentionally separate from the room simulation. Callers pass
## one stable run_id to settle_room_run() when a four-room run ends.

const SAVE_VERSION := 1
const CHARACTER_IDS: Array[String] = ["shade", "bloom", "gale", "blade"]
const SEASONS: Array[String] = ["spring", "summer", "autumn", "winter"]
const SLOT_PRICES := {
	"head": 50, "chest": 85, "legs": 70, "boots": 45, "charm": 65, "weapon": 105,
}
const STAR_COSTS: Array[int] = [30, 65, 110, 170, 250]
const RECOVERY_COSTS: Array[int] = [250, 600, 1000]
const MAX_RECOVERY_LEVEL := 3
const RECOVERY_PER_LEVEL := 0.35
const GEAR_PRICE_MULTIPLIER := 10
const ABANDON_BANK_RATE := 0.5

var save_path: String
var _profile: Dictionary = {}
var _loaded := false
var last_error := ""


func _init(path: String = "user://profile.json") -> void:
	save_path = path
	load_profile()


static func default_profile() -> Dictionary:
	var stars := {}
	for character_id in CHARACTER_IDS:
		stars[character_id] = 0
	return {
		"version": SAVE_VERSION,
		"mode": "single_player",
		"coins": 0.0,
		"runes": 0,
		"stars": stars,
		"permanentGear": {},
		"recoveryTraining": 0,
		"settledRuns": [],
	}


func load_profile() -> bool:
	last_error = ""
	_loaded = false
	if not FileAccess.file_exists(save_path):
		_profile = default_profile()
		_loaded = true
		return true

	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		last_error = "无法打开档案文件（错误码 %d）" % FileAccess.get_open_error()
		return false
	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	file.close()
	if parse_error != OK:
		last_error = "档案 JSON 无效：%s（第 %d 行）" % [json.get_error_message(), json.get_error_line()]
		return false
	if typeof(json.data) != TYPE_DICTIONARY:
		last_error = "档案根节点必须是对象"
		return false
	var normalized := _normalize_profile(json.data)
	if not normalized["ok"]:
		last_error = str(normalized["error"])
		return false
	_profile = normalized["profile"]
	_loaded = true
	return true


func profile_snapshot() -> Dictionary:
	return _profile.duplicate(true)


func save_profile() -> bool:
	if not _loaded:
		last_error = "档案尚未成功加载；为避免覆盖损坏存档，拒绝写入"
		return false
	return _atomic_write(_profile)


func get_character_growth(character_id: String) -> Dictionary:
	if not CHARACTER_IDS.has(character_id) or not _loaded:
		return {}
	var stars := int((_profile["stars"] as Dictionary).get(character_id, 0))
	var permanent_gear: Dictionary = _profile["permanentGear"].duplicate(true)
	return {
		"character_id": character_id,
		"stars": stars,
		"max_hp_bonus": stars * 20,
		"power_bonus": stars * 0.08,
		"recovery_training": int(_profile["recoveryTraining"]),
		"regen_bonus": int(_profile["recoveryTraining"]) * RECOVERY_PER_LEVEL,
		"permanent_gear": permanent_gear,
	}


func upgrade_star(character_id: String) -> Dictionary:
	if not _loaded:
		return _failure("profile_unavailable", last_error)
	if not CHARACTER_IDS.has(character_id):
		return _failure("invalid_character", "角色不存在")
	var candidate := _profile.duplicate(true)
	var stars: Dictionary = candidate["stars"]
	var current := int(stars[character_id])
	if current >= STAR_COSTS.size():
		return _failure("max_level", "该角色已达到五星")
	var cost := STAR_COSTS[current]
	if int(candidate["runes"]) < cost:
		return _failure("insufficient_runes", "铭文不足，需要 %d 枚" % cost)
	candidate["runes"] = int(candidate["runes"]) - cost
	stars[character_id] = current + 1
	var result := _commit(candidate)
	if result["ok"]:
		result["cost"] = cost
		result["stars"] = current + 1
	return result


func buy_permanent_gear(slot: String, season: String) -> Dictionary:
	if not _loaded:
		return _failure("profile_unavailable", last_error)
	if not SLOT_PRICES.has(slot) or not SEASONS.has(season):
		return _failure("invalid_gear", "请选择有效的装备部位和季节")
	var candidate := _profile.duplicate(true)
	var gear: Dictionary = candidate["permanentGear"]
	if gear.has(slot):
		return _failure("already_unlocked", "这个部位已永久解锁")
	var cost := int(SLOT_PRICES[slot]) * GEAR_PRICE_MULTIPLIER
	if float(candidate["coins"]) < cost:
		return _failure("insufficient_coins", "旅费不足，需要 %d 金币" % cost)
	candidate["coins"] = _money(float(candidate["coins"]) - cost)
	gear[slot] = season
	var result := _commit(candidate)
	if result["ok"]:
		result["cost"] = cost
	return result


func set_permanent_gear_season(slot: String, season: String) -> Dictionary:
	if not _loaded:
		return _failure("profile_unavailable", last_error)
	if not SLOT_PRICES.has(slot) or not SEASONS.has(season):
		return _failure("invalid_gear", "请选择有效的装备部位和季节")
	var candidate := _profile.duplicate(true)
	var gear: Dictionary = candidate["permanentGear"]
	if not gear.has(slot):
		return _failure("not_unlocked", "这个部位尚未永久解锁")
	gear[slot] = season
	return _commit(candidate)


func upgrade_recovery_training() -> Dictionary:
	if not _loaded:
		return _failure("profile_unavailable", last_error)
	var candidate := _profile.duplicate(true)
	var level := int(candidate["recoveryTraining"])
	if level >= MAX_RECOVERY_LEVEL:
		return _failure("max_level", "恢复训练已满级")
	var cost := RECOVERY_COSTS[level]
	if int(candidate["coins"]) < cost:
		return _failure("insufficient_coins", "旅费不足，需要 %d 金币" % cost)
	candidate["coins"] = int(candidate["coins"]) - cost
	candidate["recoveryTraining"] = level + 1
	var result := _commit(candidate)
	if result["ok"]:
		result["cost"] = cost
		result["recovery_training"] = level + 1
	return result


func settle_room_run(run_id: String, result: Dictionary) -> Dictionary:
	if not _loaded:
		return _failure("profile_unavailable", last_error)
	if run_id.strip_edges().is_empty():
		return _failure("invalid_run_id", "结算必须提供稳定且非空的 run_id")
	if typeof(result.get("victory", null)) != TYPE_BOOL or typeof(result.get("abandoned", false)) != TYPE_BOOL:
		return _failure("invalid_result", "结算需要 victory 布尔值，可选 abandoned 布尔值")
	var victory := bool(result["victory"])
	var abandoned := bool(result.get("abandoned", false))
	if victory and abandoned:
		return _failure("invalid_result", "放弃的旅程不能同时记为胜利")
	for key in ["kills", "boss_kills"]:
		if not _is_nonnegative_number(result.get(key, null)):
			return _failure("invalid_result", "%s 必须是非负数字" % key)
	if not _is_nonnegative_number(result.get("earned_gold", 0)):
		return _failure("invalid_result", "earned_gold 必须是非负数字")
	var settled_runs: Array = _profile["settledRuns"]
	if settled_runs.has(run_id):
		return {"ok": true, "duplicate": true, "run_id": run_id, "banked_coins": 0.0, "runes_awarded": 0}

	var kills := int(floor(float(result["kills"])))
	var boss_kills := int(floor(float(result["boss_kills"])))
	var bank_rate := ABANDON_BANK_RATE if abandoned else 1.0
	var banked_coins := _money(float(result.get("earned_gold", 0)) * bank_rate)
	var runes := int(floor(float(kills / 30 + boss_kills * 15 + (40 if victory else 0)) * bank_rate))
	var candidate := _profile.duplicate(true)
	candidate["coins"] = _money(float(candidate["coins"]) + banked_coins)
	candidate["runes"] = int(candidate["runes"]) + runes
	(candidate["settledRuns"] as Array).append(run_id)
	var commit_result := _commit(candidate)
	if not commit_result["ok"]:
		return commit_result
	return {
		"ok": true,
		"duplicate": false,
		"run_id": run_id,
		"bank_rate": bank_rate,
		"banked_coins": banked_coins,
		"runes_awarded": runes,
		"profile": profile_snapshot(),
	}


static func new_run_id() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()


func _commit(candidate: Dictionary) -> Dictionary:
	if not _atomic_write(candidate):
		return _failure("save_failed", last_error)
	_profile = candidate
	return {"ok": true, "profile": profile_snapshot()}


func _atomic_write(data: Dictionary) -> bool:
	last_error = ""
	var destination := ProjectSettings.globalize_path(save_path)
	var temp_path := destination + ".tmp"
	var parent := save_path.get_base_dir()
	if parent != "." and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(parent)):
		var mkdir_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(parent))
		if mkdir_error != OK:
			last_error = "无法创建档案目录（错误码 %d）" % mkdir_error
			return false
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		last_error = "无法写入临时档案（错误码 %d）" % FileAccess.get_open_error()
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
		last_error = "临时档案写入失败（错误码 %d）" % write_error
		return false
	var rename_error := DirAccess.rename_absolute(ProjectSettings.globalize_path(temp_path), destination)
	if rename_error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
		last_error = "替换档案失败，旧档案保留（错误码 %d）" % rename_error
		return false
	return true


func _normalize_profile(raw: Dictionary) -> Dictionary:
	if raw.get("version", null) != SAVE_VERSION:
		return _failure("unsupported_version", "档案版本缺失或不受支持；请按导入契约显式迁移")
	if raw.get("mode", "single_player") != "single_player":
		return _failure("unsupported_mode", "此垂直切片档案只支持单人模式")
	var profile := default_profile()
	profile["coins"] = _clamp_nonnegative_money(raw.get("coins", 0))
	profile["runes"] = _clamp_nonnegative_int(raw.get("runes", 0))
	var raw_stars: Variant = raw.get("stars", {})
	if typeof(raw_stars) != TYPE_DICTIONARY:
		return _failure("invalid_profile", "stars 必须是对象")
	for character_id in CHARACTER_IDS:
		profile["stars"][character_id] = clampi(_clamp_nonnegative_int(raw_stars.get(character_id, 0)), 0, STAR_COSTS.size())
	var raw_gear: Variant = raw.get("permanentGear", {})
	if typeof(raw_gear) != TYPE_DICTIONARY:
		return _failure("invalid_profile", "permanentGear 必须是对象")
	for slot in SLOT_PRICES:
		var season: Variant = raw_gear.get(slot, null)
		if typeof(season) == TYPE_STRING and SEASONS.has(season):
			profile["permanentGear"][slot] = season
	profile["recoveryTraining"] = clampi(_clamp_nonnegative_int(raw.get("recoveryTraining", 0)), 0, MAX_RECOVERY_LEVEL)
	var raw_runs: Variant = raw.get("settledRuns", [])
	if typeof(raw_runs) != TYPE_ARRAY:
		return _failure("invalid_profile", "settledRuns 必须是数组")
	for run_id in raw_runs:
		if typeof(run_id) == TYPE_STRING and not run_id.is_empty() and not (profile["settledRuns"] as Array).has(run_id):
			(profile["settledRuns"] as Array).append(run_id)
	profile["mode"] = "single_player"
	profile["version"] = SAVE_VERSION
	return {"ok": true, "profile": profile}


static func _failure(code: String, message: String) -> Dictionary:
	return {"ok": false, "code": code, "error": message}


static func _is_nonnegative_number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) >= 0.0


static func _clamp_nonnegative_int(value: Variant) -> int:
	if not _is_nonnegative_number(value):
		return 0
	return int(floor(float(value)))


static func _clamp_nonnegative_money(value: Variant) -> float:
	if not _is_nonnegative_number(value):
		return 0.0
	return _money(float(value))


static func _money(value: float) -> float:
	return round(value * 100.0) / 100.0
