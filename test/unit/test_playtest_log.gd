extends GutTest
## Playtest log file handling (dev tooling) and its wiring: one JSON line per
## finished run, tags rewrite that run's line, session and attempt numbers,
## git commit lookup, and failures that never break play.

const BUILD_SCREEN_SCENE: PackedScene = preload("res://scenes/build/build_screen.tscn")
const Fixtures = preload("res://test/support/fixtures.gd")

const LOG_PATH: String = "user://test_playtest_log_unit.jsonl"
const GIT_DIR: String = "user://test_fake_git"
const HASH: String = "0123456789abcdef0123456789abcdef01234567"

var _fx: Fixtures = Fixtures.new()


func before_each() -> void:
	_remove(LOG_PATH)


func after_all() -> void:
	_remove(LOG_PATH)
	_remove_git_dir()


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _record(session_id: String, attempt: int) -> Dictionary:
	var build: ShipBuild = ShipBuild.new()
	build.place(Vector2i(0, 0), _fx.cargo_hold)
	build.place(Vector2i(2, 0), _fx.cargo_hold)
	build.place(Vector2i(1, 1), _fx.fuel_tank)
	build.place(Vector2i(1, 2), _fx.thruster)
	return PlaytestRecord.build(build, _fx.cargo_run, RunResolver.resolve(build, _fx.cargo_run, 7), {
		"timestamp": "t", "commit": null, "session_id": session_id, "attempt": attempt,
	})


func _lines() -> PackedStringArray:
	return FileAccess.get_file_as_string(LOG_PATH).split("\n", false)


# --- File handling -------------------------------------------------------------

func test_suite_hook_redirects_the_default_path() -> void:
	assert_ne(PlaytestLog.default_path, PlaytestLog.DEFAULT_PATH, "tests must not write the real log")
	assert_eq(PlaytestLog.new().path, PlaytestLog.default_path)


func test_append_writes_one_line_per_run() -> void:
	var playtest: PlaytestLog = PlaytestLog.new(LOG_PATH)
	assert_eq(playtest.append(_record("a", 1)), OK)
	assert_eq(playtest.append(_record("a", 2)), OK)
	assert_eq(_lines().size(), 2)
	var records: Array[Dictionary] = playtest.read_records()
	assert_eq(int(records[1]["attempt"]), 2)
	assert_null(records[0]["difficulty"])


func test_tag_rewrites_only_that_runs_line_and_last_tag_wins() -> void:
	var playtest: PlaytestLog = PlaytestLog.new(LOG_PATH)
	playtest.append(_record("a", 1))
	playtest.append(_record("a", 2))
	playtest.append(_record("b", 1))
	var before: PackedStringArray = _lines()
	assert_eq(playtest.set_difficulty("a", 2, PlaytestRecord.TAG_TOO_HARD), OK)
	assert_eq(playtest.set_difficulty("a", 2, PlaytestRecord.TAG_FAIR), OK)
	var after: PackedStringArray = _lines()
	assert_eq(after.size(), 3, "still one line per run")
	assert_eq(after[0], before[0], "other runs untouched")
	assert_eq(after[2], before[2], "other runs untouched")
	assert_eq(after[1], before[1].replace("\"difficulty\":null", "\"difficulty\":\"fair\""),
			"only the tag changes; numbers keep their form")
	assert_eq(playtest.read_records()[1]["difficulty"], "fair")


func test_new_log_has_new_session_and_counts_attempts() -> void:
	var first: PlaytestLog = PlaytestLog.new(LOG_PATH)
	var second: PlaytestLog = PlaytestLog.new(LOG_PATH)
	assert_ne(first.session_id, second.session_id)
	assert_eq(first.session_id.length(), PlaytestLog.SESSION_ID_BYTES * 2)
	assert_eq(first.next_attempt(), 1)
	assert_eq(first.next_attempt(), 2)
	assert_eq(second.next_attempt(), 1)


