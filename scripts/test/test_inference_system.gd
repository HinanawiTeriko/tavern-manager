extends Node

const INFERENCE_SYSTEM_SCRIPT := preload("res://scripts/systems/inference_system.gd")

var _checks := 0
var _failures := 0

class InferenceNoticeProbe:
	extends Node
	var notice_count := 0

	func show_inference_ready_notice() -> void:
		notice_count += 1


class TavernFeedbackProbe:
	extends Node
	var customer_lines: Array[String] = []
	var stage_lines: Array[String] = []
	var reward_calls := 0
	var reactions: Array[Dictionary] = []
	var daily_menu: Dictionary = {}
	var daily_menu_confirmed := true

	func customer_say(text: String) -> void:
		customer_lines.append(text)

	func show_stage_caption(text: String, _color: Color = Color.WHITE) -> void:
		stage_lines.append(text)

	func show_order_reward_feedback(_earned_gold: int, _earned_rep: int, _previous_gold: int, _previous_rep: int, _previous_max_gold: int = -1, _new_max_gold: int = -1) -> void:
		reward_calls += 1

	func show_customer_reaction(outcome: String, npc_id: String = "") -> void:
		reactions.append({"outcome": outcome, "npc_id": npc_id})

	func update_top_bar(_gold: int, _rep: int, _day: int, _max_day: int, _max_gold_held: int = -1) -> void:
		pass


func _ready() -> void:
	_test_toby_inference_rules()
	_test_mira_old_ledger_inference_rules()
	_test_grey_ledger_inference_rules()
	_test_toby_dialogue_marks_clues()
	_test_game_manager_collects_night_clues_without_board()
	_test_game_manager_collects_board_and_night_clues()
	_test_game_manager_shows_inference_ready_notice_when_question_unlocks()
	_test_game_manager_grants_mira_gossip_once_per_night()
	await _test_mira_gossip_guest_clue_uses_customer_line_not_stage_caption()
	_test_game_manager_applies_mira_inference_flags()
	_test_mira_stall_collects_old_road_clue()
	_finish()


func _test_toby_inference_rules() -> void:
	var sys = INFERENCE_SYSTEM_SCRIPT.new()
	_ok(sys.load_data(), "inference data loads")
	_ok(sys.get_available_questions().is_empty(), "no question appears before clues")
	sys.add_clue("toby_name")
	sys.add_clue("blacktooth_escort")
	sys.add_clue("high_pay_trap")
	_ok(sys.has_clue("toby_name"), "board clue is owned")
	_ok(sys.get_available_questions().is_empty(), "board clues alone do not identify Toby")
	sys.add_clue("back_alley_boy")
	sys.add_clue("one_person_walk")
	var questions: Array = sys.get_available_questions()
	_ok(questions.size() == 1, "identity question appears after night clue")
	_ok(String(questions[0].get("id", "")) == "toby_identity", "identity question appears first")
	var wrong: Dictionary = sys.try_place("toby_identity", "identity", "blacktooth_escort")
	_ok(not bool(wrong.get("accepted", true)), "wrong clue is rejected")
	_ok(String(wrong.get("hint", "")) != "", "wrong clue returns a hint")
	var identity_name: Dictionary = sys.try_place("toby_identity", "name", "toby_name")
	_ok(bool(identity_name.get("accepted", false)) and not bool(identity_name.get("solved", false)),
		"identity name blank accepts the Toby clue first")
	var identity: Dictionary = sys.try_place("toby_identity", "identity", "back_alley_boy")
	_ok(bool(identity.get("accepted", false)), "right identity clue is accepted")
	_ok(bool(identity.get("solved", false)), "identity question solves after both blanks are filled")
	_ok((identity.get("unlockFlags", []) as Array).has("toby_identity_known"), "identity solve unlocks lodging flag")
	_ok(String(identity.get("conclusion", "")).contains("后巷"), "identity conclusion is readable")
	_ok(sys.has_method("get_relevant_owned_clues"), "inference system exposes a filtered clue-word list")
	if sys.has_method("get_relevant_owned_clues"):
		var relevant_after_identity := _clue_ids(sys.get_relevant_owned_clues())
		_ok(not relevant_after_identity.has("back_alley_boy"),
			"identity-only clue is hidden after the identity question is solved")
		_ok(relevant_after_identity.has("toby_name"),
			"Toby name stays visible because a later Mira question can still use it")
	questions = sys.get_available_questions()
	_ok(questions.size() == 1, "risk question appears after identity")
	_ok(String(questions[0].get("id", "")) == "toby_commission_risk", "risk question appears second")
	var risk_a: Dictionary = sys.try_place("toby_commission_risk", "commission", "blacktooth_escort")
	_ok(bool(risk_a.get("accepted", false)) and not bool(risk_a.get("solved", false)), "first risk blank accepts commission clue")
	var risk_b: Dictionary = sys.try_place("toby_commission_risk", "risk", "high_pay_trap")
	_ok(bool(risk_b.get("accepted", false)) and not bool(risk_b.get("solved", false)), "second risk blank accepts suspicious-pay clue")
	var risk_c: Dictionary = sys.try_place("toby_commission_risk", "mindset", "one_person_walk")
	_ok(bool(risk_c.get("accepted", false)) and bool(risk_c.get("solved", false)), "third risk blank solves question")
	_ok((risk_c.get("unlockFlags", []) as Array).has("toby_commission_lead"), "risk solve unlocks fixer flag")

	var captured: Dictionary = sys.capture_state()
	var restored = INFERENCE_SYSTEM_SCRIPT.new()
	_ok(restored.load_data(), "restored inference data loads")
	restored.restore_state(captured)
	_ok(restored.has_clue("back_alley_boy"), "restore keeps owned clues")
	_ok(restored.get_available_questions().is_empty(), "restore keeps solved questions")


