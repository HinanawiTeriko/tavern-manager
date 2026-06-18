extends Node

var _checks := 0
var _failures := 0


class HeartFeedbackView extends Node:
	var stage_lines := []
	var dialogue_mode_calls := []
	var hide_calls := 0

	func show_stage_caption(text, color = Color.WHITE) -> void:
		stage_lines.append({"text": String(text), "color": color})

	func set_dialogue_mode(active: bool) -> void:
		dialogue_mode_calls.append(active)

	func hide_customer() -> void:
		hide_calls += 1


func _ready() -> void:
	_test_three_day_boundary()
	_test_state_roundtrip()
	_test_pre_toby_window_can_reach_fixer_price()
	_test_toby_day6_identity_is_masked_in_tavern()
	_test_toby_name_reveals_after_identity_deduction()
	_test_guest_budget()
	_test_game_manager_owns_slice()
	_test_pending_important_guest_blocks_early_close()
	_test_important_arrival_timing_rules()
	await _test_day2_important_npc_waits_for_one_normal_guest()
	_test_ryan_day2_dialogue_matches_single_order()
	_test_all_important_post_dialogues_have_heart_feedback_copy()
	_test_post_dialogue_shows_heart_feedback()
	_test_day3_fate_reveal_is_not_a_formal_npc_scene()
	await _test_day3_fate_reveal_spawns_when_menu_already_confirmed()
	_test_day1_settlement_warns_about_day2_fate_ledger_entry()
	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-RYAN-SLICE] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-RYAN-SLICE] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-RYAN-SLICE] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _test_three_day_boundary() -> void:
	var slice := RyanSliceSystem.new()
	# [走查脚手架] Day20 保留 Evelyn 灰账线高潮；正式流程继续到 Day30。
	_ok(slice.last_day() == 30, "slice ends on Day 30")
	_ok(slice.normal_order_limit(1) == 2, "Day 1 has two normal orders")
	_ok(slice.normal_order_limit(2) == 2, "Day 2 has two normal orders")
	_ok(slice.normal_order_limit(3) == 2, "Day 3 has two normal orders")
	_ok(slice.normal_order_limit(4) == 3, "Day 4 opens the mid-slice three-normal-order rhythm")
	_ok(slice.normal_order_limit(12) == 3, "Day 12 keeps the three-normal-order Mira climax rhythm")
	_ok(slice.normal_order_limit(20) == 3, "Day 20 keeps the three-normal-order Evelyn climax rhythm")
	_ok(slice.normal_order_limit(30) == 3, "Day 30 keeps the default three-normal-order rhythm")
	_ok(slice.day_start_ledger_entries(2).has("第三日。莱恩。\n北矿道。\n未归。"), "Day 2 adds Ryan prediction")
	_ok(slice.day_start_ledger_entries(13).has("第二十日。伊芙琳。\n灰账清算。\n封存。"), "Day 13 adds Evelyn prediction")
	_ok(not slice.should_finish_after_day(2), "Day 2 continues")
	_ok(not slice.should_finish_after_day(12), "Day 12 continues into Evelyn line")
	_ok(not slice.should_finish_after_day(20), "Day 20 continues into the final ten-day management stretch")
	_ok(slice.should_finish_after_day(30), "Day 30 finishes the slice")


func _test_state_roundtrip() -> void:
	var slice := RyanSliceSystem.new()
	slice.record_order_success()
	slice.record_order_success()
	slice.complete_day(1)
	var restored := RyanSliceSystem.new()
	restored.restore_state(slice.capture_state())
	_ok(restored.total_orders_success == 2, "total successful orders restore")
	_ok(restored.is_day_complete(1), "completed day restores")


func _test_pre_toby_window_can_reach_fixer_price() -> void:
	var slice := RyanSliceSystem.new()
	const FIXER_PRICE := 40
	const NORMAL_ORDER_NET_FLOOR := 2
	const IMPORTANT_ORDER_NET := {
		1: 3, # ale_beer 5 - ale 2
		2: 1, # meat_cooked 4 - meat_raw 3
		3: 1, # meat_cooked 4 - meat_raw 3
		4: 3, # wine 5 - grape 2
		6: 4, # herb_broth 8 - herb 2 - ale 2
	}
	var projected_gold := 0
	for day in range(1, 7):
		projected_gold += slice.normal_order_limit(day) * NORMAL_ORDER_NET_FLOOR
		projected_gold += int(IMPORTANT_ORDER_NET.get(day, 0))
	_ok(projected_gold >= FIXER_PRICE,
		"conservative Day1-6 net income can reach Toby fixer price")


