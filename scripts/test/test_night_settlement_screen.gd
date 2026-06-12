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
	gm.current_ledger_data = data

	var tm = get_node_or_null("/root/TutorialManager")
	if tm != null:
		tm.first_ledger_shown = true

	var scene := preload("res://scenes/ui/LedgerScreen.tscn")
	var screen = scene.instantiate()
	add_child(screen)
	await get_tree().process_frame

	_test_preserved_nodes(screen)
	_test_new_art_nodes(screen)
	_test_dynamic_data(screen)
	_test_compact_stats_rows(screen)
	_test_continue_button_art(screen)
	_test_pixel_fonts(screen)

	screen.queue_free()
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
