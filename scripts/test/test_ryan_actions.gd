extends Node

var _checks := 0
var _failures := 0


func _ready() -> void:
	_test_action_interface_exists()
	_test_uninformed_route()
	_test_drugged_route_closes_interaction()
	_test_alternative_requires_warning()
	_test_informed_route_rejects_drugged_ale()
	_test_alternative_route()
	_test_alternative_declined_when_low_trust()
	_test_resolve_pending_alternative_noop_without_pending()
	_test_ryan_style_affection_delta()
	_test_routes_map_to_ending_texts()
	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-RYAN-ACTIONS] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-RYAN-ACTIONS] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-RYAN-ACTIONS] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _new_narrative() -> NarrativeManager:
	var narrative := NarrativeManager.new()
	narrative.load_npc_data()
	return narrative


func _test_action_interface_exists() -> void:
	var narrative := _new_narrative()
	_ok(narrative.has_method("resolve_action"), "NarrativeManager exposes resolve_action")
	_ok(narrative.has_method("get_ryan_route"), "NarrativeManager exposes get_ryan_route")


func _test_uninformed_route() -> void:
	var narrative := _new_narrative()
	if not narrative.has_method("get_ryan_route"):
		return
	_ok(narrative.get_ryan_route() == "uninformed_fallen", "default route is uninformed_fallen")


func _test_drugged_route_closes_interaction() -> void:
	var narrative := _new_narrative()
	if not narrative.has_method("resolve_action") or not narrative.has_method("get_ryan_route"):
		return
	var mix: Dictionary = narrative.resolve_action({
		"type": "add_story_item_to_product",
		"item_key": "sleep_powder",
		"product_key": "ale_beer",
	})
	_ok(mix.get("accepted", false), "sleep powder can be added to ale_beer")
	_ok(mix.get("product_tags", []).has("sleep_powder"), "drugged ale receives sleep_powder tag")
	var give: Dictionary = narrative.resolve_action({
		"type": "give_product",
		"npc_id": "ryan",
		"product_key": "ale_beer",
		"product_tags": mix.get("product_tags", []),
	})
	_ok(give.get("accepted", false), "Ryan accepts drugged ale before warning")
	_ok(give.get("interaction_closed", false), "drugged ale closes Ryan interaction")
	_ok(narrative.get_var("ryan_drugged") == true, "drugged ale records ryan_drugged")
	_ok(narrative.get_ryan_route() == "drugged_survivor", "drugged route is reachable")
	var late_warning: Dictionary = narrative.resolve_action({
		"type": "give_story_item",
		"npc_id": "ryan",
		"item_key": "bloodied_contract",
	})
	_ok(not late_warning.get("accepted", true), "closed Ryan interaction rejects later evidence")


func _test_alternative_requires_warning() -> void:
	var narrative := _new_narrative()
	if not narrative.has_method("resolve_action"):
		return
	var result: Dictionary = narrative.resolve_action({
		"type": "give_story_item",
		"npc_id": "ryan",
		"item_key": "alternative_contract",
	})
	_ok(not result.get("accepted", true), "alternative contract is rejected before warning")
	_ok(result.get("feedback", "") == "ryan_needs_warning_first",
		"pre-warning rejection uses ryan_needs_warning_first, not trust gate")
	_ok(narrative.get_var("ryan_has_alternative") == false, "rejected alternative is not recorded")
	_ok(narrative.get_var("ryan_alternative_pending") == false, "未警告则不提请")


func _test_informed_route_rejects_drugged_ale() -> void:
	var narrative := _new_narrative()
	if not narrative.has_method("resolve_action") or not narrative.has_method("get_ryan_route"):
		return
	var warning: Dictionary = narrative.resolve_action({
		"type": "give_story_item",
		"npc_id": "ryan",
		"item_key": "bloodied_contract",
	})
	_ok(warning.get("accepted", false), "Ryan accepts bloodied contract")
	_ok(narrative.get_var("ryan_informed") == true, "evidence records ryan_informed")
	var drugged_ale: Dictionary = narrative.resolve_action({
		"type": "give_product",
		"npc_id": "ryan",
		"product_key": "ale_beer",
		"product_tags": ["sleep_powder"],
	})
	_ok(not drugged_ale.get("accepted", true), "informed Ryan rejects drugged ale")
	_ok(narrative.get_var("ryan_drugged") == false, "rejected drugged ale does not record ryan_drugged")
	_ok(narrative.get_ryan_route() == "informed_fallen", "evidence-only route is reachable")


