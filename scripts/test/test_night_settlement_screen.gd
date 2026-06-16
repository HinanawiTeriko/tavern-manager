extends Node

var _checks := 0
var _failures := 0


func _ready() -> void:
	var gm = get_node("/root/GameManager")
	_test_guest_entries_grow_and_capture_resolution()
	_test_game_manager_builds_ledger_data_with_guest_entries(gm)

	var data := LedgerData.new()
	data.day = 3
	data.gold_today = 42
	data.rep_today = -1
	data.gold_total = 128
	data.rep_total = 7
	data.guests_served = 5
	data.orders_success = 4
	data.orders_failed = 1
	data.guest_entries = [
		{"npc_id": "regular_noel", "display_name": "Noel", "result": "success", "gold_delta": 8, "rep_delta": 2, "served_delta": 1, "success_delta": 1, "failed_delta": 0},
		{"npc_id": "ryan", "display_name": "Ryan", "result": "failed", "gold_delta": 0, "rep_delta": 0, "served_delta": 1, "success_delta": 0, "failed_delta": 1},
		{"npc_id": "regular_belta", "display_name": "Belta", "result": "success", "gold_delta": 34, "rep_delta": -3, "served_delta": 3, "success_delta": 3, "failed_delta": 0},
	]
	data.npc_fates = [
		{"npc_name": "米拉", "npc_title": "行商", "fate_text": "她把今晚的传闻收进了斗篷。"},
	]

	var tm = get_node_or_null("/root/TutorialManager")
	if tm != null:
		tm.first_ledger_shown = true

	var screen = await _make_screen(data)

	_test_preserved_nodes(screen)
	_test_new_art_nodes(screen)
	_test_aftermath_panel_hidden_but_contract_preserved(screen)
	_test_guest_silhouette_stage(screen)
	_test_revised_silhouette_queue_motion_contract(screen)
	_test_counter_board_impact_contract(screen)
	_test_score_counters_can_complete_to_authoritative_totals(screen)
	_test_dynamic_data(screen)
	_test_fate_reveal_notice(screen)
	_test_compact_stats_rows(screen)
	_test_continue_button_art(screen)
	_test_pixel_fonts(screen)
	_test_no_ryan_cinematic_for_non_ryan_fates(screen)

	screen.queue_free()
	await get_tree().process_frame

	var empty_data := LedgerData.new()
	empty_data.day = 4
	empty_data.gold_today = 0
	empty_data.rep_today = 0
	empty_data.gold_total = 128
	empty_data.rep_total = 7
	empty_data.guests_served = 2
	empty_data.orders_success = 2
	empty_data.orders_failed = 0
	empty_data.npc_fates = []
	var empty_screen = await _make_screen(empty_data)
	_test_no_fate_reveal_notice_without_fates(empty_screen)
	empty_screen.queue_free()
	await get_tree().process_frame

	var preview_data := LedgerData.new()
	preview_data.day = 1
	preview_data.gold_today = 8
	preview_data.rep_today = 0
	preview_data.gold_total = 24
	preview_data.rep_total = 1
	preview_data.guests_served = 2
	preview_data.orders_success = 2
	preview_data.orders_failed = 0
	preview_data.npc_fates = []
	preview_data.fate_warning_next_day = true
	var preview_screen = await _make_screen(preview_data)
	_test_fate_preview_notice(preview_screen)
	preview_screen.queue_free()
	await get_tree().process_frame

	await _test_fate_notice_waits_for_ledger_tutorial(data)
	await _test_tutorial_then_fate_presentation_then_score_replay_order()

	_test_ryan_fate_only_reveals_on_reveal_day(gm)
	_test_narrative_fates_include_route_keys(gm)

	var ryan_data := LedgerData.new()
	ryan_data.day = 3
	ryan_data.gold_today = 12
	ryan_data.rep_today = 0
	ryan_data.gold_total = 64
	ryan_data.rep_total = 2
	ryan_data.guests_served = 3
	ryan_data.orders_success = 3
	ryan_data.orders_failed = 0
	ryan_data.npc_fates = [
		{
			"npc_id": "ryan",
			"ending_key": "alternative_survivor",
			"npc_name": "莱恩",
			"npc_title": "见习骑士",
			"fate_text": "莱恩带着替代委托离开，放弃了血斧小队和白银阶的快速晋升，改走更慢的安全路线。"
		},
	]
	var ryan_screen = await _make_screen(ryan_data)
	_test_ryan_cinematic_overlay(ryan_screen)
	await _test_ryan_cinematic_dismisses_on_click(ryan_screen)
	ryan_screen.queue_free()
	await get_tree().process_frame

	var mira_data := LedgerData.new()
	mira_data.day = 12
	mira_data.gold_today = 18
	mira_data.rep_today = 1
	mira_data.gold_total = 72
	mira_data.rep_total = 5
	mira_data.guests_served = 4
	mira_data.orders_success = 4
	mira_data.orders_failed = 0
	mira_data.npc_fates = [
		{
			"npc_id": "mira",
			"ending_key": "she_finally_stopped",
			"npc_name": "Mira",
			"npc_title": "Merchant",
			"fate_text": "Mira tears up the long supply contract and turns back for Toby."
		},
	]
	var mira_screen = await _make_screen(mira_data)
	_test_mira_cinematic_overlay(mira_screen)
	await _test_mira_cinematic_dismisses_on_click(mira_screen)
	mira_screen.queue_free()
	await get_tree().process_frame

	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-NIGHT-SETTLEMENT] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-NIGHT-SETTLEMENT] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-NIGHT-SETTLEMENT] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _make_screen(data: LedgerData):
	var gm = get_node("/root/GameManager")
	gm.current_ledger_data = data
	var scene := preload("res://scenes/ui/LedgerScreen.tscn")
	var screen = scene.instantiate()
	add_child(screen)
	await get_tree().process_frame
	return screen