func _test_mira_old_ledger_inference_rules() -> void:
	var sys = INFERENCE_SYSTEM_SCRIPT.new()
	_ok(sys.load_data(), "inference data loads for Mira old-ledger rules")
	sys.add_clues(["toby_name", "back_alley_boy", "one_person_walk"])
	var identity: Dictionary = sys.try_place("toby_identity", "name", "toby_name")
	_ok(bool(identity.get("accepted", false)), "Toby identity accepts the name before Mira inference")
	identity = sys.try_place("toby_identity", "identity", "back_alley_boy")
	_ok(bool(identity.get("solved", false)), "Toby identity solves before Mira old relation appears")
	_ok(not sys.get_question("mira_toby_old_relation").is_empty(), "Mira old-relation question exists in data")
	_ok(not _has_available_question(sys, "mira_toby_old_relation"),
		"Mira old-relation question waits for its gossip clue")
	sys.add_clue("mira_traveling_mentor")
	_ok(_has_available_question(sys, "mira_toby_old_relation"),
		"Mira old-relation question appears after mentor gossip")
	var old_relation_question: Dictionary = sys.get_question("mira_toby_old_relation")
	_ok(String(old_relation_question.get("text", "")).begins_with("______。那个孩子"),
		"Mira old-relation wording compares the old child clue to Toby without an awkward subject")
	var old_relation_a: Dictionary = sys.try_place("mira_toby_old_relation", "past", "mira_traveling_mentor")
	_ok(bool(old_relation_a.get("accepted", false)) and not bool(old_relation_a.get("solved", false)),
		"Mira old-relation first blank accepts mentor clue")
	var old_relation_b: Dictionary = sys.try_place("mira_toby_old_relation", "name", "toby_name")
	_ok(bool(old_relation_b.get("solved", false)), "Mira old-relation solves after both blanks")
	_ok((old_relation_b.get("unlockFlags", []) as Array).has("mira_toby_link_known"),
		"Mira old-relation unlocks link flag")
	_ok(not _has_available_question(sys, "mira_phrase_origin"),
		"Mira phrase-origin question waits for child phrase gossip")
	sys.add_clue("child_learned_saying")
	_ok(_has_available_question(sys, "mira_phrase_origin"),
		"Mira phrase-origin question appears after phrase gossip")
	var phrase_a: Dictionary = sys.try_place("mira_phrase_origin", "saying", "one_person_walk")
	_ok(bool(phrase_a.get("accepted", false)) and not bool(phrase_a.get("solved", false)),
		"Mira phrase-origin first blank accepts lone-road phrase")
	var phrase_b: Dictionary = sys.try_place("mira_phrase_origin", "learned", "child_learned_saying")
	_ok(bool(phrase_b.get("solved", false)), "Mira phrase-origin solves by matching the phrase with the learned-saying clue")
	_ok((phrase_b.get("unlockFlags", []) as Array).has("mira_responsibility_lead"),
		"Mira phrase-origin unlocks responsibility lead")


