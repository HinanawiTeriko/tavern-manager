extends Node

## GM 级递交测试：把物理拖拽会调用的中介入口（request_narrative_delivery /
## request_apply_story_item_to_product / current_order_key）跑通，验证四路线在
## 真实玩法路由下可达、互斥，错误递交不改变剧情变量。物理拖拽本身走人工验证。

var _checks := 0
var _failures := 0


func _ready() -> void:
	_test_current_order_key()
	_test_post_dialogue_gate_is_export_resource_aware()
	_test_action_feedback_keeps_ryan_story_out_of_customer_bubble()
	_test_action_feedback_routes_mira_contract_handoff_to_dialogue()
	_test_day12_mira_contract_delivery_uses_unsettled_feedback()
	_test_ryan_contract_delivery_refreshes_portrait_state()
	_test_give_evidence_informs_ryan()
	_test_alternative_requires_warning()
	_test_alternative_pending_then_serve_decides()
	_test_apply_sleep_powder_to_ale()
	_test_drugged_ale_uninformed_passes_out()
	_test_informed_refuses_drugged_ale()
	_test_plain_ale_changes_nothing()
	_test_formal_order_product_not_handled()
	_test_day3_fate_reveal_wrong_product_not_handled_as_ryan_action()
	_test_day3_fate_reveal_correct_order_does_not_resolve_ryan_state()
	_test_wrong_target_story_item()
	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-RYAN-DELIVERY] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-RYAN-DELIVERY] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-RYAN-DELIVERY] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _gm():
	return get_node("/root/GameManager")


func _test_action_feedback_keeps_ryan_story_out_of_customer_bubble() -> void:
	var gm = _gm()
	var original_view = gm._tavern_view
	var fake_view := FakeFeedbackView.new()
	gm._tavern_view = fake_view

	var ryan_feedback_keys := [
		"ryan_informed",
		"ryan_accepts_alternative",
		"ryan_needs_warning_first",
		"ryan_alternative_pending",
		"ryan_accepts_ale",
		"ryan_drugged",
		"ryan_refuses_drugged_ale",
		"ryan_interaction_closed",
	]
	for key in ryan_feedback_keys:
		_ok(not gm.ACTION_FEEDBACK.has(key),
			"Ryan action feedback text is not kept in mechanical feedback table: " + key)
		_ok(gm.ACTION_FEEDBACK_DIALOGUE_TITLES.has(key),
			"Ryan action feedback is routed to dialogue: " + key)
		_ok(String(gm.ACTION_FEEDBACK_DIALOGUE_TITLES[key]) == key,
			"Ryan action feedback dialogue title matches feedback key: " + key)

	_ok(fake_view.customer_lines.is_empty(),
		"Ryan story action feedback must not use the customer reaction bubble")
	_ok(fake_view.stage_lines.is_empty(),
		"Ryan story action feedback must not use StageCaption")

	var dialogue_text := FileAccess.get_file_as_string("res://dialogue/ryan_action_feedback.dialogue")
	_ok(not dialogue_text.is_empty(), "Ryan action feedback dialogue file exists")
	_ok(ResourceLoader.exists("res://dialogue/ryan_action_feedback.dialogue"),
		"Ryan action feedback dialogue is importable by Godot")
	for key in ryan_feedback_keys:
		_ok(dialogue_text.contains("~ " + key), "Ryan action feedback dialogue has title " + key)

	gm._show_action_feedback("sleep_powder_added")
	_ok(fake_view.customer_lines.is_empty(),
		"mixing sleep powder does not create customer dialogue")
	_ok(fake_view.stage_lines.is_empty(),
		"mixing sleep powder does not use StageCaption")
	_ok(fake_view.dialogue_mode_calls.is_empty(),
		"mixing sleep powder does not start formal dialogue")

	gm._show_action_feedback("unsupported_story_product")
	_ok(fake_view.stage_lines.size() == 1,
		"non-Ryan mechanical feedback still uses StageCaption")

	gm._tavern_view = original_view
	fake_view.free()


