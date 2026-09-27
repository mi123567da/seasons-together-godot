extends CharacterBody2D

const BITMAP_CATALOG := preload("res://scripts/bitmap_animation_catalog.gd")
const MOVE_SPEED := 235.0
const PORTRAIT_SCALE := Vector2(0.105, 0.105)
const ANIMATION_SCALE := Vector2(0.5, 0.5)
const DIAGONAL_CUTOFF := 2.41421356237

var _avatar: Sprite2D
var _portrait_texture: Texture2D
var _appearance_id := "female"
var _weapon_id := "bow"
var _animation_elapsed := 0.0
var _last_render_key := ""
var movement_enabled := true
var movement_bounds := Rect2(200.0, 200.0, 880.0, 392.0)
var animation_action := "idle"
var animation_direction := "S"
var animation_frame := 0
var animation_flip_h := false


func configure_avatar(gender: String, woman_texture: Texture2D, man_texture: Texture2D, weapon_id: String = "bow") -> void:
	if _avatar == null:
		_avatar = Sprite2D.new()
		_avatar.name = "ApprovedAvatarPlaceholder"
		_avatar.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(_avatar)
	_appearance_id = "female" if gender in ["female", "woman"] else "male"
	_weapon_id = weapon_id if BITMAP_CATALOG.WEAPON_IDS.has(weapon_id) else "bow"
	_portrait_texture = woman_texture if _appearance_id == "female" else man_texture
	_animation_elapsed = 0.0
	animation_frame = 0
	_last_render_key = ""
	_render_animation_frame()


func _physics_process(delta: float) -> void:
	if not movement_enabled:
		velocity = Vector2.ZERO
		move_and_slide()
		_update_animation(delta, Vector2.ZERO)
		return
	var direction := Input.get_vector("hub_left", "hub_right", "hub_up", "hub_down")
	velocity = direction * MOVE_SPEED
	move_and_slide()
	position = Vector2(
		clampf(position.x, movement_bounds.position.x, movement_bounds.end.x),
		clampf(position.y, movement_bounds.position.y, movement_bounds.end.y)
	)
	_update_animation(delta, direction)


func _update_animation(delta: float, move_direction: Vector2) -> void:
	var next_action := "run" if move_direction.length_squared() > 0.01 else "idle"
	var next_direction := _direction_name(move_direction) if next_action == "run" else animation_direction
	if next_action != animation_action or next_direction != animation_direction:
		_animation_elapsed = 0.0
		_last_render_key = ""
	animation_action = next_action
	animation_direction = next_direction
	_animation_elapsed += delta
	var metadata: Dictionary = BITMAP_CATALOG.get_action_metadata(animation_action)
	var frame_count := BITMAP_CATALOG.get_frame_count(_appearance_id, _weapon_id, animation_action)
	if frame_count <= 0 or metadata.is_empty():
		_show_portrait(false)
		return
	var fps := maxf(float(metadata.get("fps", 0.0)), 0.0)
	if fps <= 0.0:
		_show_portrait(false)
		return
	var frame_index := int(floor(_animation_elapsed * fps))
	if bool(metadata.get("loop", false)):
		frame_index %= frame_count
	else:
		frame_index = mini(frame_index, frame_count - 1)
	animation_frame = frame_index
	_render_animation_frame()


func _direction_name(direction: Vector2) -> String:
	if direction.length_squared() <= 0.01:
		return animation_direction
	var horizontal := "E" if direction.x > 0.0 else "W"
	var vertical := "S" if direction.y > 0.0 else "N"
	var abs_x := absf(direction.x)
	var abs_y := absf(direction.y)
	if abs_x > abs_y * DIAGONAL_CUTOFF:
		return horizontal
	if abs_y > abs_x * DIAGONAL_CUTOFF:
		return vertical
	return vertical + horizontal


func _render_animation_frame() -> void:
	if _avatar == null or _portrait_texture == null:
		return
	var orientation: Dictionary = BITMAP_CATALOG.resolve_direction(animation_direction)
	if orientation.is_empty():
		_show_portrait(false)
		return
	animation_flip_h = bool(orientation.get("flip_h", false))
	var render_key := "%s|%s|%s|%s|%d" % [
		_appearance_id,
		_weapon_id,
		animation_action,
		animation_direction,
		animation_frame,
	]
	if render_key == _last_render_key:
		return
	_last_render_key = render_key
	var animated_texture: Texture2D = BITMAP_CATALOG.load_frame_or_fallback(
		_appearance_id,
		_weapon_id,
		animation_action,
		animation_direction,
		animation_frame,
		_portrait_texture,
	)
	if animated_texture == _portrait_texture:
		_show_portrait(animation_flip_h)
	else:
		_show_animated_frame(animated_texture, animation_flip_h)


func _show_portrait(flip_h: bool) -> void:
	if _avatar == null or _portrait_texture == null:
		return
	_avatar.texture = _portrait_texture
	_avatar.centered = true
	_avatar.offset = Vector2.ZERO
	_avatar.position = Vector2.ZERO
	_avatar.scale = PORTRAIT_SCALE
	_avatar.flip_h = flip_h


func _show_animated_frame(texture: Texture2D, flip_h: bool) -> void:
	_avatar.texture = texture
	_avatar.centered = false
	_avatar.offset = -Vector2(BITMAP_CATALOG.FRAME_SIZE) * BITMAP_CATALOG.get_anchor_normalized()
	_avatar.position = Vector2.ZERO
	_avatar.scale = ANIMATION_SCALE
	_avatar.flip_h = flip_h
