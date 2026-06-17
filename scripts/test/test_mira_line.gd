extends Node

## Mira 线逻辑单测：裸 NarrativeManager 实例，覆盖托比解析、变量初始化、
## toby_contract 告知、结局网格 4 格、托比存活=担责 OR 兜底。headless 安全。

var _checks := 0
var _failures := 0

func _ready() -> void:
	_test_parse_and_init()
	_test_toby_contract_informs_mira()
	_test_toby_contract_feedback_reflects_mira_trust()
	_test_day12_contract_feedback_waits_for_final_service()
	_test_dialogue_text_keeps_mira_route_coherent()
	_test_dialogue_highlights_mira_route_clues()
	_test_toby_motive_text_frames_proving_not_rescue()
	_test_toby_contract_and_inference_frame_the_phrase_as_wound()
	_test_mira_handoff_feedback_frames_the_phrase_as_her_excuse()
	_test_mira_stall_followup_names_toby_contract_without_delivery_action()
	_test_mira_endings_preserve_the_phrase_debt()
	_test_route_she_finally_stopped()
	_test_route_never_turned_back()
	_test_route_closed_the_door()
	_test_route_another_light_out()
	_test_toby_survival_flags()
	_finish()

func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-MIRA] FAIL: " + msg)

func _finish() -> void:
	if _failures == 0:
		print("[TEST-MIRA] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-MIRA] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)

func _nm() -> NarrativeManager:
	var nm := NarrativeManager.new()
	nm.load_npc_data()
	return nm

func _test_parse_and_init() -> void:
	var nm := _nm()
	var toby: NpcData = null
	for n in nm.all_npcs:
		if n.id == "toby":
			toby = n
	_ok(nm.get_var("toby_danger_known") == false, "toby_danger_known starts false")
	_ok(nm.get_var("toby_contract_found") == false, "toby_contract_found starts false")
	_ok(nm.get_var("toby_secured_by_fixer") == false, "toby_secured_by_fixer starts false")
	_ok(toby != null, "应解析到 toby")
	_ok(nm.get_affection("mira") == 5, "aff_mira 初始 5")
	_ok(nm.get_var("told_mira_truth") == false, "told_mira_truth 初始 false")
	_ok(nm.get_var("toby_secured") == false, "toby_secured 初始 false")

func _test_toby_contract_informs_mira() -> void:
	var nm := _nm()
	# 递给 mira：告知真相
	var r := nm.resolve_action({"type": "give_story_item", "npc_id": "mira", "item_key": "toby_contract"})
	_ok(nm.get_var("toby_contract_found") == true, "giving contract confirms Toby contract found")
	_ok(r.get("accepted", false), "Mira 收下托比委托书")
	_ok(nm.get_var("told_mira_truth") == true, "递交置 told_mira_truth")
	# 递给非 mira：不认
	var nm2 := _nm()
	var bad := nm2.resolve_action({"type": "give_story_item", "npc_id": "toby", "item_key": "toby_contract"})
	_ok(not bad.get("accepted", true), "托比本人不接收真相文档")


func _test_toby_contract_feedback_reflects_mira_trust() -> void:
	var guarded := _nm()
	var guarded_result := guarded.resolve_action({"type": "give_story_item", "npc_id": "mira", "item_key": "toby_contract"})
	_ok(String(guarded_result.get("feedback", "")) == "mira_informed_guarded",
		"low-trust Mira contract handoff uses guarded dialogue feedback")

	var trusted := _nm()
	trusted.set_affection("mira", trusted.MIRA_TRUST_THRESHOLD)
	var trusted_result := trusted.resolve_action({"type": "give_story_item", "npc_id": "mira", "item_key": "toby_contract"})
	_ok(String(trusted_result.get("feedback", "")) == "mira_informed_trusted",
		"trusted Mira contract handoff uses responsible dialogue feedback")


func _test_day12_contract_feedback_waits_for_final_service() -> void:
	var nm := _nm()
	nm.set_affection("mira", nm.MIRA_TRUST_THRESHOLD - 2)
	var result := nm.resolve_action({
		"type": "give_story_item",
		"npc_id": "mira",
		"item_key": "toby_contract",
		"day": 12,
	})
	_ok(String(result.get("feedback", "")) == "mira_informed_unsettled",
		"Day12 contract handoff uses unsettled feedback before final service can change trust")
	nm.resolve_serve_style("mira", "", "温柔")
	nm.finalize_mira_ending()
	_ok(String(nm.get_var("mira_ending")) == "she_finally_stopped",
		"Day12 gentle final service can still carry a borderline Mira route into responsibility")


func _test_dialogue_text_keeps_mira_route_coherent() -> void:
	_ok(_dialogue_contains("res://dialogue/mira_day4.pre.dialogue", "带着人走慢，心里也重"),
		"Day4 Mira pre-dialogue frames one-person-walk as her old excuse")
	_ok(_dialogue_contains("res://dialogue/mira_day4.post.dialogue", "把借口听成道理"),
		"Day4 Mira post-dialogue keeps her responsibility as subtext instead of confession")
	_ok(not _dialogue_contains("res://dialogue/mira_day4.post.dialogue", "把他留在半道上"),
		"Day4 Mira post-dialogue does not reveal the abandonment before Toby appears")
	_ok(_dialogue_contains("res://dialogue/toby_day6.pre.dialogue", "别问“她”是谁"),
		"Day6 Toby protects Mira's name while revealing the wound")
	_ok(_dialogue_contains("res://dialogue/ryan_action_feedback.dialogue", "他不该替我的借口去死"),
		"trusted contract handoff makes Mira own the phrase as her excuse")
	_ok(_dialogue_contains("res://dialogue/ryan_action_feedback.dialogue", "我一回头，当年那条路就又在我脚下"),
		"guarded contract handoff keeps Mira afraid of responsibility instead of instantly redeemed")
	_ok(_dialogue_contains("res://dialogue/mira_stall_encounter.dialogue", "那年我说给自己听，他当了真"),
		"Mira stall responsibility state explicitly links Toby's belief to Mira's old defense")
	_ok(_dialogue_contains("res://dialogue/mira_day12.pre.dialogue", "签字酒"),
		"Day12 pre-dialogue ties the order to the supply contract")
	_ok(_dialogue_contains("res://dialogue/mira_day12.post.dialogue", "不是为了补偿，是因为我早该回头"),
		"Day12 good ending resolves responsibility without making it a clean apology")


func _test_dialogue_highlights_mira_route_clues() -> void:
	_ok(_dialogue_contains("res://dialogue/mira_day4.pre.dialogue", "[color=#d6a84d]一个人走，才轻快[/color]"),
		"Day4 Mira pre-dialogue highlights her old one-person-walk phrase")
	_ok(_dialogue_contains("res://dialogue/mira_day4.post.dialogue", "[color=#d6a84d]半大孩子[/color]"),
		"Day4 Mira post-dialogue highlights the child clue")
	_ok(_dialogue_contains("res://dialogue/mira_day4.post.dialogue", "[color=#d6a84d]把借口听成道理[/color]"),
		"Day4 Mira post-dialogue highlights her excuse without revealing the abandonment")
	_ok(_dialogue_contains("res://dialogue/toby_day6.pre.dialogue", "[color=#d6a84d]谁也不能说我是被人丢在半道上的那个[/color]"),
		"Day6 Toby highlights proving he is not the abandoned child")
	_ok(_dialogue_contains("res://dialogue/toby_day6.post.dialogue", "[color=#d6a84d]丢在半道上[/color]"),
		"Day6 Toby post-dialogue highlights the abandonment echo")
	_ok(_dialogue_contains("res://dialogue/ryan_action_feedback.dialogue", "[color=#d6a84d]他不该替我的借口去死[/color]"),
		"trusted contract handoff highlights Mira taking responsibility for the phrase")
	_ok(_dialogue_contains("res://dialogue/mira_stall_encounter.dialogue", "[color=#d6a84d]那年我说给自己听，他当了真[/color]"),
		"Mira stall responsibility state highlights the link between her phrase and Toby")
	_ok(_dialogue_contains("res://dialogue/mira_day12.pre.dialogue", "[color=#d6a84d]长期供应协议[/color]"),
		"Day12 pre-dialogue highlights the supply agreement")


func _test_toby_motive_text_frames_proving_not_rescue() -> void:
	_ok(_dialogue_contains("res://dialogue/toby_day6.pre.dialogue", "报酬够我租下自己的摊位"),
		"Day6 Toby wants the commission as proof of independence")
	_ok(_dialogue_contains("res://dialogue/toby_day6.pre.dialogue", "她说得对"),
		"Day6 Toby repeats Mira's phrase as a wound, not neutral advice")
	_ok(_dialogue_contains("res://dialogue/toby_day6.post.dialogue", "我不是来找她的"),
		"Day6 post keeps Toby from becoming a simple rescue request")
	_ok(_dialogue_contains("res://dialogue/toby_day6.post.dialogue", "我只是想让她知道"),
		"Day6 post reveals Toby still wants Mira to witness him")


func _test_toby_contract_and_inference_frame_the_phrase_as_wound() -> void:
	_ok(_dialogue_contains("res://data/documents.json", "又被墨团压住"),
		"Toby contract shows he nearly writes Mira's name but suppresses it")
	_ok(_dialogue_contains("res://data/inference_puzzles.json", "不是他的信念"),
		"Mira responsibility inference rejects the phrase as Toby's true belief")
	_ok(_dialogue_contains("res://data/inference_puzzles.json", "一直没能吐出来的伤口"),
		"Mira responsibility inference frames the phrase as a wound")


func _test_mira_handoff_feedback_frames_the_phrase_as_her_excuse() -> void:
	_ok(_dialogue_contains("res://dialogue/ryan_action_feedback.dialogue", "这句话不是路上的规矩"),
		"trusted Mira handoff rejects the phrase as practical road wisdom")
	_ok(_dialogue_contains("res://dialogue/ryan_action_feedback.dialogue", "我逃走时给自己的借口"),
		"trusted Mira handoff names the phrase as her excuse")
	_ok(_dialogue_contains("res://dialogue/ryan_action_feedback.dialogue", "我知道那句话是谁教他的"),
		"guarded Mira handoff admits knowledge without redemption")
	_ok(_dialogue_contains("res://dialogue/ryan_action_feedback.dialogue", "回头就走不动了"),
		"guarded Mira handoff roots refusal in fear rather than ignorance")


func _test_mira_stall_followup_names_toby_contract_without_delivery_action() -> void:
	_ok(_dialogue_contains("res://dialogue/mira_stall_encounter.dialogue", "托比那份黑齿委托"),
		"Mira stall follow-up names Toby's Blacktooth contract directly")
	_ok(not _dialogue_contains("res://dialogue/mira_stall_encounter.dialogue", "酒馆里那张纸"),
		"Mira stall follow-up does not vaguely refer to a tavern paper")
	_ok(not _dialogue_contains("res://dialogue/mira_stall_encounter.dialogue", "已经递过了"),
		"Mira stall follow-up does not imply a delivery-button interaction")
	_ok(_dialogue_contains("res://scripts/game_manager.gd", "托比那份黑齿委托"),
		"Mira stall map result names Toby's Blacktooth contract directly")
	_ok(not _dialogue_contains("res://scripts/game_manager.gd", "酒馆里那张纸"),
		"Mira stall map result does not vaguely refer to a tavern paper")
	_ok(not _dialogue_contains("res://scripts/game_manager.gd", "已经递过了"),
		"Mira stall map result does not imply a delivery-button interaction")


func _test_mira_endings_preserve_the_phrase_debt() -> void:
	_ok(_dialogue_contains("res://data/npcs.json", "不该由他替她背着"),
		"good Mira ending centers taking back the phrase")
	_ok(_dialogue_contains("res://data/npcs.json", "差点把他送进黑齿矿脉"),
		"fixer route ending says Toby lived while the phrase debt stayed hidden")


func _dialogue_contains(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var body := file.get_as_text()
	file.close()
	var plain_body := body.replace("[color=#d6a84d]", "").replace("[/color]", "")
	return body.contains(text) or plain_body.contains(text)


func _test_route_she_finally_stopped() -> void:
	var nm := _nm()
	nm.set_var("toby_contract_found", true)
	nm.set_var("told_mira_truth", true)
	nm.set_affection("mira", nm.MIRA_TRUST_THRESHOLD)
	_ok(nm.get_mira_route() == "she_finally_stopped", "告知+信任达标 → 她终于停下")

func _test_route_never_turned_back() -> void:
	var nm := _nm()
	nm.set_var("toby_contract_found", true)
	nm.set_var("told_mira_truth", true)
	nm.set_affection("mira", nm.MIRA_TRUST_THRESHOLD - 1)
	_ok(nm.get_mira_route() == "never_turned_back", "告知+信任不足 → 再没回头")

func _test_route_closed_the_door() -> void:
	var nm := _nm()
	nm.set_var("toby_secured", true)
	_ok(nm.get_mira_route() == "closed_the_door", "未告知+兜底 → 替他合上门")

func _test_route_another_light_out() -> void:
	var nm := _nm()
	_ok(nm.get_mira_route() == "another_light_out", "未告知+未兜底 → 另一盏熄灭的灯")

func _test_toby_survival_flags() -> void:
	var nm_missing_contract := _nm()
	nm_missing_contract.set_var("told_mira_truth", true)
	nm_missing_contract.set_affection("mira", nm_missing_contract.MIRA_TRUST_THRESHOLD)
	_ok(not nm_missing_contract.toby_survived(), "truth flag without contract proof does not save Toby")

	var nm := _nm()
	nm.set_var("toby_contract_found", true)
	# 担责救活
	nm.set_var("told_mira_truth", true)
	nm.set_affection("mira", nm.MIRA_TRUST_THRESHOLD)
	_ok(nm.toby_survived(), "担责 → 托比存活")
	# 仅兜底救活（未告知）
	var nm2 := _nm()
	nm2.set_var("toby_secured", true)
	_ok(nm2.toby_survived(), "兜底 → 托比存活")
	# 告知但信任不足且未兜底 → 死
	var nm3 := _nm()
	nm3.set_var("toby_contract_found", true)
	nm3.set_var("told_mira_truth", true)
	nm3.set_affection("mira", nm3.MIRA_TRUST_THRESHOLD - 1)
	_ok(not nm3.toby_survived(), "知情仍逃且未兜底 → 托比赴死")
	# finalize 写入 ending 与 toby_survived
	nm3.finalize_mira_ending()
	_ok(nm3.get_var("mira_ending") == "never_turned_back", "finalize 写 mira_ending")
	_ok(nm3.get_var("toby_survived") == false, "finalize 写 toby_survived")
	_ok(nm3.endings.get("toby", "") == "lost", "finalize 写 toby 结局 lost")
	# 担责存活时托比结局为 saved
	var nm4 := _nm()
	nm4.set_var("toby_contract_found", true)
	nm4.set_var("told_mira_truth", true)
	nm4.set_affection("mira", nm4.MIRA_TRUST_THRESHOLD)
	nm4.finalize_mira_ending()
	_ok(nm4.endings.get("toby", "") == "saved", "finalize 写 toby 结局 saved")
