class_name PrologueRuinsEnvironment
extends Node2D

## N4.4-A ruins environment component: the placeholder ruin zones, the hidden
## chamber reveal trigger, and the altar area east of the N4.3 road.
##
## OWNERSHIP (N4.4 architecture design, section 3.1 — stage-owned child,
## the proven PrologueMarkInspectables component pattern): this component owns
## the authored zone table + thresholds, the placeholder zone presentation
## (exterior façade, interior passage, chamber), the identical U2-placeholder
## mark glyphs on ruin surfaces (environmental storytelling scenery, NOT
## inspectable), the one-way zone-state machine, and the reveal presentation.
## It does NOT own interaction input, any dialogue, or any completion record:
## the stage polls update_explorer_x() per physics frame during pl_05 and
## emits its own ONE `ruins_altar_reached` request at the authored altar
## threshold; PrologueShell validates the active beat and records. Zero
## stage-to-component signal connections are needed in N4.4-A (the stage
## polls state), so there is no duplicate-connection surface.
##
## PLACEHOLDER DISCIPLINE: all geometry is labelled placeholder ColorRect
## geometry — no art assets ship in N4.4-A (verified asset inventory: the
## repo ships no ruin/altar/crown art). The mark glyph is the SAME identical
## two-rect placeholder shape as the N4.3-B props (U2 stays OPEN — one
## consistent design, meaning mysterious). No name is ever shown for the
## ruins (Story Design §10: "Name of the ruins — OPEN, may remain unnamed")
## and no text/lore is implied by any surface.
##
## DORMANT pl_06 NOTE (N4.4-A boundary): the altar is the pl_05 COMPLETION
## boundary only. The crown is a labelled visual continuity placeholder —
## the crown interaction (N4.4-C), the awakening, and the fragmented vision
## (N4.4-D) are deliberately NOT implemented here, and nothing in this
## component stages any of that future content.
##
## BUILD CONTRACT (D6, fail-closed and atomic — mirrors PrologueMarkInspectables):
## build() validates the whole threshold table FIRST (ordered thresholds,
## strictly inside the authored band, vertical extents sane) before anything
## is created, then constructs every node under a temporary staging parent
## that is not in the tree, verifies every node, and only then commits the
## completed construction. Any failure frees the partial construction and
## leaves the component invalid and EMPTY — no partial ruin can ever exist.
## The factory methods are ordinary construction structure (the builder needs
## them); they also let the test-only subclasses simulate construction failures
## without adding any production test seam.
##
## ZONE-STATE MACHINE (N4.4 architecture design, section 5.2): EXTERIOR ->
## INTERIOR_PASSAGE -> CHAMBER_REVEALED, driven one-way by the explorer's x
## against the authored thresholds. Backtracking west never un-reveals and
## never re-fires a state change; the altar check is the STAGE's one-shot
## request, not a zone state. All per-run state dies with this node.

signal zone_state_changed(new_state: int)
## Emitted exactly once per component lifetime, when the chamber reveal
## trigger is crossed (the N4.4-A "hidden chamber discovery" presentation:
## the altar group becomes visible). Presentation-only — nothing records.
signal chamber_revealed()

## Authored zone thresholds (feasible-scale placeholders — OPEN decision O7;
## the band extends east from the N4.3 road end, zoom-1.5 framing verified).
## The exterior zone is everything east of the road's scenic end; the
## interior passage and the hidden chamber follow east.
const EXTERIOR_END_X: float = 1400.0
const INTERIOR_END_X: float = 1800.0
const ALTAR_X: float = 2050.0

## Zone states (one-way; values are test observability, not persisted).
const ZONE_EXTERIOR: int = 0
const ZONE_INTERIOR_PASSAGE: int = 1
const ZONE_CHAMBER_REVEALED: int = 2

