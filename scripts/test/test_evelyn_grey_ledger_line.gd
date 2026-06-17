extends Node

var _checks := 0
var _failures := 0


func _ready() -> void:
	_test_evelyn_npc_schedule()
	_test_grey_day_locations()
	_test_grey_documents_grant_inference_clues()
	_test_grey_route_endings()
	_test_evelyn_public_account_gap_diagnostics()
	_test_day20_clean_table_can_update_evelyn_final_ending()
	_test_evelyn_pending_dialogue_names_public_account_gaps()
	_test_previous_line_endings_shape_evelyn_pressure()
	_test_evelyn_living_pressure_explainers()
	_test_evelyn_day20_pre_dialogue_names_living_pressure()
	_test_evelyn_dialogue_expression_cues()
	_test_evelyn_role_and_dialogue_clarity()
	_test_grey_evidence_text_clarity()
	_finish()


func _gm():
	return get_node("/root/GameManager")


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-EVELYN] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-EVELYN] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-EVELYN] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _test_evelyn_npc_schedule() -> void:
	var text := FileAccess.get_file_as_string("res://data/npcs.json")
	var data: Variant = JSON.parse_string(text)
	_ok(data is Dictionary, "npcs.json parses")
	var evelyn := _find_by_id((data as Dictionary).get("npcs", []), "evelyn")
	_ok(not evelyn.is_empty(), "Evelyn NPC exists")
	if evelyn.is_empty():
		return
	_ok(String(evelyn.get("name", "")) == "伊芙琳", "Evelyn UI name is short")
	_ok(String(evelyn.get("title", "")).contains("灰账"), "Evelyn title names grey ledger role")
	var days := []
	for scene in evelyn.get("scenes", []):
		days.append(int(scene.get("day", 0)))
	days.sort()
	_ok(days == [5, 8, 13, 20], "Evelyn appears on Day5, Day8, Day13, and Day20")
	var endings: Dictionary = evelyn.get("endings", {})
	_ok(endings.has("sealed_account"), "Evelyn has sealed-account ending")
	_ok(endings.has("amended_account"), "Evelyn has amended-account ending")
	_ok(endings.has("public_account"), "Evelyn has public-account ending")


func _test_grey_day_locations() -> void:
	var map := DayMapSystem.new()
	_ok(map.load_data(), "locations data loads")
	map.start_day(13)
	_ok(not _location_ids(map.get_locations()).has("clearing_table"),
		"Day13 keeps the clearing table hidden until Evelyn opens the daytime investigation")
	map.start_day(14)
	var day14_ids := _location_ids(map.get_locations())
	_ok(day14_ids.has("clearing_table"), "Day14 exposes clearing table physical scene")
	var clearing := _find_location(map.get_locations(), "clearing_table")
	_ok((clearing.get("documents", []) as Array).is_empty(),
		"clearing table carries no auto-grant documents")
	var payout := _find_location(map.get_locations(), "payout_office")
	_ok(not payout.is_empty(), "Day14 exposes payout office")
	_ok((payout.get("documents", []) as Array).has("grey_ryan_case_number"),
		"payout office carries Ryan case number")
	_ok((payout.get("documents", []) as Array).has("grey_old_payout_register"),
		"payout office carries old payout register")
	_ok((payout.get("documents", []) as Array).has("grey_missing_page"),
		"payout office carries missing-page clue")
	_ok(not (payout.get("documents", []) as Array).has("grey_payout_closure"),
		"payout-closure clue is reserved for the clearing table scene")
	map.start_day(16)
	var day16_ids := _location_ids(map.get_locations())
	_ok(day16_ids.has("blacktooth_ledger"), "Day16 exposes Blacktooth transfer ledger")
	var blacktooth := _find_location(map.get_locations(), "blacktooth_ledger")
	_ok((blacktooth.get("documents", []) as Array).has("grey_blacktooth_batch"),
		"Blacktooth ledger carries batch clue")
	_ok((blacktooth.get("documents", []) as Array).has("grey_closure_method"),
		"Blacktooth ledger carries closure-method clue")
	_ok(not (blacktooth.get("documents", []) as Array).has("grey_renamed_escort"),
		"renamed-escort clue is reserved for the clearing table scene")
	map.start_day(17)
	var day17_ids := _location_ids(map.get_locations())
	_ok(day17_ids.has("mira_supply_copy"), "Day17 exposes Mira supply copy")
	var supply := _find_location(map.get_locations(), "mira_supply_copy")
	_ok((supply.get("documents", []) as Array).is_empty(),
		"Mira supply copy is text context; supply-stamp clue is reserved for clearing table")


