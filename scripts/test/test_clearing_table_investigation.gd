extends Node

const CLEARING_TABLE_SCENE := preload("res://scenes/ui/ClearingTableInvestigation.tscn")
const EXPECTED_DOCUMENTS := [
	"grey_payout_closure",
	"grey_renamed_escort",
	"grey_supply_stamp",
]
const EXPECTED_TARGET_PAPERS := [
	"clearing_payout_slip",
	"clearing_temp_name",
	"clearing_supply_contract",
]
const EXPECTED_NAME_PLATES := [
	"clearing_ryan_name",
	"clearing_toby_name",
	"clearing_mira_name",
]
const FUTURE_ROUND_TAG := "clearing_toby_name"
const NEXT_ROUND_FIRST_TAGS := [
	"clearing_toby_name",
	"clearing_mira_name",
]

var _checks := 0
var _failures := 0


func _ready() -> void:
	_test_locations_contract()
	await _test_round_prerequisites_gate_batches()
	await _test_rounds_grant_documents_once()
	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-CLEARING-TABLE] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-CLEARING-TABLE] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-CLEARING-TABLE] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _test_locations_contract() -> void:
	var map := DayMapSystem.new()
	_ok(map.load_data(), "locations data loads")
	map.set_document_owned("bloodied_contract", true)
	map.start_day(14)
	var clearing := _find_location(map.get_locations(), "clearing_table")
	_ok(not clearing.is_empty(), "Day14 exposes clearing table")
	var guild_counter := _find_location(map.get_locations(), "guild_counter")
	_ok(not guild_counter.is_empty(), "guild counter is visible for marker spacing contract")
	_ok(_location_pos(clearing).distance_to(_location_pos(guild_counter)) >= 96.0,
		"clearing table marker is separated from guild counter marker")
	_ok((clearing.get("documents", []) as Array).is_empty(), "clearing table does not auto-grant documents")
	var result: Dictionary = map.visit("clearing_table")
	_ok(result.get("success", false), "clearing table visit succeeds")
	_ok((result.get("documents", []) as Array).is_empty(), "clearing table visit returns no auto-grant documents")


func _test_rounds_grant_documents_once() -> void:
	var gm = get_node("/root/GameManager")
	var snapshot: Dictionary = gm._capture_save_state()
	gm._apply_save_state(gm._default_new_game_state())
	_prepare_all_clearing_context(gm)

	var scene := CLEARING_TABLE_SCENE.instantiate()
	add_child(scene)
	await get_tree().process_frame
	await get_tree().physics_frame

	_ok(scene.get_round_count() == 3, "clearing table has three rounds")
	_ok(scene.get_current_round_index() == 0, "clearing table starts on round one")
	_ok(not scene.is_current_round_item(FUTURE_ROUND_TAG), "future-round item is not accepted in round one")
	_assert_no_draggable_stamp_items(scene)
	_assert_current_round_labels(scene, ["名牌", "案源", "状态", "待盖"])
	_assert_nameplate_slot_lower(scene, String(EXPECTED_NAME_PLATES[0]))
	await _attempt_target_paper_before_evidence(scene, String(EXPECTED_TARGET_PAPERS[0]), String(EXPECTED_DOCUMENTS[0]))

	for i in range(EXPECTED_DOCUMENTS.size()):
		var doc_id := String(EXPECTED_DOCUMENTS[i])
		_ok(not gm.documents.owns_document(doc_id), doc_id + " is not owned before round completion")
		await _complete_current_round(scene, doc_id, String(EXPECTED_TARGET_PAPERS[i]))
		_ok(gm.documents.owns_document(doc_id), doc_id + " is granted by the physical scene")
		_ok(gm.inventory_sys.get_count(doc_id) == 1, doc_id + " enters story inventory once")
		_ok(not gm.grant_investigation_document(doc_id), doc_id + " grant is idempotent after scene collection")
		_ok(gm.inventory_sys.get_count(doc_id) == 1, doc_id + " inventory count stays idempotent")
		var hint_text := _label_text(scene, "UI/HintLabel")
		_ok(not hint_text.contains(doc_id), doc_id + " completion hint does not expose internal document id")
		if i < NEXT_ROUND_FIRST_TAGS.size():
			var next_tag := String(NEXT_ROUND_FIRST_TAGS[i])
			_ok(scene.get_current_round_index() == i,
				"completed round stays visible until the player advances after " + doc_id)
			_ok(_find_item(scene, next_tag) == null,
				"next batch is not spawned before advancing after " + doc_id)
			await _click_to_advance_round(scene)
			_ok(scene.get_current_round_index() == i + 1,
				"click advances to the next clearing batch after " + doc_id)
			_ok(_find_item(scene, next_tag) != null,
				"next batch appears after click advancing " + doc_id)
			_assert_no_draggable_stamp_items(scene)
			_assert_nameplate_slot_lower(scene, String(EXPECTED_NAME_PLATES[i + 1]))
			if i == 0:
				_assert_current_round_labels(scene, ["名牌", "案源", "诱因", "待盖"])
			elif i == 1:
				_assert_current_round_labels(scene, ["名牌", "入账", "待盖"])
		else:
			_ok(scene.get_current_round_index() == EXPECTED_DOCUMENTS.size(),
				"final round index advances to complete state after " + doc_id)

	_ok(scene.is_complete(), "clearing table reports complete after all rounds")
	_ok(scene._has_deep_progress(), "complete clearing table counts as deep progress")

	scene.queue_free()
	await get_tree().process_frame
	gm._apply_save_state(snapshot)


