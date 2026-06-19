extends Node

const TAVERN_SCENE := preload("res://scenes/ui/Tavern.tscn")

var _checks := 0
var _failures := 0


func _ready() -> void:
	await _test_chaos_ghost_tutorial_waits_until_phoebe_is_fully_visible()
	await _test_chaos_ghost_tutorial_waits_for_formal_dialogue_to_finish()
	await _test_hidden_chaos_summons_ghost_from_screen_edge_and_steals_item()
	await _test_ghost_fades_in_place_when_player_snatches_target_back()
	await _test_ghost_ignores_held_and_story_items()
	await _test_ghost_handles_target_freed_mid_approach()
	await _test_ghost_can_steal_idle_cookware_and_dock_it_after_escape()
	await _test_fast_releases_feed_hidden_chaos()
	await _test_waiting_guest_feeds_hidden_chaos_without_visible_meter()
	_finish()


func _ok(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("[TEST-CHAOS-GHOST-THIEF] FAIL: " + message)


func _is_offscreen(position: Vector2) -> bool:
	return position.x < -40.0 or position.x > 1320.0 or position.y < -40.0 or position.y > 760.0


func _ghost_texture_path(ghost: Node2D) -> String:
	if ghost == null:
		return ""
	var sprite := ghost.get_node_or_null("Sprite") as Sprite2D
	if sprite == null or sprite.texture == null:
		return ""
	return String(sprite.texture.resource_path)


func _reset_active_tutorial(tm: Node) -> void:
	if tm == null:
		return
	tm._is_active = false
	tm._current_sequence.clear()
	tm._current_step = -1
	if tm.has_method("_remove_overlay"):
		tm._remove_overlay()


func _capture_tutorial_state(tm: Node) -> Dictionary:
	return {
		"completed_steps": tm._completed_steps.duplicate(),
		"daymap_first_shown": tm.daymap_first_shown,
		"tavern_first_entered": tm.tavern_first_entered,
		"first_menu_prep_shown": tm.first_menu_prep_shown,
		"shop_first_visited": tm.shop_first_visited,
		"first_guest_arrived": tm.first_guest_arrived,
		"first_product_seasoned": tm.first_product_seasoned,
		"first_guest_served": tm.first_guest_served,
		"first_ledger_shown": tm.first_ledger_shown,
		"first_inference_shown": tm.first_inference_shown,
	}


func _restore_tutorial_state(tm: Node, state: Dictionary) -> void:
	_reset_active_tutorial(tm)
	tm._completed_steps = (state.get("completed_steps", []) as Array).duplicate()
	tm.daymap_first_shown = bool(state.get("daymap_first_shown", false))
	tm.tavern_first_entered = bool(state.get("tavern_first_entered", false))
	tm.first_menu_prep_shown = bool(state.get("first_menu_prep_shown", false))
	tm.shop_first_visited = bool(state.get("shop_first_visited", false))
	tm.first_guest_arrived = bool(state.get("first_guest_arrived", false))
	tm.first_product_seasoned = bool(state.get("first_product_seasoned", false))
	tm.first_guest_served = bool(state.get("first_guest_served", false))
	tm.first_ledger_shown = bool(state.get("first_ledger_shown", false))
	tm.first_inference_shown = bool(state.get("first_inference_shown", false))
	if tm.has_method("_save_state"):
		tm._save_state()


func _complete_existing_tutorials_except(tm: Node, except_step_id: String) -> void:
	tm._completed_steps.clear()
	for group_key in tm._steps.keys():
		for step in tm._steps[group_key]:
			var step_id := String(step.get("id", ""))
			if step_id != except_step_id and step_id != "":
				tm._completed_steps.append(step_id)
	while except_step_id != "" and tm._completed_steps.has(except_step_id):
		tm._completed_steps.erase(except_step_id)
	tm.daymap_first_shown = true
	tm.tavern_first_entered = true
	tm.first_menu_prep_shown = true
	tm.shop_first_visited = true
	tm.first_guest_arrived = true
	tm.first_product_seasoned = true
	tm.first_guest_served = true
	tm.first_ledger_shown = true
	tm.first_inference_shown = true


func _complete_all_existing_tutorials(tm: Node) -> void:
	_complete_existing_tutorials_except(tm, "")


func _test_chaos_ghost_tutorial_waits_until_phoebe_is_fully_visible() -> void:
	var tm := get_node_or_null("/root/TutorialManager")
	_ok(tm != null, "TutorialManager autoload should exist for chaos ghost tutorial")
	if tm == null:
		return

	_reset_active_tutorial(tm)
	var tutorial_backup := _capture_tutorial_state(tm)
	_complete_existing_tutorials_except(tm, "chaos_ghost_intro")

	var tavern := TAVERN_SCENE.instantiate()
	add_child(tavern)
	await get_tree().process_frame

	var bar := tavern.get_node("BarWorkspace") as BarWorkspace
	if bar == null or not bar.has_method("record_chaos_event") or not bar.has_method("try_trigger_chaos_event"):
		_restore_tutorial_state(tm, tutorial_backup)
		tavern.queue_free()
		await get_tree().process_frame
		return
	bar.set_process(false)

	var item := bar._spawn_desk_item_at(Vector2(560.0, 340.0), "ale")
	await get_tree().process_frame
	bar.call("record_chaos_event", "guest_wait", 2.0)
	var triggered: bool = bar.call("try_trigger_chaos_event")
	_ok(triggered, "high hidden chaos should start before testing the tutorial timing")
	_ok(not tm._is_active, "chaos ghost tutorial should not appear the instant Phoebe enters from offscreen")

	for _i in range(21):
		bar._process(0.1)
		await get_tree().process_frame

	_ok(not tm._is_active, "chaos ghost tutorial should wait until Phoebe is fully visible")

	bar._process(0.1)
	await get_tree().process_frame

	_ok(tm._is_active, "chaos ghost tutorial should start when Phoebe has fully appeared beside the target")
	_ok(tm._current_sequence.size() > 0 and String(tm._current_sequence[0].get("group", "")) == "chaos_ghost",
		"first full Phoebe appearance should launch the chaos_ghost tutorial group")
	_ok(is_instance_valid(item) and not item.is_queued_for_deletion(),
		"target item should remain on the table while the first chaos ghost tutorial is shown")

	_restore_tutorial_state(tm, tutorial_backup)
	tavern.queue_free()
	await get_tree().process_frame


func _test_chaos_ghost_tutorial_waits_for_formal_dialogue_to_finish() -> void:
	var tm := get_node_or_null("/root/TutorialManager")
	var gm := get_node_or_null("/root/GameManager")
	_ok(tm != null and gm != null, "TutorialManager and GameManager should exist for dialogue/tutorial exclusion")
	if tm == null or gm == null:
		return

	_reset_active_tutorial(tm)
	var tutorial_backup := _capture_tutorial_state(tm)
	var old_dialogue_phase: String = gm._dialogue_phase
	var old_dialogue_active: bool = gm._is_dialogue_active
	_complete_existing_tutorials_except(tm, "chaos_ghost_intro")
	_ok(not tm.is_group_completed("chaos_ghost"),
		"test fixture leaves the first Phoebe tutorial incomplete")

	var tavern := TAVERN_SCENE.instantiate()
	add_child(tavern)
	await get_tree().process_frame

	var bar := tavern.get_node("BarWorkspace") as BarWorkspace
	if bar == null or not bar.has_method("record_chaos_event") or not bar.has_method("try_trigger_chaos_event"):
		gm._dialogue_phase = old_dialogue_phase
		gm._is_dialogue_active = old_dialogue_active
		_restore_tutorial_state(tm, tutorial_backup)
		tavern.queue_free()
		await get_tree().process_frame
		return
	bar.set_process(false)

	var item := bar._spawn_desk_item_at(Vector2(560.0, 340.0), "ale")
	await get_tree().process_frame
	bar.call("record_chaos_event", "guest_wait", 2.0)
	var triggered: bool = bar.call("try_trigger_chaos_event")
	_ok(triggered, "high hidden chaos should start before testing dialogue exclusion")

	gm._dialogue_phase = "pre"
	gm._is_dialogue_active = false
	for _i in range(23):
		bar._process(0.1)
		await get_tree().process_frame

	_ok(not tm._is_active, "Phoebe tutorial does not start while Ryan pre-dialogue is pending")
	_ok(bar._chaos_ghost_waiting_for_tutorial,
		"Phoebe waits at the target instead of stealing while formal dialogue owns the overlay")
	_ok(bar._chaos_ghost_phase == "approach",
		"Phoebe remains in approach hold while waiting for the dialogue layer to clear")
	_ok(is_instance_valid(item) and not item.is_queued_for_deletion(),
		"target item remains on the table while Phoebe waits for dialogue to finish")

	gm._dialogue_phase = ""
	gm._is_dialogue_active = false
	bar._process(0.1)
	await get_tree().process_frame

	_ok(tm._is_active, "Phoebe tutorial starts after formal dialogue finishes")
	_ok(tm._current_sequence.size() > 0 and String(tm._current_sequence[0].get("group", "")) == "chaos_ghost",
		"deferred Phoebe tutorial still uses the chaos_ghost group")

	gm._dialogue_phase = old_dialogue_phase
	gm._is_dialogue_active = old_dialogue_active
	_restore_tutorial_state(tm, tutorial_backup)
	tavern.queue_free()
	await get_tree().process_frame


func _test_hidden_chaos_summons_ghost_from_screen_edge_and_steals_item() -> void:
	var tavern := TAVERN_SCENE.instantiate()
	add_child(tavern)
	await get_tree().process_frame

	var bar := tavern.get_node("BarWorkspace") as BarWorkspace
	_ok(bar != null, "Tavern should expose BarWorkspace")
	if bar == null:
		tavern.queue_free()
		await get_tree().process_frame
		return
	_ok(bar.has_method("record_chaos_event"), "BarWorkspace should accept hidden chaos events")
	_ok(bar.has_method("try_trigger_chaos_event"), "BarWorkspace should expose hidden chaos trigger attempt")
	_ok(bar.has_method("is_chaos_ghost_active"), "BarWorkspace should expose ghost active state")
	if not bar.has_method("record_chaos_event") or not bar.has_method("try_trigger_chaos_event"):
		tavern.queue_free()
		await get_tree().process_frame
		return

	var item := bar._spawn_desk_item_at(Vector2(560.0, 340.0), "ale")
	await get_tree().process_frame
	bar.call("record_chaos_event", "guest_wait", 2.0)
	var triggered: bool = bar.call("try_trigger_chaos_event")

	_ok(triggered, "high hidden chaos should start a ghost thief event when an item is stealable")
	_ok(item.has_meta("chaos_ghost_target"), "target item should be visibly warned before being stolen")
	var ghost := bar.get_node_or_null("ChaosGhost") as Node2D
	_ok(ghost != null and ghost.visible, "ghost should become visible when the thief event starts")
	var entry_position := Vector2.ZERO
	var entry_to_target_distance := 0.0
	if ghost != null:
		entry_position = ghost.global_position
		entry_to_target_distance = entry_position.distance_to(item.global_position)
		_ok(_is_offscreen(ghost.global_position), "ghost should enter from a random screen edge, not pop above the item")
		_ok(ghost.global_position.distance_to(item.global_position) > 180.0, "ghost should need to fly toward the target")

	for _i in range(24):
		bar._process(0.1)
		await get_tree().process_frame

	_ok(bar.call("is_chaos_ghost_active"), "ghost theft should stay readable for at least 2.4 seconds")
	_ok(is_instance_valid(item) and not item.is_queued_for_deletion(), "ghost should not finish stealing before the player has time to react")
	if ghost != null and is_instance_valid(ghost):
		_ok(ghost.global_position.distance_to(entry_position) > entry_to_target_distance + 20.0,
			"after grabbing, ghost should keep flying through the target instead of retreating to its entry edge")
		_ok(item.z_index > ghost.z_index,
			"carried item should render above the ghost while being stolen")
		_ok(_ghost_texture_path(ghost) == "res://assets/textures/characters/chaos_phoebe_chupi_ghost_grab.png",
			"ghost should switch to the grab expression while carrying an item")

	for _i in range(20):
		bar._process(0.1)
		await get_tree().process_frame

	_ok(not is_instance_valid(item) or item.is_queued_for_deletion(), "ghost should carry the stolen item offscreen instead of dropping it on the desk edge")
	_ok(not bar.call("is_chaos_ghost_active"), "ghost thief event should end after the escape")
	if ghost != null and is_instance_valid(ghost):
		_ok(not ghost.visible, "ghost should vanish after escaping offscreen")

	tavern.queue_free()
	await get_tree().process_frame


func _test_ghost_fades_in_place_when_player_snatches_target_back() -> void:
	var tavern := TAVERN_SCENE.instantiate()
	add_child(tavern)
	await get_tree().process_frame

	var bar := tavern.get_node("BarWorkspace") as BarWorkspace
	if bar == null or not bar.has_method("record_chaos_event") or not bar.has_method("try_trigger_chaos_event"):
		tavern.queue_free()
		await get_tree().process_frame
		return

	var item := bar._spawn_desk_item_at(Vector2(620.0, 340.0), "ale")
	await get_tree().process_frame
	bar.call("record_chaos_event", "guest_wait", 2.0)
	var triggered: bool = bar.call("try_trigger_chaos_event")
	var ghost := bar.get_node_or_null("ChaosGhost") as Node2D
	_ok(triggered and ghost != null and ghost.visible, "ghost should be visible before the player snatches the target back")
	if ghost == null:
		tavern.queue_free()
		await get_tree().process_frame
		return

	for _i in range(8):
		bar._process(0.1)
		await get_tree().process_frame

	var fade_origin := ghost.global_position
	item.is_held = true
	bar._process(0.1)
	await get_tree().process_frame
	var first_alpha := ghost.modulate.a
	_ok(ghost.visible, "ghost should remain visible when the player snatches the target back")
	_ok(first_alpha < 0.92 and first_alpha > 0.05, "ghost should start fading instead of disappearing instantly")
	_ok(ghost.global_position.distance_to(fade_origin) < 1.0, "ghost should fade in place after the target is snatched back")
	_ok(_ghost_texture_path(ghost) == "res://assets/textures/characters/chaos_phoebe_chupi_ghost_fade.png",
		"ghost should switch to the fade expression when the player interrupts theft")
	_ok(is_instance_valid(item) and not item.is_queued_for_deletion(), "snatched item should remain in the player's control")
	_ok(not bool(item.get_meta("chaos_ghost_stolen_once", false)), "snatched item should not be marked as stolen")

	for _i in range(3):
		bar._process(0.1)
		await get_tree().process_frame

	_ok(ghost.visible and ghost.modulate.a < first_alpha, "ghost should continue fading over multiple frames")
	_ok(ghost.global_position.distance_to(fade_origin) < 1.0, "ghost should not drift while fading out")

	for _i in range(10):
		bar._process(0.1)
		await get_tree().process_frame

	_ok(not bar.call("is_chaos_ghost_active"), "ghost fade-out should complete after the player saves the item")
	_ok(not ghost.visible, "ghost should be hidden after fade-out completes")

	item.is_held = false
	tavern.queue_free()
	await get_tree().process_frame


func _test_ghost_ignores_held_and_story_items() -> void:
	var tavern := TAVERN_SCENE.instantiate()
	add_child(tavern)
	await get_tree().process_frame

	var bar := tavern.get_node("BarWorkspace") as BarWorkspace
	if bar == null or not bar.has_method("record_chaos_event") or not bar.has_method("try_trigger_chaos_event"):
		tavern.queue_free()
		await get_tree().process_frame
		return

	var held_item := bar._spawn_desk_item_at(Vector2(520.0, 340.0), "ale")
	var story_item := bar._spawn_desk_item_at(Vector2(620.0, 340.0), "bloodied_contract")
	var free_item := bar._spawn_desk_item_at(Vector2(720.0, 340.0), "grape")
	await get_tree().process_frame
	held_item.is_held = true

	bar.call("record_chaos_event", "crowded_desk", 2.0)
	var triggered: bool = bar.call("try_trigger_chaos_event")

	_ok(triggered, "ghost should still trigger when at least one ordinary free item exists")
	_ok(not held_item.has_meta("chaos_ghost_target"), "ghost should not target the item currently held by the player")
	_ok(not story_item.has_meta("chaos_ghost_target"), "ghost should not target story-critical readable items")
	_ok(free_item.has_meta("chaos_ghost_target"), "ghost should target an ordinary unheld desk item")

	tavern.queue_free()
	await get_tree().process_frame


func _test_ghost_handles_target_freed_mid_approach() -> void:
	var tavern := TAVERN_SCENE.instantiate()
	add_child(tavern)
	await get_tree().process_frame

	var bar := tavern.get_node("BarWorkspace") as BarWorkspace
	if bar == null or not bar.has_method("record_chaos_event") or not bar.has_method("try_trigger_chaos_event"):
		tavern.queue_free()
		await get_tree().process_frame
		return

	var item := bar._spawn_desk_item_at(Vector2(560.0, 340.0), "ale")
	await get_tree().process_frame
	bar.call("record_chaos_event", "guest_wait", 2.0)
	var triggered: bool = bar.call("try_trigger_chaos_event")
	_ok(triggered, "ghost should start before its target is removed")

	item.free()
	for _i in range(10):
		bar._process(0.1)
		await get_tree().process_frame

	_ok(not bar.call("is_chaos_ghost_active"), "ghost should cancel cleanly when its target is freed mid-approach")

	tavern.queue_free()
	await get_tree().process_frame


func _test_ghost_can_steal_idle_cookware_and_dock_it_after_escape() -> void:
	var tm := get_node_or_null("/root/TutorialManager")
	var tutorial_backup := {}
	if tm != null:
		_reset_active_tutorial(tm)
		tutorial_backup = _capture_tutorial_state(tm)
		_complete_all_existing_tutorials(tm)

	var tavern := TAVERN_SCENE.instantiate()
	add_child(tavern)
	await get_tree().process_frame

	var bar := tavern.get_node("BarWorkspace") as BarWorkspace
	if bar == null or not bar.has_method("record_chaos_event") or not bar.has_method("try_trigger_chaos_event"):
		if tm != null:
			_restore_tutorial_state(tm, tutorial_backup)
		tavern.queue_free()
		await get_tree().process_frame
		return
	bar.set_process(false)

	var brewery := bar.get_node("World/Brewery") as RigidBody2D
	_ok(brewery != null, "Tavern should expose docked brewery cookware")
	if brewery == null:
		if tm != null:
			_restore_tutorial_state(tm, tutorial_backup)
		tavern.queue_free()
		await get_tree().process_frame
		return
	var dock_position := brewery.global_position

	bar.call("record_chaos_event", "guest_wait", 2.0)
	var triggered: bool = bar.call("try_trigger_chaos_event")

	_ok(triggered, "high hidden chaos should start a ghost thief event when only cookware is stealable")
	_ok(brewery.has_meta("chaos_ghost_target"), "idle cookware should be marked as the ghost target")

	for _i in range(46):
		bar._process(0.1)
		await get_tree().process_frame

	_ok(not bar.call("is_chaos_ghost_active"), "cookware ghost theft should end after the escape")
	_ok(is_instance_valid(brewery) and not brewery.is_queued_for_deletion(), "stolen cookware should not be deleted")
	_ok(brewery.global_position.distance_to(dock_position) < 1.0, "stolen cookware should dock back at its original position")
	_ok(not brewery.has_meta("chaos_ghost_target"), "cookware target marker should clear after docking")

	if tm != null:
		_restore_tutorial_state(tm, tutorial_backup)
	tavern.queue_free()
	await get_tree().process_frame


func _test_fast_releases_feed_hidden_chaos() -> void:
	var tavern := TAVERN_SCENE.instantiate()
	add_child(tavern)
	await get_tree().process_frame

	var bar := tavern.get_node("BarWorkspace") as BarWorkspace
	if bar == null or not bar.has_method("try_trigger_chaos_event"):
		tavern.queue_free()
		await get_tree().process_frame
		return

	for index in range(3):
		var item := bar._spawn_desk_item_at(Vector2(500.0 + float(index) * 80.0, 340.0), "ale")
		await get_tree().process_frame
		item.linear_velocity = Vector2(880.0, -120.0)
		item.angular_velocity = 0.0
		bar._on_drag_ended(item)

	var triggered: bool = bar.call("try_trigger_chaos_event")
	_ok(triggered, "repeated fast item releases should feed hidden chaos enough to summon the ghost")

	tavern.queue_free()
	await get_tree().process_frame


func _test_waiting_guest_feeds_hidden_chaos_without_visible_meter() -> void:
	var tavern := TAVERN_SCENE.instantiate()
	add_child(tavern)
	await get_tree().process_frame

	var bar := tavern.get_node("BarWorkspace") as BarWorkspace
	var gm = get_node("/root/GameManager")
	if bar == null or not bar.has_method("is_chaos_ghost_active"):
		tavern.queue_free()
		await get_tree().process_frame
		return

	var guest := GuestData.new()
	guest.order_key = "ale_beer"
	guest.patience = 12.0
	gm.guests.current_guest = guest
	gm.guests.has_guest = true
	var item := bar._spawn_desk_item_at(Vector2(560.0, 340.0), "ale")
	await get_tree().process_frame

	for _i in range(8):
		bar._process(1.0)

	_ok(bar.call("is_chaos_ghost_active"), "low guest patience should feed hidden chaos and summon the ghost")
	_ok(item.has_meta("chaos_ghost_target"), "waiting-pressure ghost should warn on a stealable item without a visible pressure bar")
	_ok(tavern.get_node_or_null("ChaosPressureBar") == null, "chaos director should not add a visible pressure bar")

	gm.guests.current_guest = null
	gm.guests.has_guest = false
	tavern.queue_free()
	await get_tree().process_frame


func _finish() -> void:
	print("[TEST-CHAOS-GHOST-THIEF] checks: %d failures: %d" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
