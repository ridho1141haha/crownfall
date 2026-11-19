## N44 Step3 3B — P1.2 world_time type validation regression tests.
##
## Step 2 baseline (docs/reviews/N44_STEP2_REPRODUCTION_REPORT.md, Test B):
##   - null / Array / Dictionary world_time hit an uncontrolled
##     `SCRIPT ERROR: Invalid call. Nonexistent 'float' constructor.` at
##     SaveManager.gd:304 (abort-default made the load reject, but the engine
##     error printed and polluted logs/CI),
##   - "abc" and true were silently coerced to 0.0 / 1.0 and ACCEPTED
##     end-to-end, including through TimeManager.apply_save_dict,
##   - negative / NaN / Inf were already guarded and must stay guarded.
##
## Post-fix contract: only TYPE_FLOAT / TYPE_INT convert (matches the exact-int
## schema convention; numeric strings and booleans are intentionally REJECTED —
## real saves always serialize world_time as a JSON number, see report §4).
## Every rejected case must produce NO SCRIPT ERROR and NO state mutation.
##
## Round 2 (parametric E2E): every invalid variant (null, boolean, Array,
## Dictionary, non-numeric string, numeric string, negative, NaN, ±Infinity)
## is additionally driven through the FULL session load path
## ForgottenShoreSession.load_game_state() with three assertions per case:
## rejected, gameplay state unchanged, and NO load_failed emission (these
## rejections happen at the validation layer, before any apply or rollback).
##
## Audit round 3: the fixture directory is UNIQUE per run (pid + usec), must
## NOT pre-exist (fail-closed precondition), and cleanup removes exactly that
## directory — a pre-existing user-owned user://step3b directory can never be
## reused, written into, or deleted. This suite never writes the default save
## slot (proven by the runner's save-guard and the suite's own cleanup check).
extends SceneTree

const SCENE: String = "res://scenes/world/ForgottenShore.tscn"

var _checks: int = 0
var _failed: int = 0
var _lf_texts: Array[String] = []
var fx: String = ""
var fxg: String = ""


func _check(cond: bool, msg: String) -> bool:
	_checks += 1
	if cond:
		print("CHECK OK: %s" % msg)
	else:
		_failed += 1
		print("TEST FAILURE: %s" % msg)
	return cond


func _log(tag: String, msg: String) -> void:
	print("STEP3B|%s|%s" % [tag, msg])


func _wait_session() -> ForgottenShoreSession:
	for _i: int in range(600):
		await process_frame
		if current_scene != null and String(current_scene.name) == "ForgottenShore":
			var s: ForgottenShoreSession = current_scene as ForgottenShoreSession
			if s != null and s.player != null:
				return s
	return null


func _write_json(path: String, d: Dictionary) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(d, "\t"))
	f.close()


