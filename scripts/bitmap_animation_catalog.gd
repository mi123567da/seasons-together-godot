class_name BitmapAnimationCatalog
extends RefCounted

## Contract for outsource-ready protagonist animation slots.
## This class stores no gameplay state and does not create or alter images.

const APPEARANCE_IDS: Array[String] = ["female", "male"]
const WEAPON_IDS: Array[String] = ["bow", "sword", "staff", "spirit_focus"]
const ACTION_IDS: Array[String] = ["idle", "run", "basic", "q", "e", "r", "dash", "hurt"]
const DIRECTION_IDS: Array[String] = ["N", "NE", "E", "SE", "S", "W", "NW", "SW"]
const SOURCE_DIRECTION_IDS: Array[String] = ["N", "NE", "E", "SE", "S"]
const FRAME_SIZE := Vector2i(256, 256)
const ANCHOR_NORMALIZED := Vector2(0.5, 1.0)
const _ROOT := "res://assets/animation_slots"

const _ACTION_METADATA := {
	"idle": {"frame_count": 4, "fps": 6.0, "loop": true, "playback": "loop"},
	"run": {"frame_count": 5, "fps": 10.0, "loop": true, "playback": "loop"},
	"basic": {"frame_count": 5, "fps": 12.0, "loop": false, "playback": "one_shot"},
	"q": {"frame_count": 5, "fps": 12.0, "loop": false, "playback": "one_shot"},
	"e": {"frame_count": 5, "fps": 12.0, "loop": false, "playback": "one_shot"},
	"r": {"frame_count": 5, "fps": 12.0, "loop": false, "playback": "one_shot"},
	"dash": {"frame_count": 5, "fps": 12.0, "loop": false, "playback": "one_shot"},
	"hurt": {"frame_count": 5, "fps": 8.0, "loop": false, "playback": "one_shot"},
}

## Path -> Texture2D when loaded, true when only existence has been checked,
## false when the slot is known to be missing or invalid.
static var _frame_cache: Dictionary = {}


static func appearance_ids() -> Array[String]:
	return APPEARANCE_IDS.duplicate()


static func weapon_ids() -> Array[String]:
	return WEAPON_IDS.duplicate()


static func action_ids() -> Array[String]:
	return ACTION_IDS.duplicate()


static func directions() -> Array[String]:
	return DIRECTION_IDS.duplicate()


static func source_directions() -> Array[String]:
	return SOURCE_DIRECTION_IDS.duplicate()


static func get_frame_size() -> Vector2i:
	return FRAME_SIZE


static func get_anchor_normalized() -> Vector2:
	return ANCHOR_NORMALIZED


static func get_action_metadata(action_id: String) -> Dictionary:
	if not _ACTION_METADATA.has(action_id):
		return {}
	return (_ACTION_METADATA[action_id] as Dictionary).duplicate(true)


## Returns the contract frame count even when no art has been delivered yet.
## This lets gameplay advance animation state while showing a portrait fallback.
static func get_frame_count(appearance_id: String, weapon_id: String, action_id: String) -> int:
	if not _is_valid_clip(appearance_id, weapon_id, action_id):
		return 0
	return int(_ACTION_METADATA[action_id]["frame_count"])


static func get_clip_metadata(appearance_id: String, weapon_id: String, action_id: String) -> Dictionary:
	if not _is_valid_clip(appearance_id, weapon_id, action_id):
		return {}
	var result: Dictionary = (_ACTION_METADATA[action_id] as Dictionary).duplicate(true)
	result["appearance_id"] = appearance_id
	result["weapon_id"] = weapon_id
	result["action_id"] = action_id
	result["frame_size"] = FRAME_SIZE
	result["anchor_normalized"] = ANCHOR_NORMALIZED
	return result


## Direction IDs are case-insensitive. W/NW/SW mirror the corresponding
## E/NE/SE source art horizontally.
static func resolve_direction(direction: String) -> Dictionary:
	var normalized := direction.strip_edges().to_upper()
	if not DIRECTION_IDS.has(normalized):
		return {}
	match normalized:
		"W": return {"source_direction": "E", "flip_h": true}
		"NW": return {"source_direction": "NE", "flip_h": true}
		"SW": return {"source_direction": "SE", "flip_h": true}
		_: return {"source_direction": normalized, "flip_h": false}


