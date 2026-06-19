extends Node

var _checks := 0
var _failures := 0


func _ready() -> void:
	var overlay_scene := load("res://scenes/ui/ShopOverlay.tscn") as PackedScene
	if overlay_scene == null:
		_ok(false, "ShopOverlay scene exists")
		_finish()
		return
	var overlay = overlay_scene.instantiate()
	add_child(overlay)
	overlay.configure(get_node("/root/GameManager"))
	overlay.open()
	await get_tree().process_frame
	_test_core_layout(overlay)
	_test_nearest_filtering(overlay)
	_test_shop_clean_texture_paths(overlay)
	_test_shop_clean_text_safe_layout(overlay)
	await _test_shop_clean_direct_state_textures(overlay)
	await _test_recipe_unlocks_are_pageable_without_default_scrollbar(overlay)
	_test_default_selection(overlay)
	_test_mira_discount_state(overlay)
	_test_material_quantity_total(overlay)
	await _test_purchase_updates_inventory_and_gold(overlay)
	await _test_recipe_copy_describes_shop_as_menu_registration(overlay)
	await _test_owned_recipe_state(overlay)
	await _test_close_signal(overlay)
	overlay.queue_free()
	await get_tree().process_frame
	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-SHOP-OVERLAY] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-SHOP-OVERLAY] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-SHOP-OVERLAY] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _test_core_layout(overlay) -> void:
	_ok(overlay.visible, "overlay is visible after open")
	_ok(overlay.get_node_or_null("ShopBackdrop") is TextureRect, "overlay has shop clean backdrop")
	_ok(overlay.get_node_or_null("ShopStage") == null, "old dark shop stage is removed")
	_ok(overlay.get_node_or_null("MainBrushPanel") is Control, "legacy MainBrushPanel contract root remains")
	_ok(overlay.get_node_or_null("MainBrushPanel/ListPanel") is TextureRect, "legacy list panel path remains")
	_ok(overlay.get_node_or_null("MainBrushPanel/DetailPanelArt") is TextureRect, "legacy detail panel path remains")
	_ok(overlay.get_node_or_null("DetailPanel/TitleSlipArt") is TextureRect, "clean detail title slip exists")
	_ok(overlay.get_node_or_null("DetailPanel/BodyPanelArt") is TextureRect, "clean detail body panel exists")
	_ok(overlay.get_node_or_null("DetailPanel/UsesPanelArt") is TextureRect, "clean detail uses panel exists")
	_ok(not (overlay.get_node_or_null("DetailPanel/TitleSlipArt") as TextureRect).visible, "clean title slip is hidden to reduce right-page clutter")
	_ok(not (overlay.get_node_or_null("DetailPanel/BodyPanelArt") as TextureRect).visible, "clean body panel is hidden to reduce right-page clutter")
	_ok(not (overlay.get_node_or_null("DetailPanel/UsesPanelArt") as TextureRect).visible, "clean uses panel is hidden to reduce right-page clutter")
	_ok(overlay.get_node_or_null("CategoryTabs/MaterialsZone") is Button, "materials category zone exists")
	_ok(overlay.get_node_or_null("CategoryTabs/RecipesZone") is Button, "recipes category zone exists")
	_ok(overlay.get_node_or_null("CategoryTabs/AbilitiesZone") is Button, "abilities category zone exists")
	_ok(overlay.get_node_or_null("CategoryTabs/MaterialsHoverMark") == null, "materials tab no longer uses generic hover mark")
	_ok(overlay.get_node_or_null("CategoryTabs/RecipesHoverMark") == null, "recipes tab no longer uses generic hover mark")
	_ok(overlay.get_node_or_null("CategoryTabs/AbilitiesHoverMark") == null, "abilities tab no longer uses generic hover mark")
	_ok(overlay.get_node_or_null("ItemList") is Control, "item list exists")
	_ok(overlay.get_node_or_null("ItemList/Item_grape/HoverMark") == null, "item row no longer uses generic hover mark")
	_ok(overlay.get_node_or_null("DetailPanel/Title") is Label, "detail title exists")
	_ok(overlay.get_node_or_null("CheckoutBar/StripArt") is TextureRect, "legacy checkout strip path remains")
	_ok(not (overlay.get_node_or_null("CheckoutBar/StripArt") as TextureRect).visible, "purchase receipt strip is hidden under the seal")
	_ok(overlay.get_node_or_null("CheckoutBar/GoldAreaArt") is TextureRect, "legacy checkout gold area path remains")
	_ok(not (overlay.get_node_or_null("CheckoutBar/GoldAreaArt") as TextureRect).visible, "clean gold plate art is hidden")
	_ok(overlay.get_node_or_null("CheckoutBar/CheckoutArt") == null, "checkout does not add a second strip art path")
	_ok(overlay.get_node_or_null("CheckoutBar/GoldLabel") is Label, "checkout gold label exists")
	_ok(overlay.get_node_or_null("CheckoutBar/TotalLabel") is Label, "checkout total label exists")
	_ok(overlay.get_node_or_null("CheckoutBar/QuantityControl/MinusArt") is TextureRect, "quantity minus art exists")
	_ok(overlay.get_node_or_null("CheckoutBar/QuantityControl/BodyArt") is TextureRect, "quantity body art exists")
	_ok(overlay.get_node_or_null("CheckoutBar/QuantityControl/PlusArt") is TextureRect, "quantity plus art exists")
	_ok(overlay.get_node_or_null("CheckoutBar/QuantityControl/MinusHoverMark") == null, "quantity minus no longer uses generic hover mark")
	_ok(overlay.get_node_or_null("CheckoutBar/QuantityControl/PlusHoverMark") == null, "quantity plus no longer uses generic hover mark")
	_ok(overlay.get_node_or_null("CheckoutBar/QuantityControl/MinusZone") is Button, "quantity minus zone exists")
	_ok(overlay.get_node_or_null("CheckoutBar/QuantityControl/PlusZone") is Button, "quantity plus zone exists")
	_ok(overlay.get_node_or_null("CheckoutBar/PurchaseButton/HoverMark") == null, "purchase no longer uses generic hover mark")
	_ok(overlay.get_node_or_null("CheckoutBar/PurchaseButton/PurchaseZone") is Button, "purchase zone exists")
	_ok(overlay.get_node_or_null("CheckoutBar/CloseButton/HoverMark") == null, "close no longer uses generic hover mark")
	_ok(overlay.get_node_or_null("CheckoutBar/CloseButton/CloseZone") is Button, "close zone exists")
	_ok(overlay.get_node_or_null("CheckoutBar/CloseButton/CloseLabel") == null, "close button is icon-only")
	_ok(overlay.get_node_or_null("CheckoutBar/QuantityControl/ControlArt") == null, "old single quantity art is not used")
	_test_hover_text_does_not_block_input(overlay)
	_test_clean_layout_sizes(overlay)
	var purchase := overlay.get_node_or_null("CheckoutBar/PurchaseButton/PurchaseZone") as Button
	if purchase != null:
		_ok(purchase.text == "", "purchase input zone is textless")
		_ok(not purchase.has_theme_stylebox_override("normal"), "purchase input zone does not expose normal button skin")
	var purchase_label := overlay.get_node_or_null("CheckoutBar/PurchaseButton/PurchaseLabel") as Label
	if purchase_label != null:
		_ok(not purchase_label.visible, "purchase seal label is hidden")
		_ok(purchase_label.text == "", "purchase seal label has no command text")
	_ok(overlay.get_node_or_null("BookLayer") == null, "old large ledger layer is removed")
	_ok(overlay.get_node_or_null("Tabs") == null, "old tab container is removed")
	_ok(overlay.get_node_or_null("ItemGrid") == null, "old item card grid is removed")


