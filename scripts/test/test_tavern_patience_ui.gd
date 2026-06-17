extends Node

var _checks := 0
var _failures := 0

const PIXEL_FONT_PATH := "res://assets/fonts/fusion-pixel/fusion-pixel-12px-proportional-zh_hans.ttf"
const ORDER_GROOVE_SAFE_LEFT := 392.0
const ORDER_GROOVE_SAFE_TOP := 604.0
const ORDER_GROOVE_SAFE_RIGHT := 888.0
const ORDER_GROOVE_SAFE_BOTTOM := 636.0
const PATIENCE_BAR_SIZE := Vector2(192, 16)
const REWARD_PROGRESS_FRAME_SIZE := Vector2(192, 48)
const REWARD_PROGRESS_FILL_INSET := Vector2(24, 12)
const REWARD_PROGRESS_FILL_SIZE := Vector2(144, 24)
const REWARD_REP_PROGRESS_ART_OFFSET := Vector2(0, 4)
const REWARD_GOLD_FRAME_VISIBLE_HEIGHT := 44.0
const REWARD_REP_FRAME_VISIBLE_HEIGHT := 36.0


func _ready() -> void:
	await _test_tavern_patience_ui_contract()
	await _test_tavern_game_manager_contract()
	_test_important_guest_patience_ratio_uses_important_guest_max()
	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-TAVERN-PATIENCE-UI] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-TAVERN-PATIENCE-UI] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-TAVERN-PATIENCE-UI] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _texture_path(texture: Texture2D) -> String:
	if texture == null:
		return ""
	return String(texture.resource_path)


func _stylebox_texture_path(control: Control, style_name: String) -> String:
	var stylebox := control.get_theme_stylebox(style_name) as StyleBoxTexture
	if stylebox == null:
		return ""
	return _texture_path(stylebox.texture)


func _control_uses_pixel_font(control: Control) -> bool:
	if not control.has_theme_font_override("font"):
		return false
	var font := control.get_theme_font("font")
	return font != null and font.resource_path == PIXEL_FONT_PATH


func _stylebox_texture(control: Control, style_name: String) -> Texture2D:
	var stylebox := control.get_theme_stylebox(style_name) as StyleBoxTexture
	if stylebox == null:
		return null
	return stylebox.texture


func _rect_from_array(values: Array) -> Rect2:
	if values.size() < 4:
		return Rect2()
	return Rect2(Vector2(float(values[0]), float(values[1])), Vector2(float(values[2]), float(values[3])))


func _rect_array_close(actual: Array, expected: Array, tolerance: float = 0.5) -> bool:
	if actual.size() < 4 or expected.size() < 4:
		return false
	for index in range(4):
		if abs(float(actual[index]) - float(expected[index])) > tolerance:
			return false
	return true


func _control_screen_rect(control: Control) -> Array:
	if control == null:
		return []
	var rect := control.get_global_rect()
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


func _sprite_screen_rect(sprite: Sprite2D) -> Array:
	if sprite == null or sprite.texture == null:
		return []
	var local_rect := sprite.get_rect()
	var transform := sprite.get_global_transform()
	var points := [
		transform * local_rect.position,
		transform * (local_rect.position + Vector2(local_rect.size.x, 0.0)),
		transform * (local_rect.position + Vector2(0.0, local_rect.size.y)),
		transform * (local_rect.position + local_rect.size),
	]
	var min_x := (points[0] as Vector2).x
	var min_y := (points[0] as Vector2).y
	var max_x := min_x
	var max_y := min_y
	for point in points:
		var p := point as Vector2
		min_x = min(min_x, p.x)
		min_y = min(min_y, p.y)
		max_x = max(max_x, p.x)
		max_y = max(max_y, p.y)
	return [min_x, min_y, max_x - min_x, max_y - min_y]


func _rect_contains_point(values: Array, point: Vector2, tolerance: float = 0.5) -> bool:
	if values.size() < 4:
		return false
	return _rect_from_array(values).grow(tolerance).has_point(point)


func _rect_center(values: Array) -> Vector2:
	var rect := _rect_from_array(values)
	return rect.position + rect.size * 0.5


func _tutorial_target_available(node: Node) -> bool:
	if node == null:
		return false
	if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
		return false
	return node.process_mode != Node.PROCESS_MODE_DISABLED


func _button_stylebox_texture_path(button: Button, style_name: String) -> String:
	var stylebox := button.get_theme_stylebox(style_name) as StyleBoxTexture
	if stylebox == null:
		return ""
	return _texture_path(stylebox.texture)


func _reward_coin_body_count(layer: Node) -> int:
	var count := 0
	if layer == null:
		return count
	for child in layer.get_children():
		if child is RigidBody2D:
			count += 1
	return count


func _tavern_supports_max_gold_progress() -> bool:
	var source := FileAccess.get_file_as_string("res://scripts/ui/tavern_view.gd")
	return source.contains("max_gold_held")


func _update_top_bar_with_max(tavern: Node, gold: int, rep: int, day: int, max_day: int, max_gold_held: int) -> void:
	if _tavern_supports_max_gold_progress():
		tavern.call("update_top_bar", gold, rep, day, max_day, max_gold_held)
	else:
		_ok(false, "TavernView.update_top_bar accepts max held gold for permanent gold progress")
		tavern.call("update_top_bar", gold, rep, day, max_day)


func _show_order_reward_feedback_with_max(tavern: Node, earned_gold: int, earned_rep: int, previous_gold: int, previous_rep: int, previous_max_gold: int, new_max_gold: int) -> void:
	if _tavern_supports_max_gold_progress():
		tavern.call("show_order_reward_feedback", earned_gold, earned_rep, previous_gold, previous_rep, previous_max_gold, new_max_gold)
	else:
		_ok(false, "TavernView.show_order_reward_feedback accepts max held gold for permanent gold progress")
		tavern.call("show_order_reward_feedback", earned_gold, earned_rep, previous_gold, previous_rep)


