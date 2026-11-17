class_name PrologueExplorer
extends Node2D

## N4.3-A dedicated Prologue exploration actor (technical spike).
##
## Owns ONLY character movement, animation, and its camera — no gameplay
## commands, no economy/save/NPC systems, no interaction logic (N4.3-B adds
## inspection through the stage, not here). It deliberately does NOT reuse the
## full gameplay PlayerController: that script carries world commands
## (upgrade_tier/recruit/build/save/...) the Prologue must never expose.
##
## Movement contract: the road is flat and authored, so there is no gravity
## and no vertical input — the actor walks horizontally along the road and is
## clamped to the stage bounds every frame, so it can never escape the authored
## area. Input is polled from the EXISTING gameplay actions ("move_left" /
## "move_right") only when input_enabled; during dialogue the stage-owned
## PlayerControlLock disables this node's _physics_process entirely (the same
## mechanism the runner uses on the shell), so held movement keys cannot move
## the actor. Art: the existing player_monarch_sheet.png, frames 0-3 idle /
## 4-7 walk (identical convention to scripts/player/Player.gd).

const MOVE_SPEED: float = 260.0
const IDLE_FRAMES_PER_SECOND: float = 5.0
const WALK_FRAMES_PER_SECOND: float = 10.0
const WALK_FRAME_BASE: int = 4
const FRAME_COUNT: int = 4
const CAMERA_ZOOM: float = 1.5
const CAMERA_OFFSET: Vector2 = Vector2(0.0, -80.0)
const CAMERA_SMOOTHING: float = 6.0
const FACING_THRESHOLD: float = 0.05

var _sprite: Sprite2D = null
var _camera: Camera2D = null
var _input_enabled: bool = false
var _min_x: float = 0.0
var _max_x: float = 0.0
var _facing_direction: int = 1
var _anim_time: float = 0.0
var _frozen: bool = false


## Builds the actor. texture must be a valid Texture2D (the caller fails
## closed on load errors before construction); bounds are the authored road
## extent and camera_limit_top/bottom the authored vertical view band.
func _init(texture: Texture2D, min_x: float, max_x: float, ground_y: float, camera_limit_top: float, camera_limit_bottom: float) -> void:
	_min_x = min_x
	_max_x = max_x
	position = Vector2(min_x, ground_y)
	_sprite = Sprite2D.new()
	_sprite.texture = texture
	_sprite.hframes = 8
	_sprite.centered = false
	_sprite.offset = Vector2(-16, -32)
	add_child(_sprite)
	_camera = Camera2D.new()
	_camera.position = CAMERA_OFFSET
	_camera.zoom = Vector2(CAMERA_ZOOM, CAMERA_ZOOM)
	_camera.limit_left = int(min_x)
	_camera.limit_right = int(max_x)
	_camera.limit_top = int(camera_limit_top)
	_camera.limit_bottom = int(camera_limit_bottom)
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = CAMERA_SMOOTHING
	add_child(_camera)


func _ready() -> void:
	_camera.make_current()


func _physics_process(delta: float) -> void:
	if _frozen:
		return
	var direction: float = 0.0
	if _input_enabled:
		direction = Input.get_axis("move_left", "move_right")
	if direction > FACING_THRESHOLD:
		_facing_direction = 1
	elif direction < -FACING_THRESHOLD:
		_facing_direction = -1
	if direction != 0.0:
		position.x = clampf(position.x + direction * MOVE_SPEED * delta, _min_x, _max_x)
	_update_sprite_animation(delta, absf(direction) > FACING_THRESHOLD)


## Stage-level movement gate (dialogue/transitions/cancellation/teardown).
## Independent of the PlayerControlLock physics gate: the actor only moves
## when input is enabled AND its physics processing is not lock-disabled.
func set_input_enabled(enabled: bool) -> void:
	_input_enabled = enabled


func is_input_enabled() -> bool:
	return _input_enabled


## Teardown/segment-end freeze: stops processing regardless of lock state.
## Idempotent and safe for already-freed sibling nodes (this node owns only
## its own children). Lock restoration never re-enables movement on its own
## because input stays disabled until the stage explicitly re-enables it.
func freeze() -> void:
	_frozen = true
	set_physics_process(false)


func camera() -> Camera2D:
	return _camera


func sprite() -> Sprite2D:
	return _sprite


func facing_direction() -> int:
	return _facing_direction


func _update_sprite_animation(delta: float, is_moving: bool) -> void:
	if _sprite == null:
		return
	_sprite.flip_h = _facing_direction < 0
	_anim_time += delta
	if is_moving:
		# Frames 4..7 = walk cycle at 10 FPS (same convention as gameplay).
		_sprite.frame = WALK_FRAME_BASE + (int(floorf(_anim_time * WALK_FRAMES_PER_SECOND)) % FRAME_COUNT)
	else:
		# Frames 0..3 = idle breathing cycle at 5 FPS.
		_sprite.frame = int(floorf(_anim_time * IDLE_FRAMES_PER_SECOND)) % FRAME_COUNT
