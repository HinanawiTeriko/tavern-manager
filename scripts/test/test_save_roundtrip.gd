extends Node

## GM 级存档 round-trip：capture→write→破坏内存→read→apply→断言；以及 new_game 重置。
## 标题页按钮与场景流转走人工验证（headless 测不到）。

var _checks := 0
var _failures := 0
var _had_original_save := false
var _original_save: Dictionary = {}

func _ready() -> void:
	var gm = _gm()
	_had_original_save = gm.save_sys.has_save()
	_original_save = gm.save_sys.read()
	_test_capture_apply_roundtrip()
	_test_apply_old_save_merges_new_narrative_defaults()
	_test_reset_tutorial_progress_clears_runtime_and_save_snapshot()
	_test_recipe_purchase_marks_discovered()
	_test_recipe_new_marker_roundtrip()
	_test_max_gold_held_tracks_high_watermark()
	_test_day_map_reveal_state_roundtrip()
	_test_old_save_without_day_map_state_does_not_replay_seen_locations()
	await _test_day_map_reveal_sequence_persists_after_initial_snapshot()
	await _test_day_map_restores_saved_camera_view_without_new_reveal()
	_test_new_game_resets()
	_finish()

func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-SAVE-RT] FAIL: " + msg)

func _finish() -> void:
	_restore_original_save()
	if _failures == 0:
		print("[TEST-SAVE-RT] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-SAVE-RT] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)

func _gm():
	return get_node("/root/GameManager")


func _location_ids(locations: Array) -> Array:
	var result := []
	for loc in locations:
		result.append(String(loc.get("id", "")))
	return result


func _optional_int(value, fallback: int = -999999) -> int:
	if value == null:
		return fallback
	return int(value)


func _restore_original_save() -> void:
	var gm = _gm()
	if _had_original_save:
		gm.save_sys.write(_original_save)
	else:
		gm.save_sys.clear()

func _test_capture_apply_roundtrip() -> void:
	var gm = _gm()
	gm.economy.current_day = 2
	gm.economy.gold = 88
	gm.economy.set("max_gold_held", 120)
	gm.economy.reputation = 6
	gm.inventory_sys.set_initial({"ale": 9, "sleep_powder": 1})
	gm.craft.unlock_recipe("meat_cooked")
	if gm.craft.has_method("discover_recipe"):
		gm.craft.call("discover_recipe", "herb_broth")
	if gm.craft.has_method("mark_recipe_new"):
		gm.craft.call("mark_recipe_new", "herb_broth")
	gm.narrative.set_var("ryan_informed", true)
	gm.narrative.set_ending("ryan", "informed_fallen")
	gm.documents.grant_document("bloodied_contract")
	gm.documents.request_open("bloodied_contract")

	var snap: Dictionary = gm._capture_save_state()
	gm.save_sys.write(snap)

	# 破坏内存状态，再从磁盘恢复
	gm.economy.gold = 0
	gm.economy.current_day = 1
	gm.inventory_sys.set_initial({})
	gm.narrative.set_var("ryan_informed", false)

	gm._apply_save_state(gm.save_sys.read())
	_ok(gm.economy.current_day == 2, "day restored")
	_ok(gm.economy.gold == 88, "gold restored")
	_ok(_optional_int(gm.economy.get("max_gold_held")) == 120, "max held gold restored")
	_ok(gm.inventory_sys.get_count("ale") == 9, "inventory restored")
	_ok(gm.inventory_sys.get_count("sleep_powder") == 1, "story item restored")
	_ok(gm.craft.is_recipe_unlocked("meat_cooked"), "recipe unlock restored")
	_ok(gm.craft.has_method("is_recipe_discovered"), "recipe discovery API exists after restore")
	if gm.craft.has_method("is_recipe_discovered"):
		_ok(gm.craft.call("is_recipe_discovered", "herb_broth"), "recipe discovery restored")
	_ok(gm.craft.has_method("is_recipe_new"), "recipe new marker API exists after restore")
	if gm.craft.has_method("is_recipe_new"):
		_ok(gm.craft.call("is_recipe_new", "herb_broth"), "recipe new marker restored")
	_ok(bool(gm.narrative.dialogue_vars.get("ryan_informed", false)), "ryan flag restored")
	_ok(String(gm.narrative.endings.get("ryan", "")) == "informed_fallen", "ending restored")
	_ok(gm.documents.is_read("bloodied_contract"), "document read restored")
	_ok(gm.inventory == gm.inventory_sys.materials, "gm.inventory still references system stock after restore")
	gm.save_sys.clear()

func _test_recipe_purchase_marks_discovered() -> void:
	var gm = _gm()
	gm._apply_save_state(gm._default_new_game_state())
	gm.economy.gold = 100
	var bought: bool = gm.buy_recipe_unlock("herbal_ale")
	_ok(bought, "recipe purchase succeeds with enough gold")
	_ok(gm.craft.is_recipe_unlocked("herbal_ale"), "recipe purchase still unlocks ordering")
	_ok(gm.craft.has_method("is_recipe_discovered"), "recipe discovery API exists after purchase")
	if gm.craft.has_method("is_recipe_discovered"):
		_ok(gm.craft.call("is_recipe_discovered", "herbal_ale"), "recipe purchase reveals recipe book entry")
	_ok(gm.craft.has_method("is_recipe_new"), "recipe new marker API exists after purchase")
	if gm.craft.has_method("is_recipe_new"):
		_ok(gm.craft.call("is_recipe_new", "herbal_ale"), "recipe purchase marks recipe book entry as new")
	gm.save_sys.clear()

func _test_recipe_new_marker_roundtrip() -> void:
	var gm = _gm()
	gm._apply_save_state(gm._default_new_game_state())
	_ok(gm.craft.has_method("mark_recipe_new"), "recipe new marker mutation exists before roundtrip")
	_ok(gm.craft.has_method("is_recipe_new"), "recipe new marker query exists before roundtrip")
	_ok(gm.craft.has_method("clear_recipe_new"), "recipe new marker clearing exists before roundtrip")
	if not gm.craft.has_method("mark_recipe_new") or not gm.craft.has_method("is_recipe_new") or not gm.craft.has_method("clear_recipe_new"):
		return
	gm.craft.discover_recipe("herb_broth")
	gm.craft.call("mark_recipe_new", "herb_broth")
	var snap: Dictionary = gm._capture_save_state()
	var craft_state: Dictionary = snap.get("craft", {})
	_ok(Array(craft_state.get("newly_discovered_recipes", [])).has("herb_broth"),
		"save snapshot includes recipe new markers")
	gm.craft.call("clear_recipe_new", "herb_broth")
	_ok(not gm.craft.call("is_recipe_new", "herb_broth"), "test setup clears marker before restore")
	gm._apply_save_state(snap)
	_ok(gm.craft.call("is_recipe_new", "herb_broth"), "recipe new marker survives save apply")
	gm._apply_save_state(gm._default_new_game_state())
	_ok(not gm.craft.call("is_recipe_new", "herb_broth"), "new game clears recipe new markers")
	gm.save_sys.clear()


func _test_max_gold_held_tracks_high_watermark() -> void:
	var gm = _gm()
	gm._apply_save_state(gm._default_new_game_state())
	gm.economy.add_gold(120)
	_ok(_optional_int(gm.economy.get("max_gold_held")) == 120, "max held gold increases with earned gold")
	_ok(gm.economy.spend_gold(80), "test setup spends gold")
	_ok(gm.economy.gold == 40, "current gold decreases after spending")
	_ok(_optional_int(gm.economy.get("max_gold_held")) == 120, "max held gold does not decrease after spending")
	gm.save_sys.clear()


func _test_day_map_reveal_state_roundtrip() -> void:
	var gm = _gm()
	gm._apply_save_state(gm._default_new_game_state())
	gm.start_day_map(2)
	gm.day_map.mark_revealed("mushroom_forest")
	gm.day_map.mark_revealed("mercenary_board")
	gm.day_map.mark_posting_announced("mercenary_board")
	var snap: Dictionary = gm._capture_save_state()
	_ok(snap.has("day_map"), "save snapshot includes day map reveal state")

	gm.day_map = DayMapSystem.new()
	gm.day_map.load_data()
	gm._apply_save_state(snap)
	gm.start_day_map(2)

	_ok(gm.day_map.is_revealed("mushroom_forest"), "revealed gathering location survives save apply")
	_ok(not _location_ids(gm.day_map.get_new_locations()).has("mushroom_forest"),
		"revealed gathering location does not replay the new-location camera pull after restore")
	_ok(not _location_ids(gm.day_map.get_updated_locations()).has("mercenary_board"),
		"announced board posting does not replay the update camera pull after restore")
	gm._apply_save_state(gm._default_new_game_state())
	gm.start_day_map(2)
	_ok(not gm.day_map.is_revealed("mushroom_forest"), "new game clears day map reveal state")
	gm.save_sys.clear()


func _test_old_save_without_day_map_state_does_not_replay_seen_locations() -> void:
	var gm = _gm()
	var old_save: Dictionary = gm._default_new_game_state()
	old_save.erase("day_map")
	old_save["economy"]["current_day"] = 2
	old_save["tutorial"]["daymap_first_shown"] = true
	gm._apply_save_state(old_save)
	gm.start_day_map(2)

	_ok(gm.day_map.is_revealed("mushroom_forest"),
		"old saves that already showed DayMap seed currently visible locations as revealed")
	_ok(not _location_ids(gm.day_map.get_new_locations()).has("mushroom_forest"),
		"old saves without day map state do not replay old visible gathering points as new")
	gm._apply_save_state(gm._default_new_game_state())
	gm.save_sys.clear()


func _test_day_map_reveal_sequence_persists_after_initial_snapshot() -> void:
	var gm = _gm()
	gm._apply_save_state(gm._default_new_game_state())
	gm._pending_intro_handoff = false
	var tm = get_node_or_null("/root/TutorialManager")
	if tm != null:
		tm.daymap_first_shown = true
	var day_map_scene := preload("res://scenes/ui/DayMap.tscn")
	var view = day_map_scene.instantiate()
	add_child(view)
	await get_tree().create_timer(0.85).timeout
	var saved: Dictionary = gm.save_sys.read()
	var day_map_state: Dictionary = saved.get("day_map", {})
	var revealed: Array = day_map_state.get("revealed", [])
	_ok(revealed.has("mushroom_forest"),
		"DayMap reveal sequence persists revealed locations after the initial DayMap snapshot")
	view.queue_free()
	await get_tree().process_frame
	gm._apply_save_state(gm._default_new_game_state())
	gm.save_sys.clear()


func _test_day_map_restores_saved_camera_view_without_new_reveal() -> void:
	var gm = _gm()
	gm._apply_save_state(gm._default_new_game_state())
	gm._pending_intro_handoff = false
	var tm = get_node_or_null("/root/TutorialManager")
	if tm != null:
		tm.daymap_first_shown = true
	gm.economy.current_day = 2
	gm.start_day_map(2)
	for loc in gm.day_map.get_locations():
		gm.day_map.mark_revealed(String(loc.get("id", "")))
		gm.day_map.mark_posting_announced(String(loc.get("id", "")))
	_ok(gm.day_map.has_method("set_camera_view"), "DayMapSystem can persist the camera view")
	if not gm.day_map.has_method("set_camera_view"):
		gm._apply_save_state(gm._default_new_game_state())
		gm.save_sys.clear()
		return

	var saved_pos := Vector2(1780.0, 910.0)
	var saved_zoom := 0.85
	gm.day_map.call("set_camera_view", saved_pos, saved_zoom)
	_ok(gm.day_map.get_camera_position().distance_to(saved_pos) <= 0.01,
		"DayMapSystem stores camera position before save")
	gm.save_sys.write(gm._capture_save_state())

	var day_map_scene := preload("res://scenes/ui/DayMap.tscn")
	var view = day_map_scene.instantiate()
	add_child(view)
	await get_tree().process_frame
	await get_tree().process_frame
	var camera := view.get_node("MapWorld/Camera2D") as Camera2D
	_ok(camera.position.distance_to(saved_pos) <= 1.0,
		"DayMap re-entry restores saved camera position instead of snapping to tavern: got %s expected %s zoom=%s stored=%s has_view=%s" %
		[camera.position, saved_pos, camera.zoom, gm.day_map.get_camera_position(), gm.day_map.has_camera_view()])
	_ok(absf(camera.zoom.x - saved_zoom) <= 0.01,
		"DayMap re-entry restores saved camera zoom")
	view.queue_free()
	await get_tree().process_frame
	gm._apply_save_state(gm._default_new_game_state())
	gm.save_sys.clear()


func _test_apply_old_save_merges_new_narrative_defaults() -> void:
	var gm = _gm()
	var old_save: Dictionary = gm._default_new_game_state()
	old_save["economy"]["current_day"] = 4
	old_save["economy"]["gold"] = 37
	old_save["economy"].erase("max_gold_held")
	var old_dialogue_vars := {
		"has_sleep_powder": false,
		"ryan_informed": false,
		"ryan_warhammer_lead": true,
		"ryan_has_alternative": false,
		"ryan_drugged": false,
		"ryan_interaction_closed": false,
		"ryan_alternative_pending": false,
		"ryan_alternative_declined": false,
		"ryan_ending": "uninformed_fallen",
		"aff_ryan": 6,
		"aff_mira": 5,
	}
	old_save["narrative"]["dialogue_vars"] = old_dialogue_vars

	gm._apply_save_state(old_save)

	_ok(gm.economy.current_day == 4, "old save day restored")
	_ok(_optional_int(gm.economy.get("max_gold_held")) == 37, "old save seeds max held gold from current gold")
	_ok(gm.narrative.dialogue_vars.has("told_mira_truth"),
		"old save restore fills missing told_mira_truth default")
	_ok(gm.narrative.dialogue_vars.has("mira_ending"),
		"old save restore fills missing mira_ending default")
	_ok(gm.narrative.dialogue_vars.has("toby_secured"),
		"old save restore fills missing toby_secured default")
	_ok(gm.narrative.dialogue_vars.get("ryan_ending", "") == "uninformed_fallen",
		"old save restore preserves existing Ryan ending")

func _test_reset_tutorial_progress_clears_runtime_and_save_snapshot() -> void:
	var gm = _gm()
	var tm = get_node("/root/TutorialManager")
	tm._completed_steps = ["gather_intro", "craft_intro", "serve_intro"]
	tm.daymap_first_shown = true
	tm.tavern_first_entered = true
	tm.shop_first_visited = true
	tm.first_guest_arrived = true
	tm.first_product_seasoned = true
	tm.first_guest_served = true
	tm.first_ledger_shown = true
	gm.save_sys.write(gm._capture_save_state())

	gm.reset_tutorial_progress()

	_ok(tm._completed_steps.is_empty(), "tutorial reset clears completed steps")
	_ok(not tm.daymap_first_shown, "tutorial reset clears daymap flag")
	_ok(not tm.tavern_first_entered, "tutorial reset clears tavern flag")
	_ok(not tm.shop_first_visited, "tutorial reset clears shop flag")
	_ok(not tm.first_guest_arrived, "tutorial reset clears guest arrival flag")
	_ok(not tm.first_product_seasoned, "tutorial reset clears seasoning flag")
	_ok(not tm.first_guest_served, "tutorial reset clears served flag")
	_ok(not tm.first_ledger_shown, "tutorial reset clears ledger flag")

	var saved: Dictionary = gm.save_sys.read()
	var tutorial_state: Dictionary = saved.get("tutorial", {})
	_ok(tutorial_state.get("completed_steps", ["stale"]).is_empty(), "tutorial reset writes cleared completed steps to save")
	_ok(not bool(tutorial_state.get("daymap_first_shown", true)), "tutorial reset writes cleared daymap flag to save")
	_ok(not bool(tutorial_state.get("tavern_first_entered", true)), "tutorial reset writes cleared tavern flag to save")
	_ok(not bool(tutorial_state.get("shop_first_visited", true)), "tutorial reset writes cleared shop flag to save")
	_ok(not bool(tutorial_state.get("first_guest_arrived", true)), "tutorial reset writes cleared guest flag to save")
	_ok(not bool(tutorial_state.get("first_product_seasoned", true)), "tutorial reset writes cleared seasoning flag to save")
	_ok(not bool(tutorial_state.get("first_guest_served", true)), "tutorial reset writes cleared served flag to save")
	_ok(not bool(tutorial_state.get("first_ledger_shown", true)), "tutorial reset writes cleared ledger flag to save")
	gm.save_sys.clear()

func _test_new_game_resets() -> void:
	var gm = _gm()
	gm._apply_save_state(gm._default_new_game_state())
	_ok(gm.economy.current_day == 1, "new game day 1")
	_ok(gm.economy.gold == 0, "new game gold 0")
	_ok(not gm.craft.is_recipe_unlocked("meat_cooked"), "new game clears recipe unlocks")
	_ok(gm.craft.has_method("is_recipe_discovered"), "new game exposes recipe discovery API")
	if gm.craft.has_method("is_recipe_discovered"):
		_ok(gm.craft.call("is_recipe_discovered", "ale_beer"), "new game keeps starter recipe discovered")
		_ok(not gm.craft.call("is_recipe_discovered", "herb_broth"), "new game clears non-starter recipe discoveries")
	_ok(not bool(gm.narrative.dialogue_vars.get("ryan_informed", false)), "new game clears ryan flags")
	_ok(not gm.documents.is_read("bloodied_contract"), "new game clears document read")
	_ok(gm.documents.owns_document("ledger"), "new game keeps ledger")
	gm.save_sys.clear()