func _test_tavern_patience_ui_contract() -> void:
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame
	await get_tree().process_frame

	var timer := tavern.get_node_or_null("CustomerArea/TimerBar") as ProgressBar
	var fill_clip := tavern.get_node_or_null("CustomerArea/PatienceFillClip") as Control
	var fill_art := tavern.get_node_or_null("CustomerArea/PatienceFillClip/PatienceFillArt") as TextureRect
	_ok(timer != null, "TimerBar remains the public Tavern patience ProgressBar path")
	if timer != null:
		_ok(timer.size == PATIENCE_BAR_SIZE, "TimerBar uses the slim tabletop groove patience layout")
		_ok(timer.global_position.x >= ORDER_GROOVE_SAFE_LEFT and timer.global_position.x + timer.size.x <= ORDER_GROOVE_SAFE_RIGHT,
			"TimerBar is embedded inside the table-carved order groove horizontally")
		_ok(timer.global_position.y >= ORDER_GROOVE_SAFE_TOP and timer.global_position.y + timer.size.y <= ORDER_GROOVE_SAFE_BOTTOM,
			"TimerBar is embedded inside the table-carved order groove vertically")
		_ok(timer.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"TimerBar does not block table item clicks through the customer area")
		_ok(_stylebox_texture_path(timer, "background") == "res://assets/textures/ui/bar_patience_groove_bg.png",
			"TimerBar uses the groove-sized patience background art")
		_ok(_stylebox_texture_path(timer, "fill") == "",
			"TimerBar no longer stretches the patience fill art through ProgressBar fill")
		tavern.update_timer(0.42)
		_ok(is_equal_approx(timer.value, 42.0), "TavernView.update_timer still drives TimerBar value")
	_ok(fill_clip != null, "PatienceFillClip masks the fixed patience fill art")
	if fill_clip != null:
		_ok(fill_clip.size.y == PATIENCE_BAR_SIZE.y, "PatienceFillClip keeps the production bar height")
		_ok(fill_clip.global_position == timer.global_position,
			"PatienceFillClip is aligned exactly over TimerBar")
		_ok(fill_clip.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"PatienceFillClip does not block table item clicks")
		_ok(fill_clip.clip_contents, "PatienceFillClip clips the fill instead of scaling it")
		_ok(abs(fill_clip.size.x - round(PATIENCE_BAR_SIZE.x * 0.42)) <= 1.0,
			"update_timer reduces the clip width to reveal less fill")
	_ok(fill_art != null, "PatienceFillArt keeps the full-size fill texture inside the clip")
	if fill_art != null:
		_ok(fill_art.size == PATIENCE_BAR_SIZE, "PatienceFillArt remains full width and is not resized by patience")
		_ok(fill_art.scale == Vector2.ONE, "PatienceFillArt is not scaled during patience drain")
		_ok(fill_art.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"PatienceFillArt does not block table item clicks")
		_ok(fill_art.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
			"PatienceFillArt renders with nearest filtering")
		_ok(_texture_path(fill_art.texture) == "res://assets/textures/ui/bar_patience_groove_fill.png",
			"PatienceFillArt uses the groove-sized runtime patience fill art")
		tavern.update_timer(0.0)
		_ok(fill_art.size == PATIENCE_BAR_SIZE, "PatienceFillArt stays full width even when patience is empty")
		if fill_clip != null:
			_ok(fill_clip.size.x == 0.0, "empty patience hides the fill through clipping")
		tavern.update_timer(1.0)
		_ok(fill_art.size == PATIENCE_BAR_SIZE, "PatienceFillArt stays full width when patience refills")
		if fill_clip != null:
			_ok(fill_clip.size.x == PATIENCE_BAR_SIZE.x, "full patience reveals the full fixed fill texture")

	var icon := tavern.get_node_or_null("CustomerArea/PatienceIcon") as TextureRect
	_ok(icon != null, "Tavern adds a PatienceIcon beside TimerBar")
	if icon != null:
		_ok(icon.size == Vector2(32, 32), "PatienceIcon uses the native 32x32 runtime icon size")
		_ok(icon.global_position.x >= ORDER_GROOVE_SAFE_LEFT and icon.global_position.x + icon.size.x <= ORDER_GROOVE_SAFE_RIGHT,
			"PatienceIcon sits inside the table-carved order groove horizontally")
		_ok(icon.global_position.y >= ORDER_GROOVE_SAFE_TOP and icon.global_position.y + icon.size.y <= ORDER_GROOVE_SAFE_BOTTOM,
			"PatienceIcon sits inside the table-carved order groove vertically")
		_ok(_texture_path(icon.texture) == "res://assets/textures/ui/icon_patience.png",
			"PatienceIcon uses the runtime patience icon")
		_ok(icon.texture != null and icon.texture.get_size() == Vector2(32, 32),
			"PatienceIcon loaded texture is the current 32x32 runtime export")
		_ok(icon.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "PatienceIcon uses nearest texture filtering")

	var customer_area := tavern.get_node_or_null("CustomerArea") as Control
	_ok(customer_area != null, "CustomerArea remains the public customer visual container path")
	if customer_area != null:
		_ok(customer_area.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"CustomerArea lets center-table clicks reach BarWorkspace")
	_ok(tavern.has_method("get_tutorial_highlight_rects"),
		"TavernView exposes live tutorial highlight rects for Tavern tutorial triggers")
	if tavern.has_method("get_tutorial_highlight_rects"):
		var serve_rects: Dictionary = tavern.get_tutorial_highlight_rects("serve")
		var customer_rect := serve_rects.get("CustomerNode", []) as Array
		_ok(serve_rects.has("CustomerNode"), "serve tutorial provides the CustomerNode highlight key")
		if customer_area != null:
			_ok(_rect_array_close(customer_rect, _control_screen_rect(customer_area)),
				"serve tutorial CustomerNode highlight follows the live CustomerArea rect")

	var customer_sprite := tavern.get_node_or_null("CustomerArea/CustomerSprite") as TextureRect
	var tabletop := tavern.get_node_or_null("TabletopArt") as Sprite2D
	_ok(customer_sprite != null, "CustomerSprite remains the public Tavern customer portrait path")
	if customer_sprite != null and tabletop != null:
		_ok(customer_sprite.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"CustomerSprite does not block table item clicks")
		_ok(customer_sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
			"CustomerSprite renders pixel portraits with nearest filtering")
		_ok(customer_sprite.z_index < tabletop.z_index,
			"CustomerSprite draws behind TabletopArt so bust portraits can be occluded by the bar")
		_ok(customer_sprite.global_position.y + customer_sprite.size.y > 484.0,
			"CustomerSprite extends behind the background table top edge for bar occlusion")

	var customer_name := tavern.get_node_or_null("CustomerArea/CustomerName") as Label
	var order_bubble := tavern.get_node_or_null("CustomerArea/OrderBubble") as Label
	var order_ticket_frame := tavern.get_node_or_null("CustomerArea/OrderTicketFrame") as TextureRect
	var order_icon := tavern.get_node_or_null("CustomerArea/OrderIcon") as TextureRect
	var reaction_bubble := tavern.get_node_or_null("CustomerArea/ReactionBubble") as Label
	var reaction_highlight := tavern.get_node_or_null("CustomerArea/ReactionHighlight") as RichTextLabel
	_ok(customer_name != null, "CustomerName remains the public Tavern customer name label path")
	if customer_name != null:
		_ok(_control_uses_pixel_font(customer_name), "CustomerName uses the shared pixel UI font")
		_ok(customer_name.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"CustomerName does not block table item clicks")
		_ok(customer_name.text == "", "CustomerName starts blank when no guest is present")
		_ok(not customer_name.visible, "CustomerName starts hidden when no guest is present")
	_ok(order_bubble != null, "OrderBubble remains the public Tavern customer request label path")
	if order_bubble != null:
		_ok(_control_uses_pixel_font(order_bubble), "OrderBubble uses the shared pixel UI font")
		_ok(order_bubble.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"OrderBubble does not block table item clicks")
		_ok(order_bubble.global_position.x >= ORDER_GROOVE_SAFE_LEFT and order_bubble.global_position.x + order_bubble.size.x <= ORDER_GROOVE_SAFE_RIGHT,
			"OrderBubble is embedded inside the table-carved order groove horizontally")
		_ok(order_bubble.global_position.y >= ORDER_GROOVE_SAFE_TOP and order_bubble.global_position.y + order_bubble.size.y <= ORDER_GROOVE_SAFE_BOTTOM,
			"OrderBubble is embedded inside the table-carved order groove vertically")
		_ok(order_bubble.size.y >= 28.0, "OrderBubble has enough room for a readable one-line counter order label")
		_ok(order_bubble.get_theme_font_size("font_size") >= 18, "OrderBubble uses a readable order font size")
		_ok(order_bubble.get_theme_color("font_color") == ThemeColors.TEXT_LIGHT,
			"OrderBubble uses high-contrast light text for the order")
		_ok(order_bubble.get_theme_constant("outline_size") >= 3,
			"OrderBubble uses a dark outline so requests remain readable over the counter")
	_ok(order_ticket_frame == null, "Tavern no longer uses a separate floating OrderTicketFrame")
	_ok(order_icon == null, "Tavern no longer uses a separate floating OrderIcon")
	_ok(reaction_bubble != null, "ReactionBubble separates temporary customer reactions from the stable order request")
	if reaction_bubble != null:
		_ok(_control_uses_pixel_font(reaction_bubble), "ReactionBubble uses the shared pixel UI font")
		_ok(reaction_bubble.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"ReactionBubble does not block table item clicks")
		_ok(reaction_bubble.get_theme_font_size("font_size") >= 16, "ReactionBubble remains readable for short customer reactions")
		_ok(reaction_bubble.get_theme_color("font_color") == Color.WHITE,
			"ReactionBubble uses white dialogue text so clue highlights can be layered separately")
	_ok(reaction_highlight != null, "ReactionHighlight renders highlighted clue phrases without replacing ReactionBubble")
	if reaction_highlight != null:
		_ok(reaction_highlight.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"ReactionHighlight does not block table item clicks")
		_ok(reaction_highlight.get_theme_font("normal_font") != null
				and reaction_highlight.get_theme_font("normal_font").resource_path == PIXEL_FONT_PATH,
			"ReactionHighlight uses the shared pixel UI font")

	if order_bubble != null and reaction_bubble != null:
		tavern.show_customer("Test Guest", "order_ale", "regular_belta", "ale_beer")
		if customer_name != null:
			_ok(customer_name.visible, "show_customer reveals CustomerName for the active guest")
			_ok(customer_name.text == "Test Guest", "show_customer writes the active guest name")
		_ok(order_bubble.visible, "show_customer reveals the table-carved order text")
		_ok(order_bubble.text.begins_with("需要 · "), "show_customer uses readable Chinese order prefix")
		_ok(order_bubble.text.find("order_ale") >= 0, "show_customer writes the stable order request to OrderBubble")
		tavern.customer_say("hurry")
		_ok(order_bubble.text.find("order_ale") >= 0, "customer_say does not overwrite the stable order request")
		_ok(order_bubble.text.find("hurry") == -1, "temporary reaction text stays out of OrderBubble")
		_ok(reaction_bubble.text == "hurry", "customer_say writes temporary text to ReactionBubble")
		if reaction_highlight != null:
			_ok(not reaction_highlight.visible, "plain customer_say keeps the highlight overlay hidden")
			tavern.customer_say("客人: [color=#d6a84d]线索[/color]")
			_ok(reaction_bubble.text == "客人: 线索", "highlighted customer_say keeps plain text in ReactionBubble")
			_ok(reaction_highlight.visible, "highlighted customer_say shows the rich-text clue overlay")
			_ok(reaction_highlight.text.contains("[color=#d6a84d]线索[/color]"),
				"ReactionHighlight keeps the BBCode clue color span")
		if tavern.has_method("show_order_timeout"):
			tavern.show_order_timeout("timeout")
			_ok(order_bubble.text.find("order_ale") >= 0, "timeout state keeps the original order readable")
			_ok(order_bubble.text.find("timeout") >= 0, "timeout state adds a clear failure reason in the groove label")
			_ok(order_bubble.text.find("\n") == -1, "groove order text stays on one readable line")
		tavern.hide_customer()
		if customer_name != null:
			_ok(customer_name.text == "", "hide_customer clears the idle waiting placeholder text")
			_ok(not customer_name.visible, "hide_customer hides CustomerName while no guest is present")
		_ok(not order_bubble.visible, "hide_customer hides the order text while no guest is present")
	var btn_tutorial := tavern.get_node_or_null("OverlayMenu/TabBtns/BtnTutorial") as Button
	_ok(btn_tutorial != null and btn_tutorial.text == "重置教程", "reset tutorial menu button uses readable Chinese")
	var tavern_source := FileAccess.get_file_as_string("res://scripts/ui/tavern_view.gd")
	_ok(tavern_source.contains('"barrel": "酒桶"') and tavern_source.contains('"grill": "烤架"') and tavern_source.contains('"pot": "炖锅"'),
		"recipe container names use readable Chinese source strings")
	_ok(tavern_source.contains('tutorial_btn.text = "重置教程"'),
		"reset tutorial dynamic button uses readable Chinese source text")
	_ok(tavern_source.contains('%d金') and not tavern_source.contains('%d閲'),
		"recipe row price source uses readable Chinese currency text")
	_ok(tavern_source.contains('"暂无配方"') and not tavern_source.contains("鏆傛棤"),
		"empty recipe detail source uses readable Chinese")
	_ok(tavern_source.contains('"IngredientTitle", "材料"') and not tavern_source.contains("鏉愭枡"),
		"recipe ingredient heading source uses readable Chinese")
	var stage_caption := tavern.get_node_or_null("StageCaption") as Label
	_ok(stage_caption != null, "StageCaption remains the public tavern feedback caption path")
	if stage_caption != null:
		_ok(_control_uses_pixel_font(stage_caption), "StageCaption uses the shared pixel UI font")
		_ok(stage_caption.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"StageCaption does not block center-table item clicks while faded out")
		tavern.show_stage_caption("今日客流招待完毕，可以打烊了！", ThemeColors.AMBER_PRIMARY)
		_ok(stage_caption.text == "今日客流招待完毕，可以打烊了！",
			"show_stage_caption keeps the all-guests-served caption as Godot-rendered text")
		_ok(_control_uses_pixel_font(stage_caption),
			"all-guests-served StageCaption remains rendered with the pixel UI font")
	var inference_notice := tavern.get_node_or_null("InferenceReadyNotice") as Label
	_ok(inference_notice != null, "Tavern exposes a visual-only inference-ready question mark notice")
	if inference_notice != null:
		_ok(inference_notice.text == "?", "inference-ready notice uses a question mark, not button text")
		_ok(inference_notice.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"inference-ready notice never blocks tavern clicks")
		_ok(not inference_notice.visible and inference_notice.modulate.a <= 0.01,
			"inference-ready notice starts hidden")
		_ok(_control_uses_pixel_font(inference_notice),
			"inference-ready notice uses the shared pixel UI font")
	_ok(tavern.has_method("show_inference_ready_notice"),
		"TavernView exposes a transient inference-ready notice method for GameManager")
	if inference_notice != null and tavern.has_method("show_inference_ready_notice"):
		tavern.call("show_inference_ready_notice")
		await get_tree().process_frame
		_ok(inference_notice.visible and inference_notice.modulate.a > 0.0,
			"show_inference_ready_notice reveals the question mark immediately")
		await get_tree().create_timer(1.8).timeout
		_ok((not inference_notice.visible) or inference_notice.modulate.a <= 0.05,
			"inference-ready notice fades itself out instead of staying on the tavern screen")

	var top_panel_bg := tavern.get_node_or_null("TopPanelBg") as Panel
	var top_panel := tavern.get_node_or_null("TopPanel") as HBoxContainer
	_ok(top_panel_bg != null, "TopPanelBg remains the public Tavern top-strip background path")
	if top_panel_bg != null:
		_ok(top_panel_bg.size == Vector2(1280, 48), "TopPanelBg uses the production 1280x48 top strip layout")
		_ok(_stylebox_texture_path(top_panel_bg, "panel") == "res://assets/textures/ui/bar_top_panel.png",
			"TopPanelBg uses the runtime topbar pixel art")
		var topbar_texture := _stylebox_texture(top_panel_bg, "panel")
		_ok(topbar_texture != null and topbar_texture.get_size() == Vector2(1280, 48),
			"TopPanelBg topbar texture is the 1280x48 runtime export")
	_ok(top_panel != null, "TopPanel remains the public Tavern top-strip container path")
	if top_panel != null:
		_ok(top_panel.size == Vector2(1280, 48), "TopPanel uses the production 1280x48 top strip layout")
		_ok(top_panel.get_theme_constant("separation") == 8, "TopPanel uses compact 8px spacing")
		var left_inset := top_panel.get_node_or_null("TopbarLeftInset") as Control
		var action_spacer := top_panel.get_node_or_null("TopbarActionSpacer") as Control
		var right_inset := top_panel.get_node_or_null("TopbarRightInset") as Control
		_ok(left_inset != null and left_inset.custom_minimum_size == Vector2(28, 48),
			"TopPanel keeps text clear of the left metal cap")
		_ok(action_spacer != null and action_spacer.size_flags_horizontal == Control.SIZE_EXPAND_FILL,
			"TopPanel pushes action buttons to the right side of the strip")
		_ok(right_inset != null and right_inset.custom_minimum_size == Vector2(28, 48),
			"TopPanel keeps buttons clear of the right metal cap")
		for path in ["GoldLabel", "ReputationLabel", "DayLabel", "MenuButton", "EndNightBtn"]:
			var control := top_panel.get_node_or_null(path) as Control
			_ok(control != null, "TopPanel/%s remains available" % path)
			if control != null:
				_ok(_control_uses_pixel_font(control), "TopPanel/%s uses the shared pixel UI font" % path)
		for path in ["GoldLabel", "ReputationLabel", "DayLabel"]:
			var label := top_panel.get_node_or_null(path) as Label
			if label != null:
				_ok(label.custom_minimum_size.y == 48.0, "TopPanel/%s fills the 48px strip height" % path)
				_ok(label.vertical_alignment == VERTICAL_ALIGNMENT_CENTER,
					"TopPanel/%s text is vertically centered" % path)
		var menu_button := top_panel.get_node_or_null("MenuButton") as Button
		if menu_button != null:
			_ok(menu_button.custom_minimum_size == Vector2(96, 48), "TopPanel/MenuButton uses the dedicated topbar button size")
			_ok(menu_button.global_position.x >= 1040.0, "TopPanel/MenuButton sits in the right action group")
			_ok(_button_stylebox_texture_path(menu_button, "normal") == "res://assets/textures/ui/topbar_menu_button_normal.png",
				"TopPanel/MenuButton normal art is dedicated topbar art")
			_ok(_button_stylebox_texture_path(menu_button, "hover") == "res://assets/textures/ui/topbar_menu_button_hover.png",
				"TopPanel/MenuButton hover art is dedicated topbar art")
			_ok(_button_stylebox_texture_path(menu_button, "pressed") == "res://assets/textures/ui/topbar_menu_button_pressed.png",
				"TopPanel/MenuButton pressed art is dedicated topbar art")
		var end_night_button := top_panel.get_node_or_null("EndNightBtn") as Button
		if end_night_button != null:
			_ok(end_night_button.custom_minimum_size == Vector2(96, 48), "TopPanel/EndNightBtn uses the dedicated topbar button size")
			_ok(end_night_button.global_position.x + end_night_button.size.x <= 1252.0,
				"TopPanel/EndNightBtn leaves room for the right metal cap")
			_ok(_button_stylebox_texture_path(end_night_button, "normal") == "res://assets/textures/ui/topbar_end_night_button_normal.png",
				"TopPanel/EndNightBtn normal art is dedicated topbar art")
			_ok(_button_stylebox_texture_path(end_night_button, "hover") == "res://assets/textures/ui/topbar_end_night_button_hover.png",
				"TopPanel/EndNightBtn hover art is dedicated topbar art")
			_ok(_button_stylebox_texture_path(end_night_button, "pressed") == "res://assets/textures/ui/topbar_end_night_button_pressed.png",
				"TopPanel/EndNightBtn pressed art is dedicated topbar art")

	var reward_layer := tavern.get_node_or_null("RewardFeedbackLayer") as CanvasLayer
	_ok(reward_layer != null, "Tavern adds a visual-only RewardFeedbackLayer for UI-travel rewards")
	var reward_particles: Node = null
	if reward_layer != null:
		reward_particles = reward_layer.get_node_or_null("Particles")
		_ok(reward_particles is Node2D, "RewardFeedbackLayer exposes a Particles node for travel particles")

	var coin_layer := tavern.get_node_or_null("RewardCoinPhysicsLayer") as Node2D
	_ok(coin_layer != null, "Tavern adds an isolated RewardCoinPhysicsLayer for bouncing reward coins")
	if coin_layer != null:
		_ok(coin_layer.get_node_or_null("CoinGround") is StaticBody2D,
			"RewardCoinPhysicsLayer exposes an invisible reward-only CoinGround")

	var gold_progress := tavern.get_node_or_null("TopPanel/GoldProgress") as Control
	var rep_progress := tavern.get_node_or_null("TopPanel/ReputationProgress") as Control
	_ok(gold_progress != null, "TopPanel adds GoldProgress without replacing GoldLabel")
	_ok(rep_progress != null, "TopPanel adds ReputationProgress without replacing ReputationLabel")
	if gold_progress != null and rep_progress != null:
		_ok(gold_progress.size == rep_progress.size,
			"GoldProgress and ReputationProgress use the same visual frame size")
		_ok(abs(gold_progress.global_position.y - rep_progress.global_position.y) <= 0.01,
			"GoldProgress and ReputationProgress top edges are vertically aligned")
	for progress in [gold_progress, rep_progress]:
		if progress == null:
			continue
		_ok(progress.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"%s ignores mouse input" % progress.name)
		_ok(progress.get_node_or_null("Bg") is TextureRect,
			"%s has a background art node" % progress.name)
		_ok(progress.get_node_or_null("FillClip") is Control,
			"%s has a clipping fill node" % progress.name)
		_ok(progress.get_node_or_null("FillClip/Fill") is TextureRect,
			"%s has a fixed fill art node" % progress.name)
		_ok(progress.get_node_or_null("Ornate") is TextureRect,
			"%s has a milestone-only ornate overlay" % progress.name)
		var bg := progress.get_node_or_null("Bg") as TextureRect
		var progress_fill_clip := progress.get_node_or_null("FillClip") as Control
		var fill := progress.get_node_or_null("FillClip/Fill") as TextureRect
		var ornate := progress.get_node_or_null("Ornate") as TextureRect
		if bg != null and progress_fill_clip != null:
			_ok(bg.z_index > progress_fill_clip.z_index,
				"%s draws the progress frame above the fill layer" % progress.name)
			_ok(bg.size == REWARD_PROGRESS_FRAME_SIZE,
				"%s frame uses the full progress art size" % progress.name)
			var expected_art_offset := REWARD_REP_PROGRESS_ART_OFFSET if progress.name == "ReputationProgress" else Vector2.ZERO
			_ok(bg.position == expected_art_offset,
				"%s frame art is vertically offset to align visible slot centers" % progress.name)
			_ok(progress_fill_clip.position == expected_art_offset + REWARD_PROGRESS_FILL_INSET,
				"%s fill clip starts inside the frame window" % progress.name)
			_ok(progress_fill_clip.size.y == REWARD_PROGRESS_FILL_SIZE.y,
				"%s fill clip height matches the frame window" % progress.name)
		if bg != null and ornate != null:
			_ok(ornate.z_index > bg.z_index,
				"%s milestone overlay draws above the frame" % progress.name)
			_ok(ornate.position == bg.position,
				"%s milestone overlay stays aligned to the progress frame art" % progress.name)
			_ok(ornate.size == bg.size,
				"%s milestone overlay uses the same frame size as the progress art" % progress.name)
		if fill != null:
			_ok(fill.size == REWARD_PROGRESS_FRAME_SIZE,
				"%s fill art keeps full frame size for texture alignment" % progress.name)
			_ok(fill.position == -REWARD_PROGRESS_FILL_INSET,
				"%s fill art is offset so the texture aligns with the frame window" % progress.name)
		for art in [bg, fill, ornate]:
			if art != null:
				_ok(art.mouse_filter == Control.MOUSE_FILTER_IGNORE,
					"%s/%s ignores mouse input" % [progress.name, art.name])
				_ok(art.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
					"%s/%s uses nearest filtering" % [progress.name, art.name])
	if gold_progress != null and rep_progress != null:
		var gold_bg := gold_progress.get_node_or_null("Bg") as TextureRect
		var rep_bg := rep_progress.get_node_or_null("Bg") as TextureRect
		var gold_fill_layer := gold_progress.get_node_or_null("FillClip") as Control
		var rep_fill_layer := rep_progress.get_node_or_null("FillClip") as Control
		if gold_bg != null and rep_bg != null:
			var gold_visual_center_y := gold_bg.global_position.y + REWARD_GOLD_FRAME_VISIBLE_HEIGHT * 0.5
			var rep_visual_center_y := rep_bg.global_position.y + REWARD_REP_FRAME_VISIBLE_HEIGHT * 0.5
			_ok(abs(gold_visual_center_y - rep_visual_center_y) <= 0.01,
				"gold and reputation progress frames share the same visual centerline")
		if gold_fill_layer != null and rep_fill_layer != null:
			_ok(abs((gold_fill_layer.global_position.y + 4.0) - rep_fill_layer.global_position.y) <= 0.01,
				"gold and reputation progress fill layers are visually centered after reputation art offset")

	_ok(tavern.has_method("show_order_reward_feedback"), "TavernView exposes reward feedback method")
	if tavern.has_method("show_order_reward_feedback") and coin_layer != null and reward_particles is Node2D:
		_update_top_bar_with_max(tavern, 13, 8, 1, 30, 80)
		var gold_label := tavern.get_node_or_null("TopPanel/GoldLabel") as Label
		var gold_fill_clip := tavern.get_node_or_null("TopPanel/GoldProgress/FillClip") as Control
		var rep_fill_clip := tavern.get_node_or_null("TopPanel/ReputationProgress/FillClip") as Control
		_ok(gold_label != null and gold_label.text.find("13") >= 0,
			"GoldLabel reflects current spendable gold")
		_ok(gold_fill_clip != null and abs(gold_fill_clip.size.x - 86.0) <= 2.0,
			"GoldProgress fill reflects historical max held gold, not current spendable gold")
		_ok(rep_fill_clip != null and abs(rep_fill_clip.size.x - 23.0) <= 2.0,
			"ReputationProgress fill reflects the visible 8/50 pre-reward progress")
		_update_top_bar_with_max(tavern, 25, 8, 1, 30, 120)
		_update_top_bar_with_max(tavern, 5, 8, 1, 30, 120)
		_ok(gold_label != null and gold_label.text.find("5") >= 0 and gold_label.text.find("25") == -1,
			"GoldLabel can decrease after spending")
		_ok(gold_fill_clip != null and abs(gold_fill_clip.size.x - 29.0) <= 2.0,
			"GoldProgress does not retreat after spending when max held gold is unchanged")

		var coin_count_before := _reward_coin_body_count(coin_layer)
		var particle_count_before := (reward_particles as Node2D).get_child_count()
		_update_top_bar_with_max(tavern, 25, 10, 1, 30, 80)
		_show_order_reward_feedback_with_max(tavern, 12, 2, 13, 8, 80, 80)
		_update_top_bar_with_max(tavern, 25, 10, 1, 30, 80)
		await get_tree().process_frame
		_ok(gold_label != null and gold_label.text.find("13") >= 0 and gold_label.text.find("25") == -1,
			"gold label keeps the previous total until tabletop coins are collected")
		_ok(gold_fill_clip != null and abs(gold_fill_clip.size.x - 86.0) <= 2.0,
			"GoldProgress fill keeps historical max while tabletop coins are pending")
		_ok(rep_fill_clip != null and abs(rep_fill_clip.size.x - 29.0) <= 2.0,
			"ReputationProgress fill can advance with auto-travel reputation particles")
		var coin_count_after_spawn := _reward_coin_body_count(coin_layer)
		_ok(coin_count_after_spawn > coin_count_before,
			"positive gold reward spawns temporary physical coin bodies")
		_ok((reward_particles as Node2D).get_child_count() > particle_count_before,
			"positive reputation reward spawns UI-travel reputation particles")
		await get_tree().create_timer(0.55).timeout
		_ok(_reward_coin_body_count(coin_layer) >= coin_count_after_spawn,
			"gold reward coins remain on the bar until the player clicks")
		var gold_particle_count_before := (reward_particles as Node2D).get_child_count()
		var click_event := InputEventMouseButton.new()
		click_event.button_index = MOUSE_BUTTON_LEFT
		click_event.pressed = true
		click_event.position = Vector2(64.0, 64.0)
		_ok(tavern.has_method("_input"), "TavernView captures left-click input for reward collection")
		tavern.set_dialogue_mode(true)
		if tavern.has_method("_input"):
			tavern.call("_input", click_event)
		await get_tree().process_frame
		_ok(_reward_coin_body_count(coin_layer) >= coin_count_after_spawn,
			"left-click during dialogue does not collect pending reward coins")
		tavern.set_dialogue_mode(false)
		gold_particle_count_before = (reward_particles as Node2D).get_child_count()
		if tavern.has_method("_input"):
			tavern.call("_input", click_event)
		await get_tree().process_frame
		_ok(_reward_coin_body_count(coin_layer) == 0,
			"left-click after dialogue collects all pending reward coins")
		_ok((reward_particles as Node2D).get_child_count() > gold_particle_count_before,
			"collected reward coins transfer into UI-travel particles")
		await get_tree().create_timer(0.78).timeout
		_ok(gold_label != null and gold_label.text.find("25") >= 0,
			"gold label advances after collected coins reach the UI")
		_ok(gold_fill_clip != null and abs(gold_fill_clip.size.x - 86.0) <= 2.0,
			"GoldProgress fill remains on historical max if the reward does not beat it")

		_update_top_bar_with_max(tavern, 45, 10, 1, 30, 45)
		_update_top_bar_with_max(tavern, 55, 10, 1, 30, 55)
		_show_order_reward_feedback_with_max(tavern, 10, 0, 45, 10, 45, 55)
		await get_tree().process_frame
		var gold_ornate := tavern.get_node_or_null("TopPanel/GoldProgress/Ornate") as TextureRect
		_ok(gold_ornate != null and not gold_ornate.visible,
			"crossing a gold milestone waits for coin collection before showing ornate progress")
		if tavern.has_method("_input"):
			tavern.call("_input", click_event)
		await get_tree().create_timer(0.78).timeout
		_ok(gold_ornate != null and gold_ornate.visible,
			"crossing a gold milestone activates the ornate overlay after collection reaches the UI")
		await get_tree().create_timer(1.15).timeout
		_ok(gold_ornate != null and gold_ornate.visible,
			"gold milestone overlay remains visible as the new permanent progress slot")

		_show_order_reward_feedback_with_max(tavern, 0, 2, 55, 48, 55, 55)
		await get_tree().process_frame
		var rep_ornate := tavern.get_node_or_null("TopPanel/ReputationProgress/Ornate") as TextureRect
		_ok(rep_ornate != null and rep_ornate.visible,
			"crossing a reputation milestone activates the ornate overlay")
		await get_tree().create_timer(1.15).timeout
		_ok(rep_ornate != null and rep_ornate.visible,
			"reputation milestone overlay remains visible as the new permanent progress slot")

	var shortcut_bg := tavern.get_node_or_null("ShortcutBarBg") as Panel
	var shortcut_bar := tavern.get_node_or_null("ShortcutBar") as HBoxContainer
	_ok(shortcut_bg != null, "ShortcutBarBg remains the public Tavern shortcut tray path")
	if shortcut_bg != null:
		_ok(shortcut_bg.size == Vector2(1000, 40), "ShortcutBarBg uses the production 1000x40 shortcut tray layout")
		_ok(_stylebox_texture_path(shortcut_bg, "panel") == "res://assets/textures/ui/bar_shortcut_bg.png",
			"ShortcutBarBg uses the dedicated shortcut tray art")
		var shortcut_bg_texture := _stylebox_texture(shortcut_bg, "panel")
		_ok(shortcut_bg_texture != null and shortcut_bg_texture.get_size() == Vector2(1000, 40),
			"ShortcutBarBg texture is the 1000x40 runtime export")
	_ok(shortcut_bar != null, "ShortcutBar remains the public Tavern material slot container path")
	if shortcut_bar != null:
		_ok(shortcut_bar.size == Vector2(1000, 40), "ShortcutBar uses the production 1000x40 shortcut layout")
		_ok(shortcut_bar.get_theme_constant("separation") == 4,
			"ShortcutBar uses 4px spacing so ten 96px slots fit the tray")
		for slot_index in range(10):
			var slot := shortcut_bar.get_node_or_null("Slot%d" % slot_index) as ColorRect
			_ok(slot != null, "ShortcutBar/Slot%d remains available" % slot_index)
			if slot != null:
				_ok(slot.custom_minimum_size == Vector2(96, 40),
					"ShortcutBar/Slot%d uses the native 96x40 shortcut slot size" % slot_index)
				_ok(slot.size == Vector2(96, 40),
					"ShortcutBar/Slot%d does not stretch or squash shortcut slot art" % slot_index)
		if shortcut_bg != null:
			var slot9 := shortcut_bar.get_node_or_null("Slot9") as ColorRect
			if slot9 != null:
				var right_gap := shortcut_bg.global_position.x + shortcut_bg.size.x - (slot9.global_position.x + slot9.size.x)
				_ok(right_gap >= 2.0 and right_gap <= 6.0,
					"ShortcutBar/Slot9 ends at the tray right cap instead of leaving a visible right-side void: gap %.2f" % right_gap)
	if tavern.has_method("get_tutorial_highlight_rects"):
		var craft_rects: Dictionary = tavern.get_tutorial_highlight_rects("craft")
		var shortcut_rect := craft_rects.get("ShortcutBar", []) as Array
		_ok(craft_rects.has("ShortcutBar"), "craft tutorial provides the ShortcutBar highlight key")
		if shortcut_bar != null:
			_ok(_rect_array_close(shortcut_rect, _control_screen_rect(shortcut_bar)),
				"craft tutorial ShortcutBar highlight follows the live ShortcutBar rect")
		var barrel_rect := craft_rects.get("CraftBarrel", []) as Array
		var recovery_rect := craft_rects.get("RecoveryContainer", []) as Array
		var brewery_art := tavern.get_node_or_null("BarWorkspace/World/Brewery/Art") as Sprite2D
		_ok(craft_rects.has("CraftBarrel"), "craft tutorial provides the CraftBarrel highlight key")
		if brewery_art != null:
			_ok(_rect_contains_point(barrel_rect, brewery_art.global_position),
				"craft tutorial CraftBarrel highlight contains the live brewery art center")
			_ok(_rect_center(barrel_rect).distance_to(brewery_art.global_position) <= 32.0,
				"craft tutorial CraftBarrel highlight is centered on the live brewery art")
		_ok(craft_rects.has("RecoveryContainer"), "craft tutorial provides the RecoveryContainer highlight key")
		for container_path in [
			"BarWorkspace/World/Brewery",
			"BarWorkspace/World/SeasoningShaker",
			"BarWorkspace/World/Pot",
		]:
			var container := tavern.get_node_or_null(container_path) as Node2D
			if _tutorial_target_available(container):
				_ok(_rect_contains_point(recovery_rect, container.global_position),
					"craft tutorial RecoveryContainer highlight covers %s" % container_path)
		if tavern.has_method("configure_slice_day"):
			tavern.configure_slice_day(3)
			await get_tree().process_frame
			craft_rects = tavern.get_tutorial_highlight_rects("craft")
			recovery_rect = craft_rects.get("RecoveryContainer", []) as Array
			var day3_pot := tavern.get_node_or_null("BarWorkspace/World/Pot") as Node2D
			_ok(_tutorial_target_available(day3_pot), "Day 3 enables the pot tutorial target")
			if day3_pot != null:
				_ok(_rect_contains_point(recovery_rect, day3_pot.global_position),
					"craft tutorial RecoveryContainer highlight covers the pot when it is unlocked")
		var seasoning_rects: Dictionary = tavern.get_tutorial_highlight_rects("seasoning")
		var seasoning_rect := seasoning_rects.get("SeasoningShaker", []) as Array
		var shaker := tavern.get_node_or_null("BarWorkspace/World/SeasoningShaker") as Node2D
		_ok(seasoning_rects.has("SeasoningShaker"), "seasoning tutorial provides the SeasoningShaker highlight key")
		if shaker != null:
			_ok(_rect_contains_point(seasoning_rect, shaker.global_position),
				"seasoning tutorial SeasoningShaker highlight contains the live shaker")
		_ok(seasoning_rects.has("ShortcutBar"), "seasoning tutorial also exposes ShortcutBar as source context")
		if shortcut_bar != null:
			_ok(_rect_array_close(seasoning_rects.get("ShortcutBar", []) as Array, _control_screen_rect(shortcut_bar)),
				"seasoning tutorial ShortcutBar highlight follows the live ShortcutBar rect")

	var ledger := tavern.get_node_or_null("BarWorkspace/World/Ledger") as ReadableDeskItem
	_ok(ledger != null, "Ledger compatibility node remains at BarWorkspace/World/Ledger")
	if ledger != null:
		_ok(ledger.visible, "Tavern work-surface ledger is visible on the table")
		_ok(ledger.input_pickable, "Tavern work-surface ledger receives double-click input")
		_ok(ledger.document_id == "ledger", "visible ledger still targets the ledger document")
		var ledger_art := ledger.get_node_or_null("Art") as Sprite2D
		_ok(ledger_art != null and ledger_art.texture != null, "visible ledger has production texture art")
		if ledger_art != null and ledger_art.texture != null:
			_ok(String(ledger_art.texture.resource_path) == "res://assets/textures/tavern/props/ledger.png",
				"visible ledger uses Tavern ledger prop art")

	tavern.queue_free()
	await get_tree().process_frame


