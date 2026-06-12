extends Node

var _checks := 0
var _failures := 0


func _ready() -> void:
	await _test_ryan_entry_portrait_reads_story_state()
	await _test_ryan_serve_reaction_changes_portrait()
	await _test_serving_ryan_through_game_manager_changes_portrait()
	await _test_informed_ryan_stays_hesitant_after_correct_meat()
	await _test_day3_fate_reveal_uses_mercenary_portrait()
	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-RYAN-PORTRAIT-STATE] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-RYAN-PORTRAIT-STATE] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-RYAN-PORTRAIT-STATE] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _gm():
	return get_node("/root/GameManager")


func _reset_ryan_story() -> void:
	var narrative = _gm().narrative
	for key in [
		"ryan_informed",
		"ryan_has_alternative",
		"ryan_drugged",
		"ryan_interaction_closed",
		"ryan_alternative_pending",
		"ryan_alternative_declined",
	]:
		narrative.set_var(key, false)
	narrative.set_var("ryan_ending", "")
	narrative.set_affection("ryan", 0)


func _spawn_tavern() -> TavernView:
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate() as TavernView
	add_child(tavern)
	await get_tree().process_frame
	await get_tree().process_frame
	return tavern


func _portrait_path(tavern: TavernView) -> String:
	var sprite := tavern.get_node_or_null("CustomerArea/CustomerSprite") as TextureRect
	if sprite == null or sprite.texture == null:
		return ""
	return sprite.texture.resource_path


func _test_ryan_entry_portrait_reads_story_state() -> void:
	_reset_ryan_story()
	var tavern := await _spawn_tavern()
	tavern.show_customer("Ryan", "Ale", "ryan")
	_ok(_portrait_path(tavern).ends_with("/ryan_neutral.png"), "Ryan entry defaults to neutral portrait")

	_gm().narrative.set_var("ryan_informed", true)
	tavern.show_customer("Ryan", "Ale", "ryan")
	_ok(_portrait_path(tavern).ends_with("/ryan_hesitant.png"), "informed Ryan enters with hesitant portrait")

	_gm().narrative.set_var("ryan_has_alternative", true)
	tavern.show_customer("Ryan", "Ale", "ryan")
	_ok(_portrait_path(tavern).ends_with("/ryan_excited.png"), "alternative route Ryan enters with excited portrait")

	_gm().narrative.set_var("ryan_alternative_declined", true)
	tavern.show_customer("Ryan", "Ale", "ryan")
	_ok(_portrait_path(tavern).ends_with("/ryan_dejected.png"), "declined route Ryan enters with dejected portrait")
	tavern.queue_free()


func _test_ryan_serve_reaction_changes_portrait() -> void:
	_reset_ryan_story()
	var tavern := await _spawn_tavern()
	tavern.show_customer("Ryan", "Ale", "ryan")
	if not tavern.has_method("show_customer_reaction"):
		_ok(false, "TavernView exposes show_customer_reaction for serve feedback portraits")
		tavern.queue_free()
		return

	tavern.show_customer_reaction("success", "ryan")
	_ok(_portrait_path(tavern).ends_with("/ryan_excited.png"), "Ryan switches to excited portrait after correct serve")

	tavern.show_customer("Ryan", "Ale", "ryan")
	tavern.show_customer_reaction("fail_wrong", "ryan")
	_ok(_portrait_path(tavern).ends_with("/ryan_dejected.png"), "Ryan switches to dejected portrait after wrong product")

	tavern.show_customer("Ryan", "Ale", "ryan")
	tavern.show_customer_reaction("fail_weird", "ryan")
	_ok(_portrait_path(tavern).ends_with("/ryan_dejected.png"), "Ryan switches to dejected portrait after weird item")
	tavern.queue_free()


func _test_serving_ryan_through_game_manager_changes_portrait() -> void:
	_reset_ryan_story()
	var tavern := await _spawn_tavern()
	var old_day: int = _gm().economy.current_day
	var tutorial = get_node_or_null("/root/TutorialManager")
	var old_tutorial_active := false
	if tutorial != null:
		old_tutorial_active = bool(tutorial._is_active)
		tutorial._is_active = true
	_gm().economy.current_day = 99
	_gm().guests.clear_guest()
	_gm().guests.spawn_important("ryan", "ale_beer")
	await get_tree().process_frame
	_ok(_portrait_path(tavern).ends_with("/ryan_neutral.png"), "GameManager shows Ryan neutral before serving")

	_gm().request_serve("ale_beer")
	await get_tree().process_frame
	_ok(_portrait_path(tavern).ends_with("/ryan_excited.png"), "GameManager switches Ryan to excited after correct serve")
	await get_tree().create_timer(2.0).timeout

	_reset_ryan_story()
	_gm().guests.spawn_important("ryan", "ale_beer")
	await get_tree().process_frame
	_gm().request_serve("bread")
	await get_tree().process_frame
	_ok(_portrait_path(tavern).ends_with("/ryan_dejected.png"), "GameManager switches Ryan to dejected after wrong serve")
	await get_tree().create_timer(2.0).timeout

	_gm().economy.current_day = old_day
	if tutorial != null:
		tutorial._is_active = old_tutorial_active
	tavern.queue_free()


func _test_informed_ryan_stays_hesitant_after_correct_meat() -> void:
	_reset_ryan_story()
	var tavern := await _spawn_tavern()
	var old_day: int = _gm().economy.current_day
	var tutorial = get_node_or_null("/root/TutorialManager")
	var old_tutorial_active := false
	if tutorial != null:
		old_tutorial_active = bool(tutorial._is_active)
		tutorial._is_active = true
	_gm().economy.current_day = 99
	_gm().guests.clear_guest()
	_gm().guests.spawn_important("ryan", "meat_cooked")
	await get_tree().process_frame

	var evidence_result: Dictionary = _gm().request_narrative_delivery("bloodied_contract", [])
	_ok(evidence_result.get("accepted", false), "Ryan accepts the bloodied contract before meat")
	_gm().request_serve("meat_cooked")
	await get_tree().process_frame
	_ok(_portrait_path(tavern).ends_with("/ryan_hesitant.png"),
		"informed Ryan stays hesitant after receiving the correct meat order")
	await get_tree().create_timer(2.0).timeout

	_gm().economy.current_day = old_day
	if tutorial != null:
		tutorial._is_active = old_tutorial_active
	tavern.queue_free()


func _test_day3_fate_reveal_uses_mercenary_portrait() -> void:
	_reset_ryan_story()
	var tavern := await _spawn_tavern()
	var old_day: int = _gm().economy.current_day
	var tutorial = get_node_or_null("/root/TutorialManager")
	var old_tutorial_active := false
	if tutorial != null:
		old_tutorial_active = bool(tutorial._is_active)
		tutorial._is_active = true
	_gm().economy.current_day = 3
	_gm().guests.clear_guest()
	_gm().guests.spawn_important("ryan", "herb_broth")
	await get_tree().process_frame

	_ok(_portrait_path(tavern).ends_with("/mercenary_a.png"),
		"Day 3 fate reveal shows the mercenary messenger portrait instead of Ryan")

	if _gm().guests.has_guest:
		_gm().guests.clear_guest()
	_gm().economy.current_day = old_day
	if tutorial != null:
		tutorial._is_active = old_tutorial_active
	tavern.queue_free()