func _test_grey_ledger_inference_rules() -> void:
	var sys = INFERENCE_SYSTEM_SCRIPT.new()
	_ok(sys.load_data(), "inference data loads for grey ledger rules")
	sys.add_clues(["toby_name", "back_alley_boy", "blacktooth_escort", "high_pay_trap", "one_person_walk"])
	var identity_a: Dictionary = sys.try_place("toby_identity", "name", "toby_name")
	_ok(bool(identity_a.get("accepted", false)), "grey route solves Toby identity name blank")
	var identity_b: Dictionary = sys.try_place("toby_identity", "identity", "back_alley_boy")
	_ok(bool(identity_b.get("solved", false)), "grey route solves Toby identity prerequisite")
	var risk_a: Dictionary = sys.try_place("toby_commission_risk", "commission", "blacktooth_escort")
	_ok(bool(risk_a.get("accepted", false)), "grey route accepts Blacktooth escort prerequisite")
	var risk_b: Dictionary = sys.try_place("toby_commission_risk", "risk", "high_pay_trap")
	_ok(bool(risk_b.get("accepted", false)), "grey route accepts suspicious pay prerequisite")
	var risk_c: Dictionary = sys.try_place("toby_commission_risk", "mindset", "one_person_walk")
	_ok(bool(risk_c.get("solved", false)), "grey route solves Toby risk prerequisite")

	sys.add_clues(["mira_traveling_mentor", "child_learned_saying", "mira_avoids_old_road"])
	var relation_a: Dictionary = sys.try_place("mira_toby_old_relation", "past", "mira_traveling_mentor")
	_ok(bool(relation_a.get("accepted", false)), "grey route accepts Mira relation prerequisite")
	var relation_b: Dictionary = sys.try_place("mira_toby_old_relation", "name", "toby_name")
	_ok(bool(relation_b.get("solved", false)), "grey route solves Mira relation prerequisite")
	var phrase_a: Dictionary = sys.try_place("mira_phrase_origin", "saying", "one_person_walk")
	_ok(bool(phrase_a.get("accepted", false)), "grey route accepts phrase prerequisite")
	var phrase_b: Dictionary = sys.try_place("mira_phrase_origin", "learned", "child_learned_saying")
	_ok(bool(phrase_b.get("solved", false)), "grey route solves phrase prerequisite")

	sys.add_clues([
		"grey_ryan_case_number",
		"grey_blacktooth_batch",
		"grey_payout_closure",
		"grey_old_payout_register",
		"grey_missing_page",
		"grey_renamed_escort",
		"grey_supply_stamp",
		"grey_closure_method",
	])
	_ok(_has_available_question(sys, "grey_same_batch"),
		"grey same-batch question appears after Ryan/Toby clearing clues")
	var batch_question: Dictionary = sys.get_question("grey_same_batch")
	_ok(String(batch_question.get("title", "")).contains("莱恩") and String(batch_question.get("title", "")).contains("托比"),
		"grey same-batch title names the two cases being joined")
	_ok(String(batch_question.get("hint", "")).contains("G-17") and String(batch_question.get("hint", "")).contains("结案顺序"),
		"grey same-batch hint points at batch number and closure order")
	_ok(not String(batch_question.get("text", "")).contains("都被 ______ 盖进"),
		"grey same-batch wording does not make the payout-closure clue read like the thing doing the covering")
	var batch_a: Dictionary = sys.try_place("grey_same_batch", "ryan_case", "grey_ryan_case_number")
	_ok(bool(batch_a.get("accepted", false)), "grey same-batch accepts Ryan case number")
	var batch_b: Dictionary = sys.try_place("grey_same_batch", "toby_case", "grey_blacktooth_batch")
	_ok(bool(batch_b.get("accepted", false)), "grey same-batch accepts Blacktooth batch")
	var batch_c: Dictionary = sys.try_place("grey_same_batch", "closure", "grey_payout_closure")
	_ok(bool(batch_c.get("solved", false)), "grey same-batch solves after all blanks")
	_ok((batch_c.get("unlockFlags", []) as Array).has("grey_same_batch_known"),
		"grey same-batch unlocks route flag")

	_ok(_has_available_question(sys, "grey_payout_method"),
		"grey payout-method question appears after same-batch solve")
	sys.try_place("grey_payout_method", "register", "grey_old_payout_register")
	sys.try_place("grey_payout_method", "missing", "grey_missing_page")
	var payout: Dictionary = sys.try_place("grey_payout_method", "closure", "grey_payout_closure")
	_ok(bool(payout.get("solved", false)), "grey payout-method solves")
	_ok(String(payout.get("conclusion", "")).contains("先决定赔付") and String(payout.get("conclusion", "")).contains("再把事故补成已结"),
		"grey payout-method conclusion explains the order plainly")

	_ok(_has_available_question(sys, "grey_mira_supply_link"),
		"grey Mira supply-link question appears after payout and Mira prerequisites")
	var supply_question: Dictionary = sys.get_question("grey_mira_supply_link")
	_ok(String(supply_question.get("title", "")).contains("米拉") and String(supply_question.get("title", "")).contains("灰账"),
		"grey Mira supply title names the character and account link")
	_ok(String(supply_question.get("hint", "")).contains("米拉") and String(supply_question.get("hint", "")).contains("托比"),
		"grey Mira supply hint tells the player this joins Mira to Toby's case")
	_ok(String(supply_question.get("text", "")).contains("托比那份 ______"),
		"grey Mira supply-link wording fits the renamed escort clue")
	sys.try_place("grey_mira_supply_link", "supply", "grey_supply_stamp")
	sys.try_place("grey_mira_supply_link", "escort", "grey_renamed_escort")
	var supply: Dictionary = sys.try_place("grey_mira_supply_link", "method", "grey_closure_method")
	_ok(bool(supply.get("solved", false)), "grey Mira supply-link solves")

	_ok(_has_available_question(sys, "grey_public_account"),
		"grey public-account question appears after all grey subquestions")
	var public_question: Dictionary = sys.get_question("grey_public_account")
	_ok(String(public_question.get("hint", "")).contains("莱恩") and String(public_question.get("hint", "")).contains("托比") and String(public_question.get("hint", "")).contains("米拉"),
		"grey public-account hint names all three lines")
	_ok(not (public_question.get("requiresClues", []) as Array).has("grey_closure_method"),
		"grey public-account does not require a method clue that is not fillable in this final question")
	var public_a: Dictionary = sys.try_place("grey_public_account", "ryan_case", "grey_supply_stamp")
	_ok(bool(public_a.get("accepted", false)) and not bool(public_a.get("solved", false)),
		"grey public-account accepts Mira stamp in the first public evidence slot")
	var duplicate_public: Dictionary = sys.try_place("grey_public_account", "toby_batch", "grey_supply_stamp")
	_ok(not bool(duplicate_public.get("accepted", true)),
		"grey public-account does not allow the same evidence clue twice")
	var public_b: Dictionary = sys.try_place("grey_public_account", "toby_batch", "grey_ryan_case_number")
	_ok(bool(public_b.get("accepted", false)) and not bool(public_b.get("solved", false)),
		"grey public-account accepts Ryan case number in a later public evidence slot")
	var public_result: Dictionary = sys.try_place("grey_public_account", "mira_stamp", "grey_blacktooth_batch")
	_ok(bool(public_result.get("solved", false)), "grey public-account solves with its three public evidence clues in any order")
	_ok(String(public_result.get("conclusion", "")).contains("三条线") and String(public_result.get("conclusion", "")).contains("公开账本"),
		"grey public-account conclusion states why the route can no longer be sealed")
	_ok((public_result.get("unlockFlags", []) as Array).has("grey_public_account_known"),
		"grey public-account unlocks final route flag")


