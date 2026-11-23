class_name EldergroveThreatPresenter
extends Node2D

## N6.5: Pixel-art side-view presentation adapter for EldergroveNightSurvival.
##
## Strictly observes authoritative EldergroveNightSurvival state; never decides
## spawning, blocking, breaching, or resolution independently.
## Decouples gameplay from asset paths, frame indexes, and visual hierarchy via
## swappable archetype visual profiles (see docs/assets/N65_ASSET_MANIFEST.md).

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
var _loaded_archetype: String = ""
var _has_valid_texture: bool = false
var _anim_elapsed: float = 0.0
var _last_visual_state: String = "hidden"
var _attack_cue_remaining: float = 0.0
var _attack_cue_facing: int = 1
var _impact_cue_remaining: float = 0.0
var _brute_recoil_remaining: float = 0.0
var _brute_recoil_dir: int = 1


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
			# Temporary pixel-art-compatible placeholder reusing the verified 32x32
			# side-view raider sheet at exact 2x integer scale until final Brute art lands.
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


func _ensure_nodes() -> void:
	if threat_actor == null:
		threat_actor = Node2D.new()
		threat_actor.name = "ThreatActor"
		threat_actor.visible = false
		threat_actor.position = Vector2(EldergroveNightSurvival.THREAT_SPAWN_X, GROUND_BASELINE_Y)
		add_child(threat_actor)

	if threat_sprite == null:
		threat_sprite = Sprite2D.new()
		threat_sprite.name = "ThreatSprite"
		threat_sprite.centered = false
		threat_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		threat_sprite.offset = Vector2(-16.0, -32.0)
		threat_sprite.hframes = 4
		threat_actor.add_child(threat_sprite)

	if threat_label == null:
		threat_label = Label.new()
		threat_label.name = "ThreatLabel"
		threat_label.offset_left = -72.0
		threat_label.offset_top = -54.0
		threat_label.offset_right = 72.0
		threat_label.offset_bottom = -34.0
		threat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		threat_actor.add_child(threat_label)

	if brute_hp_bg == null:
		brute_hp_bg = ColorRect.new()
		brute_hp_bg.name = "BruteHpBg"
		brute_hp_bg.visible = false
		brute_hp_bg.position = Vector2(-HP_BAR_WIDTH * 0.5, -72.0)
		brute_hp_bg.size = Vector2(HP_BAR_WIDTH, HP_BAR_HEIGHT)
		brute_hp_bg.color = COLOR_HP_BG
		threat_actor.add_child(brute_hp_bg)

	if brute_hp_fill == null:
		brute_hp_fill = ColorRect.new()
		brute_hp_fill.name = "BruteHpFill"
		brute_hp_fill.visible = false
		brute_hp_fill.position = Vector2(-HP_BAR_WIDTH * 0.5, -72.0)
		brute_hp_fill.size = Vector2(HP_BAR_WIDTH, HP_BAR_HEIGHT)
		brute_hp_fill.color = COLOR_HP_FILL
		threat_actor.add_child(brute_hp_fill)

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
	if _loaded_archetype == archetype:
		_loaded_archetype = ""


func has_valid_texture() -> bool:
	return _has_valid_texture


func is_threat_visible() -> bool:
	return threat_actor != null and threat_actor.visible


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
	return _brute_recoil_remaining > 0.0


func get_brute_recoil_offset_x() -> float:
	if _brute_recoil_remaining <= 0.0:
		return 0.0
	return roundf(float(_brute_recoil_dir) * BRUTE_RECOIL_PX)


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


func trigger_hit_impact(impact_x: float, attack_facing_dir: int, defeated: bool) -> void:
	_ensure_nodes()
	var norm_dir: int = -1 if attack_facing_dir < 0 else 1
	_impact_cue_remaining = IMPACT_CUE_DURATION_SEC
	hit_impact_cue.position = Vector2(roundf(impact_x), IMPACT_CUE_Y)
	var c: Color = COLOR_IMPACT_DEFEAT if defeated else COLOR_IMPACT_HIT
	impact_bar_h.color = c
	impact_bar_v.color = c
	hit_impact_cue.visible = true
	if not defeated:
		_brute_recoil_dir = norm_dir
		_brute_recoil_remaining = BRUTE_RECOIL_DURATION_SEC
	else:
		_brute_recoil_remaining = 0.0


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
	if _brute_recoil_remaining > 0.0:
		_brute_recoil_remaining = maxf(0.0, _brute_recoil_remaining - dt)


func set_threat_hidden() -> void:
	_ensure_nodes()
	threat_actor.visible = false
	if ward_pulse_bar != null:
		ward_pulse_bar.visible = false
	if brute_hp_bg != null:
		brute_hp_bg.visible = false
	if brute_hp_fill != null:
		brute_hp_fill.visible = false
	_anim_elapsed = 0.0
	_last_visual_state = "hidden"


