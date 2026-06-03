extends Node

## 香料系统单元测：数据查询 + resolve_seasoning_application 判定。
## 物理装罐/摇撒走人工编辑器验证。

var _checks := 0
var _failures := 0


func _ready() -> void:
	_test_seasoning_queries()
	_test_taste_applies_attribute()
	_test_sleep_powder_on_ale()
	_test_sleep_powder_rejects_non_ale()
	_test_non_seasoning_rejected()
	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-SEASONING] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-SEASONING] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-SEASONING] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _gm():
	return get_node("/root/GameManager")


func _test_seasoning_queries() -> void:
	var s = _gm().seasoning
	_ok(s.get_attribute("spice") == "辛辣", "spice attribute is 辛辣")
	_ok(s.get_category("spice") == "taste", "spice category is taste")
	_ok(s.get_category("sleep_powder") == "effect", "sleep_powder category is effect")
	_ok(s.get_product_tag("sleep_powder") == "sleep_powder", "sleep_powder carries product_tag")
	_ok(s.get_product_tag("spice") == "", "taste seasoning has no product_tag")


func _test_taste_applies_attribute() -> void:
	var r: Dictionary = _gm().resolve_seasoning_application("spice", "ale_beer")
	_ok(r.get("accepted", false), "taste seasoning always applies")
	_ok(String(r.get("attribute", "")) == "辛辣", "taste seasoning writes its attribute")
	_ok((r.get("product_tags", []) as Array).is_empty(), "taste seasoning carries no tag")


func _test_sleep_powder_on_ale() -> void:
	var r: Dictionary = _gm().resolve_seasoning_application("sleep_powder", "ale_beer")
	_ok(r.get("accepted", false), "sleep_powder applies to ale_beer")
	_ok(String(r.get("attribute", "")) == "安眠", "drugged ale gets 安眠 attribute")
	_ok((r.get("product_tags", []) as Array).has("sleep_powder"), "drugged ale carries sleep_powder tag")


func _test_sleep_powder_rejects_non_ale() -> void:
	var r: Dictionary = _gm().resolve_seasoning_application("sleep_powder", "bread")
	_ok(not r.get("accepted", true), "sleep_powder rejects non-ale products")


func _test_non_seasoning_rejected() -> void:
	var r: Dictionary = _gm().resolve_seasoning_application("ale", "ale_beer")
	_ok(not r.get("accepted", true), "non-seasoning key is rejected")