func _test_action_feedback_routes_mira_contract_handoff_to_dialogue() -> void:
	var gm = _gm()
	var original_view = gm._tavern_view
	var fake_view := FakeFeedbackView.new()
	gm._tavern_view = fake_view

	var mira_feedback_keys := [
		"mira_informed_trusted",
		"mira_informed_guarded",
		"mira_informed_unsettled",
	]
	for key in mira_feedback_keys:
		_ok(not gm.ACTION_FEEDBACK.has(key),
			"Mira contract handoff feedback text is not kept in mechanical feedback table: " + key)
		_ok(gm.ACTION_FEEDBACK_DIALOGUE_TITLES.has(key),
			"Mira contract handoff feedback is routed to dialogue: " + key)
		_ok(String(gm.ACTION_FEEDBACK_DIALOGUE_TITLES.get(key, "")) == key,
			"Mira contract handoff dialogue title matches feedback key: " + key)

	var dialogue_text := FileAccess.get_file_as_string("res://dialogue/ryan_action_feedback.dialogue")
	for key in mira_feedback_keys:
		_ok(dialogue_text.contains("~ " + key), "action feedback dialogue has Mira title " + key)

	gm._show_action_feedback("mira_informed_trusted")
	_ok(fake_view.customer_lines.is_empty(),
		"Mira contract handoff must not use the customer reaction bubble")
	_ok(fake_view.stage_lines.is_empty(),
		"Mira contract handoff must not use StageCaption")

	gm._tavern_view = original_view
	fake_view.free()


func _test_day12_mira_contract_delivery_uses_unsettled_feedback() -> void:
	var gm = _gm()
	var old_day: int = gm.economy.current_day
	var original_view = gm._tavern_view
	var fake_view := FakeFeedbackView.new()
	gm._tavern_view = fake_view
	gm.economy.current_day = 12
	_reset_ryan("spiced_wine", "mira")
	gm.narrative.set_affection("mira", gm.narrative.MIRA_TRUST_THRESHOLD - 2)

	var result: Dictionary = gm.request_narrative_delivery("toby_contract", [])
	_ok(result.get("accepted", false), "Day12 Mira accepts Toby contract through the gameplay delivery route")
	_ok(String(result.get("feedback", "")) == "mira_informed_unsettled",
		"Day12 gameplay delivery route returns unsettled feedback before final service")
	_ok(gm.narrative.get_var("told_mira_truth") == true,
		"Day12 gameplay delivery route still records that Mira learned the truth")

	gm.economy.current_day = old_day
	gm._tavern_view = original_view
	gm.guests.clear_guest()
	fake_view.free()


func _test_ryan_contract_delivery_refreshes_portrait_state() -> void:
	var gm = _gm()
	var original_view = gm._tavern_view
	var old_day: int = gm.economy.current_day
	var tutorial = get_node_or_null("/root/TutorialManager")
	var old_tutorial_active := false
	if tutorial != null:
		old_tutorial_active = bool(tutorial._is_active)
		tutorial._is_active = true
	var fake_view := FakeFeedbackView.new()
	gm._tavern_view = fake_view
	gm.economy.current_day = 99
	_reset_ryan()

	var evidence_result: Dictionary = gm.request_narrative_delivery("bloodied_contract", [])
	_ok(evidence_result.get("accepted", false), "Ryan accepts bloodied contract before portrait refresh")
	_ok(fake_view.reactions.size() == 1,
		"bloodied contract delivery refreshes the current Ryan portrait")
	if fake_view.reactions.size() >= 1:
		_ok(fake_view.reactions[0]["npc_id"] == "ryan",
			"bloodied contract portrait refresh targets Ryan")
		_ok(fake_view.reactions[0]["outcome"] == "",
			"bloodied contract portrait refresh uses story-state portrait selection")

	var alternative_result: Dictionary = gm.request_narrative_delivery("alternative_contract", [])
	_ok(alternative_result.get("accepted", false), "Ryan accepts alternative contract prompt before portrait refresh")
	_ok(fake_view.reactions.size() == 2,
		"alternative contract delivery refreshes the current Ryan portrait")
	if fake_view.reactions.size() >= 2:
		_ok(fake_view.reactions[1]["npc_id"] == "ryan",
			"alternative contract portrait refresh targets Ryan")
		_ok(fake_view.reactions[1]["outcome"] == "",
			"alternative contract portrait refresh uses story-state portrait selection")

	gm.economy.current_day = old_day
	if tutorial != null:
		tutorial._is_active = old_tutorial_active
	gm._tavern_view = original_view
	fake_view.free()


## 重置 Ryan 剧情变量并让指定客人在场（不依赖 _tavern_view，headless 安全）。
func _reset_ryan(order_key := "meat_cooked", npc_id := "ryan") -> void:
	var n = _gm().narrative
	for v in ["ryan_informed", "ryan_has_alternative", "ryan_drugged", "ryan_interaction_closed",
			"ryan_alternative_pending", "ryan_alternative_declined"]:
		n.set_var(v, false)
	n.set_var("ryan_ending", "")
	n.set_affection("ryan", 0)
	_gm().guests.clear_guest()
	_gm().guests.spawn_important(npc_id, order_key)


