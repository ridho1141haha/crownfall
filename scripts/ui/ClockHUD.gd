extends CanvasLayer

@export var time_manager: TimeManager
@onready var status_label: Label = $MarginContainer/StatusLabel


func _ready() -> void:
	if time_manager == null:
		return
	time_manager.daylight_started.connect(_on_phase_changed)
	time_manager.sunset_started.connect(_on_phase_changed)
	time_manager.night_started.connect(_on_phase_changed)
	_refresh_label()


func _on_phase_changed(_day_number: int) -> void:
	_refresh_label()


func _refresh_label() -> void:
	if time_manager == null or status_label == null:
		return
	status_label.text = "Day %d  •  %s" % [time_manager.current_day, time_manager.get_phase_name()]
