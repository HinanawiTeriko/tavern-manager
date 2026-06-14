extends Node

var _checks := 0
var _failures := 0


func _ready() -> void:
	_test_three_day_boundary()
	_test_state_roundtrip()
	_test_pre_toby_window_can_reach_fixer_price()
	_test_guest_budget()
	_test_game_manager_owns_slice()
	_test_pending_important_guest_blocks_early_close()
	await _test_day2_important_npc_spawns_when_menu_already_confirmed()
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
	# [走查脚手架] 收尾日临时延至 Day12 以走查 Mira 线高潮（见 ryan_slice_system.gd LAST_DAY 注释）。
	_ok(slice.last_day() == 12, "slice ends on Day 12 (走查脚手架)")
	_ok(slice.normal_order_limit(1) == 2, "Day 1 has two normal orders")
	_ok(slice.normal_order_limit(2) == 2, "Day 2 has two normal orders")
	_ok(slice.normal_order_limit(3) == 2, "Day 3 has two normal orders")
	_ok(slice.normal_order_limit(4) == 3, "Day 4 opens the mid-slice three-normal-order rhythm")
	_ok(slice.normal_order_limit(12) == 3, "Day 12 keeps the three-normal-order Mira climax rhythm")
	_ok(slice.day_start_ledger_entries(2).has("第三日。莱恩。\n北矿道。\n未归。"), "Day 2 adds Ryan prediction")
	_ok(not slice.should_finish_after_day(2), "Day 2 continues")
	_ok(not slice.should_finish_after_day(3), "Day 3 continues (走查脚手架)")
	_ok(slice.should_finish_after_day(12), "Day 12 finishes the slice")


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
		3: 4, # herb_broth 8 - herb 2 - ale 2
		4: 3, # wine 5 - grape 2
		6: 4, # herb_broth 8 - herb 2 - ale 2
	}
	var projected_gold := 0
	for day in range(1, 7):
		projected_gold += slice.normal_order_limit(day) * NORMAL_ORDER_NET_FLOOR
		projected_gold += int(IMPORTANT_ORDER_NET.get(day, 0))
	_ok(projected_gold >= FIXER_PRICE,
		"conservative Day1-6 net income can reach Toby fixer price")


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


func _test_day2_important_npc_spawns_when_menu_already_confirmed() -> void:
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

	_ok(tavern.daily_menu_confirmed,
		"Day 2 tavern starts with the default menu already confirmed")
	_ok(gm.narrative.today_important_npc == "ryan",
		"Day 2 selects Ryan as today's important NPC")
	_ok(gm.guests.has_guest,
		"Day 2 auto-confirmed tavern spawns the pending important NPC")
	_ok(gm.guests.current_guest != null and gm.guests.current_guest.npc_id == "ryan",
		"Day 2 important guest is Ryan")
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