func test_unwritable_path_returns_error_without_crashing() -> void:
	var playtest: PlaytestLog = PlaytestLog.new("user://no_such_dir/deeper/log.jsonl")
	assert_ne(playtest.append(_record("a", 1)), OK)
	assert_ne(playtest.set_difficulty("a", 1, PlaytestRecord.TAG_FAIR), OK)


func test_utc_timestamp_is_iso_8601_utc() -> void:
	var before: String = Time.get_datetime_string_from_system(true)
	var stamp: String = PlaytestLog.utc_timestamp()
	var regex: RegEx = RegEx.create_from_string("^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z$")
	assert_not_null(regex.search(stamp), "got %s" % stamp)
	assert_eq(stamp.substr(0, 13), before.substr(0, 13), "UTC, not local time (same date and hour)")


func test_unknown_tag_text_can_still_be_retagged() -> void:
	var playtest: PlaytestLog = PlaytestLog.new(LOG_PATH)
	playtest.append(_record("a", 1))
	assert_eq(playtest.set_difficulty("a", 1, "Too-Hard"), OK)
	assert_eq(playtest.set_difficulty("a", 1, PlaytestRecord.TAG_FAIR), OK)
	assert_eq(playtest.read_records()[0]["difficulty"], PlaytestRecord.TAG_FAIR)
	assert_false(FileAccess.file_exists(LOG_PATH + ".tmp"), "temp file swapped in")


func test_absolute_path_is_on_disk() -> void:
	var playtest: PlaytestLog = PlaytestLog.new(LOG_PATH)
	assert_false(playtest.absolute_path().begins_with("user://"))
	assert_string_ends_with(playtest.absolute_path(), LOG_PATH.get_file())


# --- Git commit ----------------------------------------------------------------

func _remove_git_dir() -> void:
	for file: String in ["HEAD", "packed-refs", "refs/heads/main"]:
		_remove(GIT_DIR.path_join(file))
	for dir: String in ["refs/heads", "refs", ""]:
		if DirAccess.dir_exists_absolute(GIT_DIR.path_join(dir)):
			DirAccess.remove_absolute(GIT_DIR.path_join(dir))


func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func test_git_commit_null_without_git() -> void:
	assert_null(PlaytestLog.read_git_commit("user://no_git_here"))


func test_git_commit_from_loose_ref() -> void:
	_remove_git_dir()
	_write(GIT_DIR.path_join("HEAD"), "ref: refs/heads/main\n")
	_write(GIT_DIR.path_join("refs/heads/main"), HASH + "\n")
	assert_eq(PlaytestLog.read_git_commit(GIT_DIR), HASH)


func test_git_commit_from_packed_refs_and_detached_head() -> void:
	_remove_git_dir()
	_write(GIT_DIR.path_join("HEAD"), "ref: refs/heads/main\n")
	_write(GIT_DIR.path_join("packed-refs"), "# pack-refs with: peeled\n%s refs/heads/main\n" % HASH)
	assert_eq(PlaytestLog.read_git_commit(GIT_DIR), HASH)
	_write(GIT_DIR.path_join("HEAD"), HASH + "\n")
	assert_eq(PlaytestLog.read_git_commit(GIT_DIR), HASH)


func test_this_repo_reports_a_full_commit() -> void:
	var commit: Variant = PlaytestLog.read_git_commit()
	assert_true(commit is String and (commit as String).length() == 40, "got %s" % str(commit))


# --- Build and run screen wiring -------------------------------------------------

func _open_build_screen() -> Control:
	var screen: Control = BUILD_SCREEN_SCENE.instantiate() as Control
	screen.set("mission", _fx.cargo_run)
	screen.set("playtest_log", PlaytestLog.new(LOG_PATH))
	add_child_autofree(screen)
	var build: ShipBuild = screen.get("build") as ShipBuild
	build.place(Vector2i(0, 0), _fx.cargo_hold)
	build.place(Vector2i(2, 0), _fx.cargo_hold)
	build.place(Vector2i(0, 1), _fx.fuel_tank)
	build.place(Vector2i(2, 1), _fx.fuel_tank)
	build.place(Vector2i(1, 2), _fx.thruster)
	return screen


