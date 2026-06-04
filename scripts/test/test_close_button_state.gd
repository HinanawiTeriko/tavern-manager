extends Node

## 打烊按钮状态回归测试。
## Bug：GuestSystem.clear_guest() 先 emit guest_left 再置 has_guest=false，
## 导致 _on_guest_left 同步刷新按钮时读到 stale has_guest=true，按钮卡在禁用，
## 整个"等待中"期间无法打烊。修复：_on_guest_left 改 call_deferred 刷新，
## 等 clear_guest 收尾（has_guest=false）后再算。

var _checks := 0
var _failures := 0
var _fake_view


func _ready() -> void:
	await _test_button_reenabled_after_guest_leaves()
	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-CLOSE-BTN] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-CLOSE-BTN] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-CLOSE-BTN] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _gm():
	return get_node("/root/GameManager")


func _test_button_reenabled_after_guest_leaves() -> void:
	var gm = _gm()
	# 隔离：非 NIGHT 阶段，避免 GameManager._process 自动刷客人干扰本测。
	var orig_phase = gm.day_cycle.phase
	gm.day_cycle.phase = DayCycleSystem.DayPhase.DAY
	var orig_view = gm._tavern_view
	var orig_pending = gm._important_npc_pending
	gm._important_npc_pending = false
	gm._guest_lingering = false

	_fake_view = FakeCloseView.new()
	gm._tavern_view = _fake_view

	# 模拟"订单未耗尽"：离场时不会触发 normal_orders_completed 的二次刷新，
	# 这样才暴露 guest_left 同步刷新读到 stale has_guest 的真 bug。
	gm.guests._normal_order_limit = 5
	gm.guests._normal_orders_spawned = 1
	gm.guests._normal_completion_emitted = false

	# 装一个在场客人
	var g = GuestData.new()
	g.has_dialogue = false
	gm.guests.current_guest = g
	gm.guests.has_guest = true

	# sanity：客人在场时按钮应禁用
	gm._refresh_close_button()
	_ok(_fake_view.last_enabled == false, "客人在场时打烊按钮禁用")

	# 客人离场 → 进入"等待中"
	_fake_view.last_enabled = null
	gm.guests.clear_guest()
	# 冲刷 call_deferred（修复后刷新被推迟到本帧末）
	await get_tree().process_frame
	await get_tree().process_frame

	_ok(_fake_view.last_enabled == true, "客人离场进入等待中后打烊按钮恢复可用")

	# 还原
	gm._tavern_view = orig_view
	gm.day_cycle.phase = orig_phase
	gm._important_npc_pending = orig_pending
	_fake_view.free()


class FakeCloseView extends Node:
	var last_enabled = null
	func set_close_enabled(e) -> void:
		last_enabled = e
	func hide_customer() -> void:
		pass
	func customer_say(_t) -> void:
		pass
	func show_stage_caption(_t, _c = Color.WHITE) -> void:
		pass
