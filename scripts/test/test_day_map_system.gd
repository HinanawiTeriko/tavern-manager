extends Node

var _checks := 0
var _failures := 0


func _ready() -> void:
	_test_day2_investigation_chain()
	_test_game_manager_routes_visits()
	_test_gathering_confirmation_does_not_write_ledger()
	_test_get_locations_breadcrumb()
	_test_board_requires_lead()
	_test_day6_toby_choice_chain()
	_test_day2_shop_gossip_points_to_sleep_powder()
	_test_game_manager_previews_shop_gossip_without_consuming()
	_test_game_manager_consumes_shop_gossip_once()
	_test_shop_button_checks_gossip_before_opening()
	_test_reveal_tracking()
	_test_intro_handoff_timing_contract()
	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-DAYMAP] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-DAYMAP] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-DAYMAP] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _test_day2_investigation_chain() -> void:
	var map := DayMapSystem.new()
	_ok(map.load_data(), "locations data loads")
	map.start_day(2)
	map.set_lead_flag("ryan_warhammer_lead", true)
	_ok(map.stamina == 4, "day2 starts with four stamina")
	_ok(not map.visit("abandoned_mine").get("success", false), "mine is blocked before board clue")
	_ok(map.stamina == 4, "blocked visit does not spend stamina")
	var board := map.visit("mercenary_board")
	_ok(board.get("success", false), "board visit succeeds")
	_ok(map.stamina == 3, "board spends one stamina")
	# 旧：mine 直接授予 bloodied_contract；新：授予搬进物理场景，visit 不再带 documents
	var mine := map.visit("abandoned_mine")
	_ok(mine.get("success", false), "mine is visitable after board clue")
	_ok(mine.get("documents", []).is_empty(), "mine no longer auto-grants documents (granted in scene)")
	_ok(not map.visit("guild_counter").get("success", false), "guild counter requires read evidence")
	map.set_document_read("bloodied_contract", true)
	var counter := map.visit("guild_counter")
	_ok(counter.get("documents", []).has("alternative_contract"), "counter grants alternative contract")
	_ok(map.stamina == 0, "positive route spends all day2 stamina")

	map.start_day(2)
	var forest := map.visit("mushroom_forest")
	_ok(forest.get("rewards", []).has("sleep_powder"), "day2 mushroom forest grants sleep powder")


func _test_game_manager_routes_visits() -> void:
	var gm = get_node("/root/GameManager")
	_ok(gm.day_map is DayMapSystem, "GameManager owns DayMapSystem")
	gm.start_day_map(2)
	var before: int = gm.inventory_sys.get_count("sleep_powder")
	var ledger_before: int = gm.documents.capture_state().get("ledger_entries", []).size()
	_ok(gm.visit_day_location("mushroom_forest").get("success", false), "GameManager routes forest visit")
	_ok(gm.inventory_sys.get_count("sleep_powder") == before + 1, "forest reward enters inventory")
	_ok(gm.narrative.get_var("has_sleep_powder") == true, "forest reward triggers narrative hook")
	var ledger_after: int = gm.documents.capture_state().get("ledger_entries", []).size()
	_ok(ledger_after == ledger_before, "forest reward does not enter ledger")
	gm.narrative.set_var("ryan_warhammer_lead", true)
	gm.start_day_map(2)
	_ok(_location_ids(gm.day_map.get_locations()).has("mercenary_board"), "GM exposes board after lead set")
	gm.visit_day_location("mercenary_board")
	gm.visit_day_location("abandoned_mine")
	_ok(not gm.documents.owns_document("bloodied_contract"), "visiting mine alone does not grant evidence")
	gm.grant_investigation_document("bloodied_contract")
	_ok(gm.documents.owns_document("bloodied_contract"), "digging out contract grants it via GameManager")
	_ok(gm.inventory_sys.get_count("bloodied_contract") == 1, "granting evidence adds it to the story bag")
	gm.request_open_document("bloodied_contract")
	_ok(gm.inventory_sys.get_count("bloodied_contract") == 1, "reading evidence does not duplicate it")
	gm.request_open_document("bloodied_contract")
	_ok(gm.inventory_sys.get_count("bloodied_contract") == 1, "re-reading evidence does not duplicate it")
	gm.visit_day_location("guild_counter")
	_ok(gm.documents.owns_document("alternative_contract"), "read evidence unlocks counter document")