func _test_grey_documents_grant_inference_clues() -> void:
	var gm = _gm()
	gm._apply_save_state(gm._default_new_game_state())
	_ok(gm.grant_investigation_document("grey_payout_closure"), "payout office grants payout-closure note")
	_ok(gm.inference.has_clue("grey_payout_closure"), "payout-closure document adds inference clue")
	_ok(gm.grant_investigation_document("grey_renamed_escort"), "Blacktooth ledger grants renamed-escort note")
	_ok(gm.inference.has_clue("grey_renamed_escort"), "renamed-escort document adds inference clue")
	_ok(gm.grant_investigation_document("grey_supply_stamp"), "Mira supply copy grants supply-stamp note")
	_ok(gm.inference.has_clue("grey_supply_stamp"), "supply-stamp document adds inference clue")
	_ok(not gm.grant_investigation_document("grey_supply_stamp"),
		"grey investigation grant is idempotent")


func _test_grey_route_endings() -> void:
	var gm = _gm()
	gm._apply_save_state(gm._default_new_game_state())
	gm.narrative.finalize_evelyn_ending()
	_ok(String(gm.narrative.get_var("evelyn_ending")) == "sealed_account",
		"default Evelyn ending seals the account")
	_ok(str(gm.narrative.get_var("evelyn_pressure")) == "sealed_account",
		"default Evelyn pressure records a sealed account")
	gm.narrative.set_var("grey_same_batch_known", true)
	gm.narrative.finalize_evelyn_ending()
	_ok(String(gm.narrative.get_var("evelyn_ending")) == "amended_account",
		"partial grey truth amends the account")
	gm.narrative.set_var("grey_public_account_known", true)
	gm.narrative.finalize_evelyn_ending()
	_ok(String(gm.narrative.get_var("evelyn_ending")) == "public_account",
		"final public-account inference opens the account")


func _test_evelyn_public_account_gap_diagnostics() -> void:
	var gm = _gm()
	gm._apply_save_state(gm._default_new_game_state())
	gm.economy.current_day = 20
	_ok(gm.has_method("get_evelyn_public_account_gap_summary"),
		"GameManager exposes public-account gap diagnostics for the Day20 route gate")
	if not gm.has_method("get_evelyn_public_account_gap_summary"):
		return

	var summary := String(gm.get_evelyn_public_account_gap_summary())
	_ok(summary.contains("公开账本缺"), "gap summary is framed as a public-account checklist")
	_ok(summary.contains("托比身份"), "gap summary starts from the missing Toby identity inference")

	gm.narrative.set_var("toby_identity_known", true)
	gm.narrative.set_var("toby_commission_lead", true)
	gm.narrative.set_var("mira_toby_link_known", true)
	gm.narrative.set_var("mira_responsibility_lead", true)
	gm.narrative.set_var("grey_same_batch_known", true)
	gm.narrative.set_var("grey_payout_method_known", true)
	summary = String(gm.get_evelyn_public_account_gap_summary())
	_ok(summary.contains("米拉供应灰印"),
		"gap summary names the missing Mira supply stamp link instead of silently hiding the public-account route")

	gm.narrative.set_var("mira_grey_ledger_link_known", true)
	summary = String(gm.get_evelyn_public_account_gap_summary())
	_ok(summary.contains("公开抄本"),
		"gap summary distinguishes an available-but-unsolved final public-account inference")

	gm.narrative.set_var("grey_public_account_known", true)
	_ok(String(gm.get_evelyn_public_account_gap_summary()) == "",
		"gap summary clears once the public-account inference is solved")