func _test_round_prerequisites_gate_batches() -> void:
	var gm = get_node("/root/GameManager")
	var snapshot: Dictionary = gm._capture_save_state()
	gm._apply_save_state(gm._default_new_game_state())

	var scene := await _spawn_clearing_scene()
	_ok(scene.current_round_item_tags().is_empty(),
		"clearing table waits for payout-office context before spawning Ryan batch")
	_ok(_label_text(scene, "UI/HintLabel").contains("赔付登记处"),
		"locked clearing table points the player back to the payout office")
	await _free_clearing_scene(scene)

	_grant_documents(gm, ["grey_ryan_case_number", "grey_old_payout_register", "grey_missing_page"])
	scene = await _spawn_clearing_scene()
	_ok(scene.get_current_round_index() == 0, "payout context unlocks the Ryan clearing batch")
	_ok(scene.is_current_round_item("clearing_ryan_name"),
		"Ryan batch becomes playable after payout-office context is known")
	await _free_clearing_scene(scene)

	gm.grant_investigation_document("grey_payout_closure")
	scene = await _spawn_clearing_scene()
	_ok(scene.current_round_item_tags().is_empty(),
		"clearing table does not spawn Toby batch before the Blacktooth ledger is checked")
	_ok(_label_text(scene, "UI/HintLabel").contains("黑齿转运账"),
		"Toby locked batch points the player to the Blacktooth ledger")
	await _free_clearing_scene(scene)

	_grant_documents(gm, ["grey_blacktooth_batch", "grey_closure_method"])
	scene = await _spawn_clearing_scene()
	_ok(scene.get_current_round_index() == 1, "Blacktooth context unlocks the Toby clearing batch")
	_ok(scene.is_current_round_item("clearing_toby_name"),
		"Toby batch becomes playable after Blacktooth context is known")
	await _free_clearing_scene(scene)

	gm.grant_investigation_document("grey_renamed_escort")
	scene = await _spawn_clearing_scene()
	_ok(scene.current_round_item_tags().is_empty(),
		"clearing table does not spawn Mira batch before the old supply copy is checked")
	_ok(_label_text(scene, "UI/HintLabel").contains("米拉旧供应副本"),
		"Mira locked batch points the player to the old supply copy")
	await _free_clearing_scene(scene)

	gm.day_map.mark_completed("mira_supply_copy")
	scene = await _spawn_clearing_scene()
	_ok(scene.get_current_round_index() == 2, "Mira supply copy context unlocks the Mira clearing batch")
	_ok(scene.is_current_round_item("clearing_mira_name"),
		"Mira batch becomes playable after the old supply copy is checked")
	await _free_clearing_scene(scene)

	gm._apply_save_state(snapshot)


