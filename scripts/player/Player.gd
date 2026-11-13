extends CharacterBody2D

@export var move_speed: float = 220.0

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity") as float


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

	var direction: float = Input.get_axis("move_left", "move_right")
	velocity.x = direction * move_speed

	move_and_slide()