func _test_toby_day6_identity_is_masked_in_tavern() -> void:
	var slice := RyanSliceSystem.new()
	_ok(slice.important_display_name(6, "toby", "托比") == "瘦小少年",
		"Day 6 tavern nameplate describes Toby by appearance before any dialogue clue")
	_ok(slice.important_display_name(6, "mira", "米拉") == "米拉",
		"Day 6 display-name masking only applies to Toby")
	_ok(slice.important_display_name(13, "evelyn", "伊芙琳") == "伊芙琳",
		"Evelyn uses her own name when she opens the grey-ledger case")
	_ok(slice.important_portrait_id(13, "evelyn", "evelyn") == "grey_ledger_lady",
		"Evelyn tavern encounter reuses the approved Grey Ledger Lady portrait pipeline")
	var pre_dialogue := FileAccess.get_file_as_string("res://dialogue/toby_day6.pre.dialogue")
	var post_dialogue := FileAccess.get_file_as_string("res://dialogue/toby_day6.post.dialogue")
	_ok(pre_dialogue.contains("瘦小少年:"),
		"Day 6 Toby pre-service dialogue uses the same appearance-only speaker label")
	_ok(post_dialogue.contains("瘦小少年:"),
		"Day 6 Toby post-service dialogue uses the same appearance-only speaker label")
	_ok(not pre_dialogue.contains("托比:") and not post_dialogue.contains("托比:"),
		"Day 6 Toby dialogue does not reveal the real name in the speaker label")
	_ok(not pre_dialogue.contains("后巷少年:") and not post_dialogue.contains("后巷少年:"),
		"Day 6 Toby speaker label does not reveal the later back-alley clue")


func _test_toby_name_reveals_after_identity_deduction() -> void:
	var gm = get_node("/root/GameManager")
	_ok(gm.has_method("_important_guest_display_name"),
		"GameManager centralizes important NPC display names before TavernView sees them")
	if not gm.has_method("_important_guest_display_name"):
		return
	var original_day: int = gm.economy.current_day
	var original_identity = gm.narrative.get_var("toby_identity_known")
	gm.economy.current_day = 6
	gm.narrative.set_var("toby_identity_known", false)
	_ok(gm.call("_important_guest_display_name", "toby", "托比") == "瘦小少年",
		"Toby stays unidentified in the tavern before the identity deduction")
	gm.narrative.set_var("toby_identity_known", true)
	_ok(gm.call("_important_guest_display_name", "toby", "托比") == "托比",
		"Toby's real name can be shown after the identity deduction")
	gm.narrative.set_var("toby_identity_known", original_identity)
	gm.economy.current_day = original_day


func _test_guest_budget() -> void:
	var guests := GuestSystem.new(func(): return ["ale_beer"])
	var completed := [0]
	guests.normal_orders_completed.connect(func(): completed[0] += 1)
	guests.configure_night(2)
	guests._spawn_normal()
	_ok(guests.has_guest, "first normal order spawns")
	guests.clear_guest()
	guests._spawn_normal()
	_ok(guests.has_guest, "second normal order spawns")
	guests.clear_guest()
	_ok(completed[0] == 1, "completion emits when second normal order leaves")
	guests._spawn_normal()
	_ok(not guests.has_guest, "third normal order is blocked")
	_ok(completed[0] == 1, "completion signal emits once")


func _test_game_manager_owns_slice() -> void:
	var gm = get_node("/root/GameManager")
	_ok(gm.ryan_slice is RyanSliceSystem, "GameManager owns RyanSliceSystem")


func _test_pending_important_guest_blocks_early_close() -> void:
	var gm = get_node("/root/GameManager")
	var original_phase = gm.day_cycle.phase
	var original_ledger_data = gm.current_ledger_data
	gm.day_cycle.phase = DayCycleSystem.DayPhase.NIGHT
	gm._important_npc_pending = true
	gm.current_ledger_data = null
	gm.end_night()
	_ok(gm.current_ledger_data == null, "pending important NPC blocks early close")
	gm._important_npc_pending = false
	gm.current_ledger_data = original_ledger_data
	gm.day_cycle.phase = original_phase