func _complete_current_round(scene: Node, document_id: String, target_tag: String) -> void:
	for tag in scene.current_round_item_tags():
		var item := _find_item(scene, String(tag))
		_ok(item != null, "current round item exists: " + String(tag))
		if item == null:
			continue
		if String(tag) == target_tag:
			if not _station_targets(scene, target_tag):
				_ok(scene._try_pickup(item.global_position), "current round item can be picked up: " + String(tag))
				scene._drag_ctrl.end_drag()
				item.global_position = scene.slot_position_for_item(String(tag))
				scene._investigation_physics(0.016)
				await get_tree().process_frame
			_ok(scene.has_method("is_stamp_target_item"), "clearing table exposes target paper classification")
			_ok(scene.call("is_stamp_target_item", target_tag), target_tag + " is the stamp target paper")
			_assert_target_paper_under_station(scene, target_tag)
			_ok(not get_node("/root/GameManager").documents.owns_document(document_id),
				document_id + " is not granted by merely placing the target paper")
			_assert_stamp_station(scene, target_tag, true)
			await _assert_stamp_station_drag_feedback(scene, target_tag)
			await _release_station_without_enough_pressure(scene, document_id)
			await _press_station_down(scene)
			_assert_target_paper_has_no_socket_imprint(scene, target_tag)
			await _assert_stamped_output(scene, target_tag)
		else:
			_ok(scene._try_pickup(item.global_position), "current round item can be picked up: " + String(tag))
			scene._drag_ctrl.end_drag()
			item.global_position = scene.slot_position_for_item(String(tag))
			scene._investigation_physics(0.016)
			await get_tree().process_frame


func _attempt_target_paper_before_evidence(scene: Node, item_tag: String, document_id: String) -> void:
	var item := _find_item(scene, item_tag)
	_ok(item != null, item_tag + " exists for early target-paper attempt")
	if item == null:
		return
	_ok(scene._try_pickup(item.global_position), item_tag + " can be picked up before evidence is placed")
	scene._drag_ctrl.end_drag()
	item.global_position = scene.slot_position_for_item(item_tag)
	scene._investigation_physics(0.016)
	await get_tree().process_frame
	_assert_target_paper_under_station(scene, item_tag)
	_ok(not get_node("/root/GameManager").documents.owns_document(document_id),
		document_id + " is not granted by placing the target paper before the evidence")
	_assert_stamp_station(scene, item_tag, false)
	await _press_station_down(scene)
	_assert_no_stamped_output(scene, item_tag)
	_ok(not get_node("/root/GameManager").documents.owns_document(document_id),
		document_id + " is not granted by pressing the station before evidence is complete")


func _assert_stamp_station(scene: Node, item_tag: String, expected_armed: bool) -> void:
	var station := _stamp_station(scene)
	_ok(station != null, "clearing table creates a StampPressStation component")
	if station == null:
		return
	_ok(station.has_method("target_tag"), "StampPressStation exposes current target tag")
	_ok(station.call("target_tag") == item_tag, "StampPressStation targets " + item_tag)
	_ok(station.has_method("is_armed"), "StampPressStation exposes armed state")
	_ok(bool(station.call("is_armed")) == expected_armed,
		item_tag + " station armed state matches evidence readiness")
	_ok(station.has_method("socket_global_position"), "StampPressStation exposes the paper socket position")
	_ok(station.get_node_or_null("Base") is Sprite2D, "StampPressStation has authored base sprite")
	_ok(station.get_node_or_null("Handle") is Sprite2D, "StampPressStation has authored handle sprite")
	_ok(station.get_node_or_null("Head") is Sprite2D, "StampPressStation has authored head sprite")
	_ok(station.get_node_or_null("SocketHighlight") is Sprite2D, "StampPressStation has authored socket highlight sprite")


func _assert_target_paper_under_station(scene: Node, item_tag: String) -> void:
	var item := _find_item(scene, item_tag)
	var station := _stamp_station(scene)
	_ok(item != null, item_tag + " target paper still exists after slot placement")
	_ok(station != null, "StampPressStation exists for target-paper placement")
	if item == null or station == null:
		return
	_ok(station.has_method("socket_global_position"), "StampPressStation exposes socket_global_position")
	if not station.has_method("socket_global_position"):
		return
	var socket_pos: Vector2 = station.call("socket_global_position")
	_ok(item.global_position.distance_to(socket_pos) <= 2.0,
		item_tag + " locks under the stamp station socket instead of the old slot")


func _assert_target_paper_has_no_socket_imprint(scene: Node, item_tag: String) -> void:
	var item := _find_item(scene, item_tag)
	_ok(item != null, item_tag + " target paper still exists for duplicate-imprint check")
	if item == null:
		return
	_ok(item.get_node_or_null("StampImprint") == null,
		item_tag + " keeps the grey imprint only on the ejected paper, not under the machine")


func _assert_nameplate_slot_lower(scene: Node, item_tag: String) -> void:
	var slot_pos: Vector2 = scene.slot_position_for_item(item_tag)
	_ok(slot_pos.y >= 336.0,
		item_tag + " nameplate slot is lowered on the table surface")