func _test_day20_clean_table_can_update_evelyn_final_ending() -> void:
	var gm = _gm()
	gm._apply_save_state(gm._default_new_game_state())
	gm.economy.current_day = 20
	_prepare_public_account_question(gm)
	_ok(gm.inference.has_available_questions(), "Day20 still has a final grey-ledger inference available")
	gm._finalize_evelyn_ending_for_current_day()
	_ok(str(gm.narrative.get_var("evelyn_ending")) == "",
		"Day20 serve does not lock Evelyn's route while clean-table inference is still available")
	_ok(str(gm.narrative.get_var("evelyn_resolution_state")) == "pending",
		"Day20 serve marks Evelyn's resolution as pending until the inference screen closes")
	gm.current_ledger_data = gm._create_ledger_data_for_current_day()
	_ok(_fate_ending_key(gm.current_ledger_data.npc_fates, "evelyn") == "",
		"pre-inference Day20 ledger data does not present a provisional Evelyn route")
	_ok(not _ledger_pages_text(gm).contains("承认账面有误"),
		"pre-inference Day20 ledger document does not write a provisional Evelyn result")

	_solve_public_account_question(gm)
	gm.finish_clean_table_inference()
	_ok(str(gm.narrative.get_var("evelyn_ending")) == "public_account",
		"Day20 clean-table inference sets Evelyn's final route once")
	_ok(str(gm.narrative.get_var("evelyn_resolution_state")) == "final",
		"Day20 clean-table return marks Evelyn's resolution as final")
	_ok(gm.current_ledger_data != null, "Day20 clean-table return keeps ledger data available")
	if gm.current_ledger_data != null:
		_ok(_fate_ending_key(gm.current_ledger_data.npc_fates, "evelyn") == "public_account",
			"Day20 ledger data is rebuilt with the post-inference Evelyn route")
	_ok(_ledger_pages_text(gm).contains("灰账公开"),
		"Day20 ledger document records the final Evelyn result after inference")


func _test_evelyn_pending_dialogue_names_public_account_gaps() -> void:
	var text := FileAccess.get_file_as_string("res://dialogue/evelyn_day20.post.dialogue")
	_ok(text.contains("evelyn_public_gap_primary"),
		"Day20 pending dialogue branches on the first missing public-account gap")
	_ok(text.contains("托比的名字还没和后巷少年对上"),
		"Day20 pending dialogue can name the missing Toby identity proof")
	_ok(text.contains("米拉供应协议背面的灰印还没接到账上"),
		"Day20 pending dialogue can name the missing Mira grey-ledger link")


func _prepare_public_account_question(gm) -> void:
	gm.inference.add_clues([
		"toby_name",
		"blacktooth_escort",
		"high_pay_trap",
		"back_alley_boy",
		"one_person_walk",
		"mira_traveling_mentor",
		"child_learned_saying",
		"mira_avoids_old_road",
		"grey_ryan_case_number",
		"grey_old_payout_register",
		"grey_missing_page",
		"grey_blacktooth_batch",
		"grey_closure_method",
		"grey_payout_closure",
		"grey_renamed_escort",
		"grey_supply_stamp",
	])
	_place_and_apply(gm, "toby_identity", "name", "toby_name")
	_place_and_apply(gm, "toby_identity", "identity", "back_alley_boy")
	_place_and_apply(gm, "toby_commission_risk", "commission", "blacktooth_escort")
	_place_and_apply(gm, "toby_commission_risk", "risk", "high_pay_trap")
	_place_and_apply(gm, "toby_commission_risk", "mindset", "one_person_walk")
	_place_and_apply(gm, "mira_toby_old_relation", "past", "mira_traveling_mentor")
	_place_and_apply(gm, "mira_toby_old_relation", "name", "toby_name")
	_place_and_apply(gm, "mira_phrase_origin", "saying", "one_person_walk")
	_place_and_apply(gm, "mira_phrase_origin", "learned", "child_learned_saying")
	_place_and_apply(gm, "grey_same_batch", "ryan_case", "grey_ryan_case_number")
	_place_and_apply(gm, "grey_same_batch", "toby_case", "grey_blacktooth_batch")
	_place_and_apply(gm, "grey_same_batch", "closure", "grey_payout_closure")
	_place_and_apply(gm, "grey_payout_method", "register", "grey_old_payout_register")
	_place_and_apply(gm, "grey_payout_method", "missing", "grey_missing_page")
	_place_and_apply(gm, "grey_payout_method", "closure", "grey_payout_closure")
	_place_and_apply(gm, "grey_mira_supply_link", "supply", "grey_supply_stamp")
	_place_and_apply(gm, "grey_mira_supply_link", "escort", "grey_renamed_escort")
	_place_and_apply(gm, "grey_mira_supply_link", "method", "grey_closure_method")


func _solve_public_account_question(gm) -> void:
	_place_and_apply(gm, "grey_public_account", "ryan_case", "grey_ryan_case_number")
	_place_and_apply(gm, "grey_public_account", "toby_batch", "grey_blacktooth_batch")
	_place_and_apply(gm, "grey_public_account", "mira_stamp", "grey_supply_stamp")