func _test_toby_dialogue_marks_clues() -> void:
	var text := FileAccess.get_file_as_string("res://dialogue/toby_day6.pre.dialogue")
	_ok(text.contains("[color="), "Toby Day6 dialogue marks clue text with BBCode color")
	_ok(text.contains("黑齿矿脉") and text.contains("[/color]"), "Toby Day6 dialogue highlights the mine clue")
	_ok(text.contains("一个人走"), "Toby Day6 dialogue still carries the lone-road phrase")


func _test_game_manager_collects_night_clues_without_board() -> void:
	var gm = get_node("/root/GameManager")
	gm._apply_save_state(gm._default_new_game_state())
	gm.economy.current_day = 6
	gm.start_day_map(6)
	var changed: bool = gm._collect_toby_day6_night_clues_for_test()
	_ok(changed, "Toby night dialogue grants night clues even before the mercenary board is read")
	_ok(gm.inference.has_clue("back_alley_boy"), "night-first route records the back-alley clue")
	_ok(gm.inference.has_clue("one_person_walk"), "night-first route records the lone-road clue")
	_ok(not gm.inference.has_clue("toby_name"), "night-first route does not invent the board name clue")
	_ok(gm.narrative.get_var("toby_name_seen") != true, "night-first route does not pretend the board was read")
	_ok(gm.inference.get_available_questions().is_empty(),
		"night clues alone do not unlock the identity deduction")
	var board: Dictionary = gm.visit_day_location("mercenary_board")
	_ok(board.get("success", false), "GM board visit still succeeds after night clues were collected")
	_ok(gm.inference.has_clue("toby_name"), "board later grants the name clue")
	_ok(gm.inference.get_available_questions().size() == 1,
		"identity deduction appears once night clues and board clues have both been found")