## Placeholder presentation palette (no lore; tints only distinguish zones).
const RUIN_WALL_COLOR: Color = Color(0.36, 0.35, 0.38, 1.0)
const PASSAGE_WALL_COLOR: Color = Color(0.3, 0.29, 0.32, 1.0)
const PASSAGE_OVERLAY_COLOR: Color = Color(0.02, 0.02, 0.03, 0.5)
const CHAMBER_OVERLAY_COLOR: Color = Color(0.02, 0.02, 0.03, 0.62)
const ALTAR_STONE_COLOR: Color = Color(0.44, 0.43, 0.47, 1.0)
## Crown placeholder tint follows the existing gold placeholder family (the
## U2 glyph gold) so the continuity object reads without implying any design.
const CROWN_PLACEHOLDER_COLOR: Color = Color(0.85, 0.78, 0.45, 1.0)
const CHAMBER_GLOW_COLOR: Color = Color(0.85, 0.78, 0.45, 0.12)
const RUIN_GLYPH_COLOR: Color = Color(0.85, 0.78, 0.45, 1.0)
## The identical U2-placeholder mark glyph geometry (same two-rect plus-mark
## as PrologueMarkInspectables — one consistent placeholder design).
const GLYPH_VERTICAL_SIZE: Vector2 = Vector2(3.0, 12.0)
const GLYPH_VERTICAL_OFFSET: Vector2 = Vector2(-1.5, -6.0)
const GLYPH_HORIZONTAL_SIZE: Vector2 = Vector2(10.0, 3.0)
const GLYPH_HORIZONTAL_OFFSET: Vector2 = Vector2(-5.0, -1.5)

var _valid: bool = false
var _zone_state: int = ZONE_EXTERIOR
var _chamber_revealed: bool = false
var _altar_group: Node2D = null


## Validates and builds the whole ruins environment atomically. Returns true
## only when the completed construction was committed; on any failure the
## component stays invalid and EMPTY (D6 fail-closed). Rejects a second
## successful build (the environment is built once per stage setup).
func build(road_min_x: float, road_max_x: float, ground_y: float, view_top: float, view_bottom: float) -> bool:
	if _valid:
		return false
	if not _validate_table(road_min_x, road_max_x, ground_y, view_top, view_bottom):
		return false
	# Atomic construction: everything is built under a staging parent that is
	# NOT in the tree yet; a fully verified build is committed in one step.
	var staging: Node2D = Node2D.new()
	staging.name = "RuinsEnvironment"
	var ok: bool = true

	var exterior := _create_exterior_walls(ground_y)
	if exterior == null:
		ok = false
	if ok:
		staging.add_child(exterior)
		var passage_overlay := _create_zone_overlay("InteriorPassageOverlay", EXTERIOR_END_X, INTERIOR_END_X - EXTERIOR_END_X, ground_y, view_top, PASSAGE_OVERLAY_COLOR)
		if passage_overlay == null:
			ok = false
		else:
			staging.add_child(passage_overlay)
	if ok:
		var chamber_overlay := _create_zone_overlay("ChamberOverlay", INTERIOR_END_X, _chamber_end_x(road_max_x) - INTERIOR_END_X, ground_y, view_top, CHAMBER_OVERLAY_COLOR)
		if chamber_overlay == null:
			ok = false
		else:
			staging.add_child(chamber_overlay)
	if ok:
		var passage_walls := _create_passage_and_chamber_walls(ground_y)
		if passage_walls == null:
			ok = false
		else:
			staging.add_child(passage_walls)
	if ok:
		var glyphs := _create_ruin_mark_glyphs(ground_y)
		if glyphs == null:
			ok = false
		else:
			staging.add_child(glyphs)
	if ok:
		_altar_group = _create_altar_group(ground_y)
		if _altar_group == null:
			ok = false
			_altar_group = null
		else:
			_altar_group.visible = false
			staging.add_child(_altar_group)
	if ok:
		# Commit: every node verified non-null — the construction goes live.
		add_child(staging)
		_valid = true
	else:
		staging.free()
		_altar_group = null
	return _valid


func is_valid() -> bool:
	return _valid


func zone_state() -> int:
	return _zone_state


func is_chamber_revealed() -> bool:
	return _chamber_revealed


## The authored altar threshold (the stage's pl_05 completion trigger reads
## this; the stage owns the one-shot emission guard).
func altar_x() -> float:
	return _thresholds()["altar_x"]


## The committed altar group (test observability; presentation only).
func altar_group() -> Node2D:
	return _altar_group


