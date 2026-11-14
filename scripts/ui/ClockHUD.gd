extends CanvasLayer

@export var time_manager: TimeManager

var _session: ForgottenShoreSession

@onready var status_label: Label = $MarginContainer/VBoxContainer/StatusLabel as Label
@onready var resources_label: Label = $MarginContainer/VBoxContainer/ResourcesLabel as Label
@onready var feedback_label: Label = $MarginContainer/VBoxContainer/FeedbackLabel as Label
@onready var forecast_label: Label = get_node_or_null("MarginContainer/VBoxContainer/ForecastLabel") as Label


func set_forecast_text(txt: String) -> void:
	if forecast_label != null:
		forecast_label.text = txt


func _ready() -> void:
	if time_manager != null:
		time_manager.daylight_started.connect(_on_phase_changed)
		time_manager.sunset_started.connect(_on_phase_changed)
		time_manager.night_started.connect(_on_phase_changed)
	_refresh_clock()


func bind_session(session: ForgottenShoreSession) -> void:
	_session = session
	if _session == null:
		return
	_session.economy.balance_changed.connect(_on_balance_changed)
	_session.feedback_message.connect(_on_feedback_message)
	_refresh_resources()
	_refresh_clock()


func _on_phase_changed(_day_number: int) -> void:
	_refresh_clock()


func _on_balance_changed(_res_id: StringName, _new_val: int) -> void:
	_refresh_resources()


func _on_feedback_message(msg: String) -> void:
	if feedback_label != null:
		feedback_label.text = msg


func _refresh_clock() -> void:
	if time_manager == null or status_label == null:
		return
	status_label.text = "Day %d  •  %s" % [time_manager.current_day, time_manager.get_phase_name()]


func _refresh_resources() -> void:
	if _session == null or resources_label == null:
		return
	var b: Dictionary = _session.economy.get_all_balances()
	resources_label.text = "Gold: %d   |   Wood: %d   |   Stone: %d" % [
		int(b["gold"]),
		int(b["wood"]),
		int(b["stone"]),
	]