func _test_guest_entries_grow_and_capture_resolution() -> void:
	var guest_system := GuestSystem.new(func(): return [{"key": "ale_beer"}])
	guest_system.spawn_important("ryan", "ale_beer")

	var pending_entries: Array = guest_system.get_guest_entries_today()
	_ok(pending_entries.size() == 1, "guest entry is recorded when a guest appears")
	if pending_entries.size() > 0:
		_ok(String(pending_entries[0].get("npc_id", "")) == "ryan", "guest entry stores npc_id")
		_ok(String(pending_entries[0].get("result", "")) == "pending", "new guest entry starts pending")

	guest_system.record_order_success(12, 2)
	guest_system.record_guest_served()
	var success_entries: Array = guest_system.get_guest_entries_today()
	if success_entries.size() > 0:
		var entry: Dictionary = success_entries[0]
		_ok(String(entry.get("result", "")) == "success", "successful service resolves the current guest entry")
		_ok(int(entry.get("gold_delta", -1)) == 12, "successful guest entry stores real gold delta")
		_ok(int(entry.get("rep_delta", -1)) == 2, "successful guest entry stores real reputation delta")
		_ok(int(entry.get("served_delta", 0)) == 1, "successful guest entry increments served count")
		_ok(int(entry.get("success_delta", 0)) == 1, "successful guest entry increments success count")
		_ok(int(entry.get("failed_delta", 1)) == 0, "successful guest entry does not increment failed count")

	guest_system.clear_guest()
	guest_system.spawn_important("toby", "bread")
	guest_system.record_order_failed(0, 0, "failed")
	var failed_entries: Array = guest_system.get_guest_entries_today()
	_ok(failed_entries.size() == 2, "second guest entry is appended instead of replacing the first")
	if failed_entries.size() > 1:
		var failed_entry: Dictionary = failed_entries[1]
		_ok(String(failed_entry.get("npc_id", "")) == "toby", "failed guest entry stores npc_id")
		_ok(String(failed_entry.get("result", "")) == "failed", "failed service resolves the current guest entry")
		_ok(int(failed_entry.get("failed_delta", 0)) == 1, "failed guest entry increments failed count")


func _test_game_manager_builds_ledger_data_with_guest_entries(gm: Node) -> void:
	var original_ledger = gm.current_ledger_data
	var original_day: int = gm.economy.current_day
	var original_gold_today: int = gm.economy.gold_today
	var original_rep_today: int = gm.economy.rep_today

	gm.economy.current_day = 99
	gm.economy.gold_today = 12
	gm.economy.rep_today = 2
	gm.guests.reset_daily()
	gm.guests.spawn_important("ryan", "ale_beer")
	gm.guests.record_order_success(12, 2)
	gm.guests.record_guest_served()
	gm.guests.clear_guest()

	_ok(gm.has_method("_create_ledger_data_for_current_day"), "GameManager exposes internal ledger data builder")
	var ledger_data = gm._create_ledger_data_for_current_day() if gm.has_method("_create_ledger_data_for_current_day") else null
	_ok(ledger_data != null, "ledger data builder returns data")
	if ledger_data != null:
		_ok(ledger_data.guest_entries.size() == 1, "ledger data receives guest entry snapshot")
		if ledger_data.guest_entries.size() > 0:
			var entry: Dictionary = ledger_data.guest_entries[0]
			_ok(String(entry.get("npc_id", "")) == "ryan", "ledger guest entry preserves npc_id")
			_ok(int(entry.get("gold_delta", 0)) == 12, "ledger guest entry preserves gold delta")
			_ok(int(entry.get("rep_delta", 0)) == 2, "ledger guest entry preserves reputation delta")

	gm.current_ledger_data = original_ledger
	gm.economy.current_day = original_day
	gm.economy.gold_today = original_gold_today
	gm.economy.rep_today = original_rep_today
	gm.guests.reset_daily()


