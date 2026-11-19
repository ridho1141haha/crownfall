## Runner-level save-isolation gate (round 2).
##
## tests/run_all.sh redirects HOME/XDG_DATA_HOME/XDG_CACHE_HOME of the WHOLE
## run into a fresh temporary base before executing any Godot process, so no
## suite (present or future) can touch the developer's real user data
## directory. This gate PROVES the redirection took effect before the runner
## proceeds — an env override alone is never trusted (round-2 review
## requirement): OS.get_user_data_dir() must actually resolve INSIDE the
## runner sandbox, the default autosave path must resolve inside it too, and
## the sandbox must start with no pre-existing autosave slot. Audit round 3:
## containment is additionally proven on CANONICALIZED paths (readlink -m),
## so a symlinked sandbox can never satisfy the gate. Fail-closed:
## any failed condition aborts this runner step (exit 1) before the import
## step or any suite runs.
## PLATFORM: the gate is validated on Linux (XDG redirection + rm-based
## cleanup are Linux-specific); on any other platform it reports an explicit
## SKIP (exit 2) — the runner itself handles unsupported platforms explicitly.
extends SceneTree

const RUNNER_PREFIX: String = "/tmp/step3_runner_iso_"
const REAL_SAVE: String = SaveManager.DEFAULT_SAVE_PATH

var _checks: int = 0
var _failed: int = 0


func _check(cond: bool, msg: String) -> bool:
	_checks += 1
	if cond:
		print("CHECK OK: %s" % msg)
	else:
		_failed += 1
		print("TEST FAILURE: %s" % msg)
	return cond


func _is_descendant_of(child_path: String, base_path: String) -> bool:
	# Same TRUE-descendant containment as the 3A suite: lexical normalization
	# (String.simplify_path) + a path-component boundary match — never a bare
	# string prefix. Empty and root bases contain nothing.
	var child: String = child_path.simplify_path()
	var base: String = base_path.simplify_path()
	if base == "" or base == "/":
		return false
	if child == base:
		return true
	return child.begins_with(base + "/")


func _canonicalize(path: String) -> String:
	# F5 (audit round 3): resolve symlinks for EVERY path component via GNU
	# readlink -m (also works for not-yet-existing tails). An empty string
	# means resolution failed — callers must treat that as fail-closed.
	var out: Array = []
	var rc: int = OS.execute("readlink", ["-m", "--", path], out, true)
	if rc != 0 or out.is_empty():
		return ""
	var resolved: String = String(out[0]).strip_edges()
	if resolved.contains("\n"):
		resolved = resolved.split("\n")[0]
	return resolved if resolved.is_absolute_path() else ""


func _initialize() -> void:
	if OS.get_name() != "Linux":
		print("SKIP: runner sandbox gate is validated on Linux only (XDG redirection + rm-based cleanup); not executing on %s" % OS.get_name())
		quit(2)
		return
	var base: String = OS.get_environment("RUNNER_SANDBOX_BASE").simplify_path()
	var user_dir: String = OS.get_user_data_dir().simplify_path()
	var slot_global: String = ProjectSettings.globalize_path(REAL_SAVE).simplify_path()
	var conditions: Array = [
		[base != "" and base.is_absolute_path() and base.begins_with(RUNNER_PREFIX),
			"gate: runner sandbox base is a self-generated absolute step3_runner_iso path (%s)" % base],
		[_is_descendant_of(user_dir, base),
			"gate: process user data dir is a TRUE descendant of the runner sandbox (%s)" % user_dir],
		[_is_descendant_of(slot_global, base),
			"gate: default autosave path is a TRUE descendant of the runner sandbox (%s)" % slot_global],
		[_is_descendant_of(_canonicalize(user_dir), _canonicalize(base)),
			"gate: canonicalized user data dir is a TRUE descendant of the canonicalized runner sandbox (symlink-proof)"],
		[not FileAccess.file_exists(REAL_SAVE),
			"gate: runner sandbox starts with NO pre-existing autosave slot"],
	]
	var problems: PackedStringArray = PackedStringArray()
	for cond: Array in conditions:
		if not bool(cond[0]):
			problems.append(String(cond[1]))
	if not problems.is_empty():
		for p: String in problems:
			print("TEST FAILURE: runner sandbox gate: %s" % p)
		print("TEST FAILURE: runner sandbox gate refused the run — the user:// root is NOT proven to be inside the runner sandbox; no suite may execute")
		quit(1)
		return
	for cond: Array in conditions:
		_check(true, String(cond[1]))
	print("PASS: runner sandbox gate — user:// resolves inside the runner sandbox (%d checks)" % _checks)
	quit(0)
