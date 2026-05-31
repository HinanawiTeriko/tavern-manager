extends Node

## GM 级存档 round-trip：capture→write→破坏内存→read→apply→断言；以及 new_game 重置。
## 标题页按钮与场景流转走人工验证（headless 测不到）。

var _checks := 0
var _failures := 0

func _ready() -> void:
	_test_capture_apply_roundtrip()
	_test_new_game_resets()
	_finish()

func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-SAVE-RT] FAIL: " + msg)

func _finish() -> void:
	if _failures == 0:
		print("[TEST-SAVE-RT] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-SAVE-RT] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)

func _gm():
	return get_node("/root/GameManager")

func _test_capture_apply_roundtrip() -> void:
	var gm = _gm()
	gm.economy.current_day = 2
	gm.economy.gold = 88
	gm.economy.reputation = 6
	gm.inventory_sys.set_initial({"ale": 9, "sleep_powder": 1})
	gm.craft.unlock_recipe("meat_cooked")
	gm.narrative.set_var("ryan_informed", true)
	gm.narrative.set_ending("ryan", "informed_fallen")
	gm.documents.grant_document("bloodied_contract")
	gm.documents.request_open("bloodied_contract")

	var snap: Dictionary = gm._capture_save_state()
	gm.save_sys.write(snap)

	# 破坏内存状态，再从磁盘恢复
	gm.economy.gold = 0
	gm.economy.current_day = 1
	gm.inventory_sys.set_initial({})
	gm.narrative.set_var("ryan_informed", false)

	gm._apply_save_state(gm.save_sys.read())
	_ok(gm.economy.current_day == 2, "day restored")
	_ok(gm.economy.gold == 88, "gold restored")
	_ok(gm.inventory_sys.get_count("ale") == 9, "inventory restored")
	_ok(gm.inventory_sys.get_count("sleep_powder") == 1, "story item restored")
	_ok(gm.craft.is_recipe_unlocked("meat_cooked"), "recipe unlock restored")
	_ok(bool(gm.narrative.dialogue_vars.get("ryan_informed", false)), "ryan flag restored")
	_ok(String(gm.narrative.endings.get("ryan", "")) == "informed_fallen", "ending restored")
	_ok(gm.documents.is_read("bloodied_contract"), "document read restored")
	_ok(gm.inventory == gm.inventory_sys.materials, "gm.inventory still references system stock after restore")
	gm.save_sys.clear()

func _test_new_game_resets() -> void:
	var gm = _gm()
	gm._apply_save_state(gm._default_new_game_state())
	_ok(gm.economy.current_day == 1, "new game day 1")
	_ok(gm.economy.gold == 0, "new game gold 0")
	_ok(not gm.craft.is_recipe_unlocked("meat_cooked"), "new game clears recipe unlocks")
	_ok(not bool(gm.narrative.dialogue_vars.get("ryan_informed", false)), "new game clears ryan flags")
	_ok(not gm.documents.is_read("bloodied_contract"), "new game clears document read")
	_ok(gm.documents.owns_document("ledger"), "new game keeps ledger")
	gm.save_sys.clear()
