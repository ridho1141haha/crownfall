extends ColorRect

@export var time_manager: TimeManager
@export var canvas_modulate: CanvasModulate
@export var campfire_light: PointLight2D
@onready var atmosphere_overlay: ColorRect = get_node_or_null("../../ClockHUD/AtmosphereOverlay") as ColorRect

const DAY_SKY: Color = Color(0.22, 0.42, 0.62, 1.0)
const SUNSET_SKY: Color = Color(0.58, 0.26, 0.22, 1.0)
const NIGHT_SKY: Color = Color(0.05, 0.07, 0.14, 1.0)

const DAY_MOD: Color = Color(1.0, 1.0, 1.0, 1.0)
const SUNSET_MOD: Color = Color(0.95, 0.68, 0.56, 1.0)
const NIGHT_MOD: Color = Color(0.28, 0.34, 0.52, 1.0)

var _flicker_time: float = 0.0


func _process(delta: float) -> void:
	_flicker_time += delta
	if time_manager != null:
		var t: float = time_manager.get_phase_progress()
		match time_manager.current_phase:
			TimeManager.Phase.DAYLIGHT:
				var w: float = smoothstep(0.75, 1.0, t)
				color = DAY_SKY.lerp(SUNSET_SKY, w)
				if canvas_modulate != null:
					canvas_modulate.color = DAY_MOD.lerp(SUNSET_MOD, w)
			TimeManager.Phase.SUNSET:
				color = SUNSET_SKY.lerp(NIGHT_SKY, t)
				if canvas_modulate != null:
					canvas_modulate.color = SUNSET_MOD.lerp(NIGHT_MOD, t)
			TimeManager.Phase.NIGHT:
				var w: float = smoothstep(0.82, 1.0, t)
				color = NIGHT_SKY.lerp(DAY_SKY, w)
				if canvas_modulate != null:
					canvas_modulate.color = NIGHT_MOD.lerp(DAY_MOD, w)

	if campfire_light != null:
		var base_energy: float = 1.45 if (time_manager != null and time_manager.current_phase != TimeManager.Phase.DAYLIGHT) else 0.75
		campfire_light.energy = base_energy + sin(_flicker_time * 9.0) * 0.12

	if atmosphere_overlay != null and atmosphere_overlay.material is ShaderMaterial and time_manager != null:
		var mat: ShaderMaterial = atmosphere_overlay.material as ShaderMaterial
		var tint: Color = Color(1.0, 1.0, 1.0, 0.0)
		var vig: float = 0.16
		match time_manager.current_phase:
			TimeManager.Phase.SUNSET:
				tint = Color(0.95, 0.45, 0.22, 0.16)
				vig = 0.28
			TimeManager.Phase.NIGHT:
				tint = Color(0.08, 0.12, 0.28, 0.26)
				vig = 0.42
		mat.set_shader_parameter("tint_color", tint)
		mat.set_shader_parameter("vignette_strength", vig)
