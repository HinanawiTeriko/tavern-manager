extends Node

var _checks := 0
var _failures := 0


func _ready() -> void:
	_test_add_remove_real_deduction()
	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-INVENTORY] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-INVENTORY] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-INVENTORY] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _test_add_remove_real_deduction() -> void:
	var inv := InventorySystem.new()
	inv.set_initial({"ale": 5})
	_ok(inv.get_count("ale") == 5, "initial ale count should be 5")
	inv.add("ale", 2)
	_ok(inv.get_count("ale") == 7, "add should increase count")
	_ok(inv.remove("ale", 3), "remove with enough stock should succeed")
	_ok(inv.get_count("ale") == 4, "remove should really deduct")
	_ok(not inv.remove("ale", 99), "remove beyond stock should fail")
	_ok(inv.get_count("ale") == 4, "failed remove should not change count")
	_ok(inv.remove("ale", 4), "remove all should succeed")
	_ok(inv.get_count("ale") == 0, "depleted key should report 0")
	_ok(not inv.has("ale"), "depleted key should not be present")
	inv.add("ale", -1)
	_ok(inv.get_count("ale") == 0, "negative add should be a no-op")
	_ok(not inv.remove("ale", 0), "remove with zero amount should fail")