func _test_preserved_nodes(screen: Node) -> void:
	_ok(screen.get_node_or_null("UI/TitleLabel") is Label, "TitleLabel contract is preserved")
	_ok(screen.get_node_or_null("UI/StatsList") is VBoxContainer, "StatsList contract is preserved")
	_ok(screen.get_node_or_null("UI/FateTitle") is Label, "FateTitle contract is preserved")
	_ok(screen.get_node_or_null("UI/FateList") is VBoxContainer, "FateList contract is preserved")
	_ok(screen.get_node_or_null("UI/ContinueBtn") is Button, "ContinueBtn contract is preserved")
	var stats_list := screen.get_node_or_null("UI/StatsList") as VBoxContainer
	if stats_list != null:
		_ok(stats_list.position == Vector2(506, 470) and stats_list.size == Vector2(340, 150), "StatsList sits on the blue counter-board panel instead of the wood frame")
		_ok(stats_list.get_theme_constant("separation") == 0, "StatsList keeps compact vertical spacing")


func _test_new_art_nodes(screen: Node) -> void:
	var backdrop := screen.get_node_or_null("ArtLayer/SettlementBackdrop") as TextureRect
	_ok(backdrop != null, "settlement backdrop art node exists")
	if backdrop != null:
		_ok(backdrop.position == Vector2.ZERO and backdrop.size == Vector2(1280, 720), "settlement backdrop covers the screen")
		_ok(backdrop.texture != null and String(backdrop.texture.resource_path).ends_with("assets/textures/ui/night_settlement/night_settlement_backdrop.png"), "settlement backdrop uses runtime texture")
		_ok(backdrop.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "settlement backdrop uses nearest filtering")
	var stats_art := screen.get_node_or_null("ArtLayer/StatsPanelArt") as TextureRect
	var fate_art := screen.get_node_or_null("ArtLayer/FatePanelArt") as TextureRect
	_ok(stats_art != null and stats_art.texture != null and String(stats_art.texture.resource_path).ends_with("night_settlement_panel_stats.png"), "stats panel art uses settlement runtime texture")
	if stats_art != null:
		_ok(stats_art.position == Vector2(376, 424) and stats_art.size == Vector2(528, 232), "stats panel moves to the centered counter area")
	_ok(fate_art != null and fate_art.texture != null and String(fate_art.texture.resource_path).ends_with("night_settlement_panel_fates.png"), "fate panel art uses settlement runtime texture")


func _test_aftermath_panel_hidden_but_contract_preserved(screen: Node) -> void:
	var fate_title := screen.get_node_or_null("UI/FateTitle") as Label
	var fate_list := screen.get_node_or_null("UI/FateList") as VBoxContainer
	var fate_art := screen.get_node_or_null("ArtLayer/FatePanelArt") as TextureRect
	_ok(fate_title != null and not fate_title.visible, "legacy FateTitle node remains but is hidden")
	_ok(fate_list != null and not fate_list.visible, "legacy FateList node remains but is hidden")
	_ok(fate_art != null and not fate_art.visible, "legacy FatePanelArt node remains but is hidden")


func _test_guest_silhouette_stage(screen: Node) -> void:
	var layer := screen.get_node_or_null("ArtLayer/GuestSilhouetteLayer") as Control
	_ok(layer != null, "guest silhouette layer exists")
	if layer == null:
		return
	_ok(layer.mouse_filter == Control.MOUSE_FILTER_IGNORE, "guest silhouette layer does not block input")
	_ok(layer.get_child_count() == 3, "guest silhouette layer creates one silhouette per guest entry")
	for child in layer.get_children():
		_ok(child is TextureRect, "guest silhouette is a TextureRect")
		if child is TextureRect:
			var figure := child as TextureRect
			_ok(figure.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "guest silhouette uses nearest filtering")
			_ok(figure.modulate.a > 0.0 and figure.modulate.a <= 1.0, "guest silhouette is visible")


