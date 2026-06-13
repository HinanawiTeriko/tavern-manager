extends Node

## 托比落脚处物理调查的 headless 逻辑回归。镜像 test_mine_investigation 的取舍：
##   1. locations.json 数据契约——告示板贴文不再授予 toby_contract、改由场景授予；
##      托比落脚处地点 day≥6 存在、不走自动授予；
##   2. GameManager.grant_investigation_document 对 toby_contract 的幂等与授予。
## 拼合的物理手感（拖碎片靠拢）只能编辑器走查，不在此 headless 覆盖。

var _checks := 0
var _failures := 0


func _ready() -> void:
	_test_locations_contract()
	_test_grant_idempotent_and_owned()
	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-TOBY] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-TOBY] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-TOBY] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _test_locations_contract() -> void:
	var f := FileAccess.open("res://data/locations.json", FileAccess.READ)
	_ok(f != null, "locations.json opens")
	var data: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	var locations: Array = (data as Dictionary).get("locations", [])
	var board_ok := false
	var lodging_ok := false
	for loc in locations:
		if String(loc.get("id", "")) == "mercenary_board":
			for posting in loc.get("postings", []):
				if String(posting.get("id", "")) == "toby_commission":
					board_ok = true
					_ok(not posting.has("documents") or (posting.get("documents", []) as Array).is_empty(),
						"toby_commission 贴文不再直接授予委托书（搬进场景）")
		if String(loc.get("id", "")) == "toby_lodging":
			lodging_ok = true
			_ok(int(loc.get("dayMin", 0)) == 6, "托比落脚处 day≥6 开放")
			_ok(not loc.has("documents") or (loc.get("documents", []) as Array).is_empty(),
				"托比落脚处不走自动授予（场景内拼合授予）")
	_ok(board_ok, "找到 toby_commission 贴文")
	_ok(lodging_ok, "找到 toby_lodging 地点")


func _test_grant_idempotent_and_owned() -> void:
	var gm = get_node("/root/GameManager")
	_ok(not gm.documents.owns_document("toby_contract"), "toby_contract not owned at start")
	var newly: bool = gm.grant_investigation_document("toby_contract")
	_ok(newly, "first grant returns newly-granted")
	_ok(gm.documents.owns_document("toby_contract"), "toby_contract owned after grant")
	_ok(gm.narrative.get_var("toby_contract_found") == true, "granting toby_contract marks route proof found")
	_ok(gm.inventory_sys.get_count("toby_contract") == 1, "granting adds it to story bag")
	_ok(not gm.grant_investigation_document("toby_contract"), "second grant is idempotent (not newly)")