func _test_hover_text_does_not_block_input(overlay) -> void:
	for path in [
		"CategoryTabs/MaterialsLabel",
		"CategoryTabs/RecipesLabel",
		"CategoryTabs/AbilitiesLabel",
		"ItemList/Item_ale/Name",
		"ItemList/Item_ale/Price",
	]:
		var label := overlay.get_node_or_null(path) as Label
		_ok(label != null and label.mouse_filter == Control.MOUSE_FILTER_IGNORE, path + " does not block hover/click input")


func _test_clean_layout_sizes(overlay) -> void:
	var list_panel := overlay.get_node_or_null("MainBrushPanel/ListPanel") as TextureRect
	var detail_panel := overlay.get_node_or_null("MainBrushPanel/DetailPanelArt") as TextureRect
	var checkout := overlay.get_node_or_null("CheckoutBar") as Control
	var gold_area := overlay.get_node_or_null("CheckoutBar/GoldAreaArt") as TextureRect
	var item_list := overlay.get_node_or_null("ItemList") as Control
	var quantity := overlay.get_node_or_null("CheckoutBar/QuantityControl") as Control
	var purchase := overlay.get_node_or_null("CheckoutBar/PurchaseButton") as Control
	var total := overlay.get_node_or_null("CheckoutBar/TotalLabel") as Label
	var minus_art := overlay.get_node_or_null("CheckoutBar/QuantityControl/MinusArt") as TextureRect
	var body_art := overlay.get_node_or_null("CheckoutBar/QuantityControl/BodyArt") as TextureRect
	var plus_art := overlay.get_node_or_null("CheckoutBar/QuantityControl/PlusArt") as TextureRect
	var minus_zone := overlay.get_node_or_null("CheckoutBar/QuantityControl/MinusZone") as Button
	var plus_zone := overlay.get_node_or_null("CheckoutBar/QuantityControl/PlusZone") as Button
	var purchase_art := overlay.get_node_or_null("CheckoutBar/PurchaseButton/ButtonArt") as TextureRect
	var purchase_zone := overlay.get_node_or_null("CheckoutBar/PurchaseButton/PurchaseZone") as Button
	var close := overlay.get_node_or_null("CheckoutBar/CloseButton") as Control
	if list_panel != null:
		_ok(list_panel.position == Vector2(56, 112), "list panel uses clean runtime position")
		_ok(list_panel.size == Vector2(680, 400), "list panel uses clean runtime size")
	if detail_panel != null:
		_ok(detail_panel.position == Vector2(804, 96), "detail panel uses clean runtime position")
		_ok(detail_panel.size == Vector2(432, 520), "detail panel uses clean runtime size")
	if checkout != null:
		_ok(checkout.position == Vector2(804, 96), "checkout bar overlays clean detail page controls")
		_ok(checkout.size == Vector2(432, 520), "checkout bar uses clean detail page size")
	if gold_area != null:
		_ok(gold_area.position == Vector2(28, 368), "gold area aligns to less crowded clean detail page")
		_ok(gold_area.size == Vector2(144, 56), "gold area uses clean manifest runtime size")
		_ok(not gold_area.visible, "gold area art remains hidden")
	if item_list != null:
		var first_row := item_list.get_node_or_null("Item_ale") as Control
		if first_row != null:
			_ok(first_row.size == Vector2(580, 64), "item row uses clean runtime size")
		var rows := item_list.get_children()
		if rows.size() >= 2 and rows[0] is Control and rows[1] is Control:
			var first := rows[0] as Control
			var second := rows[1] as Control
			_ok(second.position.y - first.position.y >= first.size.y + 6, "item rows fit clean list safe area")
	if quantity != null:
		_ok(quantity.position == Vector2(160, 408), "quantity control sits to the right of the total on clean detail page")
		_ok(quantity.size == Vector2(108, 36), "quantity control uses compact right-of-total buttons")
	if quantity != null and total != null:
		_ok(not Rect2(quantity.position, quantity.size).intersects(Rect2(total.position, total.size)), "quantity control does not cover the total label")
		_ok(quantity.position.x >= total.position.x + total.size.x + 8.0, "quantity control is placed to the right of the total text")
	if minus_art != null:
		_ok(minus_art.position == Vector2.ZERO and minus_art.size == Vector2(36, 36), "minus art uses compact right-of-total size")
	if body_art != null:
		_ok(body_art.position == Vector2(36, 0) and body_art.size == Vector2(36, 36), "quantity body uses compact right-of-total size")
	if plus_art != null:
		_ok(plus_art.position == Vector2(72, 0) and plus_art.size == Vector2(36, 36), "plus art uses compact right-of-total size")
	if minus_zone != null:
		_ok(minus_zone.position == Vector2.ZERO and minus_zone.size == Vector2(36, 36), "minus input zone matches the compact art")
	if plus_zone != null:
		_ok(plus_zone.position == Vector2(72, 0) and plus_zone.size == Vector2(36, 36), "plus input zone matches the compact art")
	if purchase != null:
		_ok(purchase.position == Vector2(272, 404), "purchase seal sits back on the clean detail page paper")
		_ok(purchase.size == Vector2(104, 96), "purchase control uses compact clean seal size")
	if purchase_art != null:
		_ok(purchase_art.position == Vector2.ZERO and purchase_art.size == Vector2(96, 96), "purchase seal art remains inside its compact control")
	if purchase != null and purchase_art != null:
		_ok(purchase.position.x + purchase_art.position.x + purchase_art.size.x <= 368.0, "purchase seal visible art stays on the paper safe area")
	if purchase_zone != null:
		_ok(purchase_zone.position == Vector2.ZERO and purchase_zone.size == Vector2(104, 96), "purchase input zone stays inside the detail page")
	if quantity != null and purchase != null:
		_ok(not Rect2(quantity.position, quantity.size).intersects(Rect2(purchase.position, purchase.size)), "quantity plus and purchase seal do not overlap")
		_ok(purchase.position.x + purchase.size.x <= 432.0, "purchase seal stays inside the right page edge")
	if close != null:
		_ok(close.position == Vector2(352, 8), "close control aligns to clean detail page")
		_ok(close.size == Vector2(80, 128), "close control uses clean manifest runtime size")