func _launch(screen: Control) -> RunScreen:
	(screen.get_node("%LaunchButton") as Button).pressed.emit()
	return screen.call("get_run_screen") as RunScreen


func _finish(run: RunScreen) -> void:
	run._process(PlaybackClock.DEFAULT_SECONDS_PER_CARD * (_fx.cargo_run.card_pool.size() + 1))
	assert_true(run.is_outcome_shown())


func test_build_screen_shows_the_log_path() -> void:
	var screen: Control = _open_build_screen()
	var playtest: PlaytestLog = screen.get("playtest_log") as PlaytestLog
	assert_string_contains((screen.get_node("%LogPathLabel") as Label).text, playtest.absolute_path())


func test_nothing_logged_until_the_outcome_appears() -> void:
	var screen: Control = _open_build_screen()
	var run: RunScreen = _launch(screen)
	run._process(0.0)
	assert_false(FileAccess.file_exists(LOG_PATH))
	_finish(run)
	run._process(PlaybackClock.DEFAULT_SECONDS_PER_CARD)
	assert_eq(_lines().size(), 1, "written once, when the outcome appears")


func test_finished_run_is_logged_and_untagged_without_a_click() -> void:
	var screen: Control = _open_build_screen()
	var run: RunScreen = _launch(screen)
	var result: RunResult = run.get_result()
	_finish(run)
	(run.get_node("%RebuildButton") as Button).pressed.emit()
	await wait_process_frames(1)
	var records: Array[Dictionary] = (screen.get("playtest_log") as PlaytestLog).read_records()
	assert_eq(records.size(), 1)
	assert_eq(int(records[0]["seed"]), result.seed)
	assert_eq(int(records[0]["attempt"]), 1)
	assert_eq(records[0]["commit"], PlaytestLog.read_git_commit())
	assert_true(String(records[0]["timestamp"]).ends_with("Z"))
	assert_eq(records[0]["outcome"], "won" if result.won else "lost")
	assert_null(records[0]["difficulty"])


func test_feedback_tags_the_run_and_attempts_count_up() -> void:
	var screen: Control = _open_build_screen()
	var playtest: PlaytestLog = screen.get("playtest_log") as PlaytestLog
	var run: RunScreen = _launch(screen)
	_finish(run)
	(run.get_node("%TooHardButton") as Button).pressed.emit()
	assert_eq(run.get_difficulty_tag(), PlaytestRecord.TAG_TOO_HARD)
	assert_true((run.get_node("%TooHardButton") as Button).button_pressed)
	(run.get_node("%TooEasyButton") as Button).pressed.emit()
	assert_false((run.get_node("%TooHardButton") as Button).button_pressed, "one tag shown at a time")
	(run.get_node("%RetryButton") as Button).pressed.emit()
	await wait_process_frames(1)

	run = _launch(screen)
	_finish(run)
	assert_eq(run.get_difficulty_tag(), "", "a new run starts untagged")
	(run.get_node("%FairButton") as Button).pressed.emit()

	var records: Array[Dictionary] = playtest.read_records()
	assert_eq(records.size(), 2)
	assert_eq(records[0]["difficulty"], PlaytestRecord.TAG_TOO_EASY)
	assert_eq(records[1]["difficulty"], PlaytestRecord.TAG_FAIR)
	assert_eq(records[0]["session_id"], playtest.session_id)
	assert_eq(records[1]["session_id"], playtest.session_id)
	assert_eq(int(records[1]["attempt"]), 2)
	assert_eq(records[1]["seed"], records[0]["seed"], "retry kept the seed")
