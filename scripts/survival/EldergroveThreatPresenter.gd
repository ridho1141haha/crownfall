class_name EldergroveThreatPresenter
extends Node2D

## N6.5–N6.12: Pixel-art side-view presentation adapter for EldergroveNightSurvival.
##
## Strictly observes authoritative EldergroveNightSurvival state; never decides
## spawning, blocking, breaching, or resolution independently.
## Supports multiple simultaneous threats keyed by stable runtime threat IDs
## while preserving backwards-compatible primary-actor accessors.

const GROUND_BASELINE_Y: float = 0.0
const WALK_FPS: float = 6.0
const BLOCKED_FPS: float = 3.0
const BREACH_FPS: float = 5.0

const DEFAULT_RAIDER_TEXTURE_PATH: String = "res://assets/enemies/first_enemy/enemy_greedling_raider_sheet.png"

const COLOR_WARD_IDLE: Color = Color(0.86, 0.72, 0.36, 0.85)
const COLOR_WARD_BLOCKED: Color = Color(1.0, 0.88, 0.45, 1.0)
const COLOR_WARD_BREACHED: Color = Color(0.92, 0.28, 0.32, 0.95)
const COLOR_TINT_BLOCKED: Color = Color(1.0, 0.92, 0.72, 1.0)
const COLOR_TINT_BREACHED: Color = Color(0.95, 0.45, 0.52, 1.0)
const COLOR_WARD_PULSE: Color = Color(1.0, 0.96, 0.72, 1.0)
const COLOR_TINT_STAGGERED: Color = Color(0.76, 0.92, 1.0, 1.0)
const COLOR_TINT_HIT_FLASH: Color = Color(1.0, 0.86, 0.86, 1.0)
const COLOR_HP_BG: Color = Color(0.14, 0.1, 0.12, 0.9)
const COLOR_HP_FILL: Color = Color(0.86, 0.24, 0.28, 1.0)
const HP_BAR_WIDTH: float = 36.0
const HP_BAR_HEIGHT: float = 4.0
const ATTACK_CUE_DURATION_SEC: float = 0.16
const IMPACT_CUE_DURATION_SEC: float = 0.20
const BRUTE_RECOIL_DURATION_SEC: float = 0.12
const BRUTE_RECOIL_PX: float = 4.0
const ATTACK_CUE_OFFSET_X: float = 20.0
const ATTACK_CUE_Y: float = -18.0
const IMPACT_CUE_Y: float = -28.0
const COLOR_ATTACK_HIT: Color = Color(1.0, 0.96, 0.78, 0.95)
const COLOR_ATTACK_MISS: Color = Color(0.72, 0.76, 0.82, 0.65)
const COLOR_IMPACT_HIT: Color = Color(1.0, 0.92, 0.72, 1.0)
const COLOR_IMPACT_DEFEAT: Color = Color(1.0, 0.82, 0.42, 1.0)

var threat_actor: Node2D = null
var threat_sprite: Sprite2D = null
var threat_label: Label = null
var left_ward_post: ColorRect = null
var right_ward_post: ColorRect = null
var ward_pulse_bar: ColorRect = null
var brute_hp_bg: ColorRect = null
var brute_hp_fill: ColorRect = null
var player_attack_cue: Node2D = null
var attack_arc_primary: ColorRect = null
var attack_arc_secondary: ColorRect = null
var hit_impact_cue: Node2D = null
var impact_bar_h: ColorRect = null
var impact_bar_v: ColorRect = null

var _visual_profiles: Dictionary = {}
var _threat_slots: Dictionary = {} # threat_id -> slot dict
var _primary_slot_id: String = ""
var _has_valid_texture: bool = false
var _anim_elapsed: float = 0.0
var _last_visual_state: String = "hidden"
var _attack_cue_remaining: float = 0.0
var _attack_cue_facing: int = 1
var _impact_cue_remaining: float = 0.0
var _recoil_remaining: float = 0.0
var _recoil_dir: int = 1
var _recoil_target_id: String = ""


func _init() -> void:
	_init_default_profiles()


func _ready() -> void:
	_ensure_nodes()
	set_threat_hidden()
	set_perimeter_visible(false)