class FakeFeedbackView extends Node:
	var daily_menu := {}
	var customer_lines := []
	var stage_lines := []
	var dialogue_mode_calls := []
	var reactions := []

	func customer_say(text) -> void:
		customer_lines.append(String(text))

	func show_customer(_customer_name: String, _order_name: String, _npc_id: String = "guest", _order_key: String = "") -> void:
		pass

	func show_stage_caption(text, color = Color.WHITE) -> void:
		stage_lines.append({"text": String(text), "color": color})

	func set_dialogue_mode(active: bool) -> void:
		dialogue_mode_calls.append(active)

	func set_close_enabled(_enabled: bool) -> void:
		pass

	func update_top_bar(_gold: int, _rep: int, _day: int, _last_day: int, _max_gold: int = 0) -> void:
		pass

	func show_customer_reaction(outcome: String, npc_id: String = "") -> void:
		reactions.append({"outcome": outcome, "npc_id": npc_id})

	func hide_customer() -> void:
		pass


func _test_current_order_key() -> void:
	_reset_ryan("meat_cooked")
	_ok(_gm().current_order_key() == "meat_cooked", "current_order_key reflects guest order")
	_gm().guests.clear_guest()
	_ok(_gm().current_order_key() == "", "no guest -> empty order key")


func _test_post_dialogue_gate_is_export_resource_aware() -> void:
	var gm_source := FileAccess.get_file_as_string("res://scripts/game_manager.gd")
	_ok(not gm_source.contains("FileAccess.file_exists(post_path)"),
		"post-dialogue gate must not use FileAccess.file_exists on imported dialogue resources")
	_ok(gm_source.contains("ResourceLoader.exists(post_path)"),
		"post-dialogue gate checks exported dialogue resources through ResourceLoader")
	_ok(ResourceLoader.exists("res://dialogue/ryan_day1.post.dialogue"),
		"Ryan day1 post dialogue is importable as an exported Resource")
	_ok(ResourceLoader.exists("res://dialogue/ryan_day2.post.dialogue"),
		"Ryan day2 post dialogue is importable as an exported Resource")


func _test_give_evidence_informs_ryan() -> void:
	_reset_ryan()
	var r: Dictionary = _gm().request_narrative_delivery("bloodied_contract", [])
	_ok(r.get("handled", false), "evidence delivery is handled")
	_ok(r.get("accepted", false), "Ryan accepts bloodied contract")
	_ok(r.get("consume", false), "accepted evidence is consumed (given to Ryan)")
	_ok(_gm().narrative.get_var("ryan_informed") == true, "evidence records ryan_informed")


func _test_alternative_requires_warning() -> void:
	_reset_ryan()
	var r: Dictionary = _gm().request_narrative_delivery("alternative_contract", [])
	_ok(r.get("handled", false), "alternative delivery is handled")
	_ok(not r.get("accepted", true), "alternative rejected before warning")
	_ok(not r.get("consume", true), "rejected alternative is not consumed (recovers to backpack)")
	_ok(_gm().narrative.get_var("ryan_has_alternative") == false, "rejected alternative not recorded")


func _test_alternative_pending_then_serve_decides() -> void:
	_reset_ryan()
	_gm().request_narrative_delivery("bloodied_contract", [])
	var r: Dictionary = _gm().request_narrative_delivery("alternative_contract", [])
	_ok(r.get("accepted", false), "informed Ryan 收下替代委托（提请）")
	_ok(not r.get("interaction_closed", true), "提请不关闭交互（待上菜定夺）")
	_ok(_gm().narrative.get_var("ryan_alternative_pending") == true, "递交置 ryan_alternative_pending")
	_ok(_gm().narrative.get_var("ryan_has_alternative") == false, "提请阶段未写 ryan_has_alternative")
	# 当晚上菜手法定夺：信任达标 → 收下
	_gm().narrative.set_affection("ryan", _gm().narrative.TRUST_THRESHOLD)
	var d: Dictionary = _gm().narrative.resolve_pending_alternative("ryan")
	_ok(d.get("accepted", false), "信任达标上菜后收下替代委托")
	_ok(_gm().narrative.get_var("ryan_has_alternative") == true, "决断后写 ryan_has_alternative")


func _test_apply_sleep_powder_to_ale() -> void:
	_reset_ryan()
	var r: Dictionary = _gm().request_apply_story_item_to_product("sleep_powder", "ale_beer")
	_ok(r.get("accepted", false), "sleep powder applies to ale_beer")
	_ok(r.get("product_tags", []).has("sleep_powder"), "drugged ale carries sleep_powder tag")
	var bad: Dictionary = _gm().request_apply_story_item_to_product("sleep_powder", "bread")
	_ok(not bad.get("accepted", true), "sleep powder rejects non-ale products")


