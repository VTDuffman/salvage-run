class_name PlaytestLog
extends RefCounted
## Appends playtest records as JSON Lines to a file outside the repo. Dev
## tooling only: holds the session id and attempt count for one game launch,
## and never touches game rules. Failures only warn; play is never blocked.

const DEFAULT_PATH: String = "user://playtest_log.jsonl"
const SESSION_ID_BYTES: int = 8
## The difficulty field as JSON.stringify writes it (no spaces).
const DIFFICULTY_PATTERN: String = "\"difficulty\":(null|\"[^\"]*\")"

## Where new logs write. The test suite's pre-run hook redirects this so tests
## never touch the real log.
static var default_path: String = DEFAULT_PATH

var path: String
## New for every launch of the game (every PlaytestLog instance).
var session_id: String
var _attempt: int = 0


func _init(log_path: String = "") -> void:
	path = log_path if not log_path.is_empty() else default_path
	session_id = Crypto.new().generate_random_bytes(SESSION_ID_BYTES).hex_encode()


## Counts a launch and returns its 1-based attempt number in this session.
func next_attempt() -> int:
	_attempt += 1
	return _attempt


## The log file's full path on disk.
func absolute_path() -> String:
	return ProjectSettings.globalize_path(path)


## Appends [param record] as one line.
func append(record: Dictionary) -> Error:
	var mode: FileAccess.ModeFlags = FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE
	var file: FileAccess = FileAccess.open(path, mode)
	if file == null:
		return _warn("open", FileAccess.get_open_error())
	file.seek_end()
	file.store_line(JSON.stringify(record))
	file.close()
	return OK


## Sets [code]difficulty[/code] to [param tag] on the last line matching
## [param run_session_id] and [param attempt], rewriting the file. Other lines
## are kept byte for byte.
func set_difficulty(run_session_id: String, attempt: int, tag: String) -> Error:
	if not FileAccess.file_exists(path):
		return _warn("tag (no log file)", ERR_FILE_NOT_FOUND)
	var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
	for i: int in range(lines.size() - 1, -1, -1):
		var parsed: Variant = JSON.parse_string(lines[i]) if not lines[i].is_empty() else null
		if parsed is Dictionary and parsed.get("session_id") == run_session_id \
				and int(parsed.get("attempt", 0)) == attempt:
			# Edit the text rather than re-encode: JSON parsing turns every
			# number into a float, which would rewrite 3 as 3.0.
			var regex: RegEx = RegEx.create_from_string(DIFFICULTY_PATTERN)
			if regex.search(lines[i]) == null:
				return _warn("tag (no difficulty field)", ERR_PARSE_ERROR)
			lines[i] = regex.sub(lines[i], "\"difficulty\":" + JSON.stringify(tag))
			# Write a copy and swap it in, so a failed write never empties the log.
			var temp_path: String = path + ".tmp"
			var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
			if file == null:
				return _warn("rewrite", FileAccess.get_open_error())
			file.store_string("\n".join(lines))
			file.close()
			var error: Error = DirAccess.rename_absolute(temp_path, path)
			if error != OK:
				return _warn("rewrite", error)
			return OK
	return _warn("tag (run not found)", ERR_DOES_NOT_EXIST)


## Every record in the log, oldest first; unparsable lines are skipped.
func read_records() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	if not FileAccess.file_exists(path):
		return records
	for line: String in FileAccess.get_file_as_string(path).split("\n", false):
		var parsed: Variant = JSON.parse_string(line)
		if parsed is Dictionary:
			records.append(parsed)
	return records


## Current UTC time as ISO 8601, e.g. "2026-11-11T09:30:00Z".
static func utc_timestamp() -> String:
	return Time.get_datetime_string_from_system(true) + "Z"


## The checked-out commit's full hash, read from the project's .git folder,
## or null when there is none. Always null outside the editor binary: an
## exported build has no res://.git and must not pick up an unrelated one.
static func read_git_commit(git_dir: String = "res://.git") -> Variant:
	if not OS.has_feature("editor"):
		return null
	var dir: String = ProjectSettings.globalize_path(git_dir)
	var head: String = _read_trimmed(dir.path_join("HEAD"))
	if head.is_empty():
		return null
	if not head.begins_with("ref: "):
		return head
	var ref: String = head.substr(5)
	var loose: String = _read_trimmed(dir.path_join(ref))
	if not loose.is_empty():
		return loose
	for line: String in _read_trimmed(dir.path_join("packed-refs")).split("\n", false):
		var parts: PackedStringArray = line.strip_edges().split(" ")
		if parts.size() == 2 and parts[1] == ref:
			return parts[0]
	return null


static func _read_trimmed(file_path: String) -> String:
	if not FileAccess.file_exists(file_path):
		return ""
	return FileAccess.get_file_as_string(file_path).strip_edges()


func _warn(action: String, error: Error) -> Error:
	push_warning("Playtest log: %s failed for %s (%s)" % [action, absolute_path(), error_string(error)])
	return error