func _init_default_profiles() -> void:
	_visual_profiles = {
		"raider": {
			"texture_path": DEFAULT_RAIDER_TEXTURE_PATH,
			"hframes": 4,
			"frame_offset": Vector2(-16.0, -32.0),
			"sprite_scale": Vector2(1.0, 1.0),
			"modulate": Color(1.0, 1.0, 1.0, 1.0),
			"native_faces_left": true,
			"is_placeholder": false,
			"display_label": "Night Raider",
		},
		"brute": {
			"texture_path": DEFAULT_RAIDER_TEXTURE_PATH,
			"hframes": 4,
			"frame_offset": Vector2(-16.0, -32.0),
			"sprite_scale": Vector2(2.0, 2.0),
			"modulate": Color(0.72, 0.42, 0.56, 1.0),
			"native_faces_left": true,
			"is_placeholder": true,
			"display_label": "Gloom Brute",
		},
	}


func _create_actor_slot(slot_name: String) -> Dictionary:
	var actor := Node2D.new()
	actor.name = slot_name
	actor.visible = false
	actor.position = Vector2(EldergroveNightSurvival.THREAT_SPAWN_X, GROUND_BASELINE_Y)
	add_child(actor)

	var sprite := Sprite2D.new()
	sprite.name = "ThreatSprite"
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.offset = Vector2(-16.0, -32.0)
	sprite.hframes = 4
	actor.add_child(sprite)

	var lbl := Label.new()
	lbl.name = "ThreatLabel"
	lbl.offset_left = -72.0
	lbl.offset_top = -54.0
	lbl.offset_right = 72.0
	lbl.offset_bottom = -34.0
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	actor.add_child(lbl)

	var hp_bg := ColorRect.new()
	hp_bg.name = "BruteHpBg"
	hp_bg.visible = false
	hp_bg.position = Vector2(-HP_BAR_WIDTH * 0.5, -72.0)
	hp_bg.size = Vector2(HP_BAR_WIDTH, HP_BAR_HEIGHT)
	hp_bg.color = COLOR_HP_BG
	actor.add_child(hp_bg)

	var hp_fill := ColorRect.new()
	hp_fill.name = "BruteHpFill"
	hp_fill.visible = false
	hp_fill.position = Vector2(-HP_BAR_WIDTH * 0.5, -72.0)
	hp_fill.size = Vector2(HP_BAR_WIDTH, HP_BAR_HEIGHT)
	hp_fill.color = COLOR_HP_FILL
	actor.add_child(hp_fill)

	return {
		"actor": actor,
		"sprite": sprite,
		"label": lbl,
		"hp_bg": hp_bg,
		"hp_fill": hp_fill,
		"loaded_archetype": "",
		"has_valid_texture": false,
	}


