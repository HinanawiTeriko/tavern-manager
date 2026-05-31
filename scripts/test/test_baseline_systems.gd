extends Node

var _checks := 0
var _failures := 0


func _ready() -> void:
	_test_orderable_products_respect_purchase_unlock()
	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-BASELINE] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-BASELINE] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-BASELINE] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _test_orderable_products_respect_purchase_unlock() -> void:
	var craft := CraftSystem.new()
	craft.load_data()
	var before := craft.get_orderable_products(1)
	_ok(before.has("ale_beer"), "basic ale_beer should be orderable")
	_ok(not before.has("herbal_ale"), "shop recipe should not be orderable before unlock")
	craft.unlock_recipe("herbal_ale")
	var after := craft.get_orderable_products(1)
	_ok(after.has("herbal_ale"), "shop recipe should become orderable after unlock")