func _test_alternative_route() -> void:
	var narrative := _new_narrative()
	if not narrative.has_method("resolve_action") or not narrative.has_method("get_ryan_route"):
		return
	narrative.resolve_action({
		"type": "give_story_item", "npc_id": "ryan", "item_key": "bloodied_contract",
	})
	var pending: Dictionary = narrative.resolve_action({
		"type": "give_story_item", "npc_id": "ryan", "item_key": "alternative_contract",
	})
	_ok(pending.get("accepted", false), "informed Ryan 收下替代委托（提请）")
	_ok(pending.get("feedback", "") == "ryan_alternative_pending", "递交反馈为 ryan_alternative_pending")
	_ok(narrative.get_var("ryan_has_alternative") == false, "提请阶段尚未写 ryan_has_alternative")
	# 当晚上菜：信任达标 → 收下
	narrative.set_affection("ryan", narrative.TRUST_THRESHOLD)
	var decided: Dictionary = narrative.resolve_pending_alternative("ryan")
	_ok(decided.get("accepted", false), "信任达标上菜后收下替代委托")
	_ok(narrative.get_var("ryan_has_alternative") == true, "决断后写 ryan_has_alternative")
	_ok(narrative.get_ryan_route() == "alternative_survivor", "alternative route reachable")


func _test_alternative_declined_when_low_trust() -> void:
	var narrative := _new_narrative()
	narrative.resolve_action({
		"type": "give_story_item", "npc_id": "ryan", "item_key": "bloodied_contract",
	})
	narrative.resolve_action({
		"type": "give_story_item", "npc_id": "ryan", "item_key": "alternative_contract",
	})
	# aff_ryan 默认 0 < TRUST_THRESHOLD
	var decided: Dictionary = narrative.resolve_pending_alternative("ryan")
	_ok(not decided.get("accepted", true), "信任不足上菜后婉拒替代委托")
	_ok(narrative.get_var("ryan_has_alternative") == false, "婉拒不写 ryan_has_alternative")
	_ok(narrative.get_var("ryan_alternative_declined") == true, "婉拒置 ryan_alternative_declined")
	_ok(narrative.get_var("ryan_interaction_closed") == true, "婉拒亦封闭交互（终局）")
	_ok(narrative.get_ryan_route() == "informed_fallen", "婉拒后落在 informed_fallen")


func _test_resolve_pending_alternative_noop_without_pending() -> void:
	var narrative := _new_narrative()
	var r: Dictionary = narrative.resolve_pending_alternative("ryan")
	_ok(not r.get("resolved", true), "无待定项时 resolve 为空操作")
	_ok(narrative.get_var("ryan_has_alternative") == false, "空操作不写 ryan_has_alternative")


func _test_ryan_style_affection_delta() -> void:
	var narrative := _new_narrative()
	var base: int = narrative.get_affection("ryan")
	narrative.resolve_serve_style("ryan", "", "粗鲁")
	_ok(narrative.get_affection("ryan") == base + 2, "Ryan 粗鲁上菜 +2（偏好已配）")
	var after_rough: int = narrative.get_affection("ryan")
	narrative.resolve_serve_style("ryan", "", "温柔")
	_ok(narrative.get_affection("ryan") == after_rough - 2, "Ryan 温柔上菜 -2（反感已配）")
	var after_gentle: int = narrative.get_affection("ryan")
	narrative.resolve_serve_style("ryan", "", "平静")
	_ok(narrative.get_affection("ryan") == after_gentle, "Ryan 平静上菜 0（中性）")


func _ryan_endings() -> Dictionary:
	for npc in _new_narrative().all_npcs:
		if npc.id == "ryan":
			return npc.endings
	return {}


func _test_routes_map_to_ending_texts() -> void:
	var endings := _ryan_endings()
	for route in ["uninformed_fallen", "drugged_survivor", "informed_fallen", "alternative_survivor"]:
		_ok(endings.has(route), "ryan endings include route key %s" % route)
		_ok(String(endings.get(route, "")) != "", "ryan ending %s has text" % route)

	# finalize_ryan_ending 写入的 key 必须是 endings 里存在的路线
	var narrative := _new_narrative()
	narrative.finalize_ryan_ending()
	_ok(narrative.get_var("ryan_ending") == "uninformed_fallen", "default finalize -> uninformed_fallen")
	_ok(endings.has(String(narrative.get_var("ryan_ending"))), "default ending key exists in endings")

	var drugged := _new_narrative()
	drugged.set_var("ryan_drugged", true)
	drugged.finalize_ryan_ending()
	_ok(drugged.get_var("ryan_ending") == "drugged_survivor", "finalize maps drugged route to its ending")
	_ok(drugged.get_var("ryan_ending") == drugged.get_ryan_route(), "finalize ending matches get_ryan_route")
