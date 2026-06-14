extends Node

var _checks := 0
var _failures := 0


func _ready() -> void:
	var gm = get_node("/root/GameManager")
	var data := LedgerData.new()
	data.day = 3
	data.gold_today = 42
	data.rep_today = -1
	data.gold_total = 128
	data.rep_total = 7
	data.guests_served = 5
	data.orders_success = 4
	data.orders_failed = 1
	data.npc_fates = [
		{"npc_name": "米拉", "npc_title": "行商", "fate_text": "她把今晚的传闻收进了斗篷。"},
	]

	var tm = get_node_or_null("/root/TutorialManager")
	if tm != null:
		tm.first_ledger_shown = true

	var screen = await _make_screen(data)

	_test_preserved_nodes(screen)
	_test_new_art_nodes(screen)
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


func _test_preserved_nodes(screen: Node) -> void:
	_ok(screen.get_node_or_null("UI/TitleLabel") is Label, "TitleLabel contract is preserved")
	_ok(screen.get_node_or_null("UI/StatsList") is VBoxContainer, "StatsList contract is preserved")
	_ok(screen.get_node_or_null("UI/FateTitle") is Label, "FateTitle contract is preserved")
	_ok(screen.get_node_or_null("UI/FateList") is VBoxContainer, "FateList contract is preserved")
	_ok(screen.get_node_or_null("UI/ContinueBtn") is Button, "ContinueBtn contract is preserved")
	var stats_list := screen.get_node_or_null("UI/StatsList") as VBoxContainer
	if stats_list != null:
		_ok(stats_list.position == Vector2(160, 456) and stats_list.size == Vector2(360, 120), "StatsList sits inside the neutral stats panel safe area")
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
		_ok(stats_art.position == Vector2(112, 392) and stats_art.size == Vector2(480, 264), "stats panel keeps its authored size")
	_ok(fate_art != null and fate_art.texture != null and String(fate_art.texture.resource_path).ends_with("night_settlement_panel_fates.png"), "fate panel art uses settlement runtime texture")


func _test_dynamic_data(screen: Node) -> void:
	var title := screen.get_node("UI/TitleLabel") as Label
	_ok(title.text.find("3") >= 0, "title renders settlement day")
	var combined := ""
	for child in (screen.get_node("UI/StatsList") as VBoxContainer).get_children():
		if child is Label:
			combined += (child as Label).text + "\n"
		elif child is HBoxContainer:
			for sub in child.get_children():
				if sub is Label:
					combined += (sub as Label).text + "\n"
	_ok(combined.find("42") >= 0, "stats render gold_today")
	_ok(combined.find("-1") >= 0, "stats render rep_today")
	_ok(combined.find("5") >= 0, "stats render guests_served")
	_ok(combined.find("4") >= 0, "stats render orders_success")
	_ok(combined.find("1") >= 0, "stats render orders_failed")
	var fate_text := ""
	for child in (screen.get_node("UI/FateList") as VBoxContainer).get_children():
		if child is Label:
			fate_text += (child as Label).text + "\n"
		elif child is VBoxContainer:
			for sub in child.get_children():
				if sub is Label:
					fate_text += (sub as Label).text + "\n"
	_ok(fate_text.find("米拉") >= 0, "fate list renders npc name")
	_ok(fate_text.find("传闻") >= 0, "fate list renders fate text")


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


func _test_compact_stats_rows(screen: Node) -> void:
	var stats_list := screen.get_node("UI/StatsList") as VBoxContainer
	var rows := 0
	for child in stats_list.get_children():
		if child is HBoxContainer:
			rows += 1
			var row := child as HBoxContainer
			_ok(row.custom_minimum_size.y == 24.0, "stat row keeps compact height")
			_ok(row.get_theme_constant("separation") == 6, "stat row keeps compact horizontal spacing")
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
