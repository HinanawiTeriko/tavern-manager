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
	_ok(narrative.get_var("ryan_has_alternative") == false, "rejected alternative is not recorded")


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
		"type": "give_story_item",
		"npc_id": "ryan",
		"item_key": "bloodied_contract",
	})
	var alternative: Dictionary = narrative.resolve_action({
		"type": "give_story_item",
		"npc_id": "ryan",
		"item_key": "alternative_contract",
	})
	_ok(alternative.get("accepted", false), "informed Ryan accepts alternative contract")
	_ok(alternative.get("interaction_closed", false), "alternative contract closes Ryan interaction")
	_ok(narrative.get_var("ryan_has_alternative") == true, "alternative contract records ryan_has_alternative")
	_ok(narrative.get_ryan_route() == "alternative_survivor", "alternative route is reachable")
