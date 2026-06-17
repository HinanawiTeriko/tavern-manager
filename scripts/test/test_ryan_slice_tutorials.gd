extends Node

var _checks := 0
var _failures := 0


func _ready() -> void:
	var file := FileAccess.open("res://data/tutorial_steps.json", FileAccess.READ)
	_ok(file != null, "tutorial data exists")
	if file == null:
		_finish()
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	_ok(parsed is Dictionary, "tutorial data parses")
	if not parsed is Dictionary:
		_finish()
		return
	var text := JSON.stringify(parsed)
	for stale in ["[+]", "[-]", "分配体力", "合成台", "混合区", "结果槽", "撒粉区"]:
		_ok(not text.contains(stale), "stale tutorial term removed: " + stale)
	_test_daymap_tutorial_matches_current_continue_flow(parsed)
	_test_tutorial_data_declares_narrator_lines(parsed)
	_test_tutorial_highlight_keys_match_trigger_rects(parsed)
	_test_serve_tutorial_matches_table_order_groove(parsed)
	_test_ryan_arrival_starts_serve_tutorial_after_pre_dialogue()
	for required in ["访问", "酒桶", "右键", "整理桌面", "Tab", "E"]:
		_ok(text.contains(required), "Ryan slice tutorial mentions: " + required)
	_finish()


func _test_daymap_tutorial_matches_current_continue_flow(parsed: Dictionary) -> void:
	var gather_steps: Array = parsed.get("gather", [])
	var ids := []
	var text := JSON.stringify(gather_steps)
	for step in gather_steps:
		ids.append(String(step.get("id", "")))
		_ok(String(step.get("highlight_node", "")) != "GoButton",
			"daymap tutorial must not point to removed GoButton")
		_ok(String(step.get("title", "")) != "进入夜晚",
			"daymap tutorial must not show removed 进入夜晚 step")
	_ok(not ids.has("gather_go"), "daymap tutorial removes stale gather_go step")
	_ok(not text.contains("继续 → 夜晚"), "daymap tutorial must not mention removed continue-to-night flow")
	_ok(text.contains("你的酒馆") and text.contains("开门营业"),
		"daymap tutorial explains the current tavern marker night-entry flow")


func _test_tutorial_data_declares_narrator_lines(parsed: Dictionary) -> void:
	for group_key in parsed.keys():
		for step in parsed.get(group_key, []):
			var step_id := String(step.get("id", ""))
			var lines: Array = step.get("narrator_lines", [])
			_ok(not lines.is_empty(), "tutorial step has narrator lines: " + step_id)
			for line in lines:
				_ok(String(line.get("text", "")) != "",
					"tutorial narrator line has text: " + step_id)
				_ok(["neutral", "smirk", "concerned", "surprised"].has(String(line.get("expression", ""))),
					"tutorial narrator line uses a shipped expression: " + step_id)


func _test_tutorial_highlight_keys_match_trigger_rects(parsed: Dictionary) -> void:
	var craft_steps: Array = parsed.get("craft", [])
	var craft_keys := {}
	for step in craft_steps:
		craft_keys[String(step.get("id", ""))] = String(step.get("highlight_node", ""))
	_ok(craft_keys.get("craft_intro", "") == "CraftBarrel",
		"craft intro highlights the actual barrel work area")
	_ok(craft_keys.get("craft_drag", "") == "ShortcutBar",
		"craft drag highlights the shortcut bar")
	_ok(craft_keys.get("craft_recovery", "") == "RecoveryContainer",
		"craft recovery uses its own recovery highlight instead of the intro barrel rect")

	var seasoning_steps: Array = parsed.get("seasoning", [])
	_ok(not seasoning_steps.is_empty(), "seasoning tutorial step exists")
	if not seasoning_steps.is_empty():
		_ok(String(seasoning_steps[0].get("highlight_node", "")) == "SeasoningZone",
			"seasoning tutorial highlights the seasoning zone trigger rect")