func _ensure_nodes() -> void:
	if threat_actor == null:
		var primary_slot: Dictionary = _create_actor_slot("ThreatActor")
		threat_actor = primary_slot["actor"] as Node2D
		threat_sprite = primary_slot["sprite"] as Sprite2D
		threat_label = primary_slot["label"] as Label
		brute_hp_bg = primary_slot["hp_bg"] as ColorRect
		brute_hp_fill = primary_slot["hp_fill"] as ColorRect

	if left_ward_post == null:
		var left_x: float = roundf(EldergroveNightSurvival.CAMP_CENTER_X - EldergroveNightSurvival.CAMP_PROTECTION_RADIUS)
		left_ward_post = _make_ward_post("LeftWardPost", left_x)
		add_child(left_ward_post)

	if right_ward_post == null:
		var right_x: float = roundf(EldergroveNightSurvival.CAMP_CENTER_X + EldergroveNightSurvival.CAMP_PROTECTION_RADIUS)
		right_ward_post = _make_ward_post("RightWardPost", right_x)
		add_child(right_ward_post)

	if ward_pulse_bar == null:
		var lx: float = roundf(EldergroveNightSurvival.CAMP_CENTER_X - EldergroveNightSurvival.CAMP_PROTECTION_RADIUS)
		var rx: float = roundf(EldergroveNightSurvival.CAMP_CENTER_X + EldergroveNightSurvival.CAMP_PROTECTION_RADIUS)
		ward_pulse_bar = ColorRect.new()
		ward_pulse_bar.name = "WardPulseBar"
		ward_pulse_bar.visible = false
		ward_pulse_bar.position = Vector2(lx, -6.0)
		ward_pulse_bar.size = Vector2(rx - lx, 4.0)
		ward_pulse_bar.color = COLOR_WARD_PULSE
		add_child(ward_pulse_bar)

	if player_attack_cue == null:
		player_attack_cue = Node2D.new()
		player_attack_cue.name = "PlayerAttackCue"
		player_attack_cue.visible = false
		player_attack_cue.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(player_attack_cue)

		attack_arc_primary = ColorRect.new()
		attack_arc_primary.name = "AttackArcPrimary"
		attack_arc_primary.position = Vector2(0.0, -3.0)
		attack_arc_primary.size = Vector2(12.0, 3.0)
		attack_arc_primary.color = COLOR_ATTACK_HIT
		player_attack_cue.add_child(attack_arc_primary)

		attack_arc_secondary = ColorRect.new()
		attack_arc_secondary.name = "AttackArcSecondary"
		attack_arc_secondary.position = Vector2(4.0, 1.0)
		attack_arc_secondary.size = Vector2(8.0, 2.0)
		attack_arc_secondary.color = COLOR_ATTACK_HIT
		player_attack_cue.add_child(attack_arc_secondary)

	if hit_impact_cue == null:
		hit_impact_cue = Node2D.new()
		hit_impact_cue.name = "HitImpactCue"
		hit_impact_cue.visible = false
		hit_impact_cue.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(hit_impact_cue)

		impact_bar_h = ColorRect.new()
		impact_bar_h.name = "ImpactBarH"
		impact_bar_h.position = Vector2(-7.0, -1.0)
		impact_bar_h.size = Vector2(14.0, 2.0)
		impact_bar_h.color = COLOR_IMPACT_HIT
		hit_impact_cue.add_child(impact_bar_h)

		impact_bar_v = ColorRect.new()
		impact_bar_v.name = "ImpactBarV"
		impact_bar_v.position = Vector2(-1.0, -7.0)
		impact_bar_v.size = Vector2(2.0, 14.0)
		impact_bar_v.color = COLOR_IMPACT_HIT
		hit_impact_cue.add_child(impact_bar_v)


func _make_ward_post(post_name: String, world_x: float) -> ColorRect:
	var post := ColorRect.new()
	post.name = post_name
	post.visible = false
	post.position = Vector2(world_x - 2.0, -22.0)
	post.size = Vector2(4.0, 22.0)
	post.color = COLOR_WARD_IDLE
	return post


func get_visual_profile(archetype: String) -> Dictionary:
	if _visual_profiles.has(archetype):
		return (_visual_profiles[archetype] as Dictionary).duplicate(true)
	return (_visual_profiles["raider"] as Dictionary).duplicate(true)


func set_visual_profile(archetype: String, profile: Dictionary) -> void:
	if archetype.is_empty():
		return
	var base: Dictionary = get_visual_profile(archetype)
	for k: Variant in profile.keys():
		base[k] = profile[k]
	_visual_profiles[archetype] = base
	for sid: String in _threat_slots.keys():
		var slot: Dictionary = _threat_slots[sid] as Dictionary
		if String(slot.get("loaded_archetype", "")) == archetype:
			slot["loaded_archetype"] = ""
			_threat_slots[sid] = slot


func has_valid_texture() -> bool:
	return _has_valid_texture


func is_threat_visible() -> bool:
	return get_visible_threat_count() > 0


func get_visible_threat_count() -> int:
	var count: int = 0
	for sid: String in _threat_slots.keys():
		var slot: Dictionary = _threat_slots[sid] as Dictionary
		var actor: Node2D = slot.get("actor", null) as Node2D
		if actor != null and actor.visible:
			count += 1
	return count


func get_threat_actor_by_id(threat_id: String) -> Node2D:
	if not _threat_slots.has(threat_id):
		return null
	var slot: Dictionary = _threat_slots[threat_id] as Dictionary
	return slot.get("actor", null) as Node2D


func is_perimeter_visible() -> bool:
	return left_ward_post != null and left_ward_post.visible and right_ward_post != null and right_ward_post.visible


func get_visual_state() -> String:
	return _last_visual_state


