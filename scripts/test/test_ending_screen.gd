extends Node

var _checks := 0
var _failures := 0


func _ready() -> void:
	var scene := preload("res://scenes/ui/EndingScreen.tscn")
	var screen = scene.instantiate()
	add_child(screen)
	await get_tree().process_frame

	var endings := {
		"ryan": "alternative_survivor",
		"mira": "she_finally_stopped",
		"toby": "saved",
		"evelyn": "public_account",
	}
	screen.show_endings(186, 12, 48, endings)
	await get_tree().process_frame

	_test_preserved_contract_nodes(screen)
	_test_formal_final_copy(screen)
	_test_character_comments(screen)
	_test_brush_runtime_art(screen)
	_test_content_stays_inside_panel(screen)
	_test_pixel_fonts(screen)

	screen.queue_free()
	await get_tree().process_frame
	_finish()


func _test_preserved_contract_nodes(screen: Node) -> void:
	_ok(screen.get_node_or_null("Content/TitleLabel") is Label, "TitleLabel contract is preserved")
	_ok(screen.get_node_or_null("Content/Stats/GoldLabel") is Label, "GoldLabel contract is preserved")
	_ok(screen.get_node_or_null("Content/Stats/RepLabel") is Label, "RepLabel contract is preserved")
	_ok(screen.get_node_or_null("Content/Stats/OrdersLabel") is Label, "OrdersLabel contract is preserved")
	_ok(screen.get_node_or_null("Content/ClosingLabel") is Label, "ClosingLabel contract is preserved")
	_ok(screen.get_node_or_null("Content/NPCEndingsList") is VBoxContainer, "NPCEndingsList contract is preserved")
	_ok(screen.get_node_or_null("Content/QuitBtn") is Button, "QuitBtn contract is preserved")
	_ok(screen.get_node_or_null("Content/RestartBtn") is Button, "RestartBtn contract is preserved")


func _test_formal_final_copy(screen: Node) -> void:
	var title := screen.get_node("Content/TitleLabel") as Label
	var closing := screen.get_node("Content/ClosingLabel") as Label
	var gold := screen.get_node("Content/Stats/GoldLabel") as Label
	var rep := screen.get_node("Content/Stats/RepLabel") as Label
	var orders := screen.get_node("Content/Stats/OrdersLabel") as Label
	_ok(title.text != "Ryan 垂直切片结束", "ending title is no longer the vertical-slice placeholder")
	_ok(title.text.find("灯") >= 0 or title.text.find("账") >= 0 or title.text.find("酒馆") >= 0, "ending title reads like a formal closure")
	_ok(closing.text.length() >= 12, "closing verdict contains a sentence")
	_ok(_text_tree(screen).find("A") < 0 and _text_tree(screen).find("B") < 0 and _text_tree(screen).find("C") < 0, "player-facing copy does not expose letter grades")
	_ok(gold.text == "最终金币：186", "gold stat is rendered")
	_ok(rep.text == "最终声望：12", "reputation stat is rendered")
	_ok(orders.text == "成功订单：48", "orders stat is rendered")


func _test_character_comments(screen: Node) -> void:
	var list := screen.get_node("Content/NPCEndingsList") as VBoxContainer
	var text := _text_tree(list)
	for name in ["莱恩", "米拉", "托比", "伊芙琳"]:
		_ok(text.find(name) >= 0, "%s final comment is present" % name)
	for raw_key in ["alternative_survivor", "she_finally_stopped", "public_account", "saved"]:
		_ok(text.find(raw_key) < 0, "%s route key is not exposed to the player" % raw_key)
	_ok(_count_character_rows(list) == 4, "four character verdict rows are rendered")


func _test_brush_runtime_art(screen: Node) -> void:
	var backdrop := screen.get_node_or_null("ArtLayer/SettlementBackdrop") as TextureRect
	_ok(backdrop != null, "ending screen has settlement backdrop art")
	if backdrop != null:
		_ok(backdrop.texture != null and String(backdrop.texture.resource_path).ends_with("assets/textures/ui/night_settlement/night_settlement_backdrop.png"), "ending backdrop uses existing runtime texture")
		_ok(backdrop.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "ending backdrop uses nearest filtering")
	var panel := screen.get_node_or_null("ArtLayer/FinalPanelArt") as TextureRect
	_ok(panel != null, "ending screen has a brush final panel art node")
	if panel != null:
		_ok(panel.texture != null and String(panel.texture.resource_path).ends_with("assets/textures/ui/night_settlement/night_settlement_panel_fates.png"), "final panel uses existing settlement brush panel")
		_ok(panel.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "final panel uses nearest filtering")


func _test_content_stays_inside_panel(screen: Node) -> void:
	var panel := screen.get_node("ArtLayer/FinalPanelArt") as TextureRect
	var panel_rect := panel.get_global_rect().grow(-24.0)
	for path in ["Content/TitleLabel", "Content/Stats", "Content/ClosingLabel", "Content/NPCEndingsList"]:
		var control := screen.get_node(path) as Control
		var rect := control.get_global_rect()
		_ok(rect.position.y >= panel_rect.position.y, "%s starts inside the brush panel" % path)
		_ok(_visible_controls_bottom(control) <= panel_rect.end.y, "%s stays inside the brush panel bottom" % path)
	for path in ["Content/QuitBtn", "Content/RestartBtn"]:
		var button := screen.get_node(path) as Button
		_ok(button.get_global_rect().position.y >= panel.get_global_rect().end.y + 4.0, "%s sits below the brush panel" % path)


func _visible_controls_bottom(control: Control) -> float:
	var bottom := control.get_global_rect().end.y
	for child in control.get_children():
		if child is Control and (child as Control).visible:
			bottom = max(bottom, _visible_controls_bottom(child as Control))
	return bottom


func _test_pixel_fonts(screen: Node) -> void:
	var expected_suffix := "assets/fonts/fusion-pixel/fusion-pixel-12px-proportional-zh_hans.ttf"
	var labels: Array[Label] = [
		screen.get_node("Content/TitleLabel") as Label,
		screen.get_node("Content/Stats/GoldLabel") as Label,
		screen.get_node("Content/Stats/RepLabel") as Label,
		screen.get_node("Content/Stats/OrdersLabel") as Label,
		screen.get_node("Content/ClosingLabel") as Label,
	]
	for child in (screen.get_node("Content/NPCEndingsList") as VBoxContainer).get_children():
		_collect_labels(child, labels)
	for label in labels:
		var font: Font = label.get_theme_font("font")
		_ok(font != null and String(font.resource_path).ends_with(expected_suffix), "%s uses Fusion Pixel font" % label.name)
	for button_path in ["Content/QuitBtn", "Content/RestartBtn"]:
		var button := screen.get_node(button_path) as Button
		var button_font: Font = button.get_theme_font("font")
		_ok(button_font != null and String(button_font.resource_path).ends_with(expected_suffix), "%s uses Fusion Pixel font" % button.name)


func _collect_labels(node: Node, labels: Array[Label]) -> void:
	if node is Label:
		labels.append(node as Label)
	for child in node.get_children():
		_collect_labels(child, labels)


func _text_tree(node: Node) -> String:
	var result := ""
	if node is Label:
		result += (node as Label).text + "\n"
	elif node is Button:
		result += (node as Button).text + "\n"
	for child in node.get_children():
		result += _text_tree(child)
	return result


func _count_character_rows(list: VBoxContainer) -> int:
	var rows := 0
	for child in list.get_children():
		if child is HBoxContainer:
			rows += 1
	return rows


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-ENDING-SCREEN] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-ENDING-SCREEN] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-ENDING-SCREEN] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)