func _apply_archetype_profile(archetype: String) -> void:
	_ensure_nodes()
	var profile: Dictionary = get_visual_profile(archetype)
	var tex_path: String = String(profile.get("texture_path", ""))
	var loaded_tex: Texture2D = null
	if not tex_path.is_empty() and ResourceLoader.exists(tex_path):
		loaded_tex = load(tex_path) as Texture2D

	_has_valid_texture = loaded_tex != null
	threat_sprite.texture = loaded_tex
	threat_sprite.hframes = maxi(1, int(profile.get("hframes", 4)))
	threat_sprite.offset = profile.get("frame_offset", Vector2(-16.0, -32.0)) as Vector2
	var s: Vector2 = profile.get("sprite_scale", Vector2(1.0, 1.0)) as Vector2
	threat_sprite.scale = s
	threat_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	threat_sprite.modulate = profile.get("modulate", Color(1.0, 1.0, 1.0, 1.0)) as Color
	var label_y: float = -34.0 * maxf(1.0, s.y) - 20.0
	threat_label.offset_top = label_y
	threat_label.offset_bottom = label_y + 20.0
	_loaded_archetype = archetype


func sync_from_survival(survival: EldergroveNightSurvival, player_x: float, camp_built: bool, delta: float = 0.0) -> void:
	_ensure_nodes()
	_tick_transient_cues(delta)
	var protection_active: bool = survival != null and survival.is_camp_protection_active(camp_built)
	if survival == null or not survival.is_encounter_active():
		_brute_recoil_remaining = 0.0
		set_threat_hidden()
		set_perimeter_visible(protection_active, COLOR_WARD_IDLE)
		return

	if _loaded_archetype != survival.threat_archetype:
		_apply_archetype_profile(survival.threat_archetype)

	var profile: Dictionary = get_visual_profile(survival.threat_archetype)
	var base_mod: Color = profile.get("modulate", Color(1.0, 1.0, 1.0, 1.0)) as Color
	var display_name: String = String(profile.get("display_label", survival.threat_archetype))
	var native_faces_left: bool = bool(profile.get("native_faces_left", true))

	threat_actor.visible = true
	var recoil_x: float = get_brute_recoil_offset_x()
	threat_actor.position = Vector2(roundf(survival.threat_x) + recoil_x, GROUND_BASELINE_Y)

	# Side-view facing direction toward player
	var moving_right: bool = player_x > survival.threat_x
	threat_sprite.flip_h = moving_right if native_faces_left else (not moving_right)

	_anim_elapsed += maxf(0.0, delta)
	var frame_count: int = maxi(1, threat_sprite.hframes)

	var pulse_active: bool = survival.defense_pulse_visual_remaining > 0.0
	if ward_pulse_bar != null:
		ward_pulse_bar.visible = protection_active and pulse_active

	var show_hp: bool = survival.threat_max_hp > 0 and not survival.is_threat_defeated()
	if brute_hp_bg != null and brute_hp_fill != null:
		brute_hp_bg.visible = show_hp
		brute_hp_fill.visible = show_hp
		if show_hp:
			var ratio: float = clampf(float(survival.threat_hp) / float(maxi(1, survival.threat_max_hp)), 0.0, 1.0)
			brute_hp_fill.size.x = roundf(HP_BAR_WIDTH * ratio)
			display_name = "%s [%d/%d]" % [display_name, survival.threat_hp, survival.threat_max_hp]

	if survival.is_threat_staggered():
		_last_visual_state = "staggered"
		threat_sprite.modulate = base_mod * COLOR_TINT_STAGGERED
		threat_sprite.frame = mini(frame_count - 1, 1)
		threat_label.text = "%s — Staggered" % display_name
		set_perimeter_visible(protection_active, COLOR_WARD_PULSE if pulse_active else COLOR_WARD_BLOCKED)
	elif survival.camp_breached:
		_last_visual_state = "breached"
		threat_sprite.modulate = COLOR_TINT_BREACHED
		threat_sprite.frame = int(floor(_anim_elapsed * BREACH_FPS)) % frame_count
		threat_label.text = "%s — BREACHED!" % display_name
		set_perimeter_visible(protection_active, COLOR_WARD_BREACHED)
	elif survival.threat_blocked:
		_last_visual_state = "blocked"
		threat_sprite.modulate = base_mod * COLOR_TINT_BLOCKED
		var pulse: int = int(floor(_anim_elapsed * BLOCKED_FPS)) % 2
		threat_sprite.frame = mini(frame_count - 1, 1 + pulse)
		threat_label.text = "%s — Blocked" % display_name
		set_perimeter_visible(protection_active, COLOR_WARD_BLOCKED)
	else:
		_last_visual_state = "approaching"
		threat_sprite.modulate = base_mod
		threat_sprite.frame = int(floor(_anim_elapsed * WALK_FPS)) % frame_count
		threat_label.text = display_name
		set_perimeter_visible(protection_active, COLOR_WARD_PULSE if pulse_active else COLOR_WARD_IDLE)

	if survival.hit_flash_remaining > 0.0:
		threat_sprite.modulate = COLOR_TINT_HIT_FLASH
