class_name PlayerController
extends CharacterBody2D

signal interaction_requested(player_x: float)
signal upgrade_tier_requested(player_x: float)
signal recruit_requested(player_x: float)
signal build_wall_requested(player_x: float)
signal repair_wall_requested(player_x: float)
signal manual_save_requested()
signal fast_clock_toggled()

@export var move_speed: float = 240.0
@export var min_bound_x: float = -1540.0
@export var max_bound_x: float = 1540.0

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity") as float
var facing_direction: int = 1
var _anim_time: float = 0.0

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

	var direction: float = Input.get_axis("move_left", "move_right")
	velocity.x = direction * move_speed
	if direction > 0.05:
		facing_direction = 1
	elif direction < -0.05:
		facing_direction = -1

	move_and_slide()
	global_position.x = clampf(global_position.x, min_bound_x, max_bound_x)
	_update_sprite_animation(delta, absf(direction) > 0.05)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		interaction_requested.emit(global_position.x)
	elif event.is_action_pressed("upgrade_tier"):
		upgrade_tier_requested.emit(global_position.x)
	elif event.is_action_pressed("recruit_villager"):
		recruit_requested.emit(global_position.x)
	elif event.is_action_pressed("build_wall"):
		build_wall_requested.emit(global_position.x)
	elif event.is_action_pressed("repair_wall"):
		repair_wall_requested.emit(global_position.x)
	elif event.is_action_pressed("save_game"):
		manual_save_requested.emit()
	elif event.is_action_pressed("toggle_fast_clock"):
		fast_clock_toggled.emit()


func _update_sprite_animation(delta: float, is_moving: bool) -> void:
	if sprite == null:
		return
	sprite.flip_h = (facing_direction < 0)
	_anim_time += delta
	if is_moving and is_on_floor():
		# Frames 4..7 = walk cycle at 10 FPS
		sprite.frame = 4 + (int(floorf(_anim_time * 10.0)) % 4)
	else:
		# Frames 0..3 = idle breathing cycle at 5 FPS
		sprite.frame = int(floorf(_anim_time * 5.0)) % 4
