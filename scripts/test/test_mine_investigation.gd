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
	await _test_scene_collect_feedback_is_labeled_evidence()
	await _test_scene_feedback_names_unlocked_inference()
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


func _test_scene_collect_feedback_is_labeled_evidence() -> void:
	var gm = get_node("/root/GameManager")
	var snapshot: Dictionary = gm._capture_save_state()
	gm._apply_save_state(gm._default_new_game_state())
	var scene: MineInvestigation = preload("res://scenes/ui/MineInvestigation.tscn").instantiate()
	add_child(scene)
	await get_tree().process_frame
	scene._take_contract()
	var hint := _label_text(scene, "UI/HintLabel")
	_ok(hint.contains("证据 · 染血委托书"),
		"collecting the mine contract labels the immediate feedback as evidence")
	_ok(hint.contains("收入账本"),
		"collecting the mine contract tells the player the evidence went into the ledger")
	scene.queue_free()
	await get_tree().process_frame
	gm._apply_save_state(snapshot)


func _test_scene_feedback_names_unlocked_inference() -> void:
	var gm = get_node("/root/GameManager")
	var snapshot: Dictionary = gm._capture_save_state()
	gm._apply_save_state(gm._default_new_game_state())
	_solve_toby_commission_risk(gm)
	gm.grant_investigation_document("grey_ryan_case_number")
	gm.grant_investigation_document("grey_blacktooth_batch")
	var scene: MineInvestigation = preload("res://scenes/ui/MineInvestigation.tscn").instantiate()
	add_child(scene)
	await get_tree().process_frame
	_ok(gm.grant_investigation_document("grey_payout_closure"),
		"granting the third grey-ledger evidence unlocks a new deduction")
	var feedback := scene._evidence_feedback_text(gm, "grey_payout_closure", true)
	_ok(feedback.contains("推断 · "), "evidence feedback labels newly unlocked deduction")
	_ok(feedback.contains("莱恩与托比的同批灰账"),
		"evidence feedback names the newly unlocked deduction")
	scene.queue_free()
	await get_tree().process_frame
	gm._apply_save_state(snapshot)


func _solve_toby_commission_risk(gm: Node) -> void:
	gm.inference.add_clues(["toby_name", "back_alley_boy", "blacktooth_escort", "high_pay_trap", "one_person_walk"])
	gm.apply_inference_result(gm.inference.try_place("toby_identity", "name", "toby_name"))
	gm.apply_inference_result(gm.inference.try_place("toby_identity", "identity", "back_alley_boy"))
	gm.apply_inference_result(gm.inference.try_place("toby_commission_risk", "commission", "blacktooth_escort"))
	gm.apply_inference_result(gm.inference.try_place("toby_commission_risk", "risk", "high_pay_trap"))
	gm.apply_inference_result(gm.inference.try_place("toby_commission_risk", "mindset", "one_person_walk"))


func _label_text(scene: Node, path: String) -> String:
	var label := scene.get_node_or_null(path) as Label
	_ok(label != null, path + " exists")
	return label.text if label != null else ""