func _test_drugged_ale_uninformed_passes_out() -> void:
	_reset_ryan()
	var r: Dictionary = _gm().request_narrative_delivery("ale_beer", ["sleep_powder"])
	_ok(r.get("accepted", false), "uninformed Ryan accepts drugged ale")
	_ok(r.get("interaction_closed", false), "drugged ale closes interaction")
	_ok(_gm().narrative.get_var("ryan_drugged") == true, "drugged ale records ryan_drugged")
	_ok(not _gm().guests.has_guest, "drugged Ryan passes out and leaves")
	_ok(_gm().narrative.get_ryan_route() == "drugged_survivor", "drugged route reachable via delivery")


func _test_informed_refuses_drugged_ale() -> void:
	_reset_ryan()
	_gm().request_narrative_delivery("bloodied_contract", [])
	var r: Dictionary = _gm().request_narrative_delivery("ale_beer", ["sleep_powder"])
	_ok(not r.get("accepted", true), "informed Ryan refuses drugged ale")
	_ok(_gm().narrative.get_var("ryan_drugged") == false, "refused drugged ale not recorded")
	_ok(_gm().guests.has_guest, "Ryan stays after refusing")
	_ok(_gm().narrative.get_ryan_route() == "informed_fallen", "evidence-only route reachable")


func _test_plain_ale_changes_nothing() -> void:
	_reset_ryan()
	var r: Dictionary = _gm().request_narrative_delivery("ale_beer", [])
	_ok(r.get("handled", false), "plain ale delivery handled")
	_ok(r.get("accepted", false), "Ryan accepts plain ale")
	_ok(_gm().narrative.get_var("ryan_drugged") == false, "plain ale does not drug")
	_ok(_gm().narrative.get_ryan_route() == "uninformed_fallen", "plain ale leaves route unchanged")


func _test_formal_order_product_not_handled() -> void:
	_reset_ryan("meat_cooked")
	# 正式订单成品不是叙事载体 → 让视图走正常上菜（request_serve），中介返回 not handled。
	var r: Dictionary = _gm().request_narrative_delivery("meat_cooked", [])
	_ok(not r.get("handled", true), "formal-order product falls back to normal serve")


func _test_day3_fate_reveal_wrong_product_not_handled_as_ryan_action() -> void:
	var gm = _gm()
	var original_day: int = gm.economy.current_day
	var original_view = gm._tavern_view
	var fake_view := FakeFeedbackView.new()
	gm._tavern_view = fake_view
	gm.economy.current_day = 3
	_reset_ryan("meat_cooked")
	gm.guests.current_guest.set_meta("portrait_id", "mercenary_a")

	var dialogue_calls_before := fake_view.dialogue_mode_calls.size()
	var r: Dictionary = gm.request_narrative_delivery("ale_beer", [])
	_ok(not r.get("handled", true),
		"Day 3 mercenary messenger wrong product falls back to normal failed serve")
	_ok(fake_view.dialogue_mode_calls.size() == dialogue_calls_before,
		"Day 3 mercenary messenger wrong product does not open Ryan action feedback dialogue")
	_ok(gm.narrative.get_var("ryan_drugged") == false,
		"Day 3 mercenary messenger wrong product does not mutate Ryan action state")

	gm.economy.current_day = original_day
	gm._tavern_view = original_view
	gm.guests.clear_guest()
	fake_view.free()


func _test_day3_fate_reveal_correct_order_does_not_resolve_ryan_state() -> void:
	var gm = _gm()
	var original_day: int = gm.economy.current_day
	var original_view = gm._tavern_view
	var fake_view := FakeFeedbackView.new()
	gm._tavern_view = fake_view
	gm.economy.current_day = 3
	_reset_ryan("meat_cooked")
	gm.guests.current_guest.set_meta("portrait_id", "mercenary_a")
	gm.narrative.set_var("ryan_alternative_pending", true)
	gm.narrative.set_affection("ryan", 0)

	gm.request_serve("meat_cooked", {"serve_drop_speed": 700.0, "quality": "normal"}, "")
	_ok(gm.narrative.get_var("ryan_alternative_pending") == true,
		"Day 3 mercenary messenger correct order does not resolve Ryan's pending alternative")
	_ok(gm.narrative.get_var("ryan_interaction_closed") == false,
		"Day 3 mercenary messenger correct order does not close Ryan interaction state")
	_ok(gm.narrative.get_affection("ryan") == 0,
		"Day 3 mercenary messenger correct order does not apply Ryan serve-style affection")

	gm.economy.current_day = original_day
	gm._tavern_view = original_view
	gm.guests.clear_guest()
	fake_view.free()


func _test_wrong_target_story_item() -> void:
	_reset_ryan("wine", "mira")
	var r: Dictionary = _gm().request_narrative_delivery("bloodied_contract", [])
	_ok(r.get("handled", false), "wrong-target story item is handled")
	_ok(not r.get("accepted", true), "non-Ryan rejects story item")
	_ok(not r.get("consume", true), "wrong-target story item recovers to backpack")
