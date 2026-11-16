class_name ShoreFX
extends RefCounted

## Presentation-only feedback helpers extracted from ForgottenShoreSession:
## floating combat text, resource payment particles, camera shake, sprite hit
## flash, and SFX playback. Holds no gameplay state and never mutates the
## simulation — it only animates the host scene.

const PAYMENT_FLY_COLORS: Dictionary = {
	"gold": Color(1.0, 0.84, 0.28, 1.0),
	"wood": Color(0.62, 0.42, 0.22, 1.0),
	"stone": Color(0.62, 0.66, 0.7, 1.0),
}

var _host: Node2D
var _sfx_player: AudioStreamPlayer
var _camera: Camera2D
var _sfx_cache: Dictionary = {}


func _init(host: Node2D, sfx_player: AudioStreamPlayer, camera: Camera2D = null) -> void:
	_host = host
	_sfx_player = sfx_player
	_camera = camera


func play_sfx(sfx_name: String) -> void:
	if _sfx_player == null:
		return
	if not _sfx_cache.has(sfx_name):
		var path: String = "res://assets/audio/%s.wav" % sfx_name
		_sfx_cache[sfx_name] = load(path) if ResourceLoader.exists(path) else null
	var stream: AudioStream = _sfx_cache.get(sfx_name, null) as AudioStream
	if stream != null:
		_sfx_player.pitch_scale = randf_range(0.92, 1.08)
		_sfx_player.stream = stream
		_sfx_player.play()


func spawn_floating_text(world_x: float, text: String, col: Color = Color(1.0, 0.92, 0.45, 1.0)) -> void:
	if _host == null or not _host.is_inside_tree():
		return
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.modulate = col
	lbl.position = Vector2(world_x - 32.0, -48.0)
	_host.add_child(lbl)
	var tw: Tween = _host.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", -78.0, 0.85)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.85)
	tw.chain().tween_callback(lbl.queue_free)


func spawn_payment_fly(cost: Dictionary, from_x: float, to_x: float) -> void:
	# Animasi pembayaran: partikel kecil per jenis resource terbang dari aktor
	# menuju target yang dibayar (plot bangunan, hearth, kapal, atau altar).
	if _host == null or not _host.is_inside_tree():
		return
	var total: int = int(cost.get("gold", 0)) + int(cost.get("wood", 0)) + int(cost.get("stone", 0))
	if total <= 0:
		return
	var lane_delay: float = 0.0
	for res_id: String in ["gold", "wood", "stone"]:
		var amount: int = int(cost.get(res_id, 0))
		if amount <= 0:
			continue
		var col: Color = PAYMENT_FLY_COLORS.get(res_id, Color(1.0, 1.0, 1.0, 1.0))
		var dots: int = mini(amount, 4)
		for i: int in range(dots):
			var dot: ColorRect = ColorRect.new()
			dot.color = col
			dot.size = Vector2(7.0, 7.0)
			dot.position = Vector2(from_x - 4.0 + randf_range(-9.0, 9.0), -38.0 + randf_range(-7.0, 7.0))
			dot.z_index = 40
			_host.add_child(dot)
			var delay: float = lane_delay + float(i) * 0.05
			var tw_fly: Tween = _host.create_tween()
			tw_fly.set_parallel(true)
			tw_fly.tween_property(dot, "position:x", to_x - 4.0, 0.55).set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			tw_fly.tween_property(dot, "position:y", -44.0, 0.55).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw_fly.chain().tween_property(dot, "modulate:a", 0.0, 0.12)
			tw_fly.chain().tween_callback(dot.queue_free)
		lane_delay += 0.08


func trigger_camera_shake(intensity: float = 4.0, duration: float = 0.14) -> void:
	if _camera == null or _host == null or not _host.is_inside_tree():
		return
	var tw: Tween = _host.create_tween()
	tw.tween_property(_camera, "offset", Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity)), duration * 0.5)
	tw.tween_property(_camera, "offset", Vector2.ZERO, duration * 0.5)


func flash_sprite(spr: CanvasItem, flash_col: Color = Color(2.0, 1.2, 1.2, 1.0), restore_col: Color = Color(1.0, 1.0, 1.0, 1.0)) -> void:
	if spr == null or _host == null or not _host.is_inside_tree():
		return
	if spr.material is ShaderMaterial:
		var smat: ShaderMaterial = spr.material as ShaderMaterial
		smat.set_shader_parameter("flash_amount", 1.0)
		var tw_s: Tween = _host.create_tween()
		tw_s.tween_method(func(v: float) -> void: smat.set_shader_parameter("flash_amount", v), 1.0, 0.0, 0.14)
		return
	spr.modulate = flash_col
	var tw: Tween = _host.create_tween()
	tw.tween_property(spr, "modulate", restore_col, 0.12)