func _test_gathering_confirmation_does_not_write_ledger() -> void:
	var gm = get_node("/root/GameManager")
	gm.economy.current_day = 2
	gm.day_cycle.phase = DayCycleSystem.DayPhase.DAY
	var before: int = gm.inventory_sys.get_count("sleep_powder")
	var ledger_before: int = gm.documents.capture_state().get("ledger_entries", []).size()
	gm._on_gathering_confirmed({"mushroom_forest": 1})
	_ok(gm.inventory_sys.get_count("sleep_powder") == before + 1, "confirmed gathering enters inventory")
	var ledger_after: int = gm.documents.capture_state().get("ledger_entries", []).size()
	_ok(ledger_after == ledger_before, "confirmed gathering does not enter ledger")


func _location_ids(locations: Array) -> Array:
	var ids := []
	for loc in locations:
		ids.append(String(loc.get("id", "")))
	return ids


func _find_location(locations: Array, location_id: String) -> Dictionary:
	for loc in locations:
		if String(loc.get("id", "")) == location_id:
			return loc
	return {}


func _ledger_text(gm) -> String:
	var pages: Array = gm.documents.get_document("ledger").get("pages", [])
	var strings: Array[String] = []
	for page in pages:
		strings.append(String(page))
	return "\n".join(PackedStringArray(strings))


func _test_get_locations_breadcrumb() -> void:
	var map := DayMapSystem.new()
	map.load_data()
	map.start_day(2)
	map.set_lead_flag("ryan_warhammer_lead", true)
	var ids_before := _location_ids(map.get_locations())
	_ok(not ids_before.has("abandoned_mine"), "mine hidden before board clue")
	_ok(not ids_before.has("guild_counter"), "counter hidden before reading evidence")
	_ok(ids_before.has("mercenary_board"), "board visible with lead")
	map.visit("mercenary_board")
	var ids_after_board := _location_ids(map.get_locations())
	_ok(ids_after_board.has("abandoned_mine"), "mine appears after board clue")
	_ok(not ids_after_board.has("guild_counter"), "counter still hidden before read")
	map.visit("abandoned_mine")
	map.set_document_read("bloodied_contract", true)
	var ids_after_read := _location_ids(map.get_locations())
	_ok(ids_after_read.has("guild_counter"), "counter appears after reading evidence")


func _test_board_requires_lead() -> void:
	# 告示板现为市集常驻地点；门控落在「贴文」而非地点本身。
	var map := DayMapSystem.new()
	map.load_data()
	map.start_day(2)
	_ok(_location_ids(map.get_locations()).has("mercenary_board"), "board is persistent and visible")
	# 无血斧 lead → 闲置贴文：访问成功但不产 mine_clue（矿道不解锁）
	_ok(map.visit("mercenary_board").get("success", false), "idle board visit succeeds")
	_ok(not _location_ids(map.get_locations()).has("abandoned_mine"), "idle board grants no mine clue")
	# 拿到 lead → 血斧贴文激活：访问产 mine_clue → 矿道解锁
	map.set_lead_flag("ryan_warhammer_lead", true)
	map.visit("mercenary_board")
	_ok(_location_ids(map.get_locations()).has("abandoned_mine"), "ryan posting unlocks the mine")