func _test_revised_silhouette_queue_motion_contract(screen: Node) -> void:
	var layer := screen.get_node_or_null("ArtLayer/GuestSilhouetteLayer") as Control
	_ok(layer != null, "guest silhouette layer exists for revised queue contract")
	if layer == null or layer.get_child_count() < 2:
		return
	var previous_target_x := -9999.0
	var previous_width := 0.0
	for i in range(layer.get_child_count()):
		var figure := layer.get_child(i) as TextureRect
		_ok(figure != null, "revised guest silhouette is a TextureRect")
		if figure == null:
			continue
		_ok(figure.size.x >= 140.0 and figure.size.y >= 196.0, "guest silhouette is large enough to read as a black figure")
		_ok(figure.has_meta("entry_position"), "guest silhouette stores its offscreen entry position")
		_ok(figure.has_meta("target_position"), "guest silhouette stores its queue target position")
		_ok(figure.has_meta("arrival_duration"), "guest silhouette stores its arrival duration")
		var entry_position = figure.get_meta("entry_position")
		var target_position = figure.get_meta("target_position")
		_ok(entry_position is Vector2 and (entry_position as Vector2).x > 1280.0, "guest silhouette starts offscreen to the right")
		_ok(target_position is Vector2 and (target_position as Vector2).x < 520.0, "guest silhouette queues on the left side")
		_ok(target_position is Vector2 and (target_position as Vector2).x >= 64.0, "guest silhouette queue keeps a small left-edge breathing margin")
		_ok(target_position is Vector2 and (target_position as Vector2).y >= 160.0, "guest silhouette queue sits on the readable wall and floor band")
		_ok(target_position is Vector2 and (target_position as Vector2).y + figure.size.y <= 410.0, "guest silhouette queue stays above the counter-board impact area")
		_ok(float(figure.get_meta("arrival_duration", 0.0)) >= 0.24, "guest silhouette has a visible slide-in duration")
		if target_position is Vector2 and i > 0:
			var target_x := (target_position as Vector2).x
			_ok(target_x < previous_target_x + previous_width, "guest silhouettes overlap slightly like a queue")
			_ok(target_x > previous_target_x + previous_width * 0.45, "guest silhouette overlap does not fully hide the previous guest")
		if target_position is Vector2:
			previous_target_x = (target_position as Vector2).x
			previous_width = figure.size.x


func _test_counter_board_impact_contract(screen: Node) -> void:
	_ok(screen.has_method("_play_counter_impact"), "settlement screen exposes counter-board impact playback")
	var stats_art := screen.get_node_or_null("ArtLayer/StatsPanelArt") as TextureRect
	_ok(stats_art != null, "stats panel art exists for impact contract")
	if stats_art == null or not screen.has_method("_apply_guest_replay_step"):
		return
	var entry := {"gold_delta": 3, "rep_delta": 1, "served_delta": 1, "success_delta": 1, "failed_delta": 0}
	screen._apply_guest_replay_step(0, entry)
	_ok(stats_art.has_meta("impact_base_position"), "counter-board impact records stats art base position")
	_ok(screen.has_meta("last_counter_impact_keys"), "counter-board impact records changed stat keys")
	var keys: Array = screen.get_meta("last_counter_impact_keys", [])
	_ok(keys.has("gold") and keys.has("reputation") and keys.has("success"), "counter-board impact records the changed business stats")


func _test_score_counters_can_complete_to_authoritative_totals(screen: Node) -> void:
	_ok(screen.has_method("_complete_score_replay"), "settlement screen exposes internal score replay completion for deterministic tests")
	if screen.has_method("_complete_score_replay"):
		screen._complete_score_replay()
	var combined := _collect_stats_text(screen)
	_ok(combined.find("42") >= 0, "completed score replay renders authoritative gold_today")
	_ok(combined.find("-1") >= 0, "completed score replay renders authoritative rep_today")
	_ok(combined.find("5") >= 0, "completed score replay renders authoritative guests_served")
	_ok(combined.find("4") >= 0, "completed score replay renders authoritative orders_success")
	_ok(combined.find("1") >= 0, "completed score replay renders authoritative orders_failed")


func _test_dynamic_data(screen: Node) -> void:
	var title := screen.get_node("UI/TitleLabel") as Label
	_ok(title.text.find("3") >= 0, "title renders settlement day")
	if screen.has_method("_complete_score_replay"):
		screen._complete_score_replay()
	var combined := _collect_stats_text(screen)
	_ok(combined.find("42") >= 0, "stats render gold_today")
	_ok(combined.find("-1") >= 0, "stats render rep_today")
	_ok(combined.find("5") >= 0, "stats render guests_served")
	_ok(combined.find("4") >= 0, "stats render orders_success")
	_ok(combined.find("1") >= 0, "stats render orders_failed")


