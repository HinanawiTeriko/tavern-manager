extends Node

const TAVERN_SCENE := preload("res://scenes/ui/Tavern.tscn")

var _checks := 0
var _failures := 0


func _ready() -> void:
	await _test_hidden_chaos_summons_ghost_from_screen_edge_and_steals_item()
	await _test_ghost_ignores_held_and_story_items()
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
	if ghost != null:
		_ok(_is_offscreen(ghost.global_position), "ghost should enter from a random screen edge, not pop above the item")
		_ok(ghost.global_position.distance_to(item.global_position) > 180.0, "ghost should need to fly toward the target")

	for _i in range(20):
		bar._process(0.1)
		await get_tree().process_frame

	_ok(not is_instance_valid(item) or item.is_queued_for_deletion(), "ghost should carry the stolen item offscreen instead of dropping it on the desk edge")
	_ok(not bar.call("is_chaos_ghost_active"), "ghost thief event should end after the escape")
	if ghost != null and is_instance_valid(ghost):
		_ok(not ghost.visible, "ghost should vanish after escaping offscreen")

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