func _assert_no_stamped_output(scene: Node, item_tag: String) -> void:
	var world := scene.get_node_or_null("World")
	_ok(world != null, "World exists for stamped-output absence check")
	if world == null:
		return
	_ok(world.get_node_or_null("StampedOutput_" + item_tag) == null,
		item_tag + " does not eject output before the evidence is complete")


func _assert_stamped_output(scene: Node, item_tag: String) -> void:
	await get_tree().create_timer(0.24).timeout
	var world := scene.get_node_or_null("World")
	_ok(world != null, "World exists for stamped-output check")
	if world == null:
		return
	var output := world.get_node_or_null("StampedOutput_" + item_tag) as Node2D
	_ok(output != null and output.visible, item_tag + " ejects a visible stamped paper output")
	if output == null:
		return
	_ok(scene.has_method("stamp_output_position"), "clearing table exposes stamped paper output position")
	if scene.has_method("stamp_output_position"):
		var output_pos: Vector2 = scene.call("stamp_output_position")
		_ok(output.global_position.distance_to(output_pos) <= 2.0,
			item_tag + " stamped paper finishes at the output slot")
	var paper := output.get_node_or_null("Paper") as Sprite2D
	var imprint := output.get_node_or_null("Imprint") as Sprite2D
	_ok(paper != null and paper.texture != null, item_tag + " output keeps the target paper texture")
	_ok(imprint != null and imprint.texture != null, item_tag + " output shows a visible grey-contract imprint")


func _assert_stamp_station_drag_feedback(scene: Node, item_tag: String) -> void:
	await get_tree().process_frame
	var station := _stamp_station(scene)
	_ok(station != null, "StampPressStation exists for press feedback test")
	if station == null:
		return
	_ok(station.has_method("press_progress"), "StampPressStation exposes continuous press progress")
	_ok(station.has_method("handle_grab_global_position"), "StampPressStation exposes handle grab position")
	_ok(station.has_method("handle_pressed_global_position"), "StampPressStation exposes pressed handle position")
	if not station.has_method("press_progress"):
		return
	var start: Vector2 = station.call("handle_grab_global_position")
	var down: Vector2 = station.call("handle_pressed_global_position")
	var event_down := InputEventMouseButton.new()
	event_down.button_index = MOUSE_BUTTON_LEFT
	event_down.pressed = true
	event_down.position = start
	event_down.global_position = start
	station.call("_input", event_down)
	var motion := InputEventMouseMotion.new()
	motion.position = start.lerp(down, 0.55)
	motion.global_position = motion.position
	station.call("_input", motion)
	scene._investigation_physics(0.016)
	await get_tree().physics_frame
	var progress := float(station.call("press_progress"))
	_ok(progress > 0.30 and progress < 0.90,
		item_tag + " reports partial press progress while the station handle is dragged")
	var event_up := InputEventMouseButton.new()
	event_up.button_index = MOUSE_BUTTON_LEFT
	event_up.pressed = false
	event_up.position = motion.position
	event_up.global_position = motion.position
	station.call("_input", event_up)


func _release_station_without_enough_pressure(scene: Node, document_id: String) -> void:
	var station := _stamp_station(scene)
	_ok(station != null, "StampPressStation exists for shallow press")
	if station == null:
		return
	var start: Vector2 = station.call("handle_grab_global_position")
	var down: Vector2 = station.call("handle_pressed_global_position")
	var event_down := InputEventMouseButton.new()
	event_down.button_index = MOUSE_BUTTON_LEFT
	event_down.pressed = true
	event_down.position = start
	event_down.global_position = start
	station.call("_input", event_down)
	var motion := InputEventMouseMotion.new()
	motion.position = start.lerp(down, 0.45)
	motion.global_position = motion.position
	station.call("_input", motion)
	var event_up := InputEventMouseButton.new()
	event_up.button_index = MOUSE_BUTTON_LEFT
	event_up.pressed = false
	event_up.position = motion.position
	event_up.global_position = motion.position
	station.call("_input", event_up)
	scene._investigation_physics(0.016)
	await get_tree().process_frame
	_ok(not get_node("/root/GameManager").documents.owns_document(document_id),
		document_id + " is not granted by a shallow station press")
	_ok(float(station.call("press_progress")) == 0.0, "StampPressStation returns to rest after shallow release")