func _place_and_apply(gm, question_id: String, blank_id: String, clue_id: String) -> Dictionary:
	var result: Dictionary = gm.inference.try_place(question_id, blank_id, clue_id)
	gm.apply_inference_result(result)
	return result


func _ledger_pages_text(gm) -> String:
	var pages: Array = gm.documents.get_document("ledger").get("pages", [])
	return "\n---\n".join(PackedStringArray(pages))


func _test_previous_line_endings_shape_evelyn_pressure() -> void:
	var gm = _gm()
	gm._apply_save_state(gm._default_new_game_state())
	gm.narrative.set_var("grey_public_account_known", true)
	gm.narrative.set_var("ryan_ending", "alternative_survivor")
	gm.narrative.set_var("mira_ending", "she_finally_stopped")
	gm.narrative.set_var("toby_survived", true)
	gm.narrative.finalize_evelyn_ending()
	_ok(str(gm.narrative.get_var("evelyn_ending")) == "public_account",
		"public-account route still controls the top-level Evelyn ending")
	_ok(str(gm.narrative.get_var("evelyn_pressure")) == "living_witnesses",
		"Ryan/Mira/Toby surviving or testifying turns public account into a living-witness pressure")
	_ok(gm._evelyn_track_result("public_account").contains("活人"),
		"public-account fate track mentions living witnesses when prior line endings leave witnesses")

	gm._apply_save_state(gm._default_new_game_state())
	gm.narrative.set_var("grey_public_account_known", true)
	gm.narrative.set_var("ryan_ending", "uninformed_fallen")
	gm.narrative.set_var("mira_ending", "never_turned_back")
	gm.narrative.set_var("toby_survived", false)
	gm.narrative.finalize_evelyn_ending()
	_ok(str(gm.narrative.get_var("evelyn_pressure")) == "paper_public",
		"dead or unwilling prior lines leave the public account as paper-only pressure")
	_ok(gm._evelyn_track_result("public_account").contains("纸证"),
		"paper public-account fate track names paper evidence instead of living witnesses")

	gm._apply_save_state(gm._default_new_game_state())
	gm.narrative.set_var("grey_same_batch_known", true)
	gm.narrative.set_var("ryan_ending", "drugged_survivor")
	gm.narrative.set_var("mira_ending", "closed_the_door")
	gm.narrative.set_var("toby_survived", true)
	gm.narrative.finalize_evelyn_ending()
	_ok(str(gm.narrative.get_var("evelyn_ending")) == "amended_account",
		"partial grey truth still produces the amended-account route")
	_ok(str(gm.narrative.get_var("evelyn_pressure")) == "damaged_amendment",
		"surviving prior lines make partial grey truth a damaged but useful amendment")
	_ok(gm._evelyn_track_result("amended_account").contains("喘息"),
		"damaged amendment fate track mentions survivors getting room to breathe")

	gm._apply_save_state(gm._default_new_game_state())
	gm.narrative.set_var("grey_same_batch_known", true)
	gm.narrative.set_var("ryan_ending", "informed_fallen")
	gm.narrative.set_var("mira_ending", "another_light_out")
	gm.narrative.set_var("toby_survived", false)
	gm.narrative.finalize_evelyn_ending()
	_ok(str(gm.narrative.get_var("evelyn_pressure")) == "cold_amendment",
		"lost prior lines leave partial grey truth as cold amendment")
	_ok(gm._evelyn_track_result("amended_account").contains("冷账"),
		"cold amendment fate track names the colder outcome")


