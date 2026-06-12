extends Node

var _checks := 0
var _failures := 0

const PIXEL_FONT_PATH := "res://assets/fonts/fusion-pixel/fusion-pixel-12px-proportional-zh_hans.ttf"


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


func _button_stylebox_texture_path(button: Button, style_name: String) -> String:
	var stylebox := button.get_theme_stylebox(style_name) as StyleBoxTexture
	if stylebox == null:
		return ""
	return _texture_path(stylebox.texture)


func _test_tavern_patience_ui_contract() -> void:
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	add_child(tavern)
	await get_tree().process_frame
	await get_tree().process_frame

	var timer := tavern.get_node_or_null("CustomerArea/TimerBar") as ProgressBar
	_ok(timer != null, "TimerBar remains the public Tavern patience ProgressBar path")
	if timer != null:
		_ok(timer.size == Vector2(300, 28), "TimerBar uses the production 300x28 patience bar layout")
		_ok(timer.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"TimerBar does not block table item clicks through the customer area")
		_ok(_stylebox_texture_path(timer, "background") == "res://assets/textures/ui/bar_patience_bg.png",
			"TimerBar uses patience background art")
		_ok(_stylebox_texture_path(timer, "fill") == "res://assets/textures/ui/bar_patience_fill.png",
			"TimerBar uses patience fill art")
		tavern.update_timer(0.42)
		_ok(is_equal_approx(timer.value, 42.0), "TavernView.update_timer still drives TimerBar value")

	var icon := tavern.get_node_or_null("CustomerArea/PatienceIcon") as TextureRect
	_ok(icon != null, "Tavern adds a PatienceIcon beside TimerBar")
	if icon != null:
		_ok(icon.size == Vector2(32, 32), "PatienceIcon uses the 32x32 runtime icon size")
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
	_ok(customer_name != null, "CustomerName remains the public Tavern customer name label path")
	if customer_name != null:
		_ok(_control_uses_pixel_font(customer_name), "CustomerName uses the shared pixel UI font")
		_ok(customer_name.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"CustomerName does not block table item clicks")
	_ok(order_bubble != null, "OrderBubble remains the public Tavern customer request label path")
	if order_bubble != null:
		_ok(_control_uses_pixel_font(order_bubble), "OrderBubble uses the shared pixel UI font")
		_ok(order_bubble.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"OrderBubble does not block table item clicks")
	var stage_caption := tavern.get_node_or_null("StageCaption") as Label
	_ok(stage_caption != null, "StageCaption remains the public tavern feedback caption path")
	if stage_caption != null:
		_ok(stage_caption.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"StageCaption does not block center-table item clicks while faded out")

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
		_ok(tavern.is_menu_config_open() == false, "TavernView menu config reports closed when no config panel exists")
	if tavern.has_method("is_preparation_phase"):
		_ok(tavern.is_preparation_phase() == false, "TavernView defaults to business-compatible phase without the menu config UI")
	if tavern.has_method("is_business_phase"):
		_ok(tavern.is_business_phase() == true, "TavernView defaults to business-compatible phase after entering tavern")

	if tavern.has_method("get_daily_menu_items"):
		var menu_items: Array[Dictionary] = tavern.get_daily_menu_items()
		_ok(menu_items.size() >= 1, "TavernView provides at least one orderable menu item to GuestSystem")
		for item in menu_items:
			_ok(item.has("key"), "TavernView menu item includes key")
			_ok(item.has("price"), "TavernView menu item includes price")
			_ok(item.has("name"), "TavernView menu item includes name")

	var gm = get_node("/root/GameManager")
	_ok(gm.guests._normal_order_limit == gm.ryan_slice.normal_order_limit(gm.economy.current_day),
		"GameManager configures the Ryan normal order budget when TavernView registers")

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
