extends GutHookScript
## Pre-run hook: points every PlaytestLog the suite creates at a throwaway
## file, so tests that play a run to its outcome never touch the real
## user://playtest_log.jsonl.

const TEST_LOG_PATH: String = "user://test_playtest_log.jsonl"


func run() -> void:
	PlaytestLog.default_path = TEST_LOG_PATH
	if FileAccess.file_exists(TEST_LOG_PATH):
		DirAccess.remove_absolute(TEST_LOG_PATH)
