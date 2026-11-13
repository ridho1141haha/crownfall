extends ColorRect

@export var time_manager: TimeManager

const DAY_COLOR: Color = Color(0.235, 0.439, 0.627, 1.0)
const SUNSET_COLOR: Color = Color(0.565, 0.251, 0.235, 1.0)
const NIGHT_COLOR: Color = Color(0.055, 0.075, 0.145, 1.0)


func _process(_delta: float) -> void:
	if time_manager == null:
		return
	var t: float = time_manager.get_phase_progress()
	match time_manager.current_phase:
		TimeManager.Phase.DAYLIGHT:
			color = DAY_COLOR.lerp(SUNSET_COLOR, smoothstep(0.75, 1.0, t))
		TimeManager.Phase.SUNSET:
			color = SUNSET_COLOR.lerp(NIGHT_COLOR, t)
		TimeManager.Phase.NIGHT:
			color = NIGHT_COLOR.lerp(DAY_COLOR, smoothstep(0.8, 1.0, t))