func _test_important_arrival_timing_rules() -> void:
	var slice := RyanSliceSystem.new()
	_ok(slice.has_method("important_arrival_normal_orders_before"),
		"RyanSliceSystem exposes important NPC arrival timing")
	if not slice.has_method("important_arrival_normal_orders_before"):
		return
	_ok(slice.important_arrival_normal_orders_before(1) == 1,
		"Day 1 Ryan waits for one ordinary customer")
	_ok(slice.important_arrival_normal_orders_before(2) == 1,
		"Day 2 Ryan waits for one ordinary customer")
	_ok(slice.important_arrival_normal_orders_before(3) == 0,
		"Day 3 fate reveal can still arrive immediately")
	_ok(slice.important_arrival_normal_orders_before(5) == 1,
		"Evelyn line also waits for tavern traffic before entering")


func _test_ryan_day2_dialogue_matches_single_order() -> void:
	var pre_dialogue := FileAccess.get_file_as_string("res://dialogue/ryan_day2.pre.dialogue")
	_ok(pre_dialogue.contains("烤肉"), "Day 2 Ryan pre-dialogue still asks for cooked meat")
	_ok(not pre_dialogue.contains("麦芽酒"), "Day 2 Ryan pre-dialogue no longer implies a second ale order")


func _test_all_important_post_dialogues_have_heart_feedback_copy() -> void:
	var gm = get_node("/root/GameManager")
	_ok(gm.has_method("_important_post_dialogue_heart_feedback"),
		"GameManager owns important NPC post-dialogue heart feedback copy")
	if not gm.has_method("_important_post_dialogue_heart_feedback"):
		return
	var cases := [
		{"npc_id": "ryan", "day": 1},
		{"npc_id": "ryan", "day": 2},
		{"npc_id": "ryan", "day": 3},
		{"npc_id": "toby", "day": 6},
		{"npc_id": "mira", "day": 4},
		{"npc_id": "mira", "day": 12},
		{"npc_id": "evelyn", "day": 5},
		{"npc_id": "evelyn", "day": 8},
		{"npc_id": "evelyn", "day": 13},
		{"npc_id": "evelyn", "day": 20},
	]
	for item in cases:
		var text := String(gm.call(
			"_important_post_dialogue_heart_feedback",
			String(item.get("npc_id", "")),
			int(item.get("day", 0))
		))
		_ok(text != "", "important NPC post-dialogue heart feedback exists for %s day %d" % [
			String(item.get("npc_id", "")),
			int(item.get("day", 0)),
		])
	var original_alternative_pending = gm.narrative.get_var("ryan_alternative_pending")
	gm.narrative.set_var("ryan_alternative_pending", true)
	var pending_text := String(gm.call("_important_post_dialogue_heart_feedback", "ryan", 2))
	_ok(pending_text.contains("替代委托"),
		"Day 2 Ryan heart feedback reacts after the alternative contract was handed over")
	_ok(not pending_text.contains("血斧委托"),
		"Day 2 Ryan heart feedback no longer says he is still chasing Bloodaxe after alternative handoff")
	gm.narrative.set_var("ryan_alternative_pending", original_alternative_pending)


func _test_post_dialogue_shows_heart_feedback() -> void:
	var gm = get_node("/root/GameManager")
	var original_day: int = gm.economy.current_day
	var original_view = gm._tavern_view
	var original_phase: String = gm._dialogue_phase
	var original_dialogue_active: bool = gm._is_dialogue_active
	var original_guest = gm.guests.current_guest
	var original_has_guest: bool = gm.guests.has_guest

	var view := HeartFeedbackView.new()
	gm._tavern_view = view
	gm.economy.current_day = 2
	gm._dialogue_phase = "post"
	gm._is_dialogue_active = true

	var guest := GuestData.new()
	guest.guest_name = "莱恩"
	guest.npc_id = "ryan"
	guest.order_key = "meat_cooked"
	guest.type = GuestData.GuestType.IMPORTANT
	guest.has_dialogue = true
	gm.guests.current_guest = guest
	gm.guests.has_guest = true

	gm._on_dialogue_ended()

	_ok(view.stage_lines.size() >= 1, "post-dialogue important NPC shows source-labeled feedback caption")
	if view.stage_lines.size() > 0:
		var text := String(view.stage_lines[view.stage_lines.size() - 1].get("text", ""))
		_ok(text.begins_with("人心 · "), "important NPC post feedback is labeled as heart source")
		_ok(text.contains("莱恩"), "Ryan post feedback names the affected NPC line")
	_ok(view.dialogue_mode_calls.has(false), "post-dialogue feedback closes dialogue mode")
	_ok(view.hide_calls == 1, "post-dialogue flow still clears the customer")
	_ok(not gm.guests.has_guest, "post-dialogue flow leaves no guest in service")

	gm.guests.current_guest = original_guest
	gm.guests.has_guest = original_has_guest
	gm._tavern_view = original_view
	gm.economy.current_day = original_day
	gm._dialogue_phase = original_phase
	gm._is_dialogue_active = original_dialogue_active
	view.queue_free()


