class_name PrologueMarkInspectables
extends Node2D

## N4.3-B inspectable mark-object set for the pl_04 exploration beat.
##
## OWNERSHIP (N4.3-B design, section 5): this component owns the authored
## object table + ids, the placeholder prop/mark geometry, the interaction-
## range query, the per-run idempotent inspection state, and the shared
## contextual prompt. It does NOT own interaction input (the stage polls the
## existing `interact` action behind the full D5 gate), the recognition
## dialogue (stage-owned, DialoguePanel), or any completion record
## (PrologueShell is the sole NarrativeState writer). Per-run state dies with
## this node — nothing here is serialized or persists.
##
## PLACEHOLDER DISCIPLINE: all geometry is labelled placeholder ColorRect
## geometry. The mark glyph is ONE identical two-rect placeholder shape on
## every prop (only the tint varies with the surface condition — planning
## section 2); the mark's real design is an OPEN owner decision (U2) and no
## lore is implied. The prompt wording "[E] Inspect" is an explicitly
## provisional placeholder (OPEN decision U5), not canon.
##
## BUILD CONTRACT (D6, fail-closed and atomic): build() validates the whole
## authored table FIRST (non-empty table, >= 2 objects, non-empty unique ids,
## positions inside the authored road bounds) before anything is created,
## then constructs every prop, glyph, and the shared prompt under a temporary
## staging parent that is not in the tree, verifies every node, and only then
## commits the completed construction. Any failure frees the partial
## construction and leaves the component invalid and empty — no partially
## functional inspection system can ever exist. The three factory methods are
## ordinary construction structure (the builder needs them); they also let
## the H9a/H9b test-only subclasses simulate construction failures without
## adding any production test seam.

## Authored interaction range: a genuine short range (about half the explorer
## sprite width). Eligibility is strictly |dx| <= range — a 1-D check, the
## road has no vertical movement.
const INSPECT_RANGE_X: float = 64.0
## Placeholder prompt wording (OPEN decision U5 — owner-approved text later).
const PROMPT_TEXT: String = "[E] Inspect"
## How far above the ground line the shared prompt floats (uniform across
## props — labelled placeholder presentation).
const PROMPT_HEIGHT_ABOVE_GROUND: float = 56.0

## Placeholder surface-condition presentation (tint/size variety only).
const PROP_STONE_COLOR: Color = Color(0.48, 0.46, 0.42, 1.0)
const PROP_FRAGMENT_COLOR: Color = Color(0.38, 0.36, 0.33, 1.0)
const PROP_ARTIFACT_COLOR: Color = Color(0.3, 0.29, 0.27, 1.0)
const GLYPH_STONE_COLOR: Color = Color(0.85, 0.78, 0.45, 1.0)
const GLYPH_FRAGMENT_COLOR: Color = Color(0.66, 0.6, 0.35, 1.0)
const GLYPH_ARTIFACT_COLOR: Color = Color(0.5, 0.45, 0.27, 1.0)
const PROMPT_COLOR: Color = Color(0.95, 0.9, 0.75, 1.0)

var _valid: bool = false
## Per-run inspection state (D1): id -> true. Dies with this node.
var _inspected_ids: Dictionary = {}
## Committed props by id (id -> Node2D at the authored ground position).
var _props: Dictionary = {}
var _prompt: Label = null


## Validates and builds the whole inspectable set atomically. Returns true
## only when the completed construction was committed; on any failure the
## component stays invalid and empty (D6 fail-closed). Rejects a second
## successful build (the set is built once per stage setup).
func build(road_min_x: float, road_max_x: float, ground_y: float) -> bool:
	if _valid:
		return false
	if not _validate_table(road_min_x, road_max_x):
		return false
	# Atomic construction: everything is built under a staging parent that is
	# NOT in the tree yet; a fully verified build is committed in one step.
	var staging: Node2D = Node2D.new()
	staging.name = "MarkProps"
	var built: Dictionary = {}
	var ok: bool = true
	for entry: Dictionary in _authored_table():
		var id := String(entry["id"])
		var condition := String(entry["condition"])
		var prop := _create_prop(String(entry["name"]), condition, float(entry["x"]), ground_y)
		if prop == null:
			ok = false
			break
		# Commit the prop to staging IMMEDIATELY: from here on staging.free()
		# releases every partial, so no created node can ever be orphaned.
		staging.add_child(prop)
		var glyph := _create_mark_glyph(condition)
		if glyph == null:
			ok = false
			break
		glyph.position = Vector2(0.0, -_prop_size(condition).y * 0.5)
		prop.add_child(glyph)
		built[id] = prop
	if ok:
		_prompt = _create_prompt()
		if _prompt == null:
			ok = false
	if ok and built.size() != _authored_table().size():
		ok = false
	if ok:
		# Commit: every node verified non-null — the construction goes live.
		add_child(staging)
		add_child(_prompt)
		_props = built
		_valid = true
	else:
		staging.free()
		_prompt = null
		_props = {}
	return _valid


func is_valid() -> bool:
	return _valid


