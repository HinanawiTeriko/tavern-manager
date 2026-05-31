extends Node

var _checks := 0
var _failures := 0


func _ready() -> void:
	_test_three_day_boundary()
	_test_state_roundtrip()
	_test_guest_budget()
	_test_game_manager_owns_slice()
	_test_pending_important_guest_blocks_early_close()
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
	_ok(slice.last_day() == 3, "slice ends on Day 3")
	_ok(slice.normal_order_limit(1) == 2, "Day 1 has two normal orders")
	_ok(slice.normal_order_limit(2) == 2, "Day 2 has two normal orders")
	_ok(slice.normal_order_limit(3) == 2, "Day 3 has two normal orders")
	_ok(slice.day_start_ledger_entries(2).has("第三日。莱恩。\n北矿道。\n未归。"), "Day 2 adds Ryan prediction")
	_ok(not slice.should_finish_after_day(2), "Day 2 continues")
	_ok(slice.should_finish_after_day(3), "Day 3 finishes the slice")


func _test_state_roundtrip() -> void:
	var slice := RyanSliceSystem.new()
	slice.record_order_success()
	slice.record_order_success()
	slice.complete_day(1)
	var restored := RyanSliceSystem.new()
	restored.restore_state(slice.capture_state())
	_ok(restored.total_orders_success == 2, "total successful orders restore")
	_ok(restored.is_day_complete(1), "completed day restores")


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