func _test_day1_settlement_warns_about_day2_fate_ledger_entry() -> void:
	var gm = get_node("/root/GameManager")
	var original_phase = gm.day_cycle.phase
	var original_day: int = gm.economy.current_day
	var original_ledger_data = gm.current_ledger_data
	var original_pending: bool = gm._important_npc_pending
	var original_guest_lingering: bool = gm._guest_lingering

	if gm.guests.has_guest:
		gm.guests.clear_guest()
	gm.guests.reset_daily()
	gm.day_cycle.phase = DayCycleSystem.DayPhase.NIGHT
	gm.economy.current_day = 1
	gm._important_npc_pending = false
	gm._guest_lingering = false
	gm.current_ledger_data = null
	gm.end_night()

	_ok(gm.current_ledger_data != null, "Day 1 can close after all guests are gone")
	if gm.current_ledger_data != null:
		_ok(gm.current_ledger_data.fate_warning_next_day,
			"Day 1 settlement warns that Day 2 will add a fate ledger record")

	gm.current_ledger_data = original_ledger_data
	gm._important_npc_pending = original_pending
	gm._guest_lingering = original_guest_lingering
	gm.economy.current_day = original_day
	gm.day_cycle.phase = original_phase


func _test_day2_important_npc_waits_for_one_normal_guest() -> void:
	var gm = get_node("/root/GameManager")
	var tutorial = get_node_or_null("/root/TutorialManager")
	var original_day: int = gm.economy.current_day
	var original_phase: int = gm.day_cycle.phase
	var original_pending: bool = gm._important_npc_pending
	var original_today_npc: String = gm.narrative.today_important_npc
	var original_dialogue_active: bool = gm._is_dialogue_active
	var original_dialogue_phase: String = gm._dialogue_phase
	var original_tutorial_entered := false
	var original_tutorial_active := false
	if tutorial != null:
		original_tutorial_entered = bool(tutorial.tavern_first_entered)
		original_tutorial_active = bool(tutorial._is_active)

	if gm.guests.has_guest:
		gm.guests.clear_guest()
	gm.guests.reset_daily()
	gm.economy.current_day = 2
	gm.day_cycle.phase = DayCycleSystem.DayPhase.NIGHT
	gm._important_npc_pending = false
	gm._is_dialogue_active = false
	gm._dialogue_phase = ""
	if tutorial != null:
		tutorial.tavern_first_entered = true
		tutorial._is_active = true

	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame
	await get_tree().process_frame

	_ok(not tavern.daily_menu_confirmed,
		"Day 2 tavern starts in menu preparation before spawning the important NPC")
	_ok(gm.narrative.today_important_npc == "ryan",
		"Day 2 selects Ryan as today's important NPC")
	_ok(not gm.guests.has_guest,
		"Day 2 holds the pending important NPC until menu confirmation")
	if tavern.has_method("_confirm_menu_preparation"):
		tavern.call("_confirm_menu_preparation")
		await get_tree().process_frame
	_ok(not gm.guests.has_guest,
		"Day 2 menu confirmation keeps the important NPC pending until tavern traffic starts")
	_ok(gm._important_npc_pending,
		"Day 2 keeps Ryan pending after menu confirmation")

	gm.guests._spawn_normal()
	await get_tree().process_frame
	_ok(gm.guests.has_guest,
		"Day 2 first service slot spawns an ordinary customer")
	_ok(gm.guests.current_guest != null and gm.guests.current_guest.type == GuestData.GuestType.NORMAL,
		"Day 2 ordinary customer arrives before Ryan")
	if gm.guests.has_guest:
		gm.guests.clear_guest()
	await _wait_until(func(): return gm.guests.has_guest and gm.guests.current_guest != null and gm.guests.current_guest.npc_id == "ryan", 30)

	_ok(gm.guests.has_guest,
		"Day 2 Ryan arrives after one ordinary customer leaves")
	_ok(gm.guests.current_guest != null and gm.guests.current_guest.npc_id == "ryan",
		"Day 2 delayed important guest is Ryan")
	_ok(gm.guests.current_guest != null and gm.guests.current_guest.order_key == "meat_cooked",
		"Day 2 Ryan orders cooked meat")

	if gm.guests.has_guest:
		gm.guests.clear_guest()
	gm.guests.reset_daily()
	tavern.queue_free()
	await get_tree().process_frame
	gm.economy.current_day = original_day
	gm.day_cycle.phase = original_phase
	gm._important_npc_pending = original_pending
	gm.narrative.today_important_npc = original_today_npc
	gm._is_dialogue_active = original_dialogue_active
	gm._dialogue_phase = original_dialogue_phase
	if tutorial != null:
		tutorial.tavern_first_entered = original_tutorial_entered
		tutorial._is_active = original_tutorial_active


