extends Node

var _checks := 0
var _failures := 0


func _ready() -> void:
	_test_files_exist()
	if _failures == 0:
		_test_rumor_system_grants_and_restores()
		_test_appetite_system_scores_customer_food_matches()
		_test_expanded_product_tag_coverage()
		_test_rumor_pool_menu_coverage()
		_test_guest_group_profiles_drive_orders()
		_test_game_manager_preserves_group_guest_portrait_id()
		_test_regular_customer_traits_are_exposed()
		_test_regular_customer_memory_persists()
		_test_game_manager_grants_location_rumors()
		_test_game_manager_enriches_rumor_customer_preview()
		_test_game_manager_records_word_of_mouth_bias()
		_test_game_manager_exposes_menu_preparation_echoes()
		_test_game_manager_recommends_menu_products()
		_test_tavern_view_exposes_menu_preparation_contract()
		_test_game_manager_exposes_rumor_match_feedback()
	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-RUMOR-APPETITE] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-RUMOR-APPETITE] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-RUMOR-APPETITE] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _test_files_exist() -> void:
	for path in [
		"res://data/rumors.json",
		"res://data/guest_appetites.json",
		"res://data/guest_group_profiles.json",
		"res://scripts/systems/rumor_system.gd",
		"res://scripts/systems/appetite_system.gd",
	]:
		_ok(ResourceLoader.exists(path) or FileAccess.file_exists(path), "required rumor/appetite file exists: " + path)


func _new_rumor_system():
	var script := load("res://scripts/systems/rumor_system.gd")
	_ok(script != null, "RumorSystem script loads")
	if script == null:
		return null
	return script.new()


func _new_appetite_system():
	var script := load("res://scripts/systems/appetite_system.gd")
	_ok(script != null, "AppetiteSystem script loads")
	if script == null:
		return null
	return script.new()