func _collect_stats_text(screen: Node) -> String:
	var combined := ""
	for child in (screen.get_node("UI/StatsList") as VBoxContainer).get_children():
		if child is Label:
			combined += (child as Label).text + "\n"
		elif child is HBoxContainer:
			for sub in child.get_children():
				if sub is Label:
					combined += (sub as Label).text + "\n"
	return combined


func _test_no_ryan_cinematic_for_non_ryan_fates(screen: Node) -> void:
	_ok(screen.get_node_or_null("RyanFateCinematic") == null, "non-Ryan settlement does not show Ryan fate cinematic")


func _test_fate_reveal_notice(screen: Node) -> void:
	var overlay := screen.get_node_or_null("FateRevealOverlay") as Control
	_ok(overlay != null, "settlement with fate records shows fate reveal overlay")
	if overlay == null:
		return
	_ok(overlay.visible, "fate reveal overlay starts visible")
	_ok(overlay.position == Vector2.ZERO and overlay.size == Vector2(1280, 720), "fate reveal overlay covers the screen")
	_ok(overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE, "fate reveal overlay does not block settlement input")
	var shade := overlay.get_node_or_null("FateRevealShade") as ColorRect
	_ok(shade != null, "fate reveal overlay has screen dim shade")
	if shade != null:
		_ok(shade.position == Vector2.ZERO and shade.size == Vector2(1280, 720), "fate reveal shade covers the screen")
		_ok(shade.color.a >= 0.55, "fate reveal shade darkens the settlement screen")
	var label := overlay.get_node_or_null("FateRevealLabel") as Label
	_ok(label != null, "fate reveal overlay has highlighted title label")
	if label != null:
		_ok(label.text == "宿命轨迹已显现", "fate reveal label uses the approved player-facing copy")
		_ok(label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER, "fate reveal title is centered")
		_ok(label.get_theme_font_size("font_size") >= 40, "fate reveal title uses large type")
		_ok(label.get_theme_constant("outline_size") >= 4, "fate reveal title has a strong outline")
		var font: Font = label.get_theme_font("font")
		_ok(font != null and String(font.resource_path).ends_with("assets/fonts/fusion-pixel/fusion-pixel-12px-proportional-zh_hans.ttf"), "fate reveal title uses Fusion Pixel font")


func _test_no_fate_reveal_notice_without_fates(screen: Node) -> void:
	_ok(screen.get_node_or_null("FateRevealOverlay") == null, "settlement without fate records does not show fate reveal overlay")


func _test_fate_preview_notice(screen: Node) -> void:
	_ok(screen.get_node_or_null("FateRevealOverlay") == null,
		"next-day fate preview does not pretend the fate record already appeared")
	var overlay := screen.get_node_or_null("FatePreviewOverlay") as Control
	_ok(overlay != null, "settlement before fate ledger records shows next-day fate preview overlay")
	if overlay == null:
		return
	_ok(overlay.visible, "fate preview overlay starts visible")
	_ok(overlay.position == Vector2.ZERO and overlay.size == Vector2(1280, 720), "fate preview overlay covers the screen")
	_ok(overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE, "fate preview overlay does not block settlement input")
	var shade := overlay.get_node_or_null("FatePreviewShade") as ColorRect
	_ok(shade != null, "fate preview overlay has screen dim shade")
	if shade != null:
		_ok(shade.position == Vector2.ZERO and shade.size == Vector2(1280, 720), "fate preview shade covers the screen")
		_ok(shade.color.a >= 0.55, "fate preview shade darkens the settlement screen")
	var label := overlay.get_node_or_null("FatePreviewLabel") as Label
	_ok(label != null, "fate preview overlay has highlighted title label")
	if label != null:
		_ok(label.text == "宿命轨迹即将显现", "fate preview label warns before the next-day ledger record")
		_ok(label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER, "fate preview title is centered")
		_ok(label.get_theme_font_size("font_size") >= 40, "fate preview title uses large type")
		_ok(label.get_theme_constant("outline_size") >= 4, "fate preview title has a strong outline")
		var font: Font = label.get_theme_font("font")
		_ok(font != null and String(font.resource_path).ends_with("assets/fonts/fusion-pixel/fusion-pixel-12px-proportional-zh_hans.ttf"), "fate preview title uses Fusion Pixel font")