func _test_day6_toby_choice_chain() -> void:
	var map := DayMapSystem.new()
	_ok(map.load_data(), "Day6 route locations data loads")
	map.start_day(6)
	var ids_before := _location_ids(map.get_locations())
	_ok(ids_before.has("mercenary_board"), "Day6 board is visible before Toby lead")
	_ok(not ids_before.has("toby_lodging"), "Toby lodging is hidden before inference")
	_ok(not ids_before.has("fixer_den"), "fixer is hidden before inference")
	var board := map.visit("mercenary_board")
	_ok(board.get("success", false), "Day6 board visit succeeds")
	_ok(String(board.get("unlockedFlag", "")) == "toby_name_lead", "board returns only Toby name lead unlock")
	var ids_after := _location_ids(map.get_locations())
	_ok(not ids_after.has("toby_lodging"), "Toby lodging does not appear after only reading the board")
	_ok(not ids_after.has("fixer_den"), "fixer does not appear after only reading the board")
	map.set_lead_flag("toby_identity_known", true)
	var ids_after_identity := _location_ids(map.get_locations())
	_ok(ids_after_identity.has("toby_lodging"), "Toby lodging appears after identity inference")
	_ok(not ids_after_identity.has("fixer_den"), "fixer still waits for risk inference")
	map.set_lead_flag("toby_commission_lead", true)
	var ids_after_risk := _location_ids(map.get_locations())
	_ok(ids_after_risk.has("fixer_den"), "fixer appears after commission-risk inference")
	var lodging := _find_location(map.get_locations(), "toby_lodging")
	_ok(String(lodging.get("name", "")) != "托比的落脚处", "map marker avoids naming Toby as known before meeting him")
	_ok(not String(lodging.get("description", "")).begins_with("酒馆后巷，托比"),
		"map marker description avoids describing Toby before meeting him")

	var gm = get_node("/root/GameManager")
	gm._apply_save_state(gm._default_new_game_state())
	gm.economy.current_day = 6
	gm.economy.add_gold(50)
	gm.start_day_map(6)
	_ok(not _location_ids(gm.day_map.get_locations()).has("toby_lodging"), "GM hides Toby lodging before persistent lead")
	var gm_board: Dictionary = gm.visit_day_location("mercenary_board")
	_ok(gm_board.get("success", false), "GM board visit succeeds")
	_ok(gm.narrative.get_var("toby_name_seen") == true, "GM persists only Toby name after board")
	_ok(gm.narrative.get_var("toby_danger_known") != true, "GM does not learn Toby danger from the board alone")
	_ok(_ledger_text(gm).contains("告示板出现黑齿矿脉护送委托"),
		"board visit writes a fate-track pressure beat")
	gm.start_day_map(7)
	_ok(not _location_ids(gm.day_map.get_locations()).has("toby_lodging"), "name lead alone does not unlock lodging next day")
	gm._collect_toby_day6_night_clues_for_test()
	gm.apply_inference_result(gm.inference.try_place("toby_identity", "name", "toby_name"))
	var identity: Dictionary = gm.inference.try_place("toby_identity", "identity", "back_alley_boy")
	gm.apply_inference_result(identity)
	_ok(gm.narrative.get_var("toby_identity_known") == true, "identity inference persists lodging lead")
	gm.start_day_map(7)
	_ok(_location_ids(gm.day_map.get_locations()).has("toby_lodging"), "identity inference unlocks lodging next day")
	_ok(not _location_ids(gm.day_map.get_locations()).has("fixer_den"), "identity inference alone does not unlock fixer")
	var risk_a: Dictionary = gm.inference.try_place("toby_commission_risk", "commission", "blacktooth_escort")
	gm.apply_inference_result(risk_a)
	var risk_b: Dictionary = gm.inference.try_place("toby_commission_risk", "risk", "high_pay_trap")
	gm.apply_inference_result(risk_b)
	var risk_c: Dictionary = gm.inference.try_place("toby_commission_risk", "mindset", "one_person_walk")
	gm.apply_inference_result(risk_c)
	_ok(gm.narrative.get_var("toby_danger_known") == true, "risk inference persists Toby danger")
	gm.start_day_map(7)
	_ok(_location_ids(gm.day_map.get_locations()).has("fixer_den"), "risk inference unlocks fixer route")
	var aff_before: int = gm.narrative.get_affection("mira")
	_ok(gm.visit_day_location("mira_stall").get("success", false), "Mira stall visit succeeds")
	_ok(gm.narrative.get_affection("mira") == aff_before + 3, "Mira stall still grants trust")
	_ok(gm.visit_day_location("mira_stall").get("success", false), "same-day repeat Mira stall visit still succeeds")
	_ok(gm.narrative.get_affection("mira") == aff_before + 3, "same-day repeat Mira stall visit does not stack trust")
	gm.start_day_map(8)
	_ok(gm.visit_day_location("mira_stall").get("success", false), "next-day Mira stall visit succeeds")
	_ok(gm.narrative.get_affection("mira") == aff_before + 6, "next-day Mira stall visit grants trust again")
	_ok(gm.grant_investigation_document("toby_contract"), "Toby contract grant succeeds")
	_ok(gm.narrative.get_var("toby_contract_found") == true, "contract grant marks proof found")
	var fixer: Dictionary = gm.visit_day_location("fixer_den")
	_ok(fixer.get("success", false), "fixer visit succeeds with enough gold")
	_ok(gm.narrative.get_var("toby_secured_by_fixer") == true, "fixer marks Toby secured by fixer")
	_ok(gm.narrative.get_var("toby_secured") == true, "legacy Toby secured flag remains true")

	gm._apply_save_state(gm._default_new_game_state())
	gm.economy.current_day = 6
	gm.economy.add_gold(10)
	gm.start_day_map(6)
	gm.visit_day_location("mercenary_board")
	gm._collect_toby_day6_night_clues_for_test()
	gm.apply_inference_result(gm.inference.try_place("toby_identity", "name", "toby_name"))
	gm.apply_inference_result(gm.inference.try_place("toby_identity", "identity", "back_alley_boy"))
	gm.apply_inference_result(gm.inference.try_place("toby_commission_risk", "commission", "blacktooth_escort"))
	gm.apply_inference_result(gm.inference.try_place("toby_commission_risk", "risk", "high_pay_trap"))
	gm.apply_inference_result(gm.inference.try_place("toby_commission_risk", "mindset", "one_person_walk"))
	gm.start_day_map(6)
	var stamina_before_fixer: int = gm.day_map.stamina
	var poor_fixer: Dictionary = gm.visit_day_location("fixer_den")
	_ok(not poor_fixer.get("success", true), "fixer visit blocks before spending stamina if gold is short")
	_ok(String(poor_fixer.get("blocked_reason", "")) == "not_enough_gold", "fixer block reports insufficient gold")
	_ok(gm.economy.gold == 10, "blocked fixer visit keeps gold unchanged")
	_ok(gm.day_map.stamina == stamina_before_fixer, "blocked fixer visit keeps stamina unchanged")
	_ok(gm.narrative.get_var("toby_secured") != true, "blocked fixer visit does not secure Toby")


