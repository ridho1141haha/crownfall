class_name SaveManager
extends RefCounted

signal save_completed(path: String)
signal save_failed(reason: String)
signal load_recovered_from_backup(path: String)

const MIN_SCHEMA_VERSION: int = 1
const SCHEMA_VERSION: int = 2
const DEFAULT_SAVE_PATH: String = "user://save_slot_0.json"

const REQUIRED_KEYS: Array[String] = [
	"schema_version",
	"world_id",
	"island_id",
	"day_count",
	"world_time",
	"world_phase",
	"resources",
	"buildings",
	"npcs",
	"night_encounter",
	"progression_flags",
]


static func is_safe_save_path(save_path: String) -> bool:
	if not save_path.begins_with("user://"):
		return false
	if save_path.find("..") != -1 or save_path.find("\\") != -1:
		return false
	if not save_path.ends_with(".json"):
		return false
	return true


func has_valid_save(save_path: String = DEFAULT_SAVE_PATH) -> bool:
	var result: Dictionary = load_state(save_path)
	return bool(result.get("ok", false))


func save_state(
	payload: Dictionary,
	save_path: String = DEFAULT_SAVE_PATH,
	simulate_write_failure: bool = false,
	simulate_replace_failure: bool = false
) -> bool:
	if not is_safe_save_path(save_path):
		save_failed.emit("Unsafe save path rejected: %s" % save_path)
		return false
	if not validate_payload(payload):
		save_failed.emit("Payload failed schema validation before write")
		return false

	var tmp_path: String = save_path + ".tmp"
	var bak_path: String = save_path + ".bak"
	var bak_tmp_path: String = save_path + ".bak.tmp"
	var old_path: String = save_path + ".old"
	var json_text: String = JSON.stringify(payload, "\t")
	if json_text.is_empty():
		save_failed.emit("Failed to serialize JSON")
		return false

	# Step 1: Write and verify temporary save file (.tmp)
	if not _write_and_verify_file(tmp_path, json_text, simulate_write_failure):
		_remove_if_exists(tmp_path)
		save_failed.emit("Failed writing or verifying temporary save file")
		return false

	# Step 2: If an active valid save exists, stage and verify .bak BEFORE touching active save
	var had_valid_active: bool = false
	if FileAccess.file_exists(save_path):
		var existing_check: Dictionary = _read_and_validate_file(save_path)
		if bool(existing_check.get("ok", false)):
			had_valid_active = true
			var prev_text: String = FileAccess.get_file_as_string(save_path)
			if not _write_and_verify_file(bak_tmp_path, prev_text, false):
				_remove_if_exists(bak_tmp_path)
				_remove_if_exists(tmp_path)
				save_failed.emit("Backup staging verification failed; active save left untouched")
				return false
			if not _safe_replace_file(bak_tmp_path, bak_path, bak_path + ".old", false):
				_remove_if_exists(bak_tmp_path)
				_remove_if_exists(tmp_path)
				save_failed.emit("Backup commit failed; active save left untouched")
				return false

	# Step 3: Windows/POSIX safe replacement of active save with automatic rollback from .old/.bak
	if not _safe_replace_file(tmp_path, save_path, old_path, simulate_replace_failure):
		_remove_if_exists(tmp_path)
		if had_valid_active and not bool(_read_and_validate_file(save_path).get("ok", false)):
			_restore_from_backup_file(bak_path, save_path)
		save_failed.emit("Failed replacing active save; previous valid save preserved/restored")
		return false

	save_completed.emit(save_path)
	return true


func load_state(save_path: String = DEFAULT_SAVE_PATH) -> Dictionary:
	if not is_safe_save_path(save_path):
		return {
			"ok": false,
			"recovered_from_backup": false,
			"error": "Unsafe save path rejected: %s" % save_path,
		}

	var primary: Dictionary = _read_and_validate_file(save_path)
	if bool(primary.get("ok", false)):
		return {
			"ok": true,
			"recovered_from_backup": false,
			"data": primary["data"],
		}

	var bak_path: String = save_path + ".bak"
	var backup: Dictionary = _read_and_validate_file(bak_path)
	if bool(backup.get("ok", false)):
		# Self-heal corrupt primary from verified backup
		_restore_from_backup_file(bak_path, save_path)
		load_recovered_from_backup.emit(bak_path)
		return {
			"ok": true,
			"recovered_from_backup": true,
			"data": backup["data"],
		}

	return {
		"ok": false,
		"recovered_from_backup": false,
		"error": String(primary.get("error", "No valid save or backup found")),
	}