## Advances the one-way zone state from the explorer's x. Backtracking west
## never un-reveals and never re-fires. No-op when invalid — the stage gates
## on is_valid() first, this stays defensive.
func update_explorer_x(at_x: float) -> void:
	if not _valid:
		return
	var thresholds := _thresholds()
	if _zone_state == ZONE_EXTERIOR and at_x >= float(thresholds["exterior_end"]):
		_zone_state = ZONE_INTERIOR_PASSAGE
		zone_state_changed.emit(_zone_state)
	if _zone_state == ZONE_INTERIOR_PASSAGE and at_x >= float(thresholds["interior_end"]):
		_zone_state = ZONE_CHAMBER_REVEALED
		_chamber_revealed = true
		if _altar_group != null:
			_altar_group.visible = true
		zone_state_changed.emit(_zone_state)
		chamber_revealed.emit()


## The authored threshold table (data only — mirrors the
## PrologueMarkInspectables._authored_table() data-accessor style). An
## instance method rather than a bare const so the D6 test-only subclasses
## can supply variant tables without adding any production test seam.
## Placements are tunable placeholders (OPEN decision O7).
func _thresholds() -> Dictionary:
	return {
		"exterior_end": EXTERIOR_END_X,
		"interior_end": INTERIOR_END_X,
		"altar_x": ALTAR_X,
	}


## D6 validation: the whole table is checked BEFORE anything is built.
func _validate_table(road_min_x: float, road_max_x: float, ground_y: float, view_top: float, view_bottom: float) -> bool:
	if is_nan(road_min_x) or is_nan(road_max_x) or is_nan(ground_y) or is_nan(view_top) or is_nan(view_bottom):
		return false
	if not view_top < ground_y or not ground_y < view_bottom:
		return false
	var thresholds := _thresholds()
	var exterior_end := float(thresholds.get("exterior_end", NAN))
	var interior_end := float(thresholds.get("interior_end", NAN))
	var altar_x := float(thresholds.get("altar_x", NAN))
	if is_nan(exterior_end) or is_nan(interior_end) or is_nan(altar_x):
		return false
	if not road_min_x < exterior_end or not exterior_end < interior_end:
		return false
	if not interior_end < altar_x or not altar_x <= road_max_x:
		return false
	return true


## The chamber zone's absolute EAST END (the walkable world boundary, per the
## extended band — the walkable world ends inside the chamber). It is an END
## coordinate, not a width: overlay callers must convert it (end minus the
## chamber threshold) before passing it to _create_zone_overlay, whose width
## parameter spans [x, x + width].
func _chamber_end_x(road_max_x: float) -> float:
	return road_max_x


## Placeholder ruin façade: three weathered wall slabs above the ground line
## in the exterior zone (environmental storytelling placeholders — no lore).
func _create_exterior_walls(ground_y: float) -> Node2D:
	var walls := Node2D.new()
	walls.name = "ExteriorWalls"
	var specs := [
		{"name": "RuinWallA", "x": 900.0, "w": 34.0, "h": 64.0},
		{"name": "RuinWallB", "x": 1150.0, "w": 42.0, "h": 84.0},
		{"name": "RuinWallC", "x": 1320.0, "w": 30.0, "h": 52.0},
	]
	for spec: Dictionary in specs:
		var wall := ColorRect.new()
		wall.name = String(spec["name"])
		wall.color = RUIN_WALL_COLOR
		wall.position = Vector2(float(spec["x"]) - float(spec["w"]) * 0.5, ground_y - float(spec["h"]))
		wall.size = Vector2(float(spec["w"]), float(spec["h"]))
		walls.add_child(wall)
	return walls


## Semi-transparent zone overlay: darkens the path band across one zone so
## the interior/chamber read as enclosed spaces (the actor draws above it).
func _create_zone_overlay(node_name: String, x: float, width: float, ground_y: float, view_top: float, color: Color) -> ColorRect:
	if width <= 0.0:
		return null
	var overlay := ColorRect.new()
	overlay.name = node_name
	overlay.color = color
	overlay.position = Vector2(x, view_top)
	overlay.size = Vector2(width, (ground_y - view_top) + 50.0)
	return overlay


