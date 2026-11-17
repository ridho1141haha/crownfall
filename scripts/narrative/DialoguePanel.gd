class_name DialoguePanel
extends CanvasLayer

## Minimal dialogue presentation (technical design, section D).
##
## Presentation only: owns no gameplay state and never mutates the economy,
## buildings, NPCs, or progression. While open it consumes ALL unhandled
## input (set_input_as_handled) and advances only on the dedicated
## `dialogue_advance` action, so dialogue input can never leak into movement,
## build, collect, recruit, or other world commands. Gameplay feedback stays
## on ClockHUD.FeedbackLabel — this panel is a separate surface.

signal dialogue_advanced(line_index: int)
signal dialogue_finished()

const PANEL_MIN_WIDTH: float = 900.0
const PANEL_BOTTOM_OFFSET: float = -150.0

var _lines: Array[Dictionary] = []
var _line_index: int = 0
var _open: bool = false
var _speaker_label: Label = null
var _body_label: Label = null
var _hint_label: Label = null


func _init() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	margin.anchor_top = 1.0
	margin.anchor_bottom = 1.0
	margin.offset_top = PANEL_BOTTOM_OFFSET
	margin.add_theme_constant_override("margin_left", 64)
	margin.add_theme_constant_override("margin_right", 64)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(PANEL_MIN_WIDTH, 0.0)
	margin.add_child(panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	_speaker_label = Label.new()
	_speaker_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.4, 1.0))
	vbox.add_child(_speaker_label)

	_body_label = Label.new()
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_body_label)

	_hint_label = Label.new()
	_hint_label.text = "[Enter] advance"
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8, 1.0))
	vbox.add_child(_hint_label)


func is_open() -> bool:
	return _open


## Opens the panel with a non-canon-safe list of {speaker, text} lines
## (validated upstream by NarrativeData). Deep-copies input; never keeps
## caller references.
func open_lines(lines: Array[Dictionary]) -> void:
	_lines.clear()
	for line: Dictionary in lines:
		_lines.append(line.duplicate(true))
	_line_index = 0
	_open = true
	visible = true
	_show_current_line()


## Advances to the next line. Returns true when a next line was shown; on the
## last line it closes the panel and returns false.
func advance() -> bool:
	if not _open:
		return false
	if _line_index + 1 < _lines.size():
		_line_index += 1
		_show_current_line()
		dialogue_advanced.emit(_line_index)
		return true
	close()
	return false


## Closes the panel. Idempotent; emits dialogue_finished exactly once per
## open session so waiting runners always resume.
func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	_lines.clear()
	_line_index = 0
	dialogue_finished.emit()


func _show_current_line() -> void:
	if _line_index < 0 or _line_index >= _lines.size():
		return
	var line: Dictionary = _lines[_line_index]
	if _speaker_label != null:
		_speaker_label.text = String(line.get("speaker", ""))
	if _body_label != null:
		_body_label.text = String(line.get("text", ""))


func get_speaker_text() -> String:
	return _speaker_label.text if _speaker_label != null else ""


func get_body_text() -> String:
	return _body_label.text if _body_label != null else ""


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	# Consume everything while open: dialogue input must never reach gameplay.
	get_viewport().set_input_as_handled()
	var advance_key: bool = event is InputEventKey and event.is_action_pressed("dialogue_advance")
	var advance_mouse: bool = event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and event.is_pressed()
	if advance_key or advance_mouse:
		advance()


func _exit_tree() -> void:
	# Scene-unload cleanup: drop state without emitting into freed nodes.
	_open = false
	visible = false
	_lines.clear()
	_line_index = 0