static func _normalize_reign_state(raw_val: Variant) -> String:
	if typeof(raw_val) == TYPE_STRING:
		var s: String = String(raw_val).to_upper()
		if ["ACTIVE", "BREACH_PENALTY", "ISLAND_CLEARED"].has(s):
			return s
		return "ACTIVE"
	if EconomyLedger.is_exact_int_value(raw_val):
		var idx: int = int(roundf(float(raw_val)))
		if idx == 1:
			return "BREACH_PENALTY"
		elif idx == 2:
			return "ISLAND_CLEARED"
	return "ACTIVE"


## Backfill fakta progresi untuk migrasi. Deterministik dan idempotent:
##   - field tidak ada (save lama) -> array baru berisi satu fakta tersebut;
##   - array valid tanpa fakta itu -> tambahkan tepat sekali;
##   - nilai eksplisit selain array valid (null, string, angka, dict, array
##     invalid) -> sengaja dibiarkan apa adanya agar validate_payload
##     menolaknya (migrasi tidak pernah "memperbaiki" data rusak diam-diam,
##     dan tidak pernah menghasilkan state hidup yang setengah dimigrasi).
## Field yang EKSPLISIT bernilai null BUKAN sama dengan field yang tidak ada:
## get() saja tidak bisa membedakan keduanya, jadi kehadiran field dicek
## dengan Dictionary.has() secara eksplisit.
static func _backfill_progression_fact(pf: Dictionary, fact_id: String) -> void:
	if not pf.has("progression_facts"):
		pf["progression_facts"] = [fact_id]
		return
	var facts_val: Variant = pf["progression_facts"]
	if typeof(facts_val) == TYPE_ARRAY and ProgressionState.is_valid_fact_array(facts_val):
		if not (facts_val as Array).has(fact_id):
			(facts_val as Array).append(fact_id)