func set_perimeter_visible(active: bool, tint: Color = COLOR_WARD_IDLE) -> void:
	_ensure_nodes()
	left_ward_post.visible = active
	right_ward_post.visible = active
	left_ward_post.color = tint
	right_ward_post.color = tint


func is_pulse_visual_active() -> bool:
	return ward_pulse_bar != null and ward_pulse_bar.visible


func is_hp_bar_visible() -> bool:
	return brute_hp_bg != null and brute_hp_bg.visible


func is_attack_cue_visible() -> bool:
	return player_attack_cue != null and player_attack_cue.visible


func get_attack_cue_facing() -> int:
	return _attack_cue_facing


func get_attack_cue_position() -> Vector2:
	if player_attack_cue == null:
		return Vector2.ZERO
	return player_attack_cue.position


func is_impact_cue_visible() -> bool:
	return hit_impact_cue != null and hit_impact_cue.visible


func is_brute_hit_feedback_active() -> bool:
	return _recoil_remaining > 0.0


func get_brute_recoil_offset_x() -> float:
	if _recoil_remaining <= 0.0:
		return 0.0
	return roundf(float(_recoil_dir) * BRUTE_RECOIL_PX)


func trigger_player_attack_cue(player_x: float, facing_dir: int, hit_confirmed: bool) -> void:
	_ensure_nodes()
	var norm_dir: int = -1 if facing_dir < 0 else 1
	_attack_cue_facing = norm_dir
	_attack_cue_remaining = ATTACK_CUE_DURATION_SEC
	player_attack_cue.position = Vector2(roundf(player_x + float(norm_dir) * ATTACK_CUE_OFFSET_X), ATTACK_CUE_Y)
	player_attack_cue.scale = Vector2(float(norm_dir), 1.0)
	var c: Color = COLOR_ATTACK_HIT if hit_confirmed else COLOR_ATTACK_MISS
	attack_arc_primary.color = c
	attack_arc_secondary.color = c
	player_attack_cue.visible = true


func trigger_hit_impact(impact_x: float, attack_facing_dir: int, defeated: bool, target_id: String = "") -> void:
	_ensure_nodes()
	var norm_dir: int = -1 if attack_facing_dir < 0 else 1
	_impact_cue_remaining = IMPACT_CUE_DURATION_SEC
	hit_impact_cue.position = Vector2(roundf(impact_x), IMPACT_CUE_Y)
	var c: Color = COLOR_IMPACT_DEFEAT if defeated else COLOR_IMPACT_HIT
	impact_bar_h.color = c
	impact_bar_v.color = c
	hit_impact_cue.visible = true
	if not defeated:
		_recoil_dir = norm_dir
		_recoil_remaining = BRUTE_RECOIL_DURATION_SEC
		_recoil_target_id = target_id
	else:
		_recoil_remaining = 0.0
		_recoil_target_id = ""


func _tick_transient_cues(delta: float) -> void:
	var dt: float = maxf(0.0, delta)
	if _attack_cue_remaining > 0.0:
		_attack_cue_remaining = maxf(0.0, _attack_cue_remaining - dt)
	if player_attack_cue != null:
		player_attack_cue.visible = _attack_cue_remaining > 0.0
	if _impact_cue_remaining > 0.0:
		_impact_cue_remaining = maxf(0.0, _impact_cue_remaining - dt)
	if hit_impact_cue != null:
		hit_impact_cue.visible = _impact_cue_remaining > 0.0
	if _recoil_remaining > 0.0:
		_recoil_remaining = maxf(0.0, _recoil_remaining - dt)


func set_threat_hidden() -> void:
	_ensure_nodes()
	threat_actor.visible = false
	if ward_pulse_bar != null:
		ward_pulse_bar.visible = false
	if brute_hp_bg != null:
		brute_hp_bg.visible = false
	if brute_hp_fill != null:
		brute_hp_fill.visible = false
	for sid: String in _threat_slots.keys():
		var slot: Dictionary = _threat_slots[sid] as Dictionary
		var actor: Node2D = slot.get("actor", null) as Node2D
		var hp_bg: ColorRect = slot.get("hp_bg", null) as ColorRect
		var hp_fill: ColorRect = slot.get("hp_fill", null) as ColorRect
		if actor != null:
			actor.visible = false
		if hp_bg != null:
			hp_bg.visible = false
		if hp_fill != null:
			hp_fill.visible = false
	_anim_elapsed = 0.0
	_last_visual_state = "hidden"