func _press_station_down(scene: Node) -> void:
	var station := _stamp_station(scene)
	_ok(station != null, "StampPressStation exists for manual press")
	if station == null:
		return
	if not station.has_method("handle_grab_global_position") or not station.has_method("handle_pressed_global_position"):
		return
	var start: Vector2 = station.call("handle_grab_global_position")
	var down: Vector2 = station.call("handle_pressed_global_position")
	var event_down := InputEventMouseButton.new()
	event_down.button_index = MOUSE_BUTTON_LEFT
	event_down.pressed = true
	event_down.position = start
	event_down.global_position = start
	station.call("_input", event_down)
	var motion := InputEventMouseMotion.new()
	motion.position = down
	motion.global_position = down
	station.call("_input", motion)
	var event_up := InputEventMouseButton.new()
	event_up.button_index = MOUSE_BUTTON_LEFT
	event_up.pressed = false
	event_up.position = down
	event_up.global_position = down
	station.call("_input", event_up)
	scene._investigation_physics(0.016)
	await get_tree().process_frame


func _click_to_advance_round(scene: Node) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = Vector2(640, 360)
	if scene.has_method("_input"):
		scene.call("_input", event)
	await get_tree().process_frame


func _find_item(scene: Node, item_tag: String) -> MineItem:
	var world := scene.get_node_or_null("World")
	if world == null:
		return null
	for child in world.get_children():
		if child is MineItem and child.item_tag == item_tag:
			return child
	return null


func _stamp_station(scene: Node) -> Node:
	return scene.get_node_or_null("World/StampPressStation")


func _station_targets(scene: Node, item_tag: String) -> bool:
	var station := _stamp_station(scene)
	if station == null or not station.has_method("target_tag"):
		return false
	return String(station.call("target_tag")) == item_tag


func _assert_no_draggable_stamp_items(scene: Node) -> void:
	for tag in scene.current_round_item_tags():
		_ok(not String(tag).ends_with("_stamp"),
			"current round does not spawn draggable stamp item: " + String(tag))
	var world := scene.get_node_or_null("World")
	_ok(world != null, "World exists for stamp item scan")
	if world == null:
		return
	for child in world.get_children():
		if child is MineItem:
			_ok(not (child as MineItem).item_tag.ends_with("_stamp"),
				"World contains no draggable stamp MineItem: " + (child as MineItem).item_tag)


func _assert_current_round_labels(scene: Node, expected_slot_labels: Array) -> void:
	var card_label_texts := []
	for tag in scene.current_round_item_tags():
		var item := _find_item(scene, String(tag))
		_ok(item != null, "current round item exists for label: " + String(tag))
		if item == null:
			continue
		var label := item.get_node_or_null("ClearingCardLabel") as Label
		_ok(label != null, String(tag) + " has a visible Godot label")
		if label != null:
			_ok(label.visible, String(tag) + " card label is visible")
			_ok(label.text.strip_edges() != "", String(tag) + " card label has text")
			card_label_texts.append(label.text)
	var slot_labels := scene.get_node_or_null("UI/SlotLabels")
	_ok(slot_labels != null, "clearing table exposes slot labels under UI/SlotLabels")
	if slot_labels == null:
		return
	var texts := []
	for child in slot_labels.get_children():
		if child is Label and child.visible:
			var slot_text := (child as Label).text
			texts.append(slot_text)
			_ok(not card_label_texts.has(slot_text),
				"slot labels use category clues instead of exact card labels")
	for expected in expected_slot_labels:
		_ok(texts.has(String(expected)), "slot labels include " + String(expected))


func _label_text(scene: Node, path: String) -> String:
	var label := scene.get_node_or_null(path) as Label
	_ok(label != null, path + " exists")
	return label.text if label != null else ""


func _location_pos(location: Dictionary) -> Vector2:
	var pos: Array = location.get("pos", [0, 0])
	return Vector2(float(pos[0]), float(pos[1]))


func _find_location(locations: Array, location_id: String) -> Dictionary:
	for loc in locations:
		if String(loc.get("id", "")) == location_id:
			return loc
	return {}


func _spawn_clearing_scene() -> Node:
	var scene := CLEARING_TABLE_SCENE.instantiate()
	add_child(scene)
	await get_tree().process_frame
	await get_tree().physics_frame
	return scene


func _free_clearing_scene(scene: Node) -> void:
	scene.queue_free()
	await get_tree().process_frame


func _grant_documents(gm: Node, document_ids: Array) -> void:
	for document_id in document_ids:
		gm.grant_investigation_document(String(document_id))


func _prepare_all_clearing_context(gm: Node) -> void:
	_grant_documents(gm, [
		"grey_ryan_case_number",
		"grey_old_payout_register",
		"grey_missing_page",
		"grey_blacktooth_batch",
		"grey_closure_method",
	])
	gm.day_map.mark_completed("mira_supply_copy")