func _test_evelyn_living_pressure_explainers() -> void:
	var gm = _gm()
	gm._apply_save_state(gm._default_new_game_state())
	_ok(gm.narrative.has_method("get_evelyn_living_pressure_labels"),
		"NarrativeManager exposes which living witnesses shape Evelyn pressure")
	if not gm.narrative.has_method("get_evelyn_living_pressure_labels"):
		return

	gm.narrative.set_var("ryan_ending", "alternative_survivor")
	gm.narrative.set_var("mira_ending", "she_finally_stopped")
	gm.narrative.set_var("toby_survived", true)
	var witnesses: Array = gm.narrative.get_evelyn_living_pressure_labels()
	_ok(witnesses.has("莱恩") and witnesses.has("米拉") and witnesses.has("托比"),
		"living pressure labels name Ryan, Mira, and Toby when their prior routes leave witnesses")

	gm.narrative.set_var("grey_public_account_known", true)
	gm.narrative.finalize_evelyn_ending()
	var living_result := String(gm._evelyn_track_result("public_account"))
	_ok(living_result.contains("活人证词：莱恩 / 米拉 / 托比"),
		"public-account fate track lists living witness pressure")
	_ok(living_result.contains("纸证：莱恩案卷编号 / 黑齿批次号 / 供应协议灰印"),
		"public-account fate track lists the paper evidence spine")

	gm._apply_save_state(gm._default_new_game_state())
	gm.narrative.set_var("ryan_ending", "uninformed_fallen")
	gm.narrative.set_var("mira_ending", "never_turned_back")
	gm.narrative.set_var("toby_survived", false)
	gm.narrative.set_var("grey_public_account_known", true)
	gm.narrative.finalize_evelyn_ending()
	var paper_result := String(gm._evelyn_track_result("public_account"))
	_ok(paper_result.contains("活人证词：无"),
		"paper-public fate track makes the missing living pressure explicit")
	_ok(paper_result.contains("纸证：莱恩案卷编号 / 黑齿批次号 / 供应协议灰印"),
		"paper-public fate track still lists the evidence spine")


func _test_evelyn_day20_pre_dialogue_names_living_pressure() -> void:
	var text := FileAccess.get_file_as_string("res://dialogue/evelyn_day20.pre.dialogue")
	_ok(text.contains("亲口作证") and text.contains("账本的重量"),
		"Day20 pre dialogue tells players that living witnesses change Evelyn's final pressure")


func _test_evelyn_dialogue_expression_cues() -> void:
	var gm = _gm()
	_ok(gm.has_method("set_customer_expression"),
		"GameManager exposes a dialogue mutation hook for important-customer expression swaps")
	var expected_by_file := {
		"res://dialogue/evelyn_day5.pre.dialogue": ["welcoming"],
		"res://dialogue/evelyn_day5.post.dialogue": ["smile", "assessing"],
		"res://dialogue/evelyn_day8.pre.dialogue": ["knowing"],
		"res://dialogue/evelyn_day8.post.dialogue": ["knowing", "assessing"],
		"res://dialogue/evelyn_day13.pre.dialogue": ["assessing"],
		"res://dialogue/evelyn_day13.post.dialogue": ["knowing", "cold"],
		"res://dialogue/evelyn_day20.pre.dialogue": ["cold"],
		"res://dialogue/evelyn_day20.post.dialogue": ["cracked", "unsettled", "cold"],
	}
	var valid_expressions := [
		"neutral",
		"smile",
		"assessing",
		"cracked",
		"welcoming",
		"knowing",
		"cold",
		"unsettled",
	]
	for path in expected_by_file.keys():
		var text := FileAccess.get_file_as_string(path)
		_ok(text != "", path + " is readable")
		for expression in expected_by_file[path]:
			_ok(text.contains('GameManager.set_customer_expression("' + expression + '")'),
				path + " cues " + expression + " portrait")
		var regex := RegEx.new()
		_ok(regex.compile('GameManager\\.set_customer_expression\\("([^"]+)"\\)') == OK,
			"expression-cue parser compiles")
		for match in regex.search_all(text):
			var expression := match.get_string(1)
			_ok(valid_expressions.has(expression),
				path + " uses shipped Evelyn expression: " + expression)
	var day20_post := FileAccess.get_file_as_string("res://dialogue/evelyn_day20.post.dialogue")
	for pressure in ["living_witnesses", "paper_public", "damaged_amendment", "cold_amendment"]:
		_ok(day20_post.contains('evelyn_pressure == "' + pressure + '"'),
			"Day20 Evelyn post dialogue branches on " + pressure)


