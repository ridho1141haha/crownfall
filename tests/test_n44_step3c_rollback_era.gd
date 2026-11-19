## N44 Step3 3C — P0.2 rollback defensive checks & era restoration reporting.
##
## Step 2 baseline (docs/reviews/N44_STEP2_REPRODUCTION_REPORT.md, Test C):
##   - the ONLY payload-injectable apply-layer failure is research
##     active_research.elapsed_sec > duration (schema checks >=0 but not
##     <= duration; ownership/duration belong to apply_save_dict);
##   - with that probe, load_failed fired ONCE with the original reason, the
##     rollback restored 22/22 compared state components and the signature;
##   - the rollback-apply result itself was unchecked (static-only gap) and
##     era_mgr.apply_save_era's bool was ignored at FSS:1201 (fail-closed but
##     unreported).
##
## Regression contract:
##   C1  the Step 2 apply-layer failure still rolls back fully, emits the
##       ORIGINAL load_failed reason exactly once, and is not misreported
##   C2  era restore: valid era applies; absent era_id stays backward
##       compatible; direct empty/unknown ids stay fail-closed. The failure
##       surface of the new era result check is NOT injectable via payload
##       (schema KNOWN_ERA_IDS gate) — documented below, not runtime-verified.
##   C3  error reporting: original failure preserved, no spurious "Rollback
##       failed" emission on a successful rollback.
##   C4  failed-rollback diagnostics (round 2): a rollback that ALSO fails is
##       deterministically injectable at runtime — no production hook — by
##       placing an apply-invalid (elapsed > duration) research value into the
##       live session state before the snapshot is taken. The rollback verdict
##       must land in the dedicated get_last_rollback_failure_reason() slot,
##       load_failed must be emitted exactly ONCE with the ORIGINAL reason,
##       and _last_rejection_reason must keep that original text.
##
## Audit round 3: the fixture directory is UNIQUE per run (pid + usec), must
## NOT pre-exist (fail-closed precondition), and cleanup removes exactly that
## directory — a pre-existing user-owned user://step3c directory can never be
## reused, written into, or deleted. This suite never writes the default save
## slot (proven by the runner's save-guard and the suite's own cleanup check).
extends SceneTree

const SCENE: String = "res://scenes/world/ForgottenShore.tscn"
const REAL_TECH_ID: String = "inscription_studies"  # data/technologies.json, duration 90.0s

const SNAP_KEYS: Array[String] = [
	"era", "reign", "hearth", "boost", "shipwreck", "portal", "shrine", "fns",
	"gold", "wood", "stone", "day", "phase", "elapsed", "px",
	"nodes", "trees", "buildings", "npcs", "research", "night", "camp",
]

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
	print("STEP3C|%s|%s" % [tag, msg])


func _wait_session() -> ForgottenShoreSession:
	for _i: int in range(600):
		await process_frame
		if current_scene != null and String(current_scene.name) == "ForgottenShore":
			var s: ForgottenShoreSession = current_scene as ForgottenShoreSession
			if s != null and s.player != null:
				return s
	return null


func _snap(s: ForgottenShoreSession) -> Dictionary:
	return {
		"era": s.era_mgr.to_save_id(),
		"reign": s.reign_state,
		"hearth": s.hearth_sys.hearth_level,
		"boost": snappedf(s.hearth_sys.boost_remaining, 0.01),
		"shipwreck": s.shipwreck_stage,
		"portal": s.portal_relic_looted,
		"shrine": s.shrine_offering_used_today,
		"fns": s.night_mgr.first_night_survived,
		"gold": s.economy.get_amount(&"gold"),
		"wood": s.economy.get_amount(&"wood"),
		"stone": s.economy.get_amount(&"stone"),
		"day": s.time_manager.current_day,
		"phase": s.time_manager.current_phase,
		"elapsed": snappedf(s.time_manager.phase_elapsed, 0.01),
		"px": snappedf(s.player.global_position.x, 0.01),
		"nodes": s.resource_mgr.to_save_dict(),
		"trees": s.tree_mgr.to_save_dict(),
		"buildings": s.building_mgr.to_save_array(),
		"npcs": s.pop_mgr.to_save_array(),
		"research": s.research_mgr.to_save_dict(),
		"night": s.night_mgr.to_save_dict(),
		"camp": s.pop_mgr.camp_vagrants_available,
	}


func _compare_all(before: Dictionary, after: Dictionary) -> int:
	var drifts: int = 0
	for k: String in SNAP_KEYS:
		if JSON.stringify(before[k]) != JSON.stringify(after[k]):
			drifts += 1
			_check(false, "C1: component '%s' restored (before=%s after=%s)" % [
				k, JSON.stringify(before[k]), JSON.stringify(after[k])])
	return drifts


func _write_json(path: String, d: Dictionary) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(d, "\t"))
	f.close()


