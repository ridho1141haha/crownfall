class_name PauseMenu
extends CanvasLayer

const SETTINGS_PATH: String = "user://settings.cfg"
const MAIN_MENU_SCENE: String = "res://scenes/main/Main.tscn"

var _session: Node = null
var _backdrop: ColorRect = null
var _main_box: VBoxContainer = null
var _settings_box: VBoxContainer = null
var _volume_slider: HSlider = null
var _volume_val_label: Label = null
var _fullscreen_check: CheckButton = null
var _status_label: Label = null


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()
	_load_settings()


func bind_session(session: Node) -> void:
	_session = session


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()
		get_viewport().set_input_as_handled()


func toggle_pause() -> void:
	if get_tree() == null:
		return
	var next_paused: bool = not get_tree().paused
	get_tree().paused = next_paused
	visible = next_paused
	if next_paused:
		_show_main_panel()
		if _status_label != null:
			_status_label.text = ""


func set_master_volume(linear_val: float) -> void:
	var clamped: float = clampf(linear_val, 0.0, 1.0)
	var bus_idx: int = AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		AudioServer.set_bus_mute(bus_idx, clamped <= 0.001)
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(maxf(clamped, 0.001)))
	if _volume_val_label != null:
		_volume_val_label.text = "%d%%" % int(roundf(clamped * 100.0))


func _build_ui() -> void:
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.04, 0.05, 0.09, 0.72)
	add_child(_backdrop)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.add_child(center)

	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 0)
	center.add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var root_vbox: VBoxContainer = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(root_vbox)

	_main_box = VBoxContainer.new()
	_main_box.add_theme_constant_override("separation", 10)
	root_vbox.add_child(_main_box)

	var title: Label = Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_main_box.add_child(title)

	var resume_btn: Button = Button.new()
	resume_btn.text = "Resume [Esc]"
	resume_btn.pressed.connect(toggle_pause)
	_main_box.add_child(resume_btn)

	var save_btn: Button = Button.new()
	save_btn.text = "Save Game"
	save_btn.pressed.connect(_on_save_pressed)
	_main_box.add_child(save_btn)

	var settings_btn: Button = Button.new()
	settings_btn.text = "Settings"
	settings_btn.pressed.connect(_show_settings_panel)
	_main_box.add_child(settings_btn)

	var menu_btn: Button = Button.new()
	menu_btn.text = "Return to Main Menu"
	menu_btn.pressed.connect(_on_main_menu_pressed)
	_main_box.add_child(menu_btn)

	_status_label = Label.new()
	_status_label.text = ""
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_main_box.add_child(_status_label)

	_settings_box = VBoxContainer.new()
	_settings_box.add_theme_constant_override("separation", 10)
	_settings_box.visible = false
	root_vbox.add_child(_settings_box)

	var s_title: Label = Label.new()
	s_title.text = "SETTINGS"
	s_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_settings_box.add_child(s_title)

	var vol_row: HBoxContainer = HBoxContainer.new()
	_settings_box.add_child(vol_row)

	var vol_lbl: Label = Label.new()
	vol_lbl.text = "Master Volume"
	vol_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vol_row.add_child(vol_lbl)

	_volume_val_label = Label.new()
	_volume_val_label.text = "100%"
	vol_row.add_child(_volume_val_label)

	_volume_slider = HSlider.new()
	_volume_slider.min_value = 0.0
	_volume_slider.max_value = 1.0
	_volume_slider.step = 0.05
	_volume_slider.value = 1.0
	_volume_slider.value_changed.connect(_on_volume_changed)
	_settings_box.add_child(_volume_slider)

	_fullscreen_check = CheckButton.new()
	_fullscreen_check.text = "Fullscreen"
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	_settings_box.add_child(_fullscreen_check)

	var back_btn: Button = Button.new()
	back_btn.text = "Back"
	back_btn.pressed.connect(_show_main_panel)
	_settings_box.add_child(back_btn)


func _show_main_panel() -> void:
	if _main_box != null:
		_main_box.visible = true
	if _settings_box != null:
		_settings_box.visible = false


func _show_settings_panel() -> void:
	if _main_box != null:
		_main_box.visible = false
	if _settings_box != null:
		_settings_box.visible = true


func _on_volume_changed(val: float) -> void:
	set_master_volume(val)
	_save_settings()


func _on_fullscreen_toggled(enabled: bool) -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)
	_save_settings()


func _on_save_pressed() -> void:
	if _session != null and _session.has_method("_on_manual_save"):
		var ok: bool = bool(_session.call("_on_manual_save"))
		if _status_label != null:
			_status_label.text = "Saved!" if ok else "Cannot save during Night!"


func _on_main_menu_pressed() -> void:
	if get_tree() != null:
		get_tree().paused = false
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _save_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("audio", "master_volume", _volume_slider.value if _volume_slider != null else 1.0)
	cfg.set_value("display", "fullscreen", _fullscreen_check.button_pressed if _fullscreen_check != null else false)
	cfg.save(SETTINGS_PATH)


func _load_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		set_master_volume(1.0)
		return
	var vol: float = float(cfg.get_value("audio", "master_volume", 1.0))
	var fs: bool = bool(cfg.get_value("display", "fullscreen", false))
	if _volume_slider != null:
		_volume_slider.set_value_no_signal(vol)
	set_master_volume(vol)
	if _fullscreen_check != null:
		_fullscreen_check.set_pressed_no_signal(fs)
	if fs and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