func _test_serve_tutorial_matches_table_order_groove(parsed: Dictionary) -> void:
	var serve_steps: Array = parsed.get("serve", [])
	_ok(not serve_steps.is_empty(), "serve tutorial step exists")
	if serve_steps.is_empty():
		return
	var serve_intro: Dictionary = serve_steps[0]
	var text := String(serve_intro.get("description", ""))
	for line in serve_intro.get("narrator_lines", []):
		text += "\n" + String(line.get("text", ""))
	_ok(not text.contains("头顶"), "serve tutorial no longer says orders appear over the customer's head")
	_ok(text.contains("订单槽"), "serve tutorial points players to the current table order groove")


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-RYAN-TUTORIAL] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-RYAN-TUTORIAL] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-RYAN-TUTORIAL] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _test_ryan_arrival_starts_serve_tutorial_after_pre_dialogue() -> void:
	var gm = get_node_or_null("/root/GameManager")
	var tm = get_node_or_null("/root/TutorialManager")
	_ok(gm != null and tm != null, "GameManager and TutorialManager are available for Ryan serve tutorial timing")
	if gm == null or tm == null:
		return

	var old_view = gm._tavern_view
	var old_guest = gm.guests.current_guest
	var old_has_guest: bool = gm.guests.has_guest
	var old_dialogue_phase: String = gm._dialogue_phase
	var old_dialogue_active: bool = gm._is_dialogue_active
	var old_first_guest_arrived: bool = tm.first_guest_arrived
	var old_completed_steps: Array = tm._completed_steps.duplicate()
	var old_active: bool = tm._is_active
	var old_sequence: Array = tm._current_sequence.duplicate(true)
	var old_step: int = tm._current_step
	var old_overlay = tm._overlay

	tm._remove_overlay()
	tm._is_active = false
	tm._current_sequence.clear()
	tm._current_step = -1
	tm.first_guest_arrived = false
	tm._completed_steps.erase("serve_intro")
	var fake_overlay := Node.new()
	add_child(fake_overlay)
	tm._overlay = fake_overlay

	var fake_view := ServeTutorialTestView.new()
	add_child(fake_view)
	gm._tavern_view = fake_view

	var guest := GuestData.new()
	guest.guest_name = "ryan"
	guest.type = GuestData.GuestType.IMPORTANT
	guest.order_key = "ale_beer"
	guest.npc_id = "ryan"
	guest.has_dialogue = true
	gm.guests.current_guest = guest
	gm.guests.has_guest = true

	var gm_source := FileAccess.get_file_as_string("res://scripts/game_manager.gd")
	_ok(gm_source.contains("_queue_first_guest_serve_tutorial(guest.has_dialogue)"),
		"guest arrival routes Ryan through the first-guest serve tutorial trigger")

	gm._queue_first_guest_serve_tutorial(true)
	_ok(tm.first_guest_arrived, "Ryan arrival marks the first service guest instead of waiting for a regular customer")
	_ok(not tm._is_active, "Ryan pre-dialogue keeps serve tutorial from overlapping the dialogue layer")

	gm._dialogue_phase = "pre"
	gm._on_dialogue_ended()
	_ok(tm._is_active, "serve tutorial starts as soon as Ryan's pre-service dialogue ends")
	_ok(not tm._current_sequence.is_empty() and String(tm._current_sequence[0].get("group", "")) == "serve",
		"Ryan-triggered tutorial uses the serve tutorial group")

	tm._remove_overlay()
	tm._is_active = old_active
	tm._current_sequence = old_sequence
	tm._current_step = old_step
	tm._completed_steps = old_completed_steps
	tm.first_guest_arrived = old_first_guest_arrived
	tm._overlay = old_overlay
	tm._save_state()
	gm._tavern_view = old_view
	gm.guests.current_guest = old_guest
	gm.guests.has_guest = old_has_guest
	gm._dialogue_phase = old_dialogue_phase
	gm._is_dialogue_active = old_dialogue_active
	if is_instance_valid(fake_view):
		remove_child(fake_view)
		fake_view.free()
	if is_instance_valid(fake_overlay):
		remove_child(fake_overlay)
		fake_overlay.free()


class ServeTutorialTestView:
	extends Node

	var daily_menu_confirmed := true
	var shown_customers := []
	var dialogue_mode_calls := []

	func show_customer(display_name: String, item_name: String, portrait_id: String, order_key: String = "") -> void:
		shown_customers.append({
			"display_name": display_name,
			"item_name": item_name,
			"portrait_id": portrait_id,
			"order_key": order_key,
		})

	func set_dialogue_mode(active: bool) -> void:
		dialogue_mode_calls.append(active)

	func set_close_enabled(_enabled: bool) -> void:
		pass

	func get_tutorial_highlight_rects(group_key: String) -> Dictionary:
		if group_key == "serve":
			return {"CustomerNode": [440, 80, 400, 360]}
		return {}