func _initialize() -> void:
	# Audit round 3: unique per-run fixture directory (pid + usec). The
	# precondition refuses ANY pre-existing entry (fail-closed), so a
	# user-owned directory can never be reused, written into, or deleted;
	# cleanup at the end removes exactly this one directory.
	fx = "user://step3b_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	fxg = ProjectSettings.globalize_path(fx)
	if DirAccess.dir_exists_absolute(fxg) or FileAccess.file_exists(fxg):
		print("TEST FAILURE: N44 Step3 3B fixture directory collision (%s pre-exists) — refusing to touch it" % fx)
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(fxg)

	# ---------- Layer 1: SaveManager.validate_payload + load_state ----------
	var sm: SaveManager = SaveManager.new()

	# Template: a REAL session payload (schema-valid round-trip baseline).
	Engine.set_meta("crownfall_load_on_start", false)
	change_scene_to_file(SCENE)
	var s: ForgottenShoreSession = await _wait_session()
	if not _check(s != null, "setup: session loads for payload template"):
		_finish()
		return
	s.time_manager.auto_advance = false
	s.set_process(false)
	s.load_failed.connect(func(t: String) -> void: _lf_texts.append(t))
	var template: Dictionary = s.build_save_payload()
	_write_json(fx + "/template.json", template)
	await process_frame

	# (case name, replacement value or raw-text token, expected accept)
	var cases: Array = [
		["c01_int", 120, true],
		["c02_float", 90.5, true],
		["c03_numeric_string", "120.5", false],
		["c04_alpha_string", "abc", false],
		["c05_bool", true, false],
		["c06_null", null, false],
		["c07_array", [1, 2], false],
		["c08_dictionary", {"a": 1}, false],
		["c09_negative", -1.5, false],
		["c12_negative_int", -2, false],
	]
	for case: Array in cases:
		var d: Dictionary = template.duplicate(true)
		d["world_time"] = case[1]
		var path: String = fx + "/%s.json" % case[0]
		_write_json(path, d)
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		_check(typeof(parsed) == TYPE_DICTIONARY, "%s: fixture parses as JSON dict" % case[0])
		var vres: bool = sm.validate_payload(parsed)
		_check(vres == bool(case[2]), "%s: validate_payload %s=%s (expected %s)" % [
			case[0], case[0], str(vres), str(case[2])])
		var lres: Dictionary = sm.load_state(path)
		_check(bool(lres.get("ok", false)) == bool(case[2]), "%s: load_state ok=%s (expected %s)" % [
			case[0], str(lres.get("ok", false)), str(case[2])])

	# Raw-text probes: NaN / 1e999 tokens (parse-level and is_inf guards).
	var raw_re: RegEx = RegEx.new()
	raw_re.compile("\"world_time\"\\s*:\\s*[-0-9.eE+]+")
	var raw_nan: String = raw_re.sub(FileAccess.get_file_as_string(fx + "/template.json"), "\"world_time\": NaN", true)
	_write_json(fx + "/c10_raw_nan.json", {})
	var fnan: FileAccess = FileAccess.open(fx + "/c10_raw_nan.json", FileAccess.WRITE)
	fnan.store_string(raw_nan)
	fnan.close()
	_check(JSON.parse_string(raw_nan) == null, "c10_raw_nan: NaN token fails JSON parse (unchanged)")
	_check(not sm.load_state(fx + "/c10_raw_nan.json").get("ok", false), "c10_raw_nan: load_state rejects")

	var raw_inf: String = raw_re.sub(FileAccess.get_file_as_string(fx + "/template.json"), "\"world_time\": 1e999", true)
	var finf: FileAccess = FileAccess.open(fx + "/c11_raw_inf.json", FileAccess.WRITE)
	finf.store_string(raw_inf)
	finf.close()
	var parsed_inf: Variant = JSON.parse_string(raw_inf)
	_check(typeof(parsed_inf) == TYPE_DICTIONARY, "c11_raw_inf: 1e999 parses (inf float)")
	_check(not sm.validate_payload(parsed_inf), "c11_raw_inf: is_inf guard rejects (preserved)")
	_check(not sm.load_state(fx + "/c11_raw_inf.json").get("ok", false), "c11_raw_inf: load_state rejects")

	var raw_ninf: String = raw_re.sub(FileAccess.get_file_as_string(fx + "/template.json"), "\"world_time\": -1e999", true)
	var fninf: FileAccess = FileAccess.open(fx + "/c13_raw_neg_inf.json", FileAccess.WRITE)
	fninf.store_string(raw_ninf)
	fninf.close()
	var parsed_ninf: Variant = JSON.parse_string(raw_ninf)
	_check(typeof(parsed_ninf) == TYPE_DICTIONARY, "c13_raw_neg_inf: -1e999 parses (negative infinity)")
	_check(not sm.validate_payload(parsed_ninf), "c13_raw_neg_inf: is_inf guard rejects -Infinity (preserved)")
	_check(not sm.load_state(fx + "/c13_raw_neg_inf.json").get("ok", false), "c13_raw_neg_inf: load_state rejects")

	# Legacy compatibility: valid int and float world_time still load end-to-end.
	var d_int: Dictionary = template.duplicate(true)
	d_int["world_time"] = 120
	_write_json(fx + "/compat_int.json", d_int)
	var r_int: Dictionary = sm.load_state(fx + "/compat_int.json")
	_check(bool(r_int.get("ok", false)), "compat_int: integer world_time loads (legacy-compatible)")
	var d_float: Dictionary = template.duplicate(true)
	d_float["world_time"] = 42.5
	_write_json(fx + "/compat_float.json", d_float)
	var r_float: Dictionary = sm.load_state(fx + "/compat_float.json")
	_check(bool(r_float.get("ok", false)), "compat_float: float world_time loads (legacy-compatible)")

	# ---------- Layer 1b: day_count contract (historical save format) ----------
	# The save format deliberately accepts integral floats for day_count:
	# EconomyLedger.is_exact_int_value accepts TYPE_INT or an integral
	# TYPE_FLOAT (EconomyLedger.gd:25-33) and the schema converts with
	# int(roundf(float(...))) — a pattern a pure-int contract would never
	# need. External/older writers may have emitted "day_count": 2.0, so the
	# regression pins the ACCEPT for integral floats and the REJECT boundary
	# for non-integral floats (validation is NOT loosened for those).
	var d_dc_float: Dictionary = template.duplicate(true)
	d_dc_float["day_count"] = 2.0
	_write_json(fx + "/compat_daycount_float.json", d_dc_float)
	var parsed_dc: Variant = JSON.parse_string(FileAccess.get_file_as_string(fx + "/compat_daycount_float.json"))
	_check(sm.validate_payload(parsed_dc), "day_count 2.0 (integral float): validate_payload accepts (format contract)")
	var l_dc: Dictionary = sm.load_state(fx + "/compat_daycount_float.json")
	_check(bool(l_dc.get("ok", false)), "day_count 2.0 (integral float): load_state accepts")

	var d_dc_frac: Dictionary = template.duplicate(true)
	d_dc_frac["day_count"] = 2.5
	_write_json(fx + "/reject_daycount_frac.json", d_dc_frac)
	var parsed_frac: Variant = JSON.parse_string(FileAccess.get_file_as_string(fx + "/reject_daycount_frac.json"))
	_check(not sm.validate_payload(parsed_frac), "day_count 2.5 (non-integral): validate_payload rejects (no loosening)")
	_check(not sm.load_state(fx + "/reject_daycount_frac.json").get("ok", false), "day_count 2.5 (non-integral): load_state rejects")

	# ---------- Layer 2: TimeManager must not trust malformed data ----------
	var tm: TimeManager = TimeManager.new()
	_check(tm.current_day == 1 and tm.current_phase == TimeManager.Phase.DAYLIGHT, "tm-setup: fresh TimeManager defaults")
	_check(not tm.apply_save_dict({"day_count": 1, "world_time": "abc", "world_phase": "daylight"}, true),
		"3B: TimeManager rejects alpha-string world_time (was silently coerced to 0.0)")
	_check(tm.current_day == 1 and tm.current_phase == TimeManager.Phase.DAYLIGHT, "3B: TimeManager state unchanged after string rejection")
	_check(not tm.apply_save_dict({"day_count": 1, "world_time": true, "world_phase": "daylight"}, true),
		"3B: TimeManager rejects boolean world_time")
	_check(not tm.apply_save_dict({"day_count": 1, "world_time": [1, 2], "world_phase": "daylight"}, true),
		"3B: TimeManager rejects array world_time without conversion error")
	_check(not tm.apply_save_dict({"day_count": 1, "world_time": NAN, "world_phase": "daylight"}, true),
		"3B: TimeManager rejects NaN world_time (new defensive guard)")
	_check(not tm.apply_save_dict({"day_count": 1, "world_time": INF, "world_phase": "daylight"}, true),
		"3B: TimeManager rejects Inf world_time (new defensive guard)")
	_check(tm.current_day == 1 and tm.current_phase == TimeManager.Phase.DAYLIGHT, "3B: TimeManager still pristine after all rejections")
	_check(tm.apply_save_dict({"day_count": 2, "world_time": 42.5, "world_phase": "daylight"}, true),
		"3B: TimeManager still accepts valid float world_time")
	_check(tm.current_day == 2 and is_equal_approx(tm.phase_elapsed, 42.5), "3B: valid float applied (day=2, elapsed=42.5)")
	_check(tm.apply_save_dict({"day_count": 3, "world_time": 0, "world_phase": "night"}, true),
		"3B: TimeManager still accepts valid integer world_time")
	_check(tm.current_day == 3 and tm.current_phase == TimeManager.Phase.NIGHT, "3B: valid integer applied (day=3, night)")
	_check(not tm.apply_save_dict({"day_count": 2.5, "world_time": 1.0, "world_phase": "daylight"}, true),
		"3B: TimeManager rejects non-integral day_count (same is_exact_int_value contract)")
	_check(not tm.apply_save_dict({"day_count": NAN, "world_time": 1.0, "world_phase": "daylight"}, true),
		"3B: TimeManager rejects NaN day_count")
	_check(tm.current_day == 3 and tm.current_phase == TimeManager.Phase.NIGHT, "3B: TimeManager unchanged after day_count rejections")
	_check(tm.apply_save_dict({"day_count": 2.0, "world_time": 42.5, "world_phase": "daylight"}, true),
		"3B: TimeManager accepts integral-float day_count (format contract)")
	_check(tm.current_day == 2 and is_equal_approx(tm.phase_elapsed, 42.5), "3B: integral-float day_count applied (day=2, elapsed=42.5)")

	# ---------- Layer 2b: parametric invalid-VARIANT sweep (round 2) ----------
	# Every invalid world_time VARIANT on a fresh TimeManager, mirroring the
	# SaveManager layer-1 contract exactly (non-float/int types, non-finite
	# values, negatives): each rejection must leave the component untouched.
	var tm2: TimeManager = TimeManager.new()
	_check(tm2.current_day == 1 and tm2.current_phase == TimeManager.Phase.DAYLIGHT and is_equal_approx(tm2.phase_elapsed, 0.0),
		"tm2-setup: fresh TimeManager defaults")
	var tm_invalid: Array = [
		["null", null], ["bool_false", false], ["bool_true", true],
		["array", [7]], ["dictionary", {"t": 1}],
		["numeric_string", "42.5"], ["alpha_string", "abc"],
		["negative_float", -0.5], ["negative_int", -2],
		["nan", NAN], ["inf", INF], ["neg_inf", -INF],
	]
	for tc: Array in tm_invalid:
		var probe: Dictionary = {"day_count": 2, "world_time": tc[1], "world_phase": "daylight"}
		_check(not tm2.apply_save_dict(probe, true), "tm2: TimeManager rejects %s world_time" % String(tc[0]))
		_check(tm2.current_day == 1 and tm2.current_phase == TimeManager.Phase.DAYLIGHT and is_equal_approx(tm2.phase_elapsed, 0.0),
			"tm2: TimeManager state unchanged after %s rejection" % String(tc[0]))

	# ---------- Layer 3: end-to-end load_game_state (no mutation on reject) ----------
	var sig0: int = s._unsaved_signature()
	var gold0: int = s.economy.get_amount(&"gold")
	var day0: int = s.time_manager.current_day

	var d_arr: Dictionary = template.duplicate(true)
	d_arr["world_time"] = [1, 2]
	_write_json(fx + "/e2e_array.json", d_arr)
	var ra: Variant = s.load_game_state(fx + "/e2e_array.json")
	_check(ra == false, "3B e2e: array world_time rejected through full load path")
	_check(s._unsaved_signature() == sig0 and s.economy.get_amount(&"gold") == gold0 and s.time_manager.current_day == day0,
		"3B e2e: gameplay state unchanged after array rejection")

	var d_str: Dictionary = template.duplicate(true)
	d_str["world_time"] = "abc"
	_write_json(fx + "/e2e_string.json", d_str)
	var rs: Variant = s.load_game_state(fx + "/e2e_string.json")
	_check(rs == false, "3B e2e: alpha-string world_time rejected through full load path (was silently accepted)")
	_check(s._unsaved_signature() == sig0 and s.economy.get_amount(&"gold") == gold0 and s.time_manager.current_day == day0,
		"3B e2e: gameplay state unchanged after string rejection")

	# ---------- Layer 3b: parametric E2E sweep through the session load path (round 2) ----------
	# Every invalid VARIANT (round-tripped through a real JSON fixture file) is
	# rejected by the validation layer before any apply/rollback: the load must
	# fail, the gameplay signature must stay identical, and load_failed must
	# stay silent.
	var e2e_invalid: Array = [
		["e2e_null", null],
		["e2e_bool", true],
		["e2e_numeric_string", "120.5"],
		["e2e_dictionary", {"a": 1}],
		["e2e_negative", -1.5],
	]
	for ec: Array in e2e_invalid:
		var d_e: Dictionary = template.duplicate(true)
		d_e["world_time"] = ec[1]
		var p_e: String = fx + "/%s.json" % String(ec[0])
		_write_json(p_e, d_e)
		var sig_e: int = s._unsaved_signature()
		var gold_e: int = s.economy.get_amount(&"gold")
		var day_e: int = s.time_manager.current_day
		var elapsed_e: float = s.time_manager.phase_elapsed
		var phase_e: int = int(s.time_manager.current_phase)
		var r_e: Variant = s.load_game_state(p_e)
		_check(r_e == false, "%s: invalid world_time rejected through the full session load path" % String(ec[0]))
		_check(s._unsaved_signature() == sig_e and s.economy.get_amount(&"gold") == gold_e
			and s.time_manager.current_day == day_e and is_equal_approx(s.time_manager.phase_elapsed, elapsed_e)
			and int(s.time_manager.current_phase) == phase_e,
			"%s: gameplay state unchanged after rejection" % String(ec[0]))

	# Raw non-finite tokens through the session load path (parse-level or
	# is_inf guard rejects them; same no-mutation / no-emission contract).
	var raw_e2e: Array = [
		["e2e_raw_nan", "\"world_time\": NaN"],
		["e2e_raw_inf", "\"world_time\": 1e999"],
		["e2e_raw_neg_inf", "\"world_time\": -1e999"],
	]
	for re_case: Array in raw_e2e:
		var raw_txt: String = raw_re.sub(FileAccess.get_file_as_string(fx + "/template.json"), String(re_case[1]), true)
		var fp_e: FileAccess = FileAccess.open(fx + "/%s.json" % String(re_case[0]), FileAccess.WRITE)
		fp_e.store_string(raw_txt)
		fp_e.close()
		var sig_r: int = s._unsaved_signature()
		var gold_r: int = s.economy.get_amount(&"gold")
		var day_r: int = s.time_manager.current_day
		var elapsed_r: float = s.time_manager.phase_elapsed
		var phase_r: int = int(s.time_manager.current_phase)
		var rr: Variant = s.load_game_state(fx + "/%s.json" % String(re_case[0]))
		_check(rr == false, "%s: raw non-finite world_time rejected through the full session load path" % String(re_case[0]))
		_check(s._unsaved_signature() == sig_r and s.economy.get_amount(&"gold") == gold_r
			and s.time_manager.current_day == day_r and is_equal_approx(s.time_manager.phase_elapsed, elapsed_r)
			and int(s.time_manager.current_phase) == phase_r,
			"%s: gameplay state unchanged after raw-token rejection" % String(re_case[0]))

	_check(_lf_texts.is_empty(),
		"e2e: ALL validation-layer world_time rejections emit NO load_failed (rejection precedes any apply/rollback)")

	var rc_f: Variant = s.load_game_state(fx + "/compat_float.json")
	_check(rc_f == true and is_equal_approx(s.time_manager.phase_elapsed, 42.5),
		"3B e2e: legacy float payload still loads with correct elapsed")

	var rc_dc: Variant = s.load_game_state(fx + "/compat_daycount_float.json")
	_check(rc_dc == true and s.time_manager.current_day == 2,
		"3B e2e: integral-float day_count payload loads end-to-end (day=2)")

	_finish()


func _finish() -> void:
	# Guarded fixture cleanup: only this run's own unique fixture directory is
	# removed — nothing else under user:// is ever touched.
	var cleaned: bool = _rmtree(fxg)
	_check(cleaned, "isolation: temporary fixture directory %s removed" % fx)
	if _failed == 0:
		print("PASS: All %d checks — N44 Step3 3B World Time Type Validation" % _checks)
		quit(0)
	else:
		print("TEST FAILURE: N44 Step3 3B (%d of %d checks failed)" % [_failed, _checks])
		quit(1)


func _rmtree(path: String) -> bool:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return false
	var ok: bool = true
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var full: String = path.path_join(entry)
		if dir.current_is_dir():
			ok = _rmtree(full) and ok
		elif DirAccess.remove_absolute(full) != OK:
			ok = false
		entry = dir.get_next()
	dir.list_dir_end()
	if DirAccess.remove_absolute(path) != OK:
		ok = false
	return ok and not DirAccess.dir_exists_absolute(path)
