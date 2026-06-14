extends Node

var _checks := 0
var _failures := 0


func _ready() -> void:
	_test_truth_and_trust_route()
	_test_truth_without_trust_route()
	_test_contract_found_without_telling_route()
	_test_mira_stall_accepts_contract()
	_test_mira_stall_followup_after_contract()
	_test_fixer_route()
	_test_fixer_with_unshown_contract_route()
	_test_missed_route()
	_finish()


func _gm():
	return get_node("/root/GameManager")


func _reset_gm(day: int = 6, gold: int = 0):
	var gm = _gm()
	gm._apply_save_state(gm._default_new_game_state())
	gm.economy.current_day = day
	gm.economy.gold = gold
	gm.economy.gold_today = 0
	gm.start_day_map(day)
	return gm


func _learn_toby_danger(gm) -> void:
	var before_entries: int = gm.documents.capture_state().get("ledger_entries", []).size()
	var board: Dictionary = gm.visit_day_location("mercenary_board")
	_ok(board.get("success", false), "board visit succeeds")
	_ok(gm.narrative.get_var("toby_danger_known") == true, "board persists Toby danger")
	var after_entries: int = gm.documents.capture_state().get("ledger_entries", []).size()
	_ok(after_entries > before_entries, "board writes a ledger beat")


func _find_contract(gm) -> void:
	var before_entries: int = gm.documents.capture_state().get("ledger_entries", []).size()
	var newly: bool = gm.grant_investigation_document("toby_contract")
	_ok(newly, "Toby contract is newly granted")
	_ok(gm.documents.owns_document("toby_contract"), "Toby contract document is owned")
	_ok(gm.narrative.get_var("toby_contract_found") == true, "contract proof flag is set")
	var after_entries: int = gm.documents.capture_state().get("ledger_entries", []).size()
	_ok(after_entries > before_entries, "contract grant writes a ledger beat")


func _tell_mira_truth(gm) -> void:
	var result: Dictionary = gm.narrative.resolve_action({
		"type": "give_story_item",
		"npc_id": "mira",
		"item_key": "toby_contract",
	})
	_ok(result.get("accepted", false), "Mira accepts Toby contract")
	_ok(gm.narrative.get_var("told_mira_truth") == true, "telling Mira truth flag is set")


func _visit_mira_on_day(gm, day: int) -> Dictionary:
	gm.economy.current_day = day
	gm.start_day_map(day)
	var visit: Dictionary = gm.visit_day_location("mira_stall")
	_ok(visit.get("success", false), "Mira stall visit succeeds on Day %d" % day)
	return visit


func _finalize_and_expect(gm, expected_mira: String, expected_toby: String, msg: String) -> void:
	gm.narrative.finalize_mira_ending()
	_ok(String(gm.narrative.get_var("mira_ending")) == expected_mira, msg + ": Mira ending")
	_ok(String(gm.narrative.endings.get("toby", "")) == expected_toby, msg + ": Toby ending")
	_ok(bool(gm.narrative.get_var("toby_survived")) == (expected_toby == "saved"), msg + ": Toby survived flag")


func _test_truth_and_trust_route() -> void:
	var gm = _reset_gm(6, 0)
	_learn_toby_danger(gm)
	_find_contract(gm)
	_visit_mira_on_day(gm, 7)
	_visit_mira_on_day(gm, 8)
	_ok(gm.narrative.get_affection("mira") >= gm.narrative.MIRA_TRUST_THRESHOLD,
		"two Mira visits reach the trust threshold")
	_tell_mira_truth(gm)
	_finalize_and_expect(gm, "she_finally_stopped", "saved", "truth plus trust route")


func _test_truth_without_trust_route() -> void:
	var gm = _reset_gm(6, 0)
	_learn_toby_danger(gm)
	_find_contract(gm)
	_tell_mira_truth(gm)
	_ok(gm.narrative.get_affection("mira") < gm.narrative.MIRA_TRUST_THRESHOLD,
		"truth-only route stays below the trust threshold")
	_finalize_and_expect(gm, "never_turned_back", "lost", "truth without trust route")


func _test_contract_found_without_telling_route() -> void:
	var gm = _reset_gm(6, 0)
	_learn_toby_danger(gm)
	_find_contract(gm)
	_ok(gm.narrative.get_var("told_mira_truth") == false,
		"finding the contract alone does not tell Mira")
	_finalize_and_expect(gm, "another_light_out", "lost", "contract found but not shown route")


func _test_mira_stall_accepts_contract() -> void:
	var gm = _reset_gm(6, 0)
	_learn_toby_danger(gm)
	_find_contract(gm)
	var visit := _visit_mira_on_day(gm, 7)
	_ok(gm.narrative.get_var("told_mira_truth") == true,
		"Mira stall visit lets the player show Toby contract")
	var message := String(visit.get("message", ""))
	_ok(message.contains("米拉:") and message.contains("托比") and message.contains("一个人走"),
		"Mira stall handoff returns visible dialogue-like event text")
	var entries: Array = gm.documents.capture_state().get("ledger_entries", [])
	var saw_handoff := false
	for entry in entries:
		var text := String(entry)
		if text.contains("米拉") and text.contains("一个人走"):
			saw_handoff = true
			break
	_ok(saw_handoff, "Mira stall handoff writes a ledger beat with the shared phrase")


func _test_mira_stall_followup_after_contract() -> void:
	var gm = _reset_gm(6, 0)
	_learn_toby_danger(gm)
	_find_contract(gm)
	_visit_mira_on_day(gm, 7)
	var followup := _visit_mira_on_day(gm, 8)
	var message := String(followup.get("message", ""))
	_ok(message.contains("米拉:") and message.contains("托比") and message.contains("住"),
		"Mira stall follow-up after contract shows her asking where Toby is")
	_ok(message.contains("货摊") or message.contains("收拾"),
		"Mira stall follow-up after contract visibly changes her routine")


func _test_fixer_route() -> void:
	var gm = _reset_gm(6, 50)
	_learn_toby_danger(gm)
	var before_gold: int = gm.economy.gold
	var fixer: Dictionary = gm.visit_day_location("fixer_den")
	_ok(fixer.get("success", false), "fixer visit succeeds after Toby lead")
	_ok(gm.economy.gold == before_gold - 40, "fixer spends 40 gold")
	_ok(gm.narrative.get_var("toby_secured_by_fixer") == true, "fixer route sets new secured flag")
	_ok(gm.narrative.get_var("toby_secured") == true, "fixer route preserves legacy secured flag")
	_finalize_and_expect(gm, "closed_the_door", "saved", "fixer route")


func _test_fixer_with_unshown_contract_route() -> void:
	var gm = _reset_gm(6, 50)
	_learn_toby_danger(gm)
	_find_contract(gm)
	var fixer: Dictionary = gm.visit_day_location("fixer_den")
	_ok(fixer.get("success", false), "fixer visit succeeds after finding unshown contract")
	_ok(gm.narrative.get_var("told_mira_truth") == false,
		"fixer with contract does not secretly tell Mira")
	_finalize_and_expect(gm, "closed_the_door", "saved", "fixer plus unshown contract route")


func _test_missed_route() -> void:
	var gm = _reset_gm(12, 0)
	_ok(gm.narrative.get_var("toby_danger_known") == false, "missed route never learns Toby danger")
	_ok(gm.narrative.get_var("toby_contract_found") == false, "missed route never finds contract")
	_finalize_and_expect(gm, "another_light_out", "lost", "missed route")


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-MIRA-TOBY-ROUTE] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-MIRA-TOBY-ROUTE] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-MIRA-TOBY-ROUTE] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)