func _apply_archetype_profile_to_slot(slot: Dictionary, archetype: String) -> void:
	var profile: Dictionary = get_visual_profile(archetype)
	var tex_path: String = String(profile.get("texture_path", ""))
	var loaded_tex: Texture2D = null
	if not tex_path.is_empty() and ResourceLoader.exists(tex_path):
		loaded_tex = load(tex_path) as Texture2D

	var valid_tex: bool = loaded_tex != null
	slot["has_valid_texture"] = valid_tex
	var sprite: Sprite2D = slot["sprite"] as Sprite2D
	var lbl: Label = slot["label"] as Label
	var hp_bg: ColorRect = slot["hp_bg"] as ColorRect
	var hp_fill: ColorRect = slot["hp_fill"] as ColorRect

	sprite.texture = loaded_tex
	sprite.hframes = maxi(1, int(profile.get("hframes", 4)))
	sprite.offset = profile.get("frame_offset", Vector2(-16.0, -32.0)) as Vector2
	var s: Vector2 = profile.get("sprite_scale", Vector2(1.0, 1.0)) as Vector2
	sprite.scale = s
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.modulate = profile.get("modulate", Color(1.0, 1.0, 1.0, 1.0)) as Color

	var label_y: float = -34.0 * maxf(1.0, s.y) - 20.0
	lbl.offset_top = label_y
	lbl.offset_bottom = label_y + 20.0
	var hp_y: float = -34.0 * maxf(1.0, s.y) - 6.0
	hp_bg.position.y = hp_y
	hp_fill.position.y = hp_y
	slot["loaded_archetype"] = archetype


func _get_or_assign_slot(threat_id: String, index: int) -> Dictionary:
	if _threat_slots.has(threat_id):
		return _threat_slots[threat_id] as Dictionary
	var slot: Dictionary
	if index == 0 and _primary_slot_id.is_empty():
		_primary_slot_id = threat_id
		slot = {
			"actor": threat_actor,
			"sprite": threat_sprite,
			"label": threat_label,
			"hp_bg": brute_hp_bg,
			"hp_fill": brute_hp_fill,
			"loaded_archetype": "",
			"has_valid_texture": false,
		}
	else:
		slot = _create_actor_slot("ThreatActor_%s" % threat_id)
	_threat_slots[threat_id] = slot
	return slot


func _cleanup_stale_slots(active_ids: Dictionary) -> void:
	var to_remove: Array[String] = []
	for sid: String in _threat_slots.keys():
		if active_ids.has(sid):
			continue
		var slot: Dictionary = _threat_slots[sid] as Dictionary
		var actor: Node2D = slot.get("actor", null) as Node2D
		if actor == threat_actor:
			actor.visible = false
			_primary_slot_id = ""
		elif actor != null:
			actor.queue_free()
		to_remove.append(sid)
	for sid: String in to_remove:
		_threat_slots.erase(sid)