func _test_day2_shop_gossip_points_to_sleep_powder() -> void:
	var map := DayMapSystem.new()
	map.load_data()
	map.start_day(2)
	map.set_lead_flag("ryan_warhammer_lead", true)
	var shop: Dictionary = {}
	for loc in map.get_locations():
		if String(loc.get("id", "")) == "market_shop":
			shop = loc
			break
	_ok(not shop.is_empty(), "market shop is visible on day2")
	var gossip: Array = shop.get("gossip", [])
	_ok(not gossip.is_empty(), "market shop carries merchant gossip")
	var hint: Dictionary = gossip[0] if not gossip.is_empty() else {}
	var message := String(hint.get("message", ""))
	_ok(String(hint.get("id", "")) == "sleep_powder_hint", "merchant gossip has stable sleep powder hint id")
	_ok(String(hint.get("hint", "")).contains("传闻"), "merchant gossip exposes a short shop-entry hint")
	_ok(message.contains("菌菇林地"), "merchant gossip names mushroom forest")
	_ok(message.contains("沉睡花粉"), "merchant gossip names sleep powder")
	_ok(message.contains("酒"), "merchant gossip hints that powder can go into drink")


func _test_game_manager_previews_shop_gossip_without_consuming() -> void:
	var gm = get_node("/root/GameManager")
	_ok(gm.has_method("peek_shop_gossip"), "GameManager exposes peek_shop_gossip")
	if not gm.has_method("peek_shop_gossip"):
		return
	gm._apply_save_state(gm._default_new_game_state())
	gm.narrative.set_var("ryan_warhammer_lead", true)
	gm.start_day_map(2)
	var preview: Dictionary = gm.peek_shop_gossip("market_shop")
	_ok(bool(preview.get("success", false)), "shop gossip preview is available after Ryan lead")
	_ok(String(preview.get("hint", "")).contains("传闻"), "shop gossip preview provides map-detail hint text")
	_ok(not bool(gm.narrative.get_var("merchant_sleep_powder_hint_seen")), "previewing shop gossip does not mark it seen")