func _rect_contains(parent: Control, child: Control) -> bool:
	var parent_rect := Rect2(parent.position, parent.size)
	var child_rect := Rect2(child.position, child.size)
	return parent_rect.encloses(child_rect)


func _test_nearest_filtering(overlay) -> void:
	for path in ["ShopBackdrop", "MainBrushPanel/ListPanel", "MainBrushPanel/DetailPanelArt", "CheckoutBar/StripArt", "CheckoutBar/GoldAreaArt"]:
		var rect := overlay.get_node_or_null(path) as TextureRect
		if rect != null:
			_ok(rect.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, path + " uses nearest texture filtering")


func _ok_shop_clean_texture(overlay, path: String) -> void:
	var node: Node = overlay.get_node_or_null(path)
	_ok(node is TextureRect, path + " is TextureRect")
	var rect := node as TextureRect
	if rect == null:
		return
	_ok(rect.texture != null, path + " has texture")
	if rect.texture != null:
		_ok(rect.texture.resource_path.contains("/shop_clean/"), path + " uses shop_clean texture")


func _test_shop_clean_texture_paths(overlay) -> void:
	for path in [
		"ShopBackdrop",
		"MainBrushPanel/ListPanel",
		"MainBrushPanel/DetailPanelArt",
		"DetailPanel/TitleSlipArt",
		"DetailPanel/BodyPanelArt",
		"DetailPanel/UsesPanelArt",
		"CheckoutBar/StripArt",
		"CheckoutBar/GoldAreaArt",
		"CategoryTabs/MaterialsArt",
		"CategoryTabs/RecipesArt",
		"CategoryTabs/AbilitiesArt",
		"ItemList/Item_ale/RowArt",
		"CheckoutBar/QuantityControl/MinusArt",
		"CheckoutBar/QuantityControl/BodyArt",
		"CheckoutBar/QuantityControl/PlusArt",
		"CheckoutBar/PurchaseButton/ButtonArt",
		"CheckoutBar/CloseButton/ButtonArt",
	]:
		_ok_shop_clean_texture(overlay, path)