func _test_evelyn_role_and_dialogue_clarity() -> void:
	var npc_text := FileAccess.get_file_as_string("res://data/npcs.json")
	_ok(npc_text.contains("封存事故、赔付和失踪记录"),
		"Evelyn NPC description names what her grey-ledger work does")
	_ok(npc_text.contains("不是所有清账都等于真相"),
		"Evelyn NPC description exposes her moral contradiction")

	var day5_pre := FileAccess.get_file_as_string("res://dialogue/evelyn_day5.pre.dialogue")
	_ok(day5_pre.contains("公会清算人"), "Day5 introduces Evelyn's guild clearer role")
	_ok(day5_pre.contains("先到的赔付") and day5_pre.contains("活人撑过今晚"),
		"Day5 explains why Evelyn sees fast settlement as mercy")

	var day8_pre := FileAccess.get_file_as_string("res://dialogue/evelyn_day8.pre.dialogue")
	_ok(day8_pre.contains("批次号") and day8_pre.contains("旧账"),
		"Day8 links Blacktooth to old ledger batches")

	var day13_pre := FileAccess.get_file_as_string("res://dialogue/evelyn_day13.pre.dialogue")
	_ok(day13_pre.contains("莱恩、托比和米拉"),
		"Day13 explicitly names the three lines in Evelyn's audit")
	_ok(day13_pre.contains("赔付登记处") and day13_pre.contains("先赔付、后结案"),
		"Day13 gives the first audit target and the ordering question")
	_ok(day13_pre.contains("我只能给你入口"),
		"Day13 explains why Evelyn points without confessing")
	_ok(day13_pre.contains("公会柜台里") and day13_pre.contains("封存") and day13_pre.contains("改账"),
		"Day13 explains Evelyn's institutional limit inside the guild")
	_ok(day13_pre.contains("离开公会") and day13_pre.contains("外面的账"),
		"Day13 explains why the player must create outside evidence")

	var day20_pre := FileAccess.get_file_as_string("res://dialogue/evelyn_day20.pre.dialogue")
	_ok(day20_pre.contains("证据不够") and day20_pre.contains("封存"),
		"Day20 pre-dialogue names the sealed-account condition")
	_ok(day20_pre.contains("只够证明几处错账") and day20_pre.contains("改账"),
		"Day20 pre-dialogue names the amended-account condition")
	_ok(day20_pre.contains("三条线能公开对上") and day20_pre.contains("公开账本"),
		"Day20 pre-dialogue names the public-account condition")

	var day20_post := FileAccess.get_file_as_string("res://dialogue/evelyn_day20.post.dialogue")
	_ok(day20_post.contains("莱恩、托比和米拉") and day20_post.contains("同一页"),
		"Day20 public route explains the three-line proof")
	_ok(day20_post.contains("只能改几笔") or day20_post.contains("几处账面错误"),
		"Day20 amended route explains the partial proof")
	_ok(day20_post.contains("证据不够") and day20_post.contains("照旧封存"),
		"Day20 sealed route explains the failed proof")


func _test_grey_evidence_text_clarity() -> void:
	var documents_text := FileAccess.get_file_as_string("res://data/documents.json")
	for phrase in [
		"这证明莱恩不是单独归档",
		"这证明灰账会先决定赔付",
		"这证明缺页不是丢失",
		"这证明托比被放进同一批",
		"这证明灰契能把人名、事故赔付和保证金合成已结账",
		"这证明莱恩案卷按赔付即结案处理",
		"这证明托比的护送被改名",
		"这证明米拉的协议也接进灰账",
	]:
		_ok(documents_text.contains(phrase), "grey document explains proof: " + phrase)

	var locations_text := FileAccess.get_file_as_string("res://data/locations.json")
	_ok(locations_text.contains("第一站查顺序"),
		"payout office location text frames it as the first audit step")
	_ok(locations_text.contains("亲手压出灰契痕迹"),
		"clearing table location text frames the physical scene as proof production")
	_ok(locations_text.contains("托比的名字怎样被改进临时人名栏"),
		"Blacktooth ledger location text names the renamed-escort question")
	_ok(locations_text.contains("米拉的旧供应协议是否也接进同一套灰契"),
		"Mira supply copy location text names the final link question")
	_ok(not locations_text.contains("也看见托比的护送委托被改成了转运清算"),
		"Blacktooth result text does not claim the clearing-table proof is already produced")
	_ok(not locations_text.contains("看见了同一枚灰契印"),
		"Mira supply result text does not claim the clearing-table stamp proof is already produced")


func _find_by_id(entries: Array, id: String) -> Dictionary:
	for entry in entries:
		if entry is Dictionary and String(entry.get("id", "")) == id:
			return entry
	return {}


func _location_ids(locations: Array) -> Array:
	var ids := []
	for loc in locations:
		ids.append(String(loc.get("id", "")))
	return ids


func _find_location(locations: Array, location_id: String) -> Dictionary:
	for loc in locations:
		if String(loc.get("id", "")) == location_id:
			return loc
	return {}


func _fate_ending_key(fates: Array, npc_id: String) -> String:
	for fate in fates:
		if fate is Dictionary and String(fate.get("npc_id", "")) == npc_id:
			return String(fate.get("ending_key", ""))
	return ""