func _test_fate_notice_waits_for_ledger_tutorial(data: LedgerData) -> void:
	var tm = get_node_or_null("/root/TutorialManager")
	if tm == null:
		return
	if tm._is_active:
		tm.skip_tutorial()
	var old_first_ledger := bool(tm.first_ledger_shown)
	var old_completed: Array = tm._completed_steps.duplicate()
	_reset_ledger_tutorial_for_sequence_test(tm)

	var screen = await _make_screen(data)
	await get_tree().process_frame
	_ok(tm._is_active, "first ledger settlement starts the ledger tutorial")
	_ok(screen.get_node_or_null("FateRevealOverlay") == null,
		"fate reveal notice waits while the first ledger tutorial is active")

	if tm._is_active:
		tm.skip_tutorial()
	await get_tree().process_frame
	_ok(screen.get_node_or_null("FateRevealOverlay") != null,
		"fate reveal notice appears after the ledger tutorial ends")

	screen.queue_free()
	await get_tree().process_frame
	tm._completed_steps = old_completed
	tm.first_ledger_shown = old_first_ledger
	tm._save_state()


func _test_tutorial_then_fate_presentation_then_score_replay_order() -> void:
	var tm = get_node_or_null("/root/TutorialManager")
	if tm == null:
		return
	if tm._is_active:
		tm.skip_tutorial()
	var old_first_ledger := bool(tm.first_ledger_shown)
	var old_completed: Array = tm._completed_steps.duplicate()
	_reset_ledger_tutorial_for_sequence_test(tm)
	_ok(not bool(tm.first_ledger_shown), "sequence fixture clears first ledger flag")
	_ok(tm._steps.has("ledger"), "sequence fixture has ledger tutorial steps loaded")
	_ok(tm._steps.get("ledger", []).size() > 0, "sequence fixture has non-empty ledger tutorial steps")
	_ok(not tm._completed_steps.has("ledger_intro"), "sequence fixture removes ledger_intro completion")
	_ok(not tm.is_group_completed("ledger"), "sequence fixture clears ledger tutorial completion")

	var data := _make_ryan_fate_ledger_data()
	var screen = await _make_screen(data)
	await get_tree().process_frame
	_ok(tm._is_active, "first ledger settlement starts tutorial before fate presentation")
	_ok(screen.get_node_or_null("RyanFateCinematic") == null,
		"fate cinematic waits while the first ledger tutorial is active")
	_ok(screen.get_node_or_null("FateRevealOverlay") == null,
		"fate reveal notice waits while the first ledger tutorial is active")
	_ok(not bool(screen.get("_score_replay_active")),
		"score replay waits while the first ledger tutorial is active")

	if tm._is_active:
		tm.skip_tutorial()
	await get_tree().process_frame
	var cinematic := screen.get_node_or_null("RyanFateCinematic") as Control
	var reveal := screen.get_node_or_null("FateRevealOverlay") as Control
	_ok(cinematic != null and cinematic.visible,
		"fate cinematic starts after the ledger tutorial ends")
	_ok(reveal != null and reveal.visible,
		"fate reveal notice can appear alongside the fate cinematic")
	_ok(not bool(screen.get("_score_replay_active")),
		"score replay waits while fate presentation is visible")

	if cinematic != null:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = true
		screen._unhandled_input(event)
		await get_tree().process_frame
		_ok(not cinematic.visible, "fate cinematic can be dismissed before score replay starts")
	_ok(not bool(screen.get("_score_replay_active")),
		"score replay still waits until the fate reveal notice finishes")

	await get_tree().create_timer(1.9).timeout
	await get_tree().process_frame
	_ok(screen.get_node_or_null("FateRevealOverlay") == null,
		"fate reveal notice clears before score replay becomes the focus")
	_ok(bool(screen.get("_score_replay_active")) or bool(screen.get("_score_replay_finished")),
		"score replay starts only after tutorial and fate presentation finish")

	screen.queue_free()
	await get_tree().process_frame
	tm._completed_steps = old_completed
	tm.first_ledger_shown = old_first_ledger
	tm._save_state()


func _reset_ledger_tutorial_for_sequence_test(tm: Node) -> void:
	tm._load_steps()
	tm.first_ledger_shown = false
	tm._completed_steps.clear()
	while tm._completed_steps.has("ledger_intro"):
		tm._completed_steps.erase("ledger_intro")
	for step in tm._steps.get("ledger", []):
		if step is Dictionary:
			tm._completed_steps.erase(String(step.get("id", "")))
	tm._save_state()