func _wait_until(condition: Callable, max_frames: int) -> bool:
	for _i in range(max_frames):
		if bool(condition.call()):
			return true
		await get_tree().process_frame
	return bool(condition.call())


func _test_day3_fate_reveal_is_not_a_formal_npc_scene() -> void:
	var narrative := NarrativeManager.new()
	narrative.load_npc_data()
	_ok(narrative.select_today_important_npc(3) == "",
		"Day 3 Ryan outcome is a slice fate reveal, not a formal Ryan NPC order from npcs.json")


func _test_day3_fate_reveal_spawns_when_menu_already_confirmed() -> void:
	var gm = get_node("/root/GameManager")
	var tutorial = get_node_or_null("/root/TutorialManager")
	var original_day: int = gm.economy.current_day
	var original_phase: int = gm.day_cycle.phase
	var original_pending: bool = gm._important_npc_pending
	var original_today_npc: String = gm.narrative.today_important_npc
	var original_dialogue_active: bool = gm._is_dialogue_active
	var original_dialogue_phase: String = gm._dialogue_phase
	var original_tutorial_entered := false
	var original_tutorial_active := false
	if tutorial != null:
		original_tutorial_entered = bool(tutorial.tavern_first_entered)
		original_tutorial_active = bool(tutorial._is_active)

	if gm.guests.has_guest:
		gm.guests.clear_guest()
	gm.guests.reset_daily()
	gm.economy.current_day = 3
	gm.day_cycle.phase = DayCycleSystem.DayPhase.NIGHT
	gm._important_npc_pending = false
	gm.narrative.today_important_npc = ""
	gm._is_dialogue_active = false
	gm._dialogue_phase = ""
	if tutorial != null:
		tutorial.tavern_first_entered = true
		tutorial._is_active = true

	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame
	await get_tree().process_frame

	_ok(not tavern.daily_menu_confirmed,
		"Day 3 tavern starts in menu preparation before the Ryan fate reveal")
	_ok(not gm.guests.has_guest,
		"Day 3 holds the fate reveal guest until menu confirmation")
	if tavern.has_method("_confirm_menu_preparation"):
		tavern.call("_confirm_menu_preparation")
		await get_tree().process_frame
	_ok(gm.guests.has_guest,
		"Day 3 menu confirmation spawns the Ryan fate reveal guest")
	_ok(gm.guests.current_guest != null and gm.guests.current_guest.npc_id == "ryan",
		"Day 3 fate reveal keeps Ryan as the story subject")
	_ok(gm.guests.current_guest != null and gm.guests.current_guest.order_key == "meat_cooked",
		"Day 3 fate reveal asks for a stable cooked meat order")
	if gm.guests.current_guest != null:
		_ok(String(gm.guests.current_guest.get_meta("portrait_id", "")) == "mercenary_a",
			"Day 3 fate reveal uses the mercenary messenger portrait")

	if gm.guests.has_guest:
		gm.guests.clear_guest()
	gm.guests.reset_daily()
	tavern.queue_free()
	await get_tree().process_frame
	gm.economy.current_day = original_day
	gm.day_cycle.phase = original_phase
	gm._important_npc_pending = original_pending
	gm.narrative.today_important_npc = original_today_npc
	gm._is_dialogue_active = original_dialogue_active
	gm._dialogue_phase = original_dialogue_phase
	if tutorial != null:
		tutorial.tavern_first_entered = original_tutorial_entered
		tutorial._is_active = original_tutorial_active