static func migrate_payload(data: Variant) -> Variant:
	if typeof(data) != TYPE_DICTIONARY:
		return data
	var d: Dictionary = (data as Dictionary).duplicate(true)
	if not d.has("schema_version") or not EconomyLedger.is_exact_int_value(d["schema_version"]):
		return d
	var ver: int = int(roundf(float(d["schema_version"])))
	if ver == 1:
		if not d.has("player") or typeof(d["player"]) != TYPE_DICTIONARY:
			d["player"] = {"position_x": 0.0, "facing_direction": 1}
		if d.has("progression_flags") and typeof(d["progression_flags"]) == TYPE_DICTIONARY:
			var pf: Dictionary = d["progression_flags"] as Dictionary
			pf["reign_state"] = _normalize_reign_state(pf.get("reign_state", "ACTIVE"))
			if not pf.has("hearth_level"):
				pf["hearth_level"] = 1
			if not pf.has("shipwreck_stage"):
				pf["shipwreck_stage"] = 0
			if not pf.has("portal_relic_looted"):
				pf["portal_relic_looted"] = false
			if not pf.has("node_states") or typeof(pf["node_states"]) != TYPE_DICTIONARY:
				var ns: Dictionary = {}
				var col_arr: Variant = pf.get("collected_nodes", [])
				if typeof(col_arr) == TYPE_ARRAY:
					for item: Variant in (col_arr as Array):
						ns[String(item)] = true
				pf["node_states"] = ns
		if d.has("buildings") and typeof(d["buildings"]) == TYPE_ARRAY:
			for b: Variant in (d["buildings"] as Array):
				if typeof(b) == TYPE_DICTIONARY:
					var bd: Dictionary = b as Dictionary
					if not bd.has("level"):
						bd["level"] = 1
					if not bd.has("type"):
						bd["type"] = "wooden_wall"
		d["schema_version"] = 2
	# Backfill lintas-versi: save lama yang dibuat di tengah malam hari ke-N tidak
	# menyimpan current_day_number. Tanpa backfill, malam hari ke-2 akan salah
	# memakai jadwal wave hari ke-1 (nilai bawaan 1). Turunkan dari day_count.
	if d.has("night_encounter") and typeof(d["night_encounter"]) == TYPE_DICTIONARY:
		var ne_mig: Dictionary = d["night_encounter"] as Dictionary
		if not ne_mig.has("current_day_number") and EconomyLedger.is_exact_int_value(d.get("day_count", null)):
			ne_mig["current_day_number"] = maxi(1, int(roundf(float(d["day_count"]))))
	# Backfill era untuk save yang dibuat sebelum sistem zaman ada: inferensi
	# Stone Age bila ada tembok batu; selain itu Wood Age. Iron Age tidak pernah
	# diinferensi saat era_id hilang: era itu tidak punya bukti faktual pada
	# save lama (lihat kebijakan koreksi era Fase 2 di bawah).
	if d.has("progression_flags") and typeof(d["progression_flags"]) == TYPE_DICTIONARY:
		var pf_mig: Dictionary = d["progression_flags"] as Dictionary
		# Fase 2.2: seluruh migrasi terkait progresi hanya berjalan bila field
		# progression_facts benar-benar TIDAK ada (jalur migrasi legacy sah) atau
		# ada sebagai array fakta valid. Bila field EKSPLISIT ada tapi nilainya
		# rusak (null, string, angka, dict, array invalid), jangan sentuh data
		# progresi sama sekali: era_id tidak diinferensi atau dikoreksi, tidak ada
		# backfill vessel/Stone Age, nilai rusak dibiarkan utuh (tidak
		# dikanonikasi/disort) — validate_payload yang menolak payload ini secara
		# keseluruhan. Migrasi tidak boleh memutasi field terkait progresi secara
		# parsial sebelum payload ditolak. (Blok migrasi progresi ini adalah
		# langkah migrasi terakhir, jadi return di sini hanya melewati blok ini.)
		var facts_gate: Variant = pf_mig.get("progression_facts", null)
		if pf_mig.has("progression_facts") and not ProgressionState.is_valid_fact_array(facts_gate):
			return d
		if not pf_mig.has("era_id") or String(pf_mig["era_id"]).is_empty():
			var inferred_era: String = "wood_age"
			if d.has("buildings") and typeof(d["buildings"]) == TYPE_ARRAY:
				for b_mig: Variant in (d["buildings"] as Array):
					if typeof(b_mig) == TYPE_DICTIONARY and String((b_mig as Dictionary).get("type", "")) == "stone_wall":
						inferred_era = "stone_age"
						break
			pf_mig["era_id"] = inferred_era
		# Koreksi era Fase 2 — migrasi konservatif untuk save legacy "iron_age".
		# Implementasi lama membuka Iron Age hanya dari Shipwreck Stage 3, padahal
		# Stage 3 berarti kapal siap berlayar, bukan milestone Eldergrove. Jadi
		# era_id "iron_age" pada save lama TIDAK membuktikan milestone Eldergrove.
		# Kebijakan (deterministik & idempotent):
		#   - Save yang SUDAH membawa fakta eldergrove_reached (hanya bisa ditulis
		#     oleh build yang benar-benar mencatat milestone-nya) mempertahankan
		#     Iron Age — bukti faktualnya ada di save.
		#   - Selain itu Iron Age dicabut dan era dihitung ulang HANYA dari bukti
		#     yang benar-benar ada di save (tembok batu -> stone_age, selain itu
		#     wood_age). Stone Age yang sah tetap terjaga; fakta Eldergrove TIDAK
		#     PERNAH difabrikasi; progres lain tidak disentuh.
		#   - shipwreck_stage == 3 adalah bukti faktual kapal siap (stage hanya
		#     bertambah lewat transaksi repair yang berhasil), jadi fakta
		#     vessel-ready di-backfill dari situ apa pun era-nya — progres
		#     Shipwreck/vessel tidak pernah hilang.
		var facts_legacy: Variant = pf_mig.get("progression_facts", null)
		var has_eldergrove_evidence: bool = facts_legacy != null and typeof(facts_legacy) == TYPE_ARRAY and ProgressionState.is_valid_fact_array(facts_legacy) and (facts_legacy as Array).has(ProgressionState.FACT_ELDERGROVE_REACHED)
		if String(pf_mig.get("era_id", "")) == "iron_age" and not has_eldergrove_evidence:
			var corrected_era: String = "wood_age"
			if d.has("buildings") and typeof(d["buildings"]) == TYPE_ARRAY:
				for b_ia: Variant in (d["buildings"] as Array):
					if typeof(b_ia) == TYPE_DICTIONARY and String((b_ia as Dictionary).get("type", "")) == "stone_wall":
						corrected_era = "stone_age"
						break
			pf_mig["era_id"] = corrected_era
		var sw_val: Variant = pf_mig.get("shipwreck_stage", null)
		if EconomyLedger.is_exact_int_value(sw_val) and int(roundf(float(sw_val))) == 3:
			_backfill_progression_fact(pf_mig, ProgressionState.FACT_FORGOTTEN_SHORE_VESSEL_READY)
		# Backfill fakta fondasi progresi Fase 1: era_id "stone_age" hanya bisa
		# dicapai lewat milestone Stone Wall Tier 2 pertama, jadi era tersebut
		# membuktikan milestone-nya sudah terjadi. Deterministik dan idempotent.
		# (Juga berlaku untuk save iron_age legacy yang baru dikoreksi menjadi
		# stone_age di atas: backfill berjalan setelah koreksi era.)
		if String(pf_mig.get("era_id", "")) == "stone_age":
			_backfill_progression_fact(pf_mig, ProgressionState.FACT_FORGOTTEN_SHORE_FIRST_STONE_WALL_TIER_2)
		# Kanoniskasi: array fakta valid diurutkan agar payload hasil migrasi
		# identik dengan kontrak to_save_array() (sorted). Array invalid tetap
		# tidak disentuh sama sekali.
		var facts_final: Variant = pf_mig.get("progression_facts", null)
		if facts_final != null and typeof(facts_final) == TYPE_ARRAY and ProgressionState.is_valid_fact_array(facts_final):
			(facts_final as Array).sort()
	return d