func _test_game_manager_consumes_shop_gossip_once() -> void:
	var gm = get_node("/root/GameManager")
	_ok(gm.has_method("consume_shop_gossip"), "GameManager exposes consume_shop_gossip")
	if not gm.has_method("consume_shop_gossip"):
		return
	gm._apply_save_state(gm._default_new_game_state())
	gm.narrative.set_var("ryan_warhammer_lead", true)
	gm.start_day_map(2)
	var gossip: Dictionary = gm.consume_shop_gossip("market_shop")
	_ok(bool(gossip.get("success", false)), "day2 shop gossip is available after Ryan lead")
	_ok(String(gossip.get("message", "")).contains("菌菇林地"), "consumed gossip points to mushroom forest")
	_ok(bool(gm.narrative.get_var("merchant_sleep_powder_hint_seen")), "consuming gossip records seen flag")
	var repeated: Dictionary = gm.consume_shop_gossip("market_shop")
	_ok(not bool(repeated.get("success", true)), "merchant gossip is only shown once")
	gm.narrative.set_var("merchant_sleep_powder_hint_seen", false)
	gm.add_to_inventory("sleep_powder", 1)
	var already_has_powder: Dictionary = gm.consume_shop_gossip("market_shop")
	_ok(not bool(already_has_powder.get("success", true)), "merchant gossip is skipped after player has sleep powder")


func _test_shop_button_checks_gossip_before_opening() -> void:
	var script := FileAccess.open("res://scripts/ui/day_map_view.gd", FileAccess.READ)
	_ok(script != null, "DayMapView script is readable for shop gossip contract")
	if script == null:
		return
	var source := script.get_as_text()
	script.close()
	_ok(source.contains("peek_shop_gossip"), "DayMap shop detail previews merchant gossip before opening shop")
	_ok(source.contains("听传闻"), "DayMap shop action text tells the player there is gossip")
	_ok(source.contains("consume_shop_gossip"), "DayMap shop button checks merchant gossip before opening shop")
	_ok(source.contains("_pending_shop_after_gossip"), "DayMap can continue into shop after gossip panel")


func _test_reveal_tracking() -> void:
	var map := DayMapSystem.new()
	map.load_data()
	map.start_day(2)
	var forest: Dictionary = {}
	for loc in map.get_locations():
		if String(loc.get("id", "")) == "mushroom_forest":
			forest = loc
	_ok(forest.has("pos"), "location dict carries pos field")
	_ok(forest["pos"].size() == 2, "pos is [x, y]")
	_ok(not map.is_revealed("mushroom_forest"), "location starts unrevealed")
	var new_ids := _location_ids(map.get_new_locations())
	_ok(new_ids.has("mushroom_forest"), "unrevealed visible location is 'new'")
	map.mark_revealed("mushroom_forest")
	_ok(map.is_revealed("mushroom_forest"), "mark_revealed sticks")
	_ok(not _location_ids(map.get_new_locations()).has("mushroom_forest"), "revealed location not 'new'")
	map.start_day(3)
	_ok(map.is_revealed("mushroom_forest"), "reveal persists across start_day")


func _test_intro_handoff_timing_contract() -> void:
	var script := FileAccess.open("res://scripts/ui/day_map_view.gd", FileAccess.READ)
	_ok(script != null, "DayMapView script is readable")
	if script == null:
		return
	var source := script.get_as_text()
	script.close()
	_ok(source.contains("const INTRO_HANDOFF_ZOOM"), "intro handoff uses a named zoom constant")
	_ok(source.contains("const INTRO_HANDOFF_DURATION"), "intro handoff uses a named duration constant")
	_ok(not source.contains("_camera.zoom = Vector2(_camera.MAX_ZOOM, _camera.MAX_ZOOM)"), "intro handoff does not start at hard max zoom")