## The nearest inspectable within the authored interaction range of at_x
## ("" when none is in range). Nearest wins; a tie keeps the first authored
## object (spacing makes exact ties impossible in practice).
func nearest_eligible_id(at_x: float) -> String:
	if not _valid:
		return ""
	var best_id := ""
	var best_dx := INF
	for entry: Dictionary in _authored_table():
		var dx := absf(float(entry["x"]) - at_x)
		if dx <= INSPECT_RANGE_X and dx < best_dx:
			best_id = String(entry["id"])
			best_dx = dx
	return best_id


## Records the inspection of one object. Returns true only on the FIRST
## inspection of that id (D1: idempotent — a repeat is a no-op that never
## increases progress and never opens anything). Unknown ids are rejected.
func mark_inspected(id: String) -> bool:
	if not _valid or id.is_empty() or not _props.has(id):
		return false
	if _inspected_ids.has(id):
		return false
	_inspected_ids[id] = true
	return true


func is_inspected(id: String) -> bool:
	return _inspected_ids.has(id)


func distinct_inspected_count() -> int:
	return _inspected_ids.size()


## Shows the shared contextual prompt above the target object, or hides it
## for "" / unknown ids. The stage re-evaluates the target every physics
## frame (design section 7 step 3), so this only applies the requested state.
func set_prompt_target(id: String) -> void:
	if _prompt == null:
		return
	if id.is_empty() or not _props.has(id):
		_prompt.visible = false
		return
	var prop: Node2D = _props[id]
	_prompt.visible = true
	_prompt.position = Vector2(prop.position.x - _prompt.custom_minimum_size.x * 0.5, prop.position.y - PROMPT_HEIGHT_ABOVE_GROUND)


## The shared prompt label (test observability; presentation only).
func prompt() -> Label:
	return _prompt


## The authored object definition table (data only — mirrors the
## PrologueBeats._beats() data-accessor style). An instance method rather
## than a bare const so the D6 test-only subclasses can supply variant
## tables without adding any production test seam. Proposed placements are
## tunable (OPEN decision U4): two objects sit within a short walk of the
## east-end handoff area where pl_04 starts, the third is the optional
## far-west reinforcement.
func _authored_table() -> Array[Dictionary]:
	return [
		{"id": "mark_stone_a", "name": "MarkStoneA", "x": 430.0, "condition": "stone"},
		{"id": "mark_fragment_b", "name": "MarkFragmentB", "x": 630.0, "condition": "fragment"},
		{"id": "mark_artifact_c", "name": "MarkArtifactC", "x": -280.0, "condition": "artifact"},
	]


## D6 validation: the whole table is checked BEFORE anything is built.
func _validate_table(road_min_x: float, road_max_x: float) -> bool:
	var table := _authored_table()
	if table.is_empty() or table.size() < 2:
		return false
	var seen_ids: Dictionary = {}
	for entry: Dictionary in table:
		var id := String(entry.get("id", ""))
		if id.is_empty() or seen_ids.has(id):
			return false
		seen_ids[id] = true
		var x := float(entry.get("x", NAN))
		if is_nan(x) or x < road_min_x or x > road_max_x:
			return false
	return true


func _create_prop(node_name: String, condition: String, x: float, ground_y: float) -> Node2D:
	var prop := Node2D.new()
	prop.name = node_name
	prop.position = Vector2(x, ground_y)
	var body := ColorRect.new()
	body.name = "Body"
	body.color = _prop_color(condition)
	body.position = Vector2(-_prop_size(condition).x * 0.5, -_prop_size(condition).y)
	body.size = _prop_size(condition)
	prop.add_child(body)
	return prop


## The ONE placeholder mark shape, identical on every prop: a small two-rect
## plus-mark. Only the tint varies with the surface condition (planning
## section 2); geometry and size are constant (U2 stays OPEN).
func _create_mark_glyph(condition: String) -> Node2D:
	var glyph := Node2D.new()
	glyph.name = "MarkGlyph"
	var vertical := ColorRect.new()
	vertical.name = "MarkGlyphVertical"
	vertical.color = _glyph_color(condition)
	vertical.position = Vector2(-1.5, -6.0)
	vertical.size = Vector2(3.0, 12.0)
	glyph.add_child(vertical)
	var horizontal := ColorRect.new()
	horizontal.name = "MarkGlyphHorizontal"
	horizontal.color = _glyph_color(condition)
	horizontal.position = Vector2(-5.0, -1.5)
	horizontal.size = Vector2(10.0, 3.0)
	glyph.add_child(horizontal)
	return glyph


func _create_prompt() -> Label:
	var label := Label.new()
	label.name = "InspectPrompt"
	label.text = PROMPT_TEXT
	label.custom_minimum_size = Vector2(96.0, 0.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", PROMPT_COLOR)
	label.visible = false
	return label


func _prop_size(condition: String) -> Vector2:
	match condition:
		"fragment":
			return Vector2(22.0, 20.0)
		"artifact":
			return Vector2(34.0, 14.0)
		_:
			return Vector2(28.0, 36.0)


func _prop_color(condition: String) -> Color:
	match condition:
		"fragment":
			return PROP_FRAGMENT_COLOR
		"artifact":
			return PROP_ARTIFACT_COLOR
		_:
			return PROP_STONE_COLOR


func _glyph_color(condition: String) -> Color:
	match condition:
		"fragment":
			return GLYPH_FRAGMENT_COLOR
		"artifact":
			return GLYPH_ARTIFACT_COLOR
		_:
			return GLYPH_STONE_COLOR
