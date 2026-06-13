extends Node

## GM 级存档 round-trip：capture→write→破坏内存→read→apply→断言；以及 new_game 重置。
## 标题页按钮与场景流转走人工验证（headless 测不到）。

var _checks := 0
var _failures := 0
var _had_original_save := false
var _original_save: Dictionary = {}

func _ready() -> void:
	var gm = _gm()
	_had_original_save = gm.save_sys.has_save()
	_original_save = gm.save_sys.read()
	_test_capture_apply_roundtrip()
	_test_apply_old_save_merges_new_narrative_defaults()
	_test_reset_tutorial_progress_clears_runtime_and_save_snapshot()
	_test_new_game_resets()
	_finish()

func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-SAVE-RT] FAIL: " + msg)

func _finish() -> void:
	_restore_original_save()
	if _failures == 0:
		print("[TEST-SAVE-RT] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-SAVE-RT] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)

func _gm():
	return get_node("/root/GameManager")

func _restore_original_save() -> void:
	var gm = _gm()
	if _had_original_save:
		gm.save_sys.write(_original_save)
	else:
		gm.save_sys.clear()

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

func _test_apply_old_save_merges_new_narrative_defaults() -> void:
	var gm = _gm()
	var old_save: Dictionary = gm._default_new_game_state()
	old_save["economy"]["current_day"] = 4
	var old_dialogue_vars := {
		"has_sleep_powder": false,
		"ryan_informed": false,
		"ryan_warhammer_lead": true,
		"ryan_has_alternative": false,
		"ryan_drugged": false,
		"ryan_interaction_closed": false,
		"ryan_alternative_pending": false,
		"ryan_alternative_declined": false,
		"ryan_ending": "uninformed_fallen",
		"aff_ryan": 6,
		"aff_mira": 5,
	}
	old_save["narrative"]["dialogue_vars"] = old_dialogue_vars

	gm._apply_save_state(old_save)

	_ok(gm.economy.current_day == 4, "old save day restored")
	_ok(gm.narrative.dialogue_vars.has("told_mira_truth"),
		"old save restore fills missing told_mira_truth default")
	_ok(gm.narrative.dialogue_vars.has("mira_ending"),
		"old save restore fills missing mira_ending default")
	_ok(gm.narrative.dialogue_vars.has("toby_secured"),
		"old save restore fills missing toby_secured default")
	_ok(gm.narrative.dialogue_vars.get("ryan_ending", "") == "uninformed_fallen",
		"old save restore preserves existing Ryan ending")

func _test_reset_tutorial_progress_clears_runtime_and_save_snapshot() -> void:
	var gm = _gm()
	var tm = get_node("/root/TutorialManager")
	tm._completed_steps = ["gather_intro", "craft_intro", "serve_intro"]
	tm.daymap_first_shown = true
	tm.tavern_first_entered = true
	tm.shop_first_visited = true
	tm.first_guest_arrived = true
	tm.first_product_seasoned = true
	tm.first_guest_served = true
	tm.first_ledger_shown = true
	gm.save_sys.write(gm._capture_save_state())

	gm.reset_tutorial_progress()

	_ok(tm._completed_steps.is_empty(), "tutorial reset clears completed steps")
	_ok(not tm.daymap_first_shown, "tutorial reset clears daymap flag")
	_ok(not tm.tavern_first_entered, "tutorial reset clears tavern flag")
	_ok(not tm.shop_first_visited, "tutorial reset clears shop flag")
	_ok(not tm.first_guest_arrived, "tutorial reset clears guest arrival flag")
	_ok(not tm.first_product_seasoned, "tutorial reset clears seasoning flag")
	_ok(not tm.first_guest_served, "tutorial reset clears served flag")
	_ok(not tm.first_ledger_shown, "tutorial reset clears ledger flag")

	var saved: Dictionary = gm.save_sys.read()
	var tutorial_state: Dictionary = saved.get("tutorial", {})
	_ok(tutorial_state.get("completed_steps", ["stale"]).is_empty(), "tutorial reset writes cleared completed steps to save")
	_ok(not bool(tutorial_state.get("daymap_first_shown", true)), "tutorial reset writes cleared daymap flag to save")
	_ok(not bool(tutorial_state.get("tavern_first_entered", true)), "tutorial reset writes cleared tavern flag to save")
	_ok(not bool(tutorial_state.get("shop_first_visited", true)), "tutorial reset writes cleared shop flag to save")
	_ok(not bool(tutorial_state.get("first_guest_arrived", true)), "tutorial reset writes cleared guest flag to save")
	_ok(not bool(tutorial_state.get("first_product_seasoned", true)), "tutorial reset writes cleared seasoning flag to save")
	_ok(not bool(tutorial_state.get("first_guest_served", true)), "tutorial reset writes cleared served flag to save")
	_ok(not bool(tutorial_state.get("first_ledger_shown", true)), "tutorial reset writes cleared ledger flag to save")
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
