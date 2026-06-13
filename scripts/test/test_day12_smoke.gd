extends Node

const DAY_MAP_SCENE := preload("res://scenes/ui/DayMap.tscn")
const TAVERN_SCENE := preload("res://scenes/ui/Tavern.tscn")
const LEDGER_SCENE := preload("res://scenes/ui/LedgerScreen.tscn")

var _checks := 0
var _failures := 0
var _had_original_save := false
var _original_save: Dictionary = {}
var _original_time_scale := 1.0


func _ready() -> void:
	var gm = _gm()
	_original_time_scale = Engine.time_scale
	Engine.time_scale = 80.0
	_had_original_save = gm.save_sys.has_save()
	_original_save = gm.save_sys.read()

	gm._apply_save_state(gm._default_new_game_state())
	_disable_tutorials()
	await _run_day12_smoke()
	await _cleanup_test_nodes()
	_finish()


func _gm():
	return get_node("/root/GameManager")


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-DAY12-SMOKE] FAIL: " + msg)


func _finish() -> void:
	Engine.time_scale = _original_time_scale
	_restore_original_save()
	if _failures == 0:
		print("[TEST-DAY12-SMOKE] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-DAY12-SMOKE] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _restore_original_save() -> void:
	var gm = _gm()
	if _had_original_save:
		gm.save_sys.write(_original_save)
	else:
		gm.save_sys.clear()


func _disable_tutorials() -> void:
	var tm = get_node_or_null("/root/TutorialManager")
	if tm == null:
		return
	tm._is_active = false
	tm.daymap_first_shown = true
	tm.tavern_first_entered = true
	tm.shop_first_visited = true
	tm.first_guest_arrived = true
	tm.first_product_seasoned = true
	tm.first_guest_served = true
	tm.first_ledger_shown = true


func _run_day12_smoke() -> void:
	var gm = _gm()
	for day in range(1, 13):
		gm.economy.current_day = day
		await _smoke_day(day)
	_ok(gm.economy.current_day == 13, "smoke advances past Day 12 without ending early")
	_ok(String(gm.narrative.get_var("mira_ending")) != "", "Day 12 finalizes Mira ending")
	_ok(String(gm.narrative.endings.get("toby", "")) != "", "Day 12 finalizes Toby fate")


func _smoke_day(day: int) -> void:
	var gm = _gm()
	gm.day_cycle.phase = DayCycleSystem.DayPhase.DAY
	gm.current_ledger_data = null
	_disable_tutorials()

	var day_map = DAY_MAP_SCENE.instantiate()
	add_child(day_map)
	await get_tree().process_frame
	await get_tree().process_frame
	_ok(day_map is DayMapView, "Day %d DayMap scene instantiates" % day)
	_ok(gm.day_map.current_day == day, "Day %d DayMap registers current day" % day)
	_ok(gm.day_map.get_locations().size() > 0, "Day %d DayMap exposes locations" % day)
	day_map.queue_free()
	await get_tree().process_frame

	gm.day_cycle.phase = DayCycleSystem.DayPhase.NIGHT
	var tavern = TAVERN_SCENE.instantiate()
	add_child(tavern)
	await get_tree().process_frame
	await get_tree().process_frame
	_ok(tavern is TavernView, "Day %d Tavern scene instantiates" % day)
	_ok(gm.guests._normal_order_limit == gm.ryan_slice.normal_order_limit(day),
		"Day %d Tavern configures normal customer budget" % day)
	_ok(gm.guests._normal_order_limit > 0, "Day %d has at least one normal customer budget" % day)

	if gm.guests.has_guest and gm.guests.current_guest != null and gm.guests.current_guest.has_dialogue:
		_ok(gm.guests.current_guest.has_dialogue, "Day %d starts with important NPC when one is scheduled" % day)
		await _serve_current_guest(day, "important")

	await _serve_all_normal_guests(day)
	_ok(not gm.guests.has_guest, "Day %d has no lingering guest before settlement" % day)
	_ok(gm.guests.remaining_normal_orders() == 0, "Day %d exhausts normal customer queue" % day)

	var ledger_data := _capture_ledger_data(day)
	gm.current_ledger_data = ledger_data
	var ledger = LEDGER_SCENE.instantiate()
	add_child(ledger)
	await get_tree().process_frame
	await get_tree().process_frame
	_ok(ledger is LedgerScreen, "Day %d LedgerScreen scene instantiates" % day)
	if day == 3:
		_ok(ledger.get_node_or_null("RyanFateCinematic") != null,
			"Day 3 settlement shows Ryan fate cinematic")
	if day == 12:
		_ok(_has_fate(ledger_data.npc_fates, "mira"), "Day 12 settlement contains Mira fate")
		_ok(_has_fate(ledger_data.npc_fates, "toby"), "Day 12 settlement contains Toby fate")
	ledger.queue_free()
	tavern.queue_free()
	_clear_dialogue_balloons()
	await get_tree().process_frame

	gm.ryan_slice.complete_day(day)
	gm.economy.reset_daily()
	gm.guests.reset_daily()
	gm.economy.current_day = day + 1


func _serve_all_normal_guests(day: int) -> void:
	var gm = _gm()
	var guard := 0
	while gm.guests.remaining_normal_orders() > 0 and guard < 20:
		guard += 1
		if not gm.guests.has_guest:
			gm.guests._spawn_normal()
			await get_tree().process_frame
		if gm.guests.has_guest:
			await _serve_current_guest(day, "normal")
	_ok(guard < 20, "Day %d normal customer loop terminates" % day)


func _serve_current_guest(day: int, expected_type: String) -> void:
	var gm = _gm()
	var guest = gm.guests.current_guest
	_ok(guest != null, "Day %d has %s guest to serve" % [day, expected_type])
	if guest == null:
		return
	var order_key: String = gm.current_order_key()
	_ok(order_key != "", "Day %d %s guest has an order" % [day, expected_type])
	if order_key == "":
		return

	if guest.has_dialogue:
		await _finish_dialogue_if_active()

	var before_served: int = gm.guests.guests_served_today
	gm.request_serve(order_key, {"serve_drop_speed": 80.0}, "")
	await get_tree().process_frame
	await get_tree().process_frame

	if gm._dialogue_phase == "post" or gm._is_dialogue_active:
		await _finish_dialogue_if_active()

	var cleared := await _wait_until(func(): return not gm.guests.has_guest and not gm._guest_lingering, 180)
	_ok(cleared, "Day %d %s guest clears after serving" % [day, expected_type])
	_ok(gm.guests.guests_served_today == before_served + 1,
		"Day %d %s guest increments served count" % [day, expected_type])


func _finish_dialogue_if_active() -> void:
	var gm = _gm()
	await get_tree().process_frame
	await get_tree().process_frame
	if gm._dialogue_phase != "" or gm._is_dialogue_active:
		gm._on_dialogue_ended()
	await get_tree().process_frame
	_clear_dialogue_balloons()


func _clear_dialogue_balloons() -> void:
	for child in get_children():
		if child is DialogueManagerExampleBalloon:
			child.queue_free()


func _cleanup_test_nodes() -> void:
	_clear_dialogue_balloons()
	for child in get_children():
		child.queue_free()
	for _i in range(3):
		await get_tree().process_frame


func _wait_until(condition: Callable, max_frames: int) -> bool:
	for _i in range(max_frames):
		if bool(condition.call()):
			return true
		await get_tree().process_frame
	return bool(condition.call())


func _capture_ledger_data(day: int) -> LedgerData:
	var gm = _gm()
	var data := LedgerData.new()
	data.day = day
	data.gold_today = gm.economy.gold_today
	data.rep_today = gm.economy.rep_today
	data.gold_total = gm.economy.gold
	data.rep_total = gm.economy.reputation
	data.guests_served = gm.guests.guests_served_today
	data.orders_success = gm.guests.orders_success
	data.orders_failed = gm.guests.orders_failed
	data.npc_fates = gm.narrative.get_today_npc_fates(day)
	return data


func _has_fate(fates: Array, npc_id: String) -> bool:
	for fate in fates:
		if fate is Dictionary and String(fate.get("npc_id", "")) == npc_id:
			return true
	return false