func _make_ryan_fate_ledger_data() -> LedgerData:
	var data := LedgerData.new()
	data.day = 3
	data.gold_today = 42
	data.rep_today = -1
	data.gold_total = 128
	data.rep_total = 7
	data.guests_served = 5
	data.orders_success = 4
	data.orders_failed = 1
	data.guest_entries = [
		{"npc_id": "regular_noel", "display_name": "Noel", "result": "success", "gold_delta": 8, "rep_delta": 2, "served_delta": 1, "success_delta": 1, "failed_delta": 0},
		{"npc_id": "ryan", "display_name": "Ryan", "result": "failed", "gold_delta": 0, "rep_delta": 0, "served_delta": 1, "success_delta": 0, "failed_delta": 1},
		{"npc_id": "regular_belta", "display_name": "Belta", "result": "success", "gold_delta": 34, "rep_delta": -3, "served_delta": 3, "success_delta": 3, "failed_delta": 0},
	]
	data.npc_fates = [
		{
			"npc_id": "ryan",
			"ending_key": "alternative_survivor",
			"npc_name": "Ryan",
			"npc_title": "Witness Knight",
			"fate_text": "Ryan leaves with the alternative commission."
		},
	]
	return data


func _test_narrative_fates_include_route_keys(gm: Node) -> void:
	gm.narrative.set_var("ryan_has_alternative", true)
	gm.narrative.finalize_ryan_ending()
	var fates: Array = gm.narrative.get_today_npc_fates(3)
	var ryan_fate: Dictionary = {}
	for fate in fates:
		if String(fate.get("npc_name", "")) == "莱恩" or String(fate.get("npc_id", "")) == "ryan":
			ryan_fate = fate
			break
	_ok(String(ryan_fate.get("npc_id", "")) == "ryan", "Ryan fate includes stable npc_id")
	_ok(String(ryan_fate.get("ending_key", "")) == "alternative_survivor", "Ryan fate includes ending route key")


func _test_ryan_fate_only_reveals_on_reveal_day(gm: Node) -> void:
	var original_vars: Dictionary = gm.narrative.dialogue_vars.duplicate(true)
	gm.narrative.set_var("ryan_ending", "alternative_survivor")

	var day2_fates: Array = gm.narrative.get_today_npc_fates(2)
	_ok(not _has_fate(day2_fates, "ryan"), "Day 2 settlement does not reveal Ryan fate even if ending is already cached")

	var day3_fates: Array = gm.narrative.get_today_npc_fates(3)
	_ok(_has_fate(day3_fates, "ryan"), "Day 3 settlement reveals Ryan fate")

	gm.narrative.dialogue_vars = original_vars


func _has_fate(fates: Array, npc_id: String) -> bool:
	for fate in fates:
		if fate is Dictionary and String(fate.get("npc_id", "")) == npc_id:
			return true
	return false