func _texture_path(node: Node) -> String:
	var rect := node as TextureRect
	if rect == null or rect.texture == null:
		return ""
	return String(rect.texture.resource_path)


func _ok_texture_suffix(overlay, path: String, suffix: String, msg: String) -> void:
	var node: Node = overlay.get_node_or_null(path)
	_ok(node is TextureRect, msg + " node exists")
	if node is TextureRect:
		_ok(_texture_path(node).ends_with(suffix), msg)


func _test_shop_clean_text_safe_layout(overlay) -> void:
	var title := overlay.get_node_or_null("DetailPanel/Title") as Label
	var description := overlay.get_node_or_null("DetailPanel/Description") as Label
	var uses := overlay.get_node_or_null("DetailPanel/Uses") as Label
	var state := overlay.get_node_or_null("DetailPanel/State") as Label
	var gold := overlay.get_node_or_null("CheckoutBar/GoldLabel") as Label
	var total := overlay.get_node_or_null("CheckoutBar/TotalLabel") as Label
	var qty := overlay.get_node_or_null("CheckoutBar/QuantityControl/QuantityLabel") as Label
	var purchase_label := overlay.get_node_or_null("CheckoutBar/PurchaseButton/PurchaseLabel") as Label
	var first_row := overlay.get_node_or_null("ItemList/Item_ale") as Control
	var first_row_name := overlay.get_node_or_null("ItemList/Item_ale/Name") as Label
	var first_row_price := overlay.get_node_or_null("ItemList/Item_ale/Price") as Label
	_ok(title != null and title.position == Vector2(36, 36) and title.size == Vector2(320, 44), "detail title uses more open clean title lane")
	_ok(title != null and title.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER, "detail title remains centered inside padded lane")
	_ok(description != null and description.position == Vector2(36, 100) and description.size == Vector2(320, 120), "description uses open clean body lane")
	_ok(description != null and description.vertical_alignment == VERTICAL_ALIGNMENT_TOP, "description text is top aligned")
	_ok(uses != null and uses.position == Vector2(36, 244) and uses.size == Vector2(320, 64), "uses text uses shorter clean uses lane")
	_ok(uses != null and uses.vertical_alignment == VERTICAL_ALIGNMENT_TOP, "uses text is top aligned")
	_ok(state != null and state.position == Vector2(36, 324) and state.size == Vector2(320, 34), "state text uses clean lower lane above controls")
	_ok(state != null and state.vertical_alignment == VERTICAL_ALIGNMENT_TOP, "state text is top aligned")
	_ok(gold != null and gold.position == Vector2(36, 380) and gold.size == Vector2(104, 30), "gold label stays inside clean gold tag")
	_ok(total != null and total.position == Vector2(36, 412) and total.size == Vector2(116, 30), "total label leaves room for quantity controls on its right")
	_ok(qty != null and qty.position == Vector2(38, 4) and qty.size == Vector2(32, 26), "quantity label stays centered inside compact quantity body")
	_ok(purchase_label != null and purchase_label.position == Vector2(10, 16) and purchase_label.size == Vector2(92, 36), "purchase label contract stays on compact clean seal")
	_ok(purchase_label != null and not purchase_label.visible and purchase_label.text == "", "purchase seal has no visible command text")
	_ok(first_row_name != null and first_row != null and first_row_name.position == Vector2(76, 11) and first_row_name.size == Vector2(300, 34), "first item row name uses padded text lane")
	_ok(first_row_price != null and first_row != null and first_row_price.position == Vector2(448, 11) and first_row_price.size == Vector2(108, 34), "first item row price uses dedicated price lane")
	_ok((overlay.get_node_or_null("CategoryTabs/MaterialsLabel") as Label).position == Vector2(124, 80), "materials tab text centers a little lower on clean tab face")
	_ok((overlay.get_node_or_null("CategoryTabs/RecipesLabel") as Label).position == Vector2(316, 80), "recipes tab text centers a little lower on clean tab face")
	_ok((overlay.get_node_or_null("CategoryTabs/AbilitiesLabel") as Label).position == Vector2(508, 80), "abilities tab text centers a little lower on clean tab face")
	for path in ["CategoryTabs/MaterialsLabel", "CategoryTabs/RecipesLabel", "CategoryTabs/AbilitiesLabel"]:
		var tab_label := overlay.get_node_or_null(path) as Label
		_ok(tab_label != null and tab_label.size == Vector2(128, 28), path + " uses clean tab face text size")