func _test_tavern_game_manager_contract() -> void:
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame
	await get_tree().process_frame

	_ok(tavern.has_method("is_menu_open"), "TavernView exposes is_menu_open for GameManager update gating")
	_ok(tavern.has_method("is_menu_config_open"), "TavernView exposes is_menu_config_open for GameManager update gating")
	_ok(tavern.has_method("is_preparation_phase"), "TavernView exposes is_preparation_phase for GameManager update gating")
	_ok(tavern.has_method("is_business_phase"), "TavernView exposes is_business_phase for phase checks")
	_ok(tavern.has_method("get_daily_menu_items"), "TavernView exposes get_daily_menu_items for GuestSystem orders")
	_ok(tavern.has_method("reset_today_gold"), "TavernView exposes reset_today_gold for GameManager day cleanup")
	var has_daily_menu := "daily_menu" in tavern
	var has_daily_menu_confirmed := "daily_menu_confirmed" in tavern
	_ok(has_daily_menu, "TavernView exposes daily_menu for GameManager pricing")
	_ok(has_daily_menu_confirmed, "TavernView exposes daily_menu_confirmed for GameManager gating")
	if has_daily_menu:
		_ok(tavern.daily_menu is Dictionary, "TavernView daily_menu is a Dictionary")
	if has_daily_menu_confirmed:
		_ok(tavern.daily_menu_confirmed is bool, "TavernView daily_menu_confirmed is a bool")
	if tavern.has_method("is_menu_config_open"):
		_ok(tavern.is_menu_config_open() == true, "TavernView opens menu config when entering tavern")
	if tavern.has_method("is_preparation_phase"):
		_ok(tavern.is_preparation_phase() == true, "TavernView starts in menu preparation phase")
	if tavern.has_method("is_business_phase"):
		_ok(tavern.is_business_phase() == false, "TavernView does not enter business phase before menu confirmation")

	if tavern.has_method("get_daily_menu_items"):
		var menu_items: Array[Dictionary] = tavern.get_daily_menu_items()
		_ok(menu_items.is_empty(), "TavernView withholds orderable menu items before menu confirmation")
		if tavern.has_method("_confirm_menu_preparation"):
			tavern.call("_confirm_menu_preparation")
			menu_items = tavern.get_daily_menu_items()
		_ok(menu_items.size() >= 1, "TavernView provides orderable menu items after menu confirmation")
		for item in menu_items:
			_ok(item.has("key"), "TavernView menu item includes key")
			_ok(item.has("price"), "TavernView menu item includes price")
			_ok(item.has("name"), "TavernView menu item includes name")

	var gm = get_node("/root/GameManager")
	_ok(gm.guests._normal_order_limit == gm.ryan_slice.normal_order_limit(gm.economy.current_day),
		"GameManager configures the Ryan normal order budget when TavernView registers")
	gm._apply_save_state(gm._default_new_game_state())
	if gm.rumors != null:
		gm.rumors.restore_state({"current_day": 1, "heard_ids": [], "today_ids": []})
	gm.register_view(tavern)
	await get_tree().process_frame
	_ok(tavern.is_menu_config_open(), "GameManager opens menu preparation even when no rumor was heard")

	tavern.queue_free()
	await get_tree().process_frame


func _test_important_guest_patience_ratio_uses_important_guest_max() -> void:
	var gm = get_node("/root/GameManager")
	_ok(gm.has_method("_guest_patience_ratio"), "GameManager exposes a testable guest patience ratio helper")
	if not gm.has_method("_guest_patience_ratio"):
		return
	var important := GuestData.new()
	important.type = GuestData.GuestType.IMPORTANT
	important.patience = GuestData.BASE_PATIENCE * 1.5 - 1.0
	var important_ratio: float = gm._guest_patience_ratio(important)
	_ok(important_ratio < 1.0, "important guest patience bar starts moving before dropping below base patience")
	_ok(important_ratio > 0.95, "important guest patience ratio still starts near full")

	var normal := GuestData.new()
	normal.type = GuestData.GuestType.NORMAL
	normal.patience = GuestData.BASE_PATIENCE * 0.5
	_ok(is_equal_approx(gm._guest_patience_ratio(normal), 0.5), "normal guest patience ratio still uses base patience")