func _test_game_manager_collects_board_and_night_clues() -> void:
	var gm = get_node("/root/GameManager")
	gm._apply_save_state(gm._default_new_game_state())
	gm.economy.current_day = 6
	gm.start_day_map(6)
	var board: Dictionary = gm.visit_day_location("mercenary_board")
	_ok(board.get("success", false), "GM board visit succeeds")
	_ok(gm.narrative.get_var("toby_name_seen") == true, "board stores only Toby name lead")
	_ok(gm.narrative.get_var("toby_danger_known") != true, "board does not mark Toby danger as known")
	_ok(gm.inference.has_clue("toby_name"), "board grants Toby name clue")
	_ok(gm.inference.has_clue("blacktooth_escort"), "board grants commission clue")
	_ok(gm.inference.has_clue("high_pay_trap"), "board grants suspicious-pay clue")
	_ok(not gm.inference.has_clue("back_alley_boy"), "night-only clue is not granted from the board")
	gm._collect_toby_day6_night_clues_for_test()
	_ok(gm.inference.has_clue("back_alley_boy"), "night event grants the back-alley boy clue")
	_ok(gm.inference.has_clue("one_person_walk"), "night event grants the lone-road clue")
	_ok(not gm.inference.has_clue("mine_danger"), "night event does not grant unused clue scraps")


func _test_game_manager_shows_inference_ready_notice_when_question_unlocks() -> void:
	var gm = get_node("/root/GameManager")
	gm._apply_save_state(gm._default_new_game_state())
	gm.economy.current_day = 6
	gm.start_day_map(6)
	var old_view = gm._tavern_view
	var probe := InferenceNoticeProbe.new()
	add_child(probe)
	gm._tavern_view = probe
	var board: Dictionary = gm.visit_day_location("mercenary_board")
	_ok(board.get("success", false), "GM board visit succeeds before inference-ready notice test")
	_ok(probe.notice_count == 0, "board clues alone do not show an inference-ready notice")
	gm._collect_toby_day6_night_clues_for_test()
	_ok(probe.notice_count == 1, "Toby night clues show the inference-ready notice when identity deduction unlocks")
	gm._collect_toby_day6_night_clues_for_test()
	_ok(probe.notice_count == 1, "already-owned clues do not repeat the inference-ready notice")
	gm._tavern_view = old_view
	probe.queue_free()


func _test_game_manager_grants_mira_gossip_once_per_night() -> void:
	var gm = get_node("/root/GameManager")
	gm._apply_save_state(gm._default_new_game_state())
	gm.economy.current_day = 7
	gm.start_day_map(7)
	gm.inference.add_clue("one_person_walk")
	var first: Dictionary = gm._grant_mira_old_ledger_gossip_for_test()
	_ok(bool(first.get("granted", false)), "Day7 ordinary success can grant first Mira old-ledger gossip")
	_ok(String(first.get("clue_id", "")) == "mira_traveling_mentor", "first Mira gossip grants mentor clue")
	_ok(gm.inference.has_clue("mira_traveling_mentor"), "mentor clue is owned after gossip")
	_ok(String(first.get("line", "")) != "", "Mira gossip returns guest-spoken clue text")
	_ok(String(first.get("line", "")).contains("[color=#d6a84d]") and String(first.get("line", "")).contains("[/color]"),
		"Mira gossip guest-spoken clue text highlights the clue phrase")
	_ok(String(first.get("notice", "")) == "",
		"Mira gossip no longer returns a separate stage-caption clue notice")
	var second: Dictionary = gm._grant_mira_old_ledger_gossip_for_test()
	_ok(not bool(second.get("granted", true)), "same night does not grant a second Mira old-ledger gossip")
	gm.economy.current_day = 8
	gm.start_day_map(8)
	var third: Dictionary = gm._grant_mira_old_ledger_gossip_for_test()
	_ok(bool(third.get("granted", false)), "next night can grant the second Mira old-ledger gossip")
	_ok(String(third.get("clue_id", "")) == "child_learned_saying", "second Mira gossip grants phrase clue")
	_ok(String(third.get("line", "")).contains("[color=#d6a84d]") and String(third.get("line", "")).contains("[/color]"),
		"second Mira gossip guest-spoken clue text highlights the clue phrase")