func _test_shop_clean_direct_state_textures(overlay) -> void:
	var recipes_zone := overlay.get_node_or_null("CategoryTabs/RecipesZone") as Button
	_ok(recipes_zone != null, "recipes tab hover zone exists")
	if recipes_zone != null:
		recipes_zone.emit_signal("mouse_entered")
		await get_tree().process_frame
		_ok_texture_suffix(overlay, "CategoryTabs/RecipesArt", "shop_clean_tab_hover.png", "recipes tab uses clean hover texture")
		recipes_zone.emit_signal("mouse_exited")
		await get_tree().process_frame
		_ok_texture_suffix(overlay, "CategoryTabs/RecipesArt", "shop_clean_tab_normal.png", "recipes tab returns to clean normal texture")

	var row_zone := overlay.get_node_or_null("ItemList/Item_grape/ClickZone") as Button
	_ok(row_zone != null, "item row hover zone exists")
	if row_zone != null:
		row_zone.emit_signal("mouse_entered")
		await get_tree().process_frame
		_ok_texture_suffix(overlay, "ItemList/Item_grape/RowArt", "shop_clean_item_row_hover.png", "item row uses clean hover texture")
		row_zone.emit_signal("mouse_exited")
		await get_tree().process_frame
		_ok_texture_suffix(overlay, "ItemList/Item_grape/RowArt", "shop_clean_item_row_normal.png", "item row returns to clean normal texture")

	var minus_zone := overlay.get_node_or_null("CheckoutBar/QuantityControl/MinusZone") as Button
	_ok(minus_zone != null, "minus quantity hover zone exists")
	if minus_zone != null:
		minus_zone.emit_signal("mouse_entered")
		await get_tree().process_frame
		_ok_texture_suffix(overlay, "CheckoutBar/QuantityControl/MinusArt", "shop_clean_quantity_button_minus_hover.png", "minus uses clean hover texture")
		minus_zone.emit_signal("button_down")
		await get_tree().process_frame
		_ok_texture_suffix(overlay, "CheckoutBar/QuantityControl/MinusArt", "shop_clean_quantity_button_minus_hover.png", "minus keeps clean hover texture while pressed")
		minus_zone.emit_signal("button_up")
		await get_tree().process_frame

	var purchase_zone := overlay.get_node_or_null("CheckoutBar/PurchaseButton/PurchaseZone") as Button
	_ok(purchase_zone != null, "purchase hover zone exists")
	if purchase_zone != null:
		purchase_zone.emit_signal("mouse_entered")
		await get_tree().process_frame
		_ok_texture_suffix(overlay, "CheckoutBar/PurchaseButton/ButtonArt", "shop_clean_purchase_seal_hover.png", "purchase uses clean hover texture")
		purchase_zone.emit_signal("button_down")
		await get_tree().process_frame
		_ok_texture_suffix(overlay, "CheckoutBar/PurchaseButton/ButtonArt", "shop_clean_purchase_seal_pressed.png", "purchase uses clean pressed texture")
		purchase_zone.emit_signal("button_up")
		purchase_zone.emit_signal("mouse_exited")
		await get_tree().process_frame

	var close_zone := overlay.get_node_or_null("CheckoutBar/CloseButton/CloseZone") as Button
	_ok(close_zone != null, "close hover zone exists")
	if close_zone != null:
		close_zone.emit_signal("mouse_entered")
		await get_tree().process_frame
		_ok_texture_suffix(overlay, "CheckoutBar/CloseButton/ButtonArt", "shop_clean_close_tag_hover.png", "close uses clean hover texture")
		close_zone.emit_signal("button_down")
		await get_tree().process_frame
		_ok_texture_suffix(overlay, "CheckoutBar/CloseButton/ButtonArt", "shop_clean_close_tag_hover.png", "close keeps clean hover texture while pressed")
		close_zone.emit_signal("button_up")
		close_zone.emit_signal("mouse_exited")
		await get_tree().process_frame


