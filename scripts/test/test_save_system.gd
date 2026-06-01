extends Node

var _checks := 0
var _failures := 0

func _ready() -> void:
	_test_roundtrip_exact()
	_test_has_and_clear()
	_test_missing_returns_empty()
	_test_version_mismatch_ignored()
	_finish()

func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-SAVE] FAIL: " + msg)

func _finish() -> void:
	if _failures == 0:
		print("[TEST-SAVE] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-SAVE] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)

func _test_roundtrip_exact() -> void:
	var s := SaveSystem.new()
	s.clear()
	var snap := {
		"economy": {"current_day": 2, "gold": 37, "reputation": 4},
		"inventory": {"ale": 12, "sleep_powder": 1},
		"flags": {"ryan_informed": true, "ryan_drugged": false, "ryan_ending": "informed_fallen"},
		"list": ["ledger", "bloodied_contract"],
	}
	_ok(s.write(snap), "write should succeed")
	var got := s.read()
	_ok(int(got["economy"]["current_day"]) == 2, "current_day int preserved")
	_ok(typeof(got["economy"]["gold"]) == TYPE_INT, "gold normalized to int, not float")
	_ok(int(got["inventory"]["sleep_powder"]) == 1, "inventory count preserved")
	_ok(got["flags"]["ryan_informed"] == true, "bool true preserved")
	_ok(got["flags"]["ryan_drugged"] == false, "bool false preserved")
	_ok(String(got["flags"]["ryan_ending"]) == "informed_fallen", "string preserved")
	_ok(got["list"] == ["ledger", "bloodied_contract"], "array preserved")
	s.clear()

func _test_has_and_clear() -> void:
	var s := SaveSystem.new()
	s.clear()
	_ok(not s.has_save(), "no save after clear")
	s.write({"a": 1})
	_ok(s.has_save(), "has_save true after write")
	s.clear()
	_ok(not s.has_save(), "has_save false after clear")

func _test_missing_returns_empty() -> void:
	var s := SaveSystem.new()
	s.clear()
	_ok(s.read().is_empty(), "read with no save returns empty dict")

func _test_version_mismatch_ignored() -> void:
	var s := SaveSystem.new()
	var file := FileAccess.open(SaveSystem.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 999, "data": {"x": 1}}))
	file.close()
	_ok(s.read().is_empty(), "version mismatch read returns empty")
	s.clear()
