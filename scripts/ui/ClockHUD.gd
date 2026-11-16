extends CanvasLayer

@export var time_manager: TimeManager

var _session: ForgottenShoreSession
var research_label: Label = null
var structures_label: Label = null

@onready var status_label: Label = $MarginContainer/VBoxContainer/StatusLabel as Label
@onready var resources_label: Label = $MarginContainer/VBoxContainer/ResourcesLabel as Label
@onready var feedback_label: Label = $MarginContainer/VBoxContainer/FeedbackLabel as Label
@onready var forecast_label: Label = get_node_or_null("MarginContainer/VBoxContainer/ForecastLabel") as Label
@onready var population_label: Label = get_node_or_null("MarginContainer/VBoxContainer/PopulationLabel") as Label


func set_forecast_text(txt: String) -> void:
	if forecast_label != null:
		forecast_label.text = txt


func set_population_text(txt: String) -> void:
	if population_label != null:
		population_label.text = txt


func _ensure_research_label() -> void:
	if research_label != null:
		return
	var vbox: Node = get_node_or_null("MarginContainer/VBoxContainer")
	if vbox == null:
		return
	research_label = Label.new()
	vbox.add_child(research_label)


func set_research_text(txt: String) -> void:
	_ensure_research_label()
	if research_label != null:
		research_label.text = txt


## Phase 5: passive blessings line (presentation only — the authoritative
## state lives in StructureDomain / ProgressionState facts).
func _ensure_structures_label() -> void:
	if structures_label != null:
		return
	var vbox: Node = get_node_or_null("MarginContainer/VBoxContainer")
	if vbox == null:
		return
	structures_label = Label.new()
	structures_label.modulate = Color(0.62, 0.92, 0.85, 1.0)
	vbox.add_child(structures_label)


func set_structures_text(txt: String) -> void:
	_ensure_structures_label()
	if structures_label != null:
		structures_label.text = txt


func show_victory_banner(title: String, subtitle: String) -> void:
	var overlay: ColorRect = ColorRect.new()
	overlay.color = Color(0.02, 0.02, 0.06, 1.0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.modulate.a = 0.0
	add_child(overlay)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var box: VBoxContainer = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)
	var title_lbl: Label = Label.new()
	title_lbl.text = title
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 42)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4, 1.0))
	box.add_child(title_lbl)
	var sub_lbl: Label = Label.new()
	sub_lbl.text = subtitle
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_color_override("font_color", Color(0.92, 0.92, 0.95, 1.0))
	box.add_child(sub_lbl)
	var tw: Tween = create_tween()
	tw.tween_property(overlay, "modulate:a", 1.0, 0.5)
	tw.tween_interval(7.0)
	tw.tween_property(overlay, "modulate:a", 0.0, 0.8)
	tw.tween_callback(overlay.queue_free)


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
	if not _session.economy.balance_changed.is_connected(_on_balance_changed):
		_session.economy.balance_changed.connect(_on_balance_changed)
	if not _session.feedback_message.is_connected(_on_feedback_message):
		_session.feedback_message.connect(_on_feedback_message)
	if _session.era_mgr != null and not _session.era_mgr.era_changed.is_connected(_on_era_changed):
		_session.era_mgr.era_changed.connect(_on_era_changed)
	_refresh_resources()
	_refresh_clock()


func _on_era_changed(_era_id: String, _era_name: String) -> void:
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
	if _session != null and _session.era_mgr != null:
		status_label.text = "Day %d  •  %s  •  %s" % [time_manager.current_day, time_manager.get_phase_name(), _session.era_mgr.get_era_name()]
	else:
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