func _test_recipe_unlocks_are_pageable_without_default_scrollbar(overlay) -> void:
	var item_list := overlay.get_node_or_null("ItemList") as Control
	_ok(item_list != null and not (item_list is ScrollContainer),
		"shop item list remains custom drawn instead of using a default ScrollContainer")
	overlay.select_category("recipes")
	await get_tree().process_frame
	var page_up := overlay.get_node_or_null("ItemPageUp/Zone") as Button
	var page_down := overlay.get_node_or_null("ItemPageDown/Zone") as Button
	var page_indicator := overlay.get_node_or_null("ItemPageIndicator") as Label
	_ok(page_up != null, "shop list exposes a custom page-up input zone")
	_ok(page_down != null, "shop list exposes a custom page-down input zone")
	_ok(page_indicator != null and page_indicator.visible, "shop list shows a compact page indicator when recipe unlocks exceed one page")
	_ok(item_list.get_child_count() <= 5, "shop list keeps the visible row count within the clean list art")
	_ok(overlay.get_node_or_null("ItemList/Item_bitter_black_ale") == null,
		"new recipe unlocks start beyond the first visible recipe page")
	if page_down != null:
		page_down.pressed.emit()
		await get_tree().process_frame
	_ok(overlay.get_node_or_null("ItemList/Item_bitter_black_ale") != null,
		"custom shop paging reveals recipe unlocks beyond the first five rows")
	_ok(item_list.get_child_count() <= 5, "paged shop list still keeps the visible row count within the clean list art")
	overlay.select_item("mushroom_meat_pie")
	var title := overlay.get_node_or_null("DetailPanel/Title") as Label
	var total := overlay.get_node_or_null("CheckoutBar/TotalLabel") as Label
	_ok(title != null and title.text != "", "new recipe unlocks have detail title text")
	_ok(total != null and total.text.contains("50"), "new recipe unlocks use their shop.json price in detail totals")
	if page_up != null:
		page_up.pressed.emit()
		await get_tree().process_frame
	overlay.select_category("materials")
	await get_tree().process_frame