func _load_json_dictionary(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	_ok(file != null, "json file is readable: " + path)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	_ok(parsed is Dictionary, "json file parses as dictionary: " + path)
	if not parsed is Dictionary:
		return {}
	return parsed


func _all_orderable_products_for_coverage() -> Array[String]:
	var craft := CraftSystem.new()
	craft.load_data()
	for product_key in craft.recipes.keys():
		craft.discover_recipe(String(product_key))
		craft.unlock_recipe(String(product_key))
	return craft.get_orderable_products(30)


func _products_matching_tags(appetite, product_keys: Array[String], tags: Array) -> Array[String]:
	var result: Array[String] = []
	for product_key in product_keys:
		var product_tags: Array = appetite.get_product_tags(product_key)
		for raw_tag in tags:
			var tag := String(raw_tag)
			if tag == "":
				continue
			if product_tags.has(tag):
				result.append(product_key)
				break
	return result


func _test_rumor_system_grants_and_restores() -> void:
	var rumors = _new_rumor_system()
	if rumors == null:
		return
	_ok(rumors.load_data(), "rumor data loads")
	rumors.start_day(2)
	var first: Dictionary = rumors.grant_location_rumor("mercenary_board", 2, {"ryan_warhammer_lead": true})
	_ok(bool(first.get("success", false)), "mercenary board grants a day-two rumor after the Ryan lead")
	_ok(String(first.get("text", "")).contains("矿"), "granted rumor text is player-facing")
	_ok(first.has("menuHints"), "granted rumor carries readable menu-planning hints")
	_ok(first.has("affectedCustomerIds"), "granted rumor exposes affected regular customer ids")
	_ok((first.get("affectedCustomerIds", []) as Array).has("regular_belta"), "mine-shift rumor marks Belta as affected")
	var hints: Dictionary = first.get("menuHints", {})
	_ok((hints.get("customerGroups", []) as Array).size() > 0, "rumor hint names likely customer groups")
	_ok((hints.get("recommendedTags", []) as Array).has("顶饿"), "rumor hint recommends a readable food tag")
	_ok(String(hints.get("summary", "")) != "", "rumor hint includes one-line planning summary")
	_ok(rumors.get_today_rumors().size() == 1, "today rumor list records the grant")
	var repeat: Dictionary = rumors.grant_location_rumor("mercenary_board", 2, {"ryan_warhammer_lead": true})
	_ok(not bool(repeat.get("success", true)), "same location rumor is not granted twice in one save")
	var bias: Dictionary = rumors.get_guest_bias()
	_ok(float(bias.get("mine", 1.0)) > 1.0, "granted rumor exposes mine guest bias")
	var snap: Dictionary = rumors.capture_state()
	var restored = _new_rumor_system()
	if restored == null:
		return
	_ok(restored.load_data(), "restored rumor data loads")
	restored.restore_state(snap)
	_ok(restored.get_today_rumors().size() == 1, "today rumor list survives restore")
	_ok(not bool(restored.grant_location_rumor("mercenary_board", 2, {"ryan_warhammer_lead": true}).get("success", true)),
		"restored heard rumor stays consumed")


func _test_appetite_system_scores_customer_food_matches() -> void:
	var appetite = _new_appetite_system()
	if appetite == null:
		return
	_ok(appetite.load_data(), "appetite data loads")
	var strong: Dictionary = appetite.evaluate("regular_belta", "meat_stew", "good", "")
	_ok(String(strong.get("tier", "")) == "delighted", "Belta is delighted by good hearty meat stew")
	_ok(int(strong.get("bonus_gold", 0)) > 0, "delighted appetite grants bonus gold")
	_ok(int(strong.get("bonus_rep", 0)) > 0, "delighted appetite grants bonus reputation")
	_ok((strong.get("matched_attributes", []) as Array).has("might"), "strong match reports might attribute")
	var weak: Dictionary = appetite.evaluate("regular_belta", "herb_tea", "normal", "")
	_ok(String(weak.get("tier", "")) != "delighted", "Belta is not delighted by ordinary herb tea")
	var scented: Dictionary = appetite.evaluate("regular_elira", "herb_tea", "normal", "清香")
	_ok(float(scented.get("score", 0.0)) > float(weak.get("score", 0.0)), "matching seasoning can improve appetite score")
	_ok(appetite.has_method("get_product_tags"), "AppetiteSystem exposes product tags for menu planning")
	if appetite.has_method("get_product_tags"):
		var stew_tags: Array = appetite.get_product_tags("meat_stew")
		_ok(stew_tags.has("顶饿"), "hearty stew advertises the filling tag")
		_ok(stew_tags.has("力量"), "hearty stew advertises the strength tag")
		var tea_tags: Array = appetite.get_product_tags("herb_tea")
		_ok(tea_tags.has("清香"), "herb tea advertises the clear-scent tag")
	_ok((strong.get("matched_tags", []) as Array).has("顶饿"), "appetite match reports readable matched tags")


func _test_expanded_product_tag_coverage() -> void:
	var appetite = _new_appetite_system()
	if appetite == null:
		return
	_ok(appetite.load_data(), "appetite data loads for expanded product tag coverage")
	for product_key in [
		"miner_dark_ale",
		"old_road_wine",
		"rock_lizard_steak",
		"cave_mushroom_stew",
	]:
		var tags: Array = appetite.get_product_tags(product_key)
		_ok(tags.size() >= 2, "%s has at least two menu-planning tags" % product_key)


func _test_rumor_pool_menu_coverage() -> void:
	var data := _load_json_dictionary("res://data/rumors.json")
	var rumor_list: Array = data.get("rumors", [])
	_ok(rumor_list.size() >= 13, "rumor pool has enough entries for the first content expansion")
	var appetite = _new_appetite_system()
	if appetite == null:
		return
	_ok(appetite.load_data(), "appetite data loads for rumor menu coverage")
	var products := _all_orderable_products_for_coverage()
	_ok(products.size() >= 12, "expanded orderable product pool has enough candidates")
	var seen_ids: Dictionary = {}
	for raw in rumor_list:
		if not raw is Dictionary:
			_ok(false, "rumor entry is a dictionary")
			continue
		var rumor: Dictionary = raw
		var id := String(rumor.get("id", ""))
		_ok(id != "", "rumor has id")
		_ok(not bool(seen_ids.get(id, false)), "rumor id is unique: " + id)
		seen_ids[id] = true
		var menu_hints: Dictionary = rumor.get("menuHints", {})
		var recommended_tags: Array = menu_hints.get("recommendedTags", [])
		_ok(String(menu_hints.get("summary", "")) != "", "rumor has menu hint summary: " + id)
		_ok(recommended_tags.size() >= 2, "rumor has multiple recommended tags: " + id)
		var effects: Dictionary = rumor.get("effects", {})
		var guest_bias: Dictionary = effects.get("guestBias", {})
		_ok(not guest_bias.is_empty(), "rumor has guest bias effects: " + id)
		var matches := _products_matching_tags(appetite, products, recommended_tags)
		_ok(matches.size() >= 2, "rumor has at least two matching menu products: %s -> %s" % [id, ", ".join(matches)])


func _test_guest_group_profiles_drive_orders() -> void:
	var data := _load_json_dictionary("res://data/guest_group_profiles.json")
	var profiles: Dictionary = data.get("groups", {})
	for group_key in ["mine", "trade", "herbal", "ledger", "old_road"]:
		var profile: Dictionary = profiles.get(group_key, {})
		_ok(not profile.is_empty(), "guest group profile exists: " + group_key)
		_ok(String(profile.get("displayName", "")) != "", "guest group has display name: " + group_key)
		_ok((profile.get("preferredTags", []) as Array).size() >= 2, "guest group has preferred tags: " + group_key)
		_ok((profile.get("fallbackOrders", []) as Array).size() >= 2, "guest group has fallback orders: " + group_key)
		var portrait_pool: Array = profile.get("portraitPool", [])
		_ok(portrait_pool.size() >= 2, "guest group has a portrait pool: " + group_key)
		for portrait_id in portrait_pool:
			var portrait_key := String(portrait_id)
			_ok(portrait_key.begins_with("regular_"), "guest group portrait uses regular customer art: " + group_key)
			_ok(ResourceLoader.exists("res://assets/textures/characters/%s_neutral.png" % portrait_key),
				"guest group portrait exists: " + portrait_key)
		_ok((profile.get("matchLines", []) as Array).size() >= 1, "guest group has match feedback: " + group_key)
	var menu_items := [
		{"key": "herb_tea"},
		{"key": "meat_stew"},
		{"key": "ale_beer"},
	]
	var guest_system := GuestSystem.new(func(): return menu_items)
	_ok(guest_system.has_method("get_guest_group_profile"), "GuestSystem exposes group profile lookup")
	_ok(guest_system.has_method("choose_guest_group_order"), "GuestSystem chooses orders from group profile tags")
	_ok(guest_system.has_method("_spawn_group_guest"), "GuestSystem can spawn a group-backed anonymous guest")
	_ok(guest_system.has_method("get_group_match_feedback"), "GuestSystem exposes group match feedback")
	if not guest_system.has_method("get_guest_group_profile") \
			or not guest_system.has_method("choose_guest_group_order") \
			or not guest_system.has_method("_spawn_group_guest") \
			or not guest_system.has_method("get_group_match_feedback"):
		return
	var mine: Dictionary = guest_system.get_guest_group_profile("mine")
	_ok((mine.get("preferredTags", []) as Array).has("顶饿"), "mine group prefers hearty food")
	var order_key := String(guest_system.choose_guest_group_order("mine", menu_items))
	_ok(order_key == "meat_stew", "mine group chooses a hearty item when the menu offers one")
	guest_system._spawn_group_guest("mine", menu_items)
	_ok(guest_system.has_guest, "group guest spawn creates current guest")
	_ok(String(guest_system.current_guest.get_meta("guest_group", "")) == "mine", "group guest carries guest_group metadata")
	_ok(String(guest_system.current_guest.get_meta("template_id", "")) == "group_mine", "group guest carries a stable template id")
	var portrait_id := String(guest_system.current_guest.get_meta("portrait_id", ""))
	_ok(portrait_id != "" and portrait_id != "guest", "group guest carries a non-placeholder portrait id")
	_ok(ResourceLoader.exists("res://assets/textures/characters/%s_neutral.png" % portrait_id),
		"group guest portrait id resolves to runtime art")
	var line := String(guest_system.get_group_match_feedback("mine", ["顶饿", "热食"]))
	_ok(line != "", "group match feedback returns a line for preferred tags")
	var miss := String(guest_system.get_group_match_feedback("mine", ["清香"]))
	_ok(miss == "", "group match feedback stays quiet for unrelated tags")


func _test_game_manager_preserves_group_guest_portrait_id() -> void:
	var gm = get_node("/root/GameManager")
	_ok(gm != null and gm.has_method("_on_guest_arrived"), "GameManager exposes guest arrival handler")
	if gm == null or not gm.has_method("_on_guest_arrived"):
		return
	var guest := GuestData.new()
	guest.guest_name = "Group Guest"
	guest.order_key = "herb_tea"
	guest.npc_id = ""
	guest.has_dialogue = false
	guest.set_meta("portrait_id", "regular_jora")
	gm._on_guest_arrived(guest)
	_ok(String(guest.get_meta("portrait_id", "")) == "regular_jora",
		"GameManager preserves anonymous group guest portrait identity")


func _test_regular_customer_traits_are_exposed() -> void:
	var guest_system := GuestSystem.new(func(): return [{"key": "meat_stew"}])
	var preview: Dictionary = guest_system.get_regular_customer_preview("regular_belta")
	_ok(preview.has("trait"), "regular customer preview exposes a gameplay trait")
	var trait_info: Dictionary = preview.get("trait", {})
	_ok(String(trait_info.get("name", "")) == "顶饿熟客", "Belta has a readable hearty-regular trait")
	_ok((trait_info.get("focusTags", []) as Array).has("顶饿"), "regular trait names the tags it cares about")
	var memory: Dictionary = guest_system.record_customer_memory("regular_belta", "meat_stew", "肉汤", ["顶饿", "热食"], 2, "传闻应验")
	_ok(String((memory.get("trait", {}) as Dictionary).get("name", "")) == "顶饿熟客", "customer memory reports the triggered trait")
	var summary: Dictionary = guest_system.get_customer_memory_summary("regular_belta")
	_ok(String((summary.get("trait", {}) as Dictionary).get("name", "")) == "顶饿熟客", "customer memory summary includes trait context")


func _test_regular_customer_memory_persists() -> void:
	var guest_system := GuestSystem.new(func(): return [{"key": "meat_stew"}])
	_ok(guest_system.has_method("record_customer_memory"), "GuestSystem can record regular customer food memories")
	_ok(guest_system.has_method("get_customer_memory_summary"), "GuestSystem can expose regular customer memory summaries")
	if not guest_system.has_method("record_customer_memory") or not guest_system.has_method("get_customer_memory_summary"):
		return
	var memory: Dictionary = guest_system.record_customer_memory("regular_belta", "meat_stew", "肉汤", ["顶饿", "热食"], 2, "传闻应验")
	_ok(String(memory.get("customer_name", "")) == "贝尔塔", "customer memory resolves display name")
	_ok(String(memory.get("item_name", "")) == "肉汤", "customer memory records the remembered dish")
	_ok((memory.get("tags", []) as Array).has("顶饿"), "customer memory records matched readable tags")
	var summary: Dictionary = guest_system.get_customer_memory_summary("regular_belta")
	_ok((summary.get("remembered_tags", []) as Array).has("顶饿"), "customer memory summary exposes remembered tags")
	_ok((summary.get("remembered_orders", []) as Array).has("meat_stew"), "customer memory summary exposes remembered dishes")
	_ok((summary.get("notes", []) as Array).size() > 0, "customer memory summary exposes player-facing notes")
	var snap: Dictionary = guest_system.capture_state()
	var restored := GuestSystem.new(func(): return [{"key": "meat_stew"}])
	restored.restore_state(snap)
	var restored_summary: Dictionary = restored.get_customer_memory_summary("regular_belta")
	_ok((restored_summary.get("remembered_tags", []) as Array).has("热食"), "customer memory survives guest state restore")


func _test_game_manager_grants_location_rumors() -> void:
	var gm = get_node("/root/GameManager")
	_ok(gm.has_method("get_today_rumors"), "GameManager exposes current-day rumors")
	if not gm.has_method("get_today_rumors"):
		return
	gm._apply_save_state(gm._default_new_game_state())
	gm.narrative.set_var("ryan_warhammer_lead", true)
	gm.start_day_map(2)
	var result: Dictionary = gm.visit_day_location("mercenary_board")
	_ok(bool(result.get("success", false)), "GM visit to mercenary board succeeds")
	_ok(result.has("rumor"), "GM visit result includes rumor payload")
	_ok(String(result.get("message", "")).contains("听到传闻"), "GM appends rumor copy to visit message")
	_ok(gm.get_today_rumors().size() == 1, "GM stores the heard rumor for menu prep")


func _test_game_manager_enriches_rumor_customer_preview() -> void:
	var gm = get_node("/root/GameManager")
	if not gm.has_method("get_today_rumors"):
		return
	gm._apply_save_state(gm._default_new_game_state())
	gm.narrative.set_var("ryan_warhammer_lead", true)
	gm.start_day_map(2)
	gm.visit_day_location("mercenary_board")
	var today: Array = gm.get_today_rumors()
	_ok(today.size() == 1, "GM has one rumor to enrich for menu prep")
	if today.is_empty():
		return
	var first: Dictionary = today[0]
	_ok(first.has("affectedCustomers"), "GM rumor payload includes readable affected customer previews")
	var customers: Array = first.get("affectedCustomers", [])
	_ok(customers.size() > 0, "affected customer preview list is not empty")
	var found_belta := false
	for raw in customers:
		if not raw is Dictionary:
			continue
		var customer: Dictionary = raw
		if String(customer.get("id", "")) == "regular_belta":
			found_belta = String(customer.get("name", "")) != "" and String(customer.get("name", "")) != "regular_belta"
	_ok(found_belta, "affected customer preview resolves Belta's display name")


func _test_game_manager_records_word_of_mouth_bias() -> void:
	var gm = get_node("/root/GameManager")
	_ok(gm.has_method("_record_customer_memory_from_appetite"), "GameManager can record customer memory from appetite hits")
	_ok(gm.has_method("_combined_guest_bias_for_night"), "GameManager can combine rumor and word-of-mouth guest bias")
	if not gm.has_method("_record_customer_memory_from_appetite") or not gm.has_method("_combined_guest_bias_for_night"):
		return
	gm._apply_save_state(gm._default_new_game_state())
	gm.economy.current_day = 2
	if gm.rumors != null:
		gm.rumors.restore_state({
			"current_day": 2,
			"heard_ids": ["mercenary_board_mine_shift"],
			"today_ids": ["mercenary_board_mine_shift"],
		})
	var memory: Dictionary = gm._record_customer_memory_from_appetite("regular_belta", "meat_stew", "肉汤", {
		"tier": "delighted",
		"matched_tags": ["顶饿", "热食"],
	})
	_ok(String(memory.get("customer_name", "")) == "贝尔塔", "GM memory event names the affected customer")
	_ok((memory.get("word_of_mouth_labels", []) as Array).has("矿口口碑 +1"), "GM memory event records group word-of-mouth feedback")
	var bias: Dictionary = gm._combined_guest_bias_for_night()
	_ok(float(bias.get("mine", 1.0)) > 1.0, "word-of-mouth contributes future mine guest bias")
	_ok(float(bias.get("regular_belta", 1.0)) > 1.0, "word-of-mouth contributes future named customer bias")
	var save_state: Dictionary = gm._capture_save_state()
	_ok(int((save_state.get("word_of_mouth", {}) as Dictionary).get("mine", 0)) > 0, "word-of-mouth is captured in save state")


func _test_game_manager_exposes_menu_preparation_echoes() -> void:
	var gm = get_node("/root/GameManager")
	_ok(gm.has_method("get_menu_preparation_echoes"), "GameManager exposes previous-night echoes for menu planning")
	if not gm.has_method("get_menu_preparation_echoes") or not gm.has_method("_record_customer_memory_from_appetite"):
		return
	gm._apply_save_state(gm._default_new_game_state())
	gm.economy.current_day = 3
	if gm.rumors != null:
		gm.rumors.restore_state({
			"current_day": 3,
			"heard_ids": ["mercenary_board_mine_shift"],
			"today_ids": ["mercenary_board_mine_shift"],
		})
	gm._record_customer_memory_from_appetite("regular_belta", "meat_stew", "肉汤", {
		"tier": "delighted",
		"matched_tags": ["顶饿", "热食"],
	})
	var echoes: Array = gm.get_menu_preparation_echoes()
	var combined := ""
	for raw in echoes:
		if raw is Dictionary:
			var echo: Dictionary = raw
			combined += String(echo.get("title", "")) + "\n" + String(echo.get("detail", "")) + "\n"
	_ok(combined.contains("矿口口碑升温"), "menu preparation echoes explain rising word-of-mouth")
	_ok(combined.contains("贝尔塔记住了肉汤"), "menu preparation echoes include customer memory notes")
	_ok(combined.contains("顶饿熟客"), "menu preparation echoes include trait context")


func _test_game_manager_recommends_menu_products() -> void:
	var gm = get_node("/root/GameManager")
	_ok(gm.has_method("get_menu_product_recommendation"), "GameManager recommends menu products with concise chips and reasons")
	if not gm.has_method("get_menu_product_recommendation") or not gm.has_method("_record_customer_memory_from_appetite"):
		return
	gm._apply_save_state(gm._default_new_game_state())
	gm.economy.current_day = 3
	if gm.rumors != null:
		gm.rumors.restore_state({
			"current_day": 3,
			"heard_ids": ["mercenary_board_mine_shift"],
			"today_ids": ["mercenary_board_mine_shift"],
		})
	gm._record_customer_memory_from_appetite("regular_belta", "meat_stew", "肉汤", {
		"tier": "delighted",
		"matched_tags": ["顶饿", "热食"],
	})
	var recommendation: Dictionary = gm.get_menu_product_recommendation("meat_stew")
	var chips: Array = recommendation.get("chips", [])
	var reasons: Array = recommendation.get("reasons", [])
	var reason_text := ""
	for reason in reasons:
		reason_text += String(reason) + "\n"
	_ok(chips.has("★贝尔塔"), "recommendation chips name the remembered regular customer")
	_ok(chips.has("★矿口"), "recommendation chips name the matching rumor/word-of-mouth group")
	_ok(reason_text.contains("贝尔塔"), "recommendation reasons explain the customer memory match")
	_ok(reason_text.contains("传闻") or reason_text.contains("矿口"), "recommendation reasons explain the rumor or word-of-mouth match")


func _test_tavern_view_exposes_menu_preparation_contract() -> void:
	var script := FileAccess.open("res://scripts/ui/tavern_view.gd", FileAccess.READ)
	_ok(script != null, "TavernView script is readable")
	if script == null:
		return
	var source := script.get_as_text()
	script.close()
	_ok(source.contains("configure_menu_preparation"), "TavernView exposes menu preparation configuration")
	_ok(source.contains("MAX_DAILY_MENU_ITEMS"), "TavernView has a fixed daily menu limit")
	_ok(source.contains("daily_menu_confirmed = false"), "TavernView can hold service until menu confirmation")
	_ok(source.contains("on_menu_confirmed"), "TavernView confirms menu through GameManager")
	_ok(source.contains("configure_menu_preparation(rumors: Array = [], echoes: Array = [])"), "TavernView accepts yesterday echoes in menu preparation")
	_ok(source.contains("customerGroups"), "TavernView renders likely customer groups from rumors")
	_ok(source.contains("affectedCustomers"), "TavernView renders affected named customers from rumors")
	_ok(source.contains("可能来"), "TavernView labels likely arriving customers")
	_ok(source.contains("recommendedTags"), "TavernView renders recommended tags from rumors")
	_ok(source.contains("YesterdayEchoList"), "TavernView has a bounded yesterday echo list")
	_ok(source.contains("昨日回响"), "TavernView labels previous-night planning feedback")
	_ok(source.contains("get_product_tags"), "TavernView labels menu products with readable food tags")
	_ok(source.contains("MenuPrepReasonLabel"), "TavernView has a bounded product recommendation detail label")
	_ok(source.contains("_menu_product_recommendation_text"), "TavernView renders short recommendation chips on menu buttons")
	_ok(source.contains("_refresh_menu_prep_reason"), "TavernView refreshes product recommendation detail text")


func _test_game_manager_exposes_rumor_match_feedback() -> void:
	var script := FileAccess.open("res://scripts/game_manager.gd", FileAccess.READ)
	_ok(script != null, "GameManager script is readable")
	if script == null:
		return
	var source := script.get_as_text()
	script.close()
	_ok(source.contains("传闻应验"), "GameManager adds explicit rumor-hit feedback to successful appetite matches")