## Framing walls for the interior passage and the hidden chamber (taller,
## darker slabs that read as enclosed architecture).
func _create_passage_and_chamber_walls(ground_y: float) -> Node2D:
	var walls := Node2D.new()
	walls.name = "PassageAndChamberWalls"
	var specs := [
		{"name": "PassageWallWest", "x": 1425.0, "w": 18.0, "h": 110.0},
		{"name": "PassageWallEast", "x": 1775.0, "w": 18.0, "h": 110.0},
		{"name": "ChamberWallWest", "x": 1830.0, "w": 18.0, "h": 120.0},
		{"name": "ChamberWallEast", "x": 2170.0, "w": 18.0, "h": 120.0},
	]
	for spec: Dictionary in specs:
		var wall := ColorRect.new()
		wall.name = String(spec["name"])
		wall.color = PASSAGE_WALL_COLOR
		wall.position = Vector2(float(spec["x"]) - float(spec["w"]) * 0.5, ground_y - float(spec["h"]))
		wall.size = Vector2(float(spec["w"]), float(spec["h"]))
		walls.add_child(wall)
	return walls


## Two identical U2-placeholder mark glyphs on ruin surfaces (environmental
## storytelling scenery — deliberately NOT inspectable: pl_05 has no
## inspection per the approved design), plus the fallen stone that carries
## the second glyph.
func _create_ruin_mark_glyphs(ground_y: float) -> Node2D:
	var glyphs := Node2D.new()
	glyphs.name = "RuinMarkGlyphs"
	var fallen_stone := ColorRect.new()
	fallen_stone.name = "FallenStone"
	fallen_stone.color = PASSAGE_WALL_COLOR
	fallen_stone.position = Vector2(1660.0 - 18.0, ground_y - 12.0)
	fallen_stone.size = Vector2(36.0, 12.0)
	glyphs.add_child(fallen_stone)
	var glyph_one := _create_mark_glyph()
	if glyph_one == null:
		return null
	glyph_one.name = "RuinMarkGlyphOne"
	glyph_one.position = Vector2(1150.0, ground_y - 44.0)
	glyphs.add_child(glyph_one)
	var glyph_two := _create_mark_glyph()
	if glyph_two == null:
		return null
	glyph_two.name = "RuinMarkGlyphTwo"
	glyph_two.position = Vector2(1660.0, ground_y - 20.0)
	glyphs.add_child(glyph_two)
	return glyphs


## The ONE placeholder mark shape, identical to the N4.3-B prop glyphs: a
## small two-rect plus-mark (U2 stays OPEN; geometry and size are constant).
func _create_mark_glyph() -> Node2D:
	var glyph := Node2D.new()
	var vertical := ColorRect.new()
	vertical.color = RUIN_GLYPH_COLOR
	vertical.position = GLYPH_VERTICAL_OFFSET
	vertical.size = GLYPH_VERTICAL_SIZE
	glyph.add_child(vertical)
	var horizontal := ColorRect.new()
	horizontal.color = RUIN_GLYPH_COLOR
	horizontal.position = GLYPH_HORIZONTAL_OFFSET
	horizontal.size = GLYPH_HORIZONTAL_SIZE
	glyph.add_child(horizontal)
	return glyph


## The altar area (the pl_05 completion boundary marker) with the labelled
## crown continuity placeholder. HIDDEN until the chamber reveal trigger —
## the reveal (entering the hidden chamber) is the N4.4-A discovery moment.
## The crown is a visual continuity object only: NO interaction, NO prompt,
## NO inventory (N4.4-C owns the interaction; nothing here stages it).
func _create_altar_group(ground_y: float) -> Node2D:
	var group := Node2D.new()
	group.name = "AltarGroup"
	var glow := ColorRect.new()
	glow.name = "ChamberGlow"
	glow.color = CHAMBER_GLOW_COLOR
	glow.position = Vector2(altar_x() - 40.0, ground_y - 70.0)
	glow.size = Vector2(80.0, 70.0)
	group.add_child(glow)
	var stone := ColorRect.new()
	stone.name = "AltarStone"
	stone.color = ALTAR_STONE_COLOR
	stone.position = Vector2(altar_x() - 20.0, ground_y - 26.0)
	stone.size = Vector2(40.0, 26.0)
	group.add_child(stone)
	var crown := ColorRect.new()
	crown.name = "CrownPlaceholder"
	crown.color = CROWN_PLACEHOLDER_COLOR
	crown.position = Vector2(altar_x() - 7.0, ground_y - 33.0)
	crown.size = Vector2(14.0, 7.0)
	group.add_child(crown)
	return group