func _test_default_selection(overlay) -> void:
	_ok(overlay.get_selected_key() == "ale", "default material selection is ale")
	var title := overlay.get_node_or_null("DetailPanel/Title") as Label
	if title != null:
		_ok(title.text == "麦芽", "detail title shows selected item name")
	var uses := overlay.get_node_or_null("DetailPanel/Uses") as Label
	if uses != null:
		_ok(uses.text.contains("麦芽酒"), "material detail shows recipe usage")


func _test_material_quantity_total(overlay) -> void:
	var gm = get_node("/root/GameManager")
	gm.economy.current_day = 1
	overlay.select_item("ale")
	overlay.set_quantity(3)
	var total := overlay.get_node_or_null("CheckoutBar/TotalLabel") as Label
	if total != null:
		_ok(total.text.contains("6"), "quantity total uses material unit price")
	_ok(overlay.get_quantity() == 3, "overlay stores selected quantity")


func _test_mira_discount_state(overlay) -> void:
	var gm = get_node("/root/GameManager")
	gm.economy.current_day = 4
	overlay.select_item("ale")
	overlay.set_quantity(1)
	var total := overlay.get_node_or_null("CheckoutBar/TotalLabel") as Label
	if total != null:
		_ok(total.text.contains("1"), "Mira day material total uses discounted unit price")
	var state := overlay.get_node_or_null("DetailPanel/State") as Label
	if state != null:
		_ok(state.text.contains("2→1金"), "Mira day state shows base to discount price")