func _test_ryan_cinematic_overlay(screen: Node) -> void:
	var overlay := screen.get_node_or_null("RyanFateCinematic") as Control
	_ok(overlay != null, "Ryan settlement shows fate cinematic overlay")
	if overlay == null:
		return
	_ok(overlay.visible, "Ryan fate cinematic starts visible")
	_ok(overlay.position == Vector2.ZERO and overlay.size == Vector2(1280, 720), "Ryan fate cinematic covers the screen")
	var still := overlay.get_node_or_null("Still") as TextureRect
	_ok(still != null, "Ryan fate cinematic has wide still texture")
	if still != null:
		_ok(still.position == Vector2(0, 80) and still.size == Vector2(1280, 560), "Ryan fate still uses intro-style letterbox image bounds")
		_ok(still.texture != null and String(still.texture.resource_path).ends_with("assets/textures/endings/ryan/ryan_alternative_survivor.png"), "Ryan fate still uses route runtime texture")
		_ok(still.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Ryan fate still uses nearest filtering")
	var fate_label := overlay.get_node_or_null("FateLabel") as Label
	_ok(fate_label != null, "Ryan fate cinematic has fate text label")
	if fate_label != null:
		_ok(fate_label.text.find("莱恩带着替代委托离开") >= 0, "Ryan fate label renders the fate text")
		_ok(fate_label.text.find("金币") < 0 and fate_label.text.find("成功订单") < 0, "Ryan fate label does not include settlement stats")


func _test_ryan_cinematic_dismisses_on_click(screen: Node) -> void:
	var overlay := screen.get_node_or_null("RyanFateCinematic") as Control
	if overlay == null:
		return
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	screen._unhandled_input(event)
	await get_tree().process_frame
	_ok(not overlay.visible, "Ryan fate cinematic hides after click")


func _test_mira_cinematic_overlay(screen: Node) -> void:
	var overlay := screen.get_node_or_null("MiraFateCinematic") as Control
	_ok(overlay != null, "Mira settlement shows fate cinematic overlay")
	if overlay == null:
		return
	_ok(screen.get_node_or_null("RyanFateCinematic") == null, "Mira settlement does not reuse the Ryan node name")
	_ok(overlay.visible, "Mira fate cinematic starts visible")
	_ok(overlay.position == Vector2.ZERO and overlay.size == Vector2(1280, 720), "Mira fate cinematic covers the screen")
	var still := overlay.get_node_or_null("Still") as TextureRect
	_ok(still != null, "Mira fate cinematic has wide still texture")
	if still != null:
		_ok(still.position == Vector2(0, 80) and still.size == Vector2(1280, 560), "Mira fate still uses intro-style letterbox image bounds")
		_ok(still.texture != null and String(still.texture.resource_path).ends_with("assets/textures/endings/mira/mira_she_finally_stopped.png"), "Mira fate still uses route runtime texture")
		_ok(still.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Mira fate still uses nearest filtering")
	var fate_label := overlay.get_node_or_null("FateLabel") as Label
	_ok(fate_label != null, "Mira fate cinematic has fate text label")
	if fate_label != null:
		_ok(fate_label.text.find("Mira tears up") >= 0, "Mira fate label renders the fate text")
		_ok(fate_label.text.find("gold") < 0 and fate_label.text.find("orders") < 0, "Mira fate label does not include settlement stats")


func _test_mira_cinematic_dismisses_on_click(screen: Node) -> void:
	var overlay := screen.get_node_or_null("MiraFateCinematic") as Control
	if overlay == null:
		return
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	screen._unhandled_input(event)
	await get_tree().process_frame
	_ok(not overlay.visible, "Mira fate cinematic hides after click")


func _test_compact_stats_rows(screen: Node) -> void:
	var stats_list := screen.get_node("UI/StatsList") as VBoxContainer
	var rows := 0
	for child in stats_list.get_children():
		if child is HBoxContainer:
			rows += 1
			var row := child as HBoxContainer
			_ok(row.custom_minimum_size.y == 24.0, "stat row keeps compact height")
			_ok(row.get_theme_constant("separation") == 10, "stat row keeps comfortable icon-to-text spacing")
			var first_icon := row.get_child(0) as TextureRect if row.get_child_count() > 0 else null
			var name_label := row.get_child(1) as Label if row.get_child_count() > 1 else null
			if first_icon != null:
				_ok(stats_list.position.x + row.position.x + first_icon.position.x >= 500.0, "stat icon column sits on the blue counter-board panel")
			if name_label != null:
				_ok(stats_list.position.x + row.position.x + name_label.position.x >= 534.0, "stat name column sits on the blue counter-board panel with breathing room")
			for sub in row.get_children():
				if sub is TextureRect:
					var icon := sub as TextureRect
					_ok(icon.custom_minimum_size == Vector2(24, 24), "stat icon is compact")
				elif sub is Label:
					var label := sub as Label
					_ok(label.custom_minimum_size.y == 24.0, "stat label is compact")
					_ok(label.get_theme_font_size("font_size") == 14, "stat label font is compact")
	_ok(rows == 5, "five stat rows are rendered")


func _test_continue_button_art(screen: Node) -> void:
	var button := screen.get_node("UI/ContinueBtn") as Button
	_ok(button.text == "" or button.text == "熄灯", "continue button is either icon-only or a short Godot-rendered label")
	for state in ["normal", "hover", "pressed"]:
		var style := button.get_theme_stylebox(state) as StyleBoxTexture
		_ok(style != null and style.texture != null, "continue button has %s texture style" % state)
		if style != null and style.texture != null:
			_ok(String(style.texture.resource_path).ends_with("assets/textures/ui/night_settlement/night_settlement_continue_%s.png" % state), "continue button uses settlement %s art" % state)


func _test_pixel_fonts(screen: Node) -> void:
	var expected_suffix := "assets/fonts/fusion-pixel/fusion-pixel-12px-proportional-zh_hans.ttf"
	var labels: Array[Label] = [
		screen.get_node("UI/TitleLabel") as Label,
		screen.get_node("UI/FateTitle") as Label,
	]
	for child in (screen.get_node("UI/StatsList") as VBoxContainer).get_children():
		if child is HBoxContainer:
			for sub in child.get_children():
				if sub is Label:
					labels.append(sub as Label)
	for child in (screen.get_node("UI/FateList") as VBoxContainer).get_children():
		if child is Label:
			labels.append(child as Label)
		elif child is VBoxContainer:
			for sub in child.get_children():
				if sub is Label:
					labels.append(sub as Label)
	for label in labels:
		var font: Font = label.get_theme_font("font")
		_ok(font != null and String(font.resource_path).ends_with(expected_suffix), "%s uses Fusion Pixel font" % label.name)
	var button := screen.get_node("UI/ContinueBtn") as Button
	var button_font: Font = button.get_theme_font("font")
	_ok(button_font != null and String(button_font.resource_path).ends_with(expected_suffix), "ContinueBtn uses Fusion Pixel font")