## Returns a slot path regardless of whether a PNG has been delivered. Invalid
## IDs, directions, or zero-based frame indices return an empty string.
static func expected_frame_path(appearance_id: String, weapon_id: String, action_id: String, direction: String, frame_index: int) -> String:
	if not _is_valid_clip(appearance_id, weapon_id, action_id):
		return ""
	var frame_count := int(_ACTION_METADATA[action_id]["frame_count"])
	if frame_index < 0 or frame_index >= frame_count:
		return ""
	var direction_info := resolve_direction(direction)
	if direction_info.is_empty():
		return ""
	return "%s/%s/%s/%s/%s_%02d.png" % [
		_ROOT,
		appearance_id,
		weapon_id,
		action_id,
		str(direction_info["source_direction"]),
		frame_index,
	]


## Returns an existing resource path, or null when the slot is empty. Existence
## results are cached so repeated animation ticks do not probe the PCK/filesystem.
static func get_frame_path(appearance_id: String, weapon_id: String, action_id: String, direction: String, frame_index: int) -> Variant:
	var path := expected_frame_path(appearance_id, weapon_id, action_id, direction, frame_index)
	if path.is_empty():
		return null
	if _frame_cache.has(path):
		return null if _frame_cache[path] == false else path
	if not ResourceLoader.exists(path, "Texture2D"):
		_frame_cache[path] = false
		return null
	_frame_cache[path] = true
	return path


## Loads one frame using ResourceLoader so it works from exported PCK files.
## Returns null for missing slots, invalid input, or non-texture resources.
static func load_frame(appearance_id: String, weapon_id: String, action_id: String, direction: String, frame_index: int) -> Texture2D:
	var path_value: Variant = get_frame_path(appearance_id, weapon_id, action_id, direction, frame_index)
	if path_value == null:
		return null
	var path := str(path_value)
	var cached: Variant = _frame_cache.get(path, null)
	if cached is Texture2D:
		return cached as Texture2D
	var texture := ResourceLoader.load(path, "Texture2D") as Texture2D
	_frame_cache[path] = texture if texture != null else false
	return texture


## Only uses an animation frame after the complete direction clip is present.
## This prevents a partially delivered sequence from flashing between art and
## the caller's existing portrait fallback.
static func load_frame_or_fallback(appearance_id: String, weapon_id: String, action_id: String, direction: String, frame_index: int, portrait_fallback: Texture2D = null) -> Texture2D:
	var complete := has_complete_direction(appearance_id, weapon_id, action_id, direction)
	var texture := load_frame(appearance_id, weapon_id, action_id, direction, frame_index) if complete else null
	return _select_animation_or_fallback(texture, portrait_fallback, complete)


## True only when every frame in the requested source/render direction exists.
## Mirrored directions share their corresponding source-direction sequence.
static func has_complete_direction(appearance_id: String, weapon_id: String, action_id: String, direction: String) -> bool:
	var frame_count := get_frame_count(appearance_id, weapon_id, action_id)
	if frame_count <= 0 or resolve_direction(direction).is_empty():
		return false
	var paths: Array[Variant] = []
	for frame_index: int in range(frame_count):
		paths.append(get_frame_path(appearance_id, weapon_id, action_id, direction, frame_index))
	return _has_complete_paths(paths, frame_count)


## Call after editor-side asset delivery if a running tool session has already
## cached empty slots. Exported game builds normally need no cache invalidation.
static func clear_cache() -> void:
	_frame_cache.clear()


static func _is_valid_clip(appearance_id: String, weapon_id: String, action_id: String) -> bool:
	return APPEARANCE_IDS.has(appearance_id) and WEAPON_IDS.has(weapon_id) and _ACTION_METADATA.has(action_id)


static func _has_complete_paths(paths: Array, expected_frame_count: int) -> bool:
	if expected_frame_count <= 0 or paths.size() != expected_frame_count:
		return false
	for path_value: Variant in paths:
		if typeof(path_value) != TYPE_STRING or str(path_value).is_empty():
			return false
	return true


static func _select_animation_or_fallback(animation_frame: Texture2D, portrait_fallback: Texture2D, complete: bool) -> Texture2D:
	if complete and animation_frame != null:
		return animation_frame
	return portrait_fallback