func _test_mira_gossip_guest_clue_uses_customer_line_not_stage_caption() -> void:
	var gm = get_node("/root/GameManager")
	var old_view = gm._tavern_view
	gm._apply_save_state(gm._default_new_game_state())
	gm.economy.current_day = 7
	gm.start_day_map(7)
	gm.inference.add_clue("one_person_walk")
	var probe := TavernFeedbackProbe.new()
	add_child(probe)
	gm._tavern_view = probe

	var guest := GuestData.new()
	guest.guest_name = "Gossip Guest"
	guest.type = GuestData.GuestType.NORMAL
	guest.order_key = "ale_beer"
	guest.npc_id = "regular_belta"
	guest.has_dialogue = false
	gm.guests.current_guest = guest
	gm.guests.has_guest = true

	gm.request_serve("ale_beer", {"quality": "normal"})
	await get_tree().process_frame

	_ok(probe.customer_lines.size() == 1, "ordinary successful service shows exactly one customer reaction line")
	if probe.customer_lines.size() == 1:
		_ok(probe.customer_lines[0].contains("客人: 以前有个女商人"),
			"Mira gossip clue is spoken as part of the guest reaction line")
		_ok(probe.customer_lines[0].contains("[color=#d6a84d]") and probe.customer_lines[0].contains("[/color]"),
			"Mira gossip clue reaction line carries BBCode highlight tags")
	_ok(probe.stage_lines.is_empty(),
		"Mira gossip clue no longer uses the bottom StageCaption bubble")
	_ok(gm.inference.has_clue("mira_traveling_mentor"), "serving an ordinary guest still grants the Mira gossip clue")

	gm._tavern_view = old_view
	gm.guests.clear_guest()
	probe.queue_free()


func _test_game_manager_applies_mira_inference_flags() -> void:
	var gm = get_node("/root/GameManager")
	gm._apply_save_state(gm._default_new_game_state())
	var changed: bool = gm.apply_inference_result({
		"solved": true,
		"unlockFlags": ["mira_toby_link_known", "mira_responsibility_lead"],
	})
	_ok(changed, "applying Mira inference flags reports changed state")
	_ok(gm.narrative.get_var("mira_toby_link_known") == true, "Mira old relation flag is stored")
	_ok(gm.narrative.get_var("mira_responsibility_lead") == true, "Mira responsibility flag is stored")


func _test_mira_stall_collects_old_road_clue() -> void:
	var gm = get_node("/root/GameManager")
	gm._apply_save_state(gm._default_new_game_state())
	gm.economy.current_day = 8
	gm.start_day_map(8)
	gm.inference.add_clue("mira_traveling_mentor")
	var result: Dictionary = gm.visit_day_location("mira_stall")
	_ok(bool(result.get("success", false)), "Mira stall remains visitable after mentor gossip")
	_ok(gm.inference.has_clue("mira_avoids_old_road"), "Mira stall grants old-road avoidance clue")
	var message := String(result.get("message", ""))
	_ok(message.contains("旧路") or message.contains("孩子"), "Mira stall text reacts to old-road gossip")


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-INFERENCE] FAIL: " + msg)


func _has_available_question(sys, question_id: String) -> bool:
	for question in sys.get_available_questions():
		if String(question.get("id", "")) == question_id:
			return true
	return false


func _clue_ids(clues: Array) -> Array[String]:
	var result: Array[String] = []
	for clue in clues:
		if clue is Dictionary:
			result.append(String((clue as Dictionary).get("id", "")))
	return result


func _finish() -> void:
	if _failures == 0:
		print("[TEST-INFERENCE] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-INFERENCE] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)