func _initialize() -> void:
	# Audit round 3: unique per-run fixture directory (pid + usec). The
	# precondition refuses ANY pre-existing entry (fail-closed), so a
	# user-owned directory can never be reused, written into, or deleted;
	# cleanup at the end removes exactly this one directory.
	fx = "user://step3c_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	fxg = ProjectSettings.globalize_path(fx)
	if DirAccess.dir_exists_absolute(fxg) or FileAccess.file_exists(fxg):
		print("TEST FAILURE: N44 Step3 3C fixture directory collision (%s pre-exists) — refusing to touch it" % fx)
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(fxg)
	Engine.set_meta("crownfall_load_on_start", false)
	change_scene_to_file(SCENE)
	var s: ForgottenShoreSession = await _wait_session()
	if not _check(s != null, "setup: session loads"):
		_finish()
		return
	s.time_manager.auto_advance = false
	s.set_process(false)
	s.load_failed.connect(func(t: String) -> void: _lf_texts.append(t))
	await process_frame

	var before: Dictionary = _snap(s)
	var sig_before: int = s._unsaved_signature()

	# ---------------- C1: the Step 2 apply-layer failure probe ----------------
	var pay: Dictionary = s.build_save_payload()
	(pay.get("player", {}) as Dictionary)["position_x"] = -500.0
	var pf: Dictionary = pay.get("progression_flags", {}) as Dictionary
	pf["first_night_survived"] = true
	pf["reign_state"] = "BREACH_PENALTY"
	pf["hearth_level"] = 3
	pf["shipwreck_stage"] = 2
	pf["portal_relic_looted"] = true
	pf["shrine_offering_used_today"] = true
	pf["era_id"] = "stone_age"
	(pay.get("research", {}) as Dictionary)["active_research"] = {
		"technology_id": REAL_TECH_ID, "elapsed_sec": 999999.0,
	}
	_write_json(fx + "/c1_apply_fail.json", pay)

	var r1: Variant = s.load_game_state(fx + "/c1_apply_fail.json")
	_check(r1 == false, "C1: load_game_state reports failure for the apply-layer probe")
	_check(_lf_texts.size() == 1, "C3: exactly ONE load_failed emission on failed load + successful rollback")
	_check(_lf_texts.size() > 0 and _lf_texts[0] == "Failed to restore saved kingdom state — rolling back",
		"C3: original failure reason preserved verbatim")
	var drifts: int = _compare_all(before, _snap(s))
	if drifts == 0:
		_check(true, "C1: all %d compared state components restored after rollback" % SNAP_KEYS.size())
	_check(s._unsaved_signature() == sig_before, "C1: unsaved-signature restored after rollback")

	# C3: subscriber audit (review follow-up) — load_failed has exactly ONE
	# subscriber, _record_rejection (FSS:208), which only stores the last
	# rejection text in _last_rejection_reason (FSS:62): a diagnostic
	# last-writer-wins string shared with other rejection signals. No UI
	# transition, navigation or state change runs on it. Round 2 removed the
	# second "Rollback failed" load_failed emission entirely (it would have
	# overwritten the ORIGINAL failure text stored here); the rollback verdict
	# now lives in the dedicated get_last_rollback_failure_reason() slot and is
	# audited by C4 below. A successful rollback keeps the diagnostic text on
	# the ORIGINAL failure. Index safety: _lf_texts[0] is only accessed when
	# the array is proven non-empty — a missing emission must produce a clean
	# TEST FAILURE + nonzero exit, never a runtime index error.
	if _lf_texts.is_empty():
		_check(false, "C3: load_failed was never emitted — subscriber-contract assertion cannot run")
	else:
		_check(s._last_rejection_reason == _lf_texts[0],
			"C3: sole subscriber (_record_rejection) retains the original load failure text")

	# ---------------- C2: era restoration result handling ----------------
	# C2a: a present, valid era_id applies on the success path (checked call
	# must not false-fail a good load).
	var pay_era: Dictionary = s.build_save_payload()
	(pay_era.get("progression_flags", {}) as Dictionary)["era_id"] = "stone_age"
	_write_json(fx + "/c2a_era_valid.json", pay_era)
	var r2a: Variant = s.load_game_state(fx + "/c2a_era_valid.json")
	_check(r2a == true, "C2a: load with valid era_id succeeds (checked apply_save_era passes)")
	_check(s.era_mgr.to_save_id() == "stone_age", "C2a: era actually restored to the payload era")
	# C2b: absent era_id is an OWNER POLICY, not a gap: migrate_payload backfills
	# an inferred era (wood_age, or stone_age when the save owns a stone wall —
	# SaveManager.gd:233-240). Step 3 must not change that policy, so the
	# regression pins the documented behavior: the load succeeds and the era
	# becomes the migration-inferred one (a fresh-session payload owns no stone
	# wall, so wood_age) — apply_save_era then receives that backfilled id.
	var pay_noera: Dictionary = s.build_save_payload()
	_check(pay_noera.get("progression_flags", {}).erase("era_id"), "C2b: fixture removes era_id from payload")
	_write_json(fx + "/c2b_era_absent.json", pay_noera)
	var r2b: Variant = s.load_game_state(fx + "/c2b_era_absent.json")
	_check(r2b == true, "C2b: load WITHOUT era_id still succeeds (migration backfills it)")
	_check(s.era_mgr.to_save_id() == "wood_age", "C2b: absent era_id resolves to the migration-inferred era (wood_age, owner policy)")
	# C2c: direct fail-closed audit (Step 2 evidence, must stay true).
	var era_c2c: String = s.era_mgr.to_save_id()
	var ret_empty: bool = s.era_mgr.apply_save_era("")
	var ret_unknown: bool = s.era_mgr.apply_save_era("nonexistent_era_xyz")
	_check(not ret_empty and not ret_unknown and s.era_mgr.to_save_id() == era_c2c,
		"C2c: apply_save_era stays fail-closed for empty/unknown ids (no mutation)")
	# Restore fixture state for cleanliness.
	s.era_mgr.apply_save_era("wood_age")
	_log("C2_LIMIT", "unknown-era_id via payload is NOT injectable: validate_payload gates era_id against KNOWN_ERA_IDS (SaveManager.gd:455-458). The new era-check failure surface is therefore verified by code review only, not by a runtime failure probe — no production seam was added for it.")

	# ---------------- C4: failed-rollback diagnostics (deterministic) ----------------
	# The prior C3_LIMIT ("rollback-apply failure cannot be runtime-injected")
	# is LIFTED without any production test hook: _apply_loaded_payload does
	# NOT pass through validate_payload, and ResearchManager.is_valid_saved_
	# research_dict is structural only (elapsed_sec >= 0, finite) while the
	# elapsed > duration rejection belongs to apply_save_dict. So placing an
	# apply-invalid value into the LIVE session state makes build_save_payload()
	# emit a snapshot that passes validation but fails to RE-apply — failing
	# both the probe payload leg and the rollback leg deterministically.
	var corrupted_elapsed: float = 999999.0  # inscription_studies duration is 90.0s
	var sm_c4: SaveManager = SaveManager.new()
	s.research_mgr._active_tech_id = REAL_TECH_ID
	s.research_mgr._active_elapsed = corrupted_elapsed
	var pay_c4: Dictionary = s.build_save_payload()
	var c4_research: Dictionary = pay_c4.get("research", {}) as Dictionary
	_check(c4_research.get("active_research", null) != null
		and is_equal_approx(float((c4_research.get("active_research", {}) as Dictionary).get("elapsed_sec", 0.0)), corrupted_elapsed),
		"C4: snapshot captures the apply-invalid live research value (both load leg and rollback leg will fail)")
	_check(sm_c4.validate_payload(pay_c4),
		"C4: the apply-invalid snapshot still passes validate_payload (structural only — rejection belongs to the apply layer)")
	_write_json(fx + "/c4_rollback_fail.json", pay_c4)
	var lf_count_before_c4: int = _lf_texts.size()
	var r4: Variant = s.load_game_state(fx + "/c4_rollback_fail.json")
	_check(r4 == false, "C4: load_game_state reports failure when the rollback also fails")
	_check(_lf_texts.size() == lf_count_before_c4 + 1,
		"C4: exactly ONE load_failed emission even when the rollback fails (no repeated same-signal emission)")
	if _lf_texts.size() > lf_count_before_c4:
		_check(String(_lf_texts[_lf_texts.size() - 1]) == "Failed to restore saved kingdom state — rolling back",
			"C4: the single emitted text is the ORIGINAL load-failure reason")
	else:
		_check(false, "C4: no emission recorded — original-reason assertion cannot run")
	_check(s._last_rejection_reason == "Failed to restore saved kingdom state — rolling back",
		"C4: sole subscriber's _last_rejection_reason keeps the ORIGINAL failure (never overwritten by the rollback)")
	_check(s.get_last_rollback_failure_reason() == "Rollback failed — session state may be incomplete; the load failure reported above still stands",
		"C4: failed-rollback verdict recorded verbatim in the dedicated diagnostic slot")
	# Hygiene: restore valid live research so the deliberately corrupted state
	# cannot leak past this suite (the session is suite-local and ends here).
	s.research_mgr._active_tech_id = ""
	s.research_mgr._active_elapsed = 0.0

	_finish()


func _finish() -> void:
	# Guarded fixture cleanup: only this run's own unique fixture directory is
	# removed — nothing else under user:// is ever touched.
	var cleaned: bool = _rmtree(fxg)
	_check(cleaned, "isolation: temporary fixture directory %s removed" % fx)
	if _failed == 0:
		print("PASS: All %d checks — N44 Step3 3C Rollback Era Reporting" % _checks)
		quit(0)
	else:
		print("TEST FAILURE: N44 Step3 3C (%d of %d checks failed)" % [_failed, _checks])
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