func sync_from_survival(survival: EldergroveNightSurvival, player_x: float, camp_built: bool, delta: float = 0.0) -> void:
	_ensure_nodes()
	_tick_transient_cues(delta)
	var protection_active: bool = survival != null and survival.is_camp_protection_active(camp_built)
	if survival == null or not survival.is_encounter_active():
		_recoil_remaining = 0.0
		_recoil_target_id = ""
		set_threat_hidden()
		set_perimeter_visible(protection_active, COLOR_WARD_IDLE)
		return

	var pulse_active: bool = survival.defense_pulse_visual_remaining > 0.0
	if ward_pulse_bar != null:
		ward_pulse_bar.visible = protection_active and pulse_active

	_anim_elapsed += maxf(0.0, delta)
	var threat_list: Array[Dictionary] = survival.threats
	var active_ids: Dictionary = {}
	var primary_set: bool = false

	for i: int in range(threat_list.size()):
		var t: Dictionary = threat_list[i]
		var tid: String = String(t.get("id", "threat_%d" % i))
		active_ids[tid] = true
		var slot: Dictionary = _get_or_assign_slot(tid, i)
		var actor: Node2D = slot["actor"] as Node2D
		var sprite: Sprite2D = slot["sprite"] as Sprite2D
		var lbl: Label = slot["label"] as Label
		var hp_bg: ColorRect = slot["hp_bg"] as ColorRect
		var hp_fill: ColorRect = slot["hp_fill"] as ColorRect

		if bool(t.get("is_defeated", false)):
			actor.visible = false
			hp_bg.visible = false
			hp_fill.visible = false
			_threat_slots[tid] = slot
			continue

		var arch: String = String(t.get("archetype", "raider"))
		if String(slot.get("loaded_archetype", "")) != arch:
			_apply_archetype_profile_to_slot(slot, arch)

		var profile: Dictionary = get_visual_profile(arch)
		var base_mod: Color = profile.get("modulate", Color(1.0, 1.0, 1.0, 1.0)) as Color
		var display_name: String = String(profile.get("display_label", arch))
		var native_faces_left: bool = bool(profile.get("native_faces_left", true))

		var tx: float = float(t.get("x", 0.0))
		var apply_recoil: bool = _recoil_remaining > 0.0 and (_recoil_target_id.is_empty() or _recoil_target_id == tid)
		var recoil_x: float = get_brute_recoil_offset_x() if apply_recoil else 0.0
		actor.visible = true
		actor.position = Vector2(roundf(tx) + recoil_x, GROUND_BASELINE_Y)

		var moving_right: bool = player_x > tx
		sprite.flip_h = moving_right if native_faces_left else (not moving_right)

		var frame_count: int = maxi(1, sprite.hframes)
		var cur_hp: int = int(t.get("hp", 0))
		var max_hp: int = int(t.get("max_hp", 0))
		var show_hp: bool = max_hp > 0
		hp_bg.visible = show_hp
		hp_fill.visible = show_hp
		if show_hp:
			var ratio: float = clampf(float(cur_hp) / float(maxi(1, max_hp)), 0.0, 1.0)
			hp_fill.size.x = roundf(HP_BAR_WIDTH * ratio)
			display_name = "%s [%d/%d]" % [display_name, cur_hp, max_hp]

		var slot_state: String = "approaching"
		if float(t.get("stagger_remaining", 0.0)) > 0.0:
			slot_state = "staggered"
			sprite.modulate = base_mod * COLOR_TINT_STAGGERED
			sprite.frame = mini(frame_count - 1, 1)
			lbl.text = "%s — Staggered" % display_name
		elif bool(t.get("breached", false)):
			slot_state = "breached"
			sprite.modulate = COLOR_TINT_BREACHED
			sprite.frame = int(floor(_anim_elapsed * BREACH_FPS)) % frame_count
			lbl.text = "%s — BREACHED!" % display_name
		elif bool(t.get("blocked", false)):
			slot_state = "blocked"
			sprite.modulate = base_mod * COLOR_TINT_BLOCKED
			var pulse: int = int(floor(_anim_elapsed * BLOCKED_FPS)) % 2
			sprite.frame = mini(frame_count - 1, 1 + pulse)
			lbl.text = "%s — Blocked" % display_name
		else:
			sprite.modulate = base_mod
			sprite.frame = int(floor(_anim_elapsed * WALK_FPS)) % frame_count
			lbl.text = display_name

		if float(t.get("hit_flash_remaining", 0.0)) > 0.0:
			sprite.modulate = COLOR_TINT_HIT_FLASH

		_threat_slots[tid] = slot
		if not primary_set:
			primary_set = true
			_has_valid_texture = bool(slot.get("has_valid_texture", false))
			_last_visual_state = slot_state
			threat_actor = actor
			threat_sprite = sprite
			threat_label = lbl
			brute_hp_bg = hp_bg
			brute_hp_fill = hp_fill

	_cleanup_stale_slots(active_ids)

	if not primary_set:
		_last_visual_state = "hidden"

	if survival.is_threat_staggered():
		set_perimeter_visible(protection_active, COLOR_WARD_PULSE if pulse_active else COLOR_WARD_BLOCKED)
	elif survival.camp_breached:
		set_perimeter_visible(protection_active, COLOR_WARD_BREACHED)
	elif survival.threat_blocked:
		set_perimeter_visible(protection_active, COLOR_WARD_BLOCKED)
	else:
		set_perimeter_visible(protection_active, COLOR_WARD_PULSE if pulse_active else COLOR_WARD_IDLE)