func validate_payload(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var dict: Dictionary = data as Dictionary
	for key: String in REQUIRED_KEYS:
		if not dict.has(key):
			return false

	if not EconomyLedger.is_exact_int_value(dict["schema_version"]):
		return false
	var ver: int = int(roundf(float(dict["schema_version"])))
	if ver < MIN_SCHEMA_VERSION or ver > SCHEMA_VERSION:
		return false
	if String(dict["world_id"]).strip_edges().is_empty() or String(dict["island_id"]).strip_edges().is_empty():
		return false
	if not EconomyLedger.is_exact_int_value(dict["day_count"]) or int(roundf(float(dict["day_count"]))) < 1:
		return false

	# P1.2: only genuine numbers convert. Composite types (null/Array/Dictionary)
	# used to hit an uncontrolled float() SCRIPT ERROR here and strings/booleans
	# were silently coerced (N44_STEP2 report, Test B); real saves always
	# serialize world_time as a JSON number, so they are rejected outright.
	if typeof(dict["world_time"]) not in [TYPE_FLOAT, TYPE_INT]:
		return false
	var wt: float = float(dict["world_time"])
	if is_nan(wt) or is_inf(wt) or wt < 0.0:
		return false

	var phase: String = String(dict["world_phase"])
	if phase != "daylight" and phase != "sunset" and phase != "night":
		return false

	if typeof(dict["resources"]) != TYPE_DICTIONARY:
		return false
	var res: Dictionary = dict["resources"]
	for r_key: String in ["gold", "wood", "stone"]:
		if not res.has(r_key) or not EconomyLedger.is_exact_int_value(res[r_key]):
			return false
		var r_val: int = int(roundf(float(res[r_key])))
		if r_val < 0 or r_val > EconomyLedger.MAX_RESOURCE_CAP:
			return false

	if typeof(dict["buildings"]) != TYPE_ARRAY or typeof(dict["npcs"]) != TYPE_ARRAY:
		return false
	var b_arr: Array = dict["buildings"]
	if b_arr.is_empty():
		return false
	var allowed_plot_types: Dictionary = {
		BuildingManager.WALL_ID: ["wooden_wall", "stone_wall"],
		BuildingManager.WEST_WALL_ID: ["wooden_wall", "stone_wall"],
		BuildingManager.WATCHTOWER_ID: ["watchtower"],
		BuildingManager.FARM_WEST_ID: ["farm_plot"],
		BuildingManager.FARM_EAST_ID: ["farm_plot"],
		SpecialistDomain.SCIENTIST_HUT_PLOT_ID: ["specialist_hut"],
	}
	var seen_plot_ids: Dictionary = {}
	for b_item: Variant in b_arr:
		if not BuildingManager.is_valid_saved_building_dict(b_item):
			return false
		var b_dict: Dictionary = b_item as Dictionary
		var plot_id: String = String(b_dict["id"])
		if not allowed_plot_types.has(plot_id) or seen_plot_ids.has(plot_id):
			return false
		seen_plot_ids[plot_id] = true
		var b_type: String = String(b_dict.get("type", "wooden_wall"))
		if not (allowed_plot_types[plot_id] as Array).has(b_type):
			return false
		if b_dict.has("position_x"):
			var bpx: float = float(b_dict["position_x"])
			if is_nan(bpx) or is_inf(bpx) or bpx < WorldConstants.MIN_PLAYABLE_X or bpx > WorldConstants.MAX_PLAYABLE_X:
				return false

	var n_arr: Array = dict["npcs"]
	if n_arr.is_empty():
		return false
	if n_arr.size() > NPCPopulationManager.MAX_POPULATION:
		return false
	var seen_npc_ids: Dictionary = {}
	for n_item: Variant in n_arr:
		if not NPCBuilderAgent.is_valid_saved_npc_dict(n_item):
			return false
		var npc_id: String = String((n_item as Dictionary)["id"])
		if seen_npc_ids.has(npc_id):
			return false
		seen_npc_ids[npc_id] = true

	if not NightEncounterManager.is_valid_saved_encounter_dict(dict["night_encounter"]):
		return false
	var ne_chk: Dictionary = dict["night_encounter"] as Dictionary
	if ne_chk.has("current_day_number"):
		var cdn_chk: int = int(roundf(float(ne_chk["current_day_number"])))
		var day_chk: int = int(roundf(float(dict["day_count"])))
		if cdn_chk > day_chk:
			return false

	if dict.has("player"):
		if typeof(dict["player"]) != TYPE_DICTIONARY:
			return false
		var p_dict: Dictionary = dict["player"]
		if typeof(p_dict.get("position_x", 0.0)) not in [TYPE_FLOAT, TYPE_INT]:
			return false
		var px: float = float(p_dict.get("position_x", 0.0))
		if is_nan(px) or is_inf(px) or px < WorldConstants.MIN_PLAYABLE_X or px > WorldConstants.MAX_PLAYABLE_X:
			return false
		if p_dict.has("facing_direction"):
			if not EconomyLedger.is_exact_int_value(p_dict["facing_direction"]):
				return false
			var fd: int = int(roundf(float(p_dict["facing_direction"])))
			if fd != -1 and fd != 1:
				return false

	if typeof(dict["progression_flags"]) != TYPE_DICTIONARY:
		return false
	var pf_chk: Dictionary = dict["progression_flags"] as Dictionary
	if pf_chk.has("hearth_level"):
		if not EconomyLedger.is_exact_int_value(pf_chk["hearth_level"]):
			return false
		var hl: int = int(roundf(float(pf_chk["hearth_level"])))
		if hl < 1 or hl > 3:
			return false
	if pf_chk.has("reign_state") and typeof(pf_chk["reign_state"]) == TYPE_STRING:
		if not ["ACTIVE", "BREACH_PENALTY", "ISLAND_CLEARED"].has(String(pf_chk["reign_state"])):
			return false
	if pf_chk.has("shipwreck_stage"):
		if not EconomyLedger.is_exact_int_value(pf_chk["shipwreck_stage"]):
			return false
		var sw: int = int(roundf(float(pf_chk["shipwreck_stage"])))
		if sw < 0 or sw > 3:
			return false
	if pf_chk.has("node_states") and typeof(pf_chk["node_states"]) != TYPE_DICTIONARY:
		return false
	if pf_chk.has("node_states"):
		var ns_chk: Dictionary = pf_chk["node_states"] as Dictionary
		for ns_key: String in ns_chk.keys():
			if typeof(ns_chk[ns_key]) != TYPE_BOOL:
				return false
	if pf_chk.has("era_id"):
		if typeof(pf_chk["era_id"]) != TYPE_STRING:
			return false
		if String(pf_chk["era_id"]) not in EraProgressionManager.KNOWN_ERA_IDS:
			return false
	if pf_chk.has("tree_states"):
		if not ForestTreeManager.is_valid_saved_tree_states(pf_chk["tree_states"]):
			return false
	if pf_chk.has("hearth_boost_remaining"):
		if typeof(pf_chk["hearth_boost_remaining"]) not in [TYPE_FLOAT, TYPE_INT]:
			return false
		var hbr: float = float(pf_chk["hearth_boost_remaining"])
		if is_nan(hbr) or is_inf(hbr) or hbr < 0.0 or hbr > HearthSystem.BOOST_DURATION_SEC:
			return false
	if pf_chk.has("progression_facts"):
		# Fase 1 fondasi progresi: array fakta wajib ID valid yang dikenal
		# registry; ID asing tidak pernah diterima dari data simpanan.
		if not ProgressionState.is_valid_fact_array(pf_chk["progression_facts"]):
			return false

	if dict.has("research"):
		# Fase 4 fondasi riset: struktur ketat, ID teknologi well-formed dan unik,
		# proyek aktif tidak boleh bertabrakan dengan teknologi yang selesai.
		# Kepemilikan ID (unknown technology) divalidasi di apply_save_dict.
		if not ResearchManager.is_valid_saved_research_dict(dict["research"]):
			return false

	if dict.has("camp_vagrants_available"):
		if not EconomyLedger.is_exact_int_value(dict["camp_vagrants_available"]):
			return false
		var cva: int = int(roundf(float(dict["camp_vagrants_available"])))
		if cva < 0 or cva > NPCPopulationManager.MAX_CAMP_VAGRANTS:
			return false

	return true


func _write_and_verify_file(path: String, text: String, simulate_failure: bool) -> bool:
	if simulate_failure:
		return false
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.flush()
	f.close()
	return bool(_read_and_validate_file(path).get("ok", false))


func _safe_replace_file(src_tmp_path: String, dst_path: String, staged_old_path: String, simulate_failure: bool) -> bool:
	var abs_src: String = ProjectSettings.globalize_path(src_tmp_path)
	var abs_dst: String = ProjectSettings.globalize_path(dst_path)
	var abs_old: String = ProjectSettings.globalize_path(staged_old_path)

	# Extreme rollback test path: move active -> .old first, then simulate crash/failure before .tmp -> active
	if simulate_failure:
		_remove_if_exists(staged_old_path)
		if FileAccess.file_exists(dst_path):
			if DirAccess.rename_absolute(abs_dst, abs_old) == OK:
				# Simulate mid-swap failure right after active was moved to .old, then verify rollback!
				DirAccess.rename_absolute(abs_old, abs_dst)
		return false

	# 1. Try direct atomic POSIX rename first (replaces target atomically on Linux/macOS)
	if DirAccess.rename_absolute(abs_src, abs_dst) == OK:
		if bool(_read_and_validate_file(dst_path).get("ok", false)):
			return true

	# 2. Windows-safe staged swap: move existing target to .old (never delete before replacement succeeds)
	_remove_if_exists(staged_old_path)
	var moved_existing: bool = false
	if FileAccess.file_exists(dst_path):
		if DirAccess.rename_absolute(abs_dst, abs_old) != OK:
			return false
		moved_existing = true

	if DirAccess.rename_absolute(abs_src, abs_dst) != OK or not bool(_read_and_validate_file(dst_path).get("ok", false)):
		# Rollback from staged .old immediately so dst_path is never lost
		if moved_existing and FileAccess.file_exists(staged_old_path):
			DirAccess.rename_absolute(abs_old, abs_dst)
		return false

	# Only clean up .old after the new dst_path is verified valid
	if moved_existing:
		_remove_if_exists(staged_old_path)
	return true


func _restore_from_backup_file(bak_path: String, active_path: String) -> bool:
	if not bool(_read_and_validate_file(bak_path).get("ok", false)):
		return false
	var bak_text: String = FileAccess.get_file_as_string(bak_path)
	var restore_tmp: String = active_path + ".restore.tmp"
	if not _write_and_verify_file(restore_tmp, bak_text, false):
		_remove_if_exists(restore_tmp)
		return false
	return _safe_replace_file(restore_tmp, active_path, active_path + ".old", false)


func _remove_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _read_and_validate_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "File does not exist: %s" % path}
	var raw_text: String = FileAccess.get_file_as_string(path)
	if raw_text.strip_edges().is_empty():
		return {"ok": false, "error": "Empty save file: %s" % path}

	var parsed: Variant = migrate_payload(JSON.parse_string(raw_text))
	if not validate_payload(parsed):
		return {"ok": false, "error": "Invalid schema or corrupt payload in %s" % path}
	return {"ok": true, "data": parsed}
