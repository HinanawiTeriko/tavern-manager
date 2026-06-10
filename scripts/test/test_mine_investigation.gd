extends Node

## 废弃矿道物理调查的 headless 逻辑回归。
## 只覆盖 test_day_map_system 未覆盖的两点：
##   1. locations.json 数据契约——矿道不再自动授予文档、仍由 mine_clue 门控；
##   2. GameManager.grant_investigation_document 的幂等与授予。
## 「挖到才开公会柜台」的连锁已由 test_day_map_system 覆盖，这里不重复。

var _checks := 0
var _failures := 0


func _ready() -> void:
	_test_locations_no_auto_grant()
	_test_grant_idempotent_and_owned()
	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-MINE] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-MINE] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-MINE] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _test_locations_no_auto_grant() -> void:
	# 矿道的文档授予已搬进物理场景，locations.json 不应再带 documents；门控不变。
	var f := FileAccess.open("res://data/locations.json", FileAccess.READ)
	_ok(f != null, "locations.json opens")
	var data: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	_ok(data is Dictionary and (data as Dictionary).has("locations"), "locations.json has locations array")
	var locations: Array = (data as Dictionary).get("locations", [])
	var found := false
	for loc in locations:
		if String(loc.get("id", "")) == "abandoned_mine":
			found = true
			_ok(not loc.has("documents") or (loc.get("documents", []) as Array).is_empty(),
				"abandoned_mine has no auto-grant documents (granted in scene)")
			_ok(String(loc.get("requiresFlag", "")) == "mine_clue", "mine still gated by mine_clue")
	_ok(found, "abandoned_mine exists in locations.json")


func _test_grant_idempotent_and_owned() -> void:
	# 经 GameManager 中介授予；首次授予返回 true、再次幂等返回 false。
	var gm = get_node("/root/GameManager")
	_ok(not gm.documents.owns_document("bloodied_contract"), "contract not owned at start")
	var newly: bool = gm.grant_investigation_document("bloodied_contract")
	_ok(newly, "first grant_investigation_document returns newly-granted")
	_ok(gm.documents.owns_document("bloodied_contract"), "contract owned after grant")
	_ok(not gm.grant_investigation_document("bloodied_contract"), "second grant is idempotent (not newly)")