func _test_purchase_updates_inventory_and_gold(overlay) -> void:
	var gm = get_node("/root/GameManager")
	gm.economy.current_day = 1
	gm.economy.gold = 30
	var before_count: int = gm.inventory_sys.get_count("ale")
	overlay.select_item("ale")
	overlay.set_quantity(2)
	overlay.purchase_selected()
	await get_tree().process_frame
	_ok(gm.inventory_sys.get_count("ale") == before_count + 2, "buying material adds inventory")
	_ok(gm.economy.gold == 26, "buying two ale spends 4 gold")
	_ok(overlay.get_quantity() == 0, "material quantity resets after successful purchase")


func _test_recipe_copy_describes_shop_as_menu_registration(overlay) -> void:
	overlay.select_category("recipes")
	await get_tree().process_frame
	overlay.select_item("spiced_wine")
	await get_tree().process_frame
	var desc := overlay.get_node_or_null("DetailPanel/Description") as Label
	var uses := overlay.get_node_or_null("DetailPanel/Uses") as Label
	if desc != null:
		_ok(not desc.text.contains("解锁后可制作"), "recipe shop description no longer implies purchase gates crafting")
		_ok(desc.text.contains("公开菜谱"), "recipe shop description frames purchase as buying a public recipe")
	if uses != null:
		_ok(not uses.text.contains("解锁后可制作"), "recipe shop usage no longer says purchase enables crafting")
		_ok(uses.text.contains("配方书") and uses.text.contains("点单池"),
			"recipe shop usage explains recipe book reveal and regular order pool")


func _test_owned_recipe_state(overlay) -> void:
	var gm = get_node("/root/GameManager")
	gm.craft.unlock_recipe("herbal_ale")
	overlay.select_category("recipes")
	await get_tree().process_frame
	overlay.select_item("herbal_ale")
	var purchase := overlay.get_node_or_null("CheckoutBar/PurchaseButton/PurchaseZone") as Button
	if purchase != null:
		_ok(purchase.disabled, "owned recipe disables purchase button")
	var state := overlay.get_node_or_null("DetailPanel/State") as Label
	if state != null:
		_ok(state.text.contains("已拥有"), "owned recipe state is visible")
	var owned_mark := overlay.get_node_or_null("DetailPanel/OwnedMark") as TextureRect
	_ok(owned_mark != null, "owned recipe marker compatibility node remains")
	if owned_mark != null:
		_ok(not owned_mark.visible, "owned recipe no longer shows cropped marker art")
		_ok(owned_mark.texture == null, "owned recipe marker no longer references cropped marker texture")


func _test_close_signal(overlay) -> void:
	var state := {"closed": false}
	overlay.closed.connect(func(): state["closed"] = true)
	overlay.close()
	await get_tree().process_frame
	_ok(bool(state["closed"]), "close emits closed signal")
	_ok(not overlay.visible, "overlay hides after close")
